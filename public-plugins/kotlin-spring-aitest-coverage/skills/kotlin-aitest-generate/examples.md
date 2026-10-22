# Kotlin @AiTest 코드 형태 · 시드 함정

[SKILL.md](SKILL.md) 4절에서 테스트를 실제로 쓸 때 연다. 규칙 · 게이트는 SKILL.md 와 규칙 원본이 정한다 — 여기는 형태와 함정만.
패키지 · 클래스 이름은 예시다. 메타 애노테이션의 패키지는 프로젝트의 지원 모듈(`<base>.test.support`)을 따른다.

## `@AiTest` — 서비스 · 리포지토리 (기본)

```kotlin
/** 검증 대상: OrderService.cancel */
@AiTest
@DisplayName("주문 취소 @AiTest")
class OrderServiceAiTest(
    private val sut: OrderService,
    private val orderRepository: OrderRepository,
) {
    @MockkBean                                          // 외부 경계만 목 (SpringMockK)
    private lateinit var paymentClient: PaymentClient

    @BeforeEach
    fun seed() {
        orderRepository.save(Order(id = ORDER_ID, status = OrderStatus.PAID))
        every { paymentClient.refund(any()) } just Runs
    }

    @Test
    fun `결제 완료 주문을 취소하면 상태가 취소로 바뀌고 환불을 요청한다`() {
        // when
        sut.cancel(ORDER_ID)
        // then
        assertThat(orderRepository.findById(ORDER_ID).get().status).isEqualTo(OrderStatus.CANCELED)
        verify(exactly = 1) { paymentClient.refund(ORDER_ID) }
    }

    @Test
    fun `없는 주문이면 예외이고 환불을 요청하지 않는다`() {
        assertThrows<OrderNotFoundException> { sut.cancel(-1L) }
        verify { paymentClient wasNot Called }
    }

    companion object {
        const val ORDER_ID = 910_001L                   // 다른 aiTest 와 겹치지 않는 대역
    }
}
```

- `@MockkBean` 은 생성자 주입이 아니라 `lateinit var` 필드에 둔다 — 목 빈은 컨텍스트가 필드에 넣는다
- mockito-kotlin 을 쓰는 프로젝트면 `@MockitoBean` + `whenever(…)` · `verify(…)`. Mockito 의 `any()` 는 non-null 파라미터에서 NPE 를 낸다 — mockito-kotlin 의 `any()` 를 쓴다

JPA Auditing 이 요청 컨텍스트(로그인 사용자)를 요구해 시드가 터지면 감사 빈을 테스트에서 고정한다. 빈 이름은 `@EnableJpaAuditing(auditorAwareRef = …)` 와 같아야 한다.

```kotlin
@TestConfiguration(proxyBeanMethods = false)
class FixedAuditorConfig {
    @Bean("auditorAware")
    @Primary
    fun auditorAware(): AuditorAware<Long> = AuditorAware { Optional.of(0L) }
}
```

## `suspend` 함수 — `runTest`

```kotlin
@Test
fun `100 퍼센트 이상 할인이면 0`() = runTest {
    assertThat(sut.discount(1_000, 100)).isEqualTo(0)
}

@Test
fun `외부 조회가 실패하면 기본 가격을 쓴다`() = runTest {
    coEvery { priceClient.fetch(any()) } throws IOException("down")
    assertThat(sut.price(ITEM_ID)).isEqualTo(DEFAULT_PRICE)
    coVerify(exactly = 1) { priceClient.fetch(ITEM_ID) }
}
```

- `delay` 는 `runTest` 의 가상 시간으로 건너뛴다. 60초가 넘으면 실패한다(`runTest(timeout = …)`)
- 대상이 `withContext(Dispatchers.IO)` 로 넘기면 가상 시간이 적용되지 않는다 — 디스패처를 생성자로 받게 돼 있으면 테스트에서 `StandardTestDispatcher(testScheduler)` 를 넘긴다

## 여러 케이스 — `@ParameterizedTest`

```kotlin
@ParameterizedTest(name = "{0}일 전 가격 → 노출={1}")
@CsvSource("0, true", "1, false", "3, false")           // 경계: 당일 / 하루 전 / 그 이상
fun `당일 가격만 노출된다`(daysBefore: Int, visible: Boolean) { … }

@ParameterizedTest
@NullAndEmptySource
@ValueSource(strings = ["  "])                           // 경계: null · "" · 공백
fun `검색어가 비어 있으면 전체를 조회한다`(keyword: String?) { … }

@ParameterizedTest
@EnumSource(OrderStatus::class, names = ["CANCELED", "REFUNDED"])   // 실패: 허용 안 되는 상태 전수
fun `취소 · 환불된 주문은 변경할 수 없다`(status: OrderStatus) {
    assertThrows<InvalidOrderStateException> { sut.change(orderIdOf(status), request) }
}

@ParameterizedTest
@MethodSource("prices")
fun `할인율별 결과`(percent: Int, expected: Long) { … }

companion object {
    @JvmStatic
    fun prices() = listOf(Arguments.of(0, 1_000L), Arguments.of(100, 0L), Arguments.of(150, 0L))
}
```

- `@NullAndEmptySource` 는 파라미터가 `String?` 이어야 한다
- 기대 결과가 케이스마다 다르면 `@CsvSource` · `@MethodSource` 로 **입력과 기대값을 함께** 넘긴다
- `@Transactional` 롤백은 **호출마다** 적용된다. 커밋 시드(`JdbcTemplate`)를 쓰면 `@AfterEach` 정리가 매 호출 돈다

## 기본 인자 — `name$default`

```kotlin
fun apply(price: Long, percent: Int = rate): Long { … }   // 이 줄을 바꾸면 apply$default 가 판정된다

@Test
fun `할인율을 주지 않으면 기본 할인율을 쓴다`() {
    assertThat(sut.apply(1_000)).isEqualTo(900)            // 기본값을 생략한 호출
}
```

## `@AiWebTest` — 컨트롤러 경계 (MockMvc Kotlin DSL)

클래스 이름은 `<Controller>AiTest` — 게이트 `C-01` 이 aiTest 본문의 클래스 이름으로 찾는다.

```kotlin
/** 검증 대상: CategoryController.tree */
@AiWebTest
@DisplayName("상품 카테고리 조회 API @AiTest")
class CategoryControllerAiTest(
    private val mvc: MockMvc,
) {
    @Test
    fun `숨김 카테고리는 트리에서 빠진다`() {
        mvc.get(URL) { param("storeId", "910001") }
            .andExpect {
                status { isOk() }
                jsonPath("$[*].id") { value(not(hasItem(HIDDEN_ID.toInt()))) }
            }
    }

    @Test
    fun `필수 파라미터가 없으면 400`() {
        mvc.get(URL).andExpect { status { isBadRequest() } }
    }

    companion object {
        const val URL = "/api/categories"
        const val HIDDEN_ID = 910_002L
    }
}
```

- 인증이 걸린 엔드포인트는 서명 키 빈을 주입받아 토큰을 직접 만들어 헤더 · 쿠키로 태우거나 `spring-security-test` 가 이미 있으면 `@WithMockUser` 를 쓴다. 인증 자체가 검증 대상이 아니면 서비스를 직접 호출하는 `@AiTest` 가 더 싸다
- 예외 핸들러를 거치지 않고 예외가 그대로 올라오는 경로는 `assertThrows<ServletException> { mvc.get(URL) { … } }` 로 보고 `cause` 를 확인한다

## 시드 함정

- **다른 DataSource · 다른 트랜잭션은 테스트 시드를 못 본다** — MyBatis 매퍼가 별도 DataSource 를 쓰거나 대상 코드가 `REQUIRES_NEW` 로 새 트랜잭션을 열면 테스트 트랜잭션 안의 `EntityManager` 시드가 보이지 않는다. 그 DataSource 의 `JdbcTemplate` 으로 **커밋되는 시드**를 넣고 `@AfterEach` 에서 직접 지운다

  ```kotlin
  class LegacyMapperAiTest(
      @Qualifier("writeDataSource") dataSource: DataSource,
  ) {
      private val jdbc = JdbcTemplate(dataSource)
  }
  ```

- 레거시 테이블은 FK · `sql_mode` 때문에 부분 시드가 막힌다 — MySQL 이면 시드 앞에 `SET FOREIGN_KEY_CHECKS=0`, `SET SESSION sql_mode=''`
- 스키마는 `ddl-auto=update` 로 엔티티에서 만든다. 엔티티가 없는 테이블(매퍼 전용)은 모듈 `src/aiTest/resources` 에 DDL 을 두고 시드 전에 실행한다
- 커밋한 시드는 반드시 정리한다 — 컨테이너를 재사용(`withReuse`)하므로 다음 실행에 남는다
- JPA 엔티티는 `kotlin("plugin.jpa")` 가 만든 인자 없는 생성자를 Hibernate 가 쓴다. 테스트 시드는 주 생성자로 만든다

## 순수 단위 테스트 (MockK)

Spring 컨텍스트가 필요 없는 계산 · 매핑 로직에만 쓴다. **게이트를 대체하지 않는다** — 변경 메서드 커버리지는 `aiTest` 리포트로만 인정된다.

```kotlin
class OrderLineCalculatorTest {
    private val priceRepository = mockk<PriceRepository>()
    private val calculator = OrderLineCalculator(priceRepository)

    @Test
    fun `옵션 상품 수량이 부모 수량에 합산된다`() {
        every { priceRepository.findById(1L) } returns Optional.of(price)
        // when … then
    }
}
```

- 단위 테스트는 `src/test/kotlin` 에 둔다 — `src/aiTest/kotlin` 에 두면 aiTest 로 돌고 `test` 태스크에서 빠진다
- `@Transactional` · 캐시 · 락 같은 프록시 애노테이션은 단위 테스트에서 동작하지 않는다. 그 동작이 검증 대상이면 `@AiTest` 로 올린다
