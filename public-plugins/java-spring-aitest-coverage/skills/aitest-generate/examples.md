# @AiTest 코드 형태 · 시드 함정

[SKILL.md](SKILL.md) 4절에서 테스트를 실제로 쓸 때 연다. 규칙 · 게이트는 SKILL.md 와 규칙 원본이 정한다 — 여기는 형태와 함정만.
패키지 · 클래스 이름은 예시다. 메타 어노테이션의 패키지는 프로젝트의 지원 모듈(`<base>.test.support`)을 따른다.

## `@AiTest` — 서비스 · 리포지토리 (기본)

```java
/**
 * 검증 대상(수정 메서드): OrderService.cancel(...)
 * 실제 Spring 컨텍스트 + testcontainer DB + 실제 행 시드. 변경 서비스 · 리포지토리는 목으로 바꾸지 않는다.
 */
@AiTest
@DisplayName("주문 취소 @AiTest")
class OrderServiceAiTest {

    private static final long ORDER_ID = 910_001L;      // 다른 AiTest 와 겹치지 않는 대역

    @Autowired
    private OrderService sut;

    @Autowired
    private OrderRepository orderRepository;

    @MockBean
    private PaymentClient paymentClient;                // 외부 경계만 목

    @BeforeEach
    void seed() {
        orderRepository.save(Order.of(ORDER_ID, OrderStatus.PAID));
    }

    @Test
    void 결제완료_주문을_취소하면_상태가_취소로_바뀌고_환불을_요청한다() {
        // when
        sut.cancel(ORDER_ID);
        // then
        assertThat(orderRepository.findById(ORDER_ID)).get()
                .extracting(Order::getStatus).isEqualTo(OrderStatus.CANCELED);
        then(paymentClient).should().refund(ORDER_ID);
    }

    @Test
    void 없는_주문이면_예외이고_환불을_요청하지_않는다() {
        assertThatThrownBy(() -> sut.cancel(-1L))
                .isInstanceOf(OrderNotFoundException.class);
        then(paymentClient).shouldHaveNoInteractions();
    }
}
```

JPA Auditing 이 요청 컨텍스트(로그인 사용자)를 요구해 시드가 터지면 감사 빈을 테스트에서 고정한다. 빈 이름은 `@EnableJpaAuditing(auditorAwareRef = …)` 와 같아야 한다.

```java
@TestConfiguration
static class FixedAuditorConfig {
    @Bean(name = "auditorAware")
    @Primary
    AuditorAware<Long> auditorAware() { return () -> Optional.of(0L); }
}
```

## 여러 케이스 — `@ParameterizedTest`

입력만 다르고 검증 형태가 같은 경계값 · 상태 · 권한 케이스. 시드는 파라미터마다 달리해 행이 겹치지 않게 한다.

```java
@ParameterizedTest(name = "{0}일 전 가격 → 노출={1}")
@CsvSource({"0, true", "1, false", "3, false"})         // 경계: 당일 / 하루 전 / 그 이상
void 당일_가격만_노출된다(int daysBefore, boolean visible) { ... }

@ParameterizedTest
@NullAndEmptySource
@ValueSource(strings = {"  "})                           // 경계: null · "" · 공백
void 검색어가_비어있으면_전체를_조회한다(String keyword) { ... }

@ParameterizedTest
@EnumSource(value = OrderStatus.class, names = {"CANCELED", "REFUNDED"})   // 실패: 허용 안 되는 상태 전수
void 취소_환불된_주문은_변경할_수_없다(OrderStatus status) {
    assertThatThrownBy(() -> sut.change(orderIdOf(status), request))
            .isInstanceOf(InvalidOrderStateException.class);
}
```

- 기대 결과가 케이스마다 다르면 `@CsvSource` · `@MethodSource` 로 **입력과 기대값을 함께** 넘긴다
- `@Transactional` 롤백은 **호출마다** 적용된다. 커밋 시드(`JdbcTemplate`)를 쓰면 `@AfterEach` 정리가 매 호출 돈다

## `@AiWebTest` — 컨트롤러 경계 (MockMvc)

파일명은 `<Controller>AiTest.java` — 게이트 `C-01` 이 파일명으로 찾는다.

```java
@AiWebTest
@DisplayName("상품 카테고리 조회 API @AiTest")
class CategoryControllerAiTest {

    private static final String URL = "/api/categories";

    @Autowired
    private MockMvc mvc;

    @Test
    void 숨김_카테고리는_트리에서_빠진다() throws Exception {
        mvc.perform(get(URL).param("storeId", "910001"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].id", not(hasItem(HIDDEN_ID.intValue()))));
    }

    @Test
    void 필수_파라미터가_없으면_400() throws Exception {
        mvc.perform(get(URL))
                .andExpect(status().isBadRequest());
    }
}
```

- 인증이 걸린 엔드포인트는 서명 키 빈을 주입받아 토큰을 직접 만들어 헤더 · 쿠키로 태우거나 `spring-security-test` 가 이미 있으면 `@WithMockUser` 를 쓴다. 인증 자체가 검증 대상이 아니면 서비스를 직접 호출하는 `@AiTest` 가 더 싸다
- 예외 핸들러를 거치지 않고 예외가 그대로 올라오는 경로는 `assertThatThrownBy(() -> mvc.perform(...)).hasRootCauseInstanceOf(...)` 로 본다

## 시드 함정

- **다른 DataSource · 다른 트랜잭션은 테스트 시드를 못 본다** — MyBatis 매퍼가 별도 DataSource 를 쓰거나 대상 코드가 `REQUIRES_NEW` 로 새 트랜잭션을 열면 테스트 트랜잭션 안의 `EntityManager` 시드가 보이지 않는다. 그 DataSource 의 `JdbcTemplate` 으로 **커밋되는 시드**를 넣고 `@AfterEach` 에서 직접 지운다

  ```java
  private JdbcTemplate jdbc;

  @Autowired
  void setDataSource(@Qualifier("writeDataSource") DataSource dataSource) {
      this.jdbc = new JdbcTemplate(dataSource);
  }
  ```

- 레거시 테이블은 FK · `sql_mode` 때문에 부분 시드가 막힌다 — MySQL 이면 시드 앞에 `SET FOREIGN_KEY_CHECKS=0`, `SET SESSION sql_mode=''`
- 스키마는 `ddl-auto=update` 로 엔티티에서 만든다. 엔티티가 없는 테이블(매퍼 전용)은 모듈 `src/test/resources` 에 DDL 을 두고 시드 전에 실행한다
- 커밋한 시드는 반드시 정리한다 — 컨테이너를 재사용(`withReuse`)하므로 다음 실행에 남는다

## 순수 단위 테스트 (JUnit 5 + Mockito)

Spring 컨텍스트가 필요 없는 계산 · 매핑 로직에만 쓴다. **게이트를 대체하지 않는다** — 변경 메서드 커버리지는 `aiTest` 리포트로만 인정된다.

```java
@ExtendWith(MockitoExtension.class)
class OrderLineCalculatorTest {

    @Mock
    private PriceRepository priceRepository;

    @InjectMocks
    private OrderLineCalculator calculator;

    @Test
    void 옵션상품_수량이_부모수량에_합산된다() {
        // given — static import: org.mockito.BDDMockito.*
        given(priceRepository.findById(1L)).willReturn(Optional.of(price));
        // when ... then
    }
}
```

- 파일명에 `AiTest` 를 넣지 않는다 — 넣으면 `aiTest` 소스셋으로 들어가 `test` 태스크에서 빠진다
- `@Transactional` · 캐시 · 락 같은 프록시 어노테이션은 단위 테스트에서 동작하지 않는다. 그 동작이 검증 대상이면 `@AiTest` 로 올린다
