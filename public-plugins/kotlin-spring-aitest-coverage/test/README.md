# kotlin-spring-aitest-coverage 테스트

`method-coverage-get.sh` · `diff-coverage-validate.sh` · `aitest-coverage-validate.sh`(훅) · `ensure-docker-for-aitest.sh.tmpl` 의 회귀 테스트.

## 실행

```bash
test/diff-coverage-validate.test.sh          # 전체 (~50초)
test/diff-coverage-validate.test.sh TC-K     # ID 접두사로 필터
```

**실제 git 저장소**로 돈다 — 임시 저장소에 멀티 모듈(`app` 환경 블록 · `core` 라이브러리, Kotlin DSL)을 만들고 소스를 바꾼 뒤, 손으로 만든 JaCoCo XML 로 판정한다.
`./gradlew` 는 호출 인자만 남기는 스텁이다. `javap` 도 스텁(`AITEST_JAVAP`)이다 — 클래스 파일 자리에 둔 **실제 javap 출력**(Kotlin 2.2.21 로 컴파일한 소스를 JDK 17 `javap -p -s -l` 로 뜬 것, 스크립트의 `javap_of`)을 그대로 낸다. 그래서 Gradle · JDK · Docker 없이 결정적으로 돈다.
`Pricing.kt` 픽스처의 메서드 · 명령 수(`PRICING_METHODS`)는 같은 소스를 JaCoCo 0.8.15 로 잰 실제 리포트에서 옮겼다.

Gradle · testcontainer 까지 태우는 확인은 자동 TC 가 아니다. 아래 "수동 확인" 을 본다.

## 자동 TC (88건)

### A. 메서드 커버리지 (method-coverage-get.sh)

| ID | 케이스 |
|---|---|
| TC-M01 | 변경 메서드가 100% 면 OK |
| TC-M02 | 변경 메서드가 100% 미만이면 FAIL |
| TC-M03 | 바뀌지 않은 메서드는 0% 여도 판정하지 않는다 |
| TC-M04 | untracked 새 파일은 전 줄을 변경으로 본다 |
| TC-M05 | 리포트가 없으면 FAIL |
| TC-M06 | 파일의 클래스가 리포트에 없으면 측정 대상 아님 |
| TC-M07 | 같은 이름 파일이 다른 패키지에 있어도 섞지 않는다 |

### B. Kotlin 메서드 귀속 (method-coverage-get.sh, 실제 javap 줄 표)

규칙 원본 3절의 합성 메서드 규칙마다 하나씩, 그리고 판정 불가(`C-09`).

| ID | 케이스 |
|---|---|
| TC-K01 | 패키지 ≠ 디렉터리 — package 선언으로 리포트를 찾는다 |
| TC-K02 | @JvmStatic 브리지는 판정하지 않고 companion 메서드로 판정한다 |
| TC-K03 | 같은 줄의 name$default 는 빼고 name 으로 판정한다 |
| TC-K04 | 기본값 식 줄만 바꾸면 name$default 를 판정한다 |
| TC-K05 | 주 생성자 줄 — 접근자 · DefaultConstructorMarker 생성자는 빼고 <init> 으로 판정한다 |
| TC-K06 | init 블록 줄은 주 생성자 <init> 으로 판정한다 |
| TC-K07 | 접근자만 있는 줄(lateinit)은 빼지 않고 접근자로 판정한다 |
| TC-K08 | data class 헤더 줄 — 접근자는 빼고 <init> 으로 판정한다 |
| TC-K09 | 람다 본문 줄은 <바깥>$lambda$N 으로 판정한다 |
| TC-K10 | 로컬 함수 줄은 <바깥>$<로컬> 로 판정한다 — 바깥 함수보다 앞줄이어도 |
| TC-K11 | 최상위 함수는 <파일>Kt 클래스로 판정한다 |
| TC-K12 | inline 함수 본문은 inline 함수로 판정하고 인라인된 호출부(가짜 줄)는 고르지 않는다 |
| TC-K13 | companion 메서드는 <클래스>$Companion 으로 판정한다 |
| TC-K14 | src/main/java 의 .kt 도 build/classes/kotlin/main 으로 판정한다 |
| TC-K15 | internal 의 $<모듈> · value class 의 -<hash> 는 표시할 때 뗀다 |
| TC-K16 | javap 이 없으면 판정 불가(2)로 끝난다 (C-09) |
| TC-K17 | 클래스 파일이 없으면 판정 불가(2)로 끝난다 (C-09) |
| TC-K18 | macOS 기본 bash 3.2 로 새 파일 전 줄을 규칙대로 고른다 |

### C. diff 판정 (diff-coverage-validate.sh)

| ID | 케이스 |
|---|---|
| TC-D01 | diff 가 없으면 OK |
| TC-D02 | main Kotlin · mapper · aiTest 밖의 변경만 있으면 OK — main 의 .java 는 보지 않는다 |
| TC-D03 | 변경 Controller 에 aiTest 가 없으면 막는다 (C-01) |
| TC-D04 | aiTest 에 <Controller>…AiTest 클래스가 있으면 인정한다 (C-01) |
| TC-D05 | aiTest 본문에 클래스명이 단어로 나오면 인정한다 (C-01) |
| TC-D06 | 부분 문자열(FooControllerHelper)은 인정하지 않는다 (C-01) |
| TC-D07 | report-only: 리포트가 없으면 막는다 (C-03) |
| TC-D08 | report-only: 리포트가 diff 보다 오래되면 막는다 (C-03) |
| TC-D09 | report-only: 최신 리포트 + 100% 면 통과한다 |
| TC-D10 | report-only: 변경 메서드가 100% 미만이면 막는다 (C-02) |
| TC-D11 | 환경 블록이 없는 모듈의 main 변경은 판정 대상이 아니다 |
| TC-D12 | libraryModules: 라이브러리 변경을 소비 모듈 리포트로 판정한다 |
| TC-D13 | libraryModules: 라이브러리 소스가 소비 모듈 리포트보다 새로우면 막는다 |
| TC-D14 | 단일 모듈 — 루트 build.gradle.kts 에 환경 블록이 있으면 루트를 모듈로 본다 |
| TC-D15 | 중첩 모듈(apps:api) — apps/api/build.gradle.kts 의 환경 블록으로 찾는다 |
| TC-D16 | 설정 .modules 가 환경 블록보다 우선한다 |
| TC-D17 | aiTest 만 바뀌면 report-only 는 리포트 최신만 본다 |
| TC-D18 | 실행: main 이 바뀐 모듈은 compileAiTestKotlin · aiTest 전체를 돌린다 |
| TC-D19 | 실행: aiTest 만 바뀌면 package 선언 + 최상위 클래스로 --tests 를 좁힌다 |
| TC-D20 | 실행: gradlew 가 실패하면 실패로 끝난다 |
| TC-D21 | 설정 파일이 JSON 이 아니면 실행 오류(2) |
| TC-D22 | macOS 기본 bash 3.2 로도 돈다 |
| TC-D23 | git 루트 ≠ Gradle 루트 — 변경 메서드가 100% 미만이면 막는다 (C-02) |
| TC-D24 | git 루트 ≠ Gradle 루트 — 최신 리포트 + 100% 면 통과한다 |
| TC-D25 | 지운 Controller 는 C-01 대상이 아니다 |
| TC-D26 | Controller 를 지우며 다른 Controller 를 바꾸면 그 Controller 는 막는다 (C-01) |
| TC-D27 | 모듈 디렉터리에서 연 세션도 Gradle 루트 기준으로 보고 100% 미만을 막는다 (C-02) |
| TC-D28 | --also: 그 ref 와 같은 파일은 보지 않는다 |
| TC-D29 | 파일 이름과 다른 @RestController 클래스도 C-01 대상이다 |
| TC-D30 | src/main/java 의 .kt 도 모듈 변경으로 본다 (C-01) |
| TC-D31 | 판정 도구(javap)가 없으면 실행 오류(2)로 끝난다 (C-09) |

### D. 훅 (aitest-coverage-validate.sh)

| ID | 케이스 |
|---|---|
| TC-H01 | git 저장소가 아니면 조용히 통과한다 |
| TC-H02 | 이번 요청에서 diff 가 그대로면 막지 않는다 (C-05) |
| TC-H03 | 요청 중 Controller 를 바꾸고 aiTest 가 없으면 막는다 (C-01) |
| TC-H04 | 최신 리포트 + 100% 면 통과한다 |
| TC-H05 | stop_hook_active 면 허용하고 systemMessage 로 남긴다 (C-08) |
| TC-H06 | ACK 면제가 있으면 통과한다 (C-07) |
| TC-H07 | 환경 블록이 없으면 막지 않고 세션당 한 번만 알린다 (C-06) |
| TC-H08 | Java 판 환경(gradle/ai-test.gradle)만 있으면 이 게이트는 꺼져 있다고 알린다 |
| TC-H09 | 소비 모듈을 모르는 main 변경에 aiTest diff 가 없으면 막는다 (C-04) |
| TC-H10 | 소비 모듈을 모르는 main 변경이어도 aiTest diff 가 있으면 통과한다 (C-04) |
| TC-H11 | 테스트만 바뀌면 막지 않는다 |
| TC-H12 | 하위 디렉터리에서 호출해도 저장소 루트 기준으로 본다 |
| TC-H13 | 요청 안에서 커밋한 Controller 변경도 본다 (C-05) |
| TC-H14 | 요청 시작 때 원격 기본 브랜치에 있던 커밋은 요청 안에서 합쳐도 이번 변경이 아니다 (C-05) |
| TC-H15 | 요청 안에서 커밋하고 원격 기본 브랜치로 push 해도 막는다 (C-05) |
| TC-H16 | 요청 시작 HEAD 를 amend 해도 막는다 (C-05) |
| TC-H17 | amend 가 대상 경로를 건드리지 않으면 막지 않는다 (C-05) |
| TC-H18 | git 루트 ≠ Gradle 루트 — Gradle 루트 아래 환경 블록으로 게이트를 켜고 0% 를 막는다 (C-02 · C-06) |
| TC-H19 | Controller 와 그 aiTest 를 지우면 막지 않는다 (C-01) |
| TC-H20 | 모듈 디렉터리에서 연 세션이 그 밖의 모듈을 고쳐도 본다 (C-04) |
| TC-H21 | 요청 전에 커밋한 Controller 를 요청 안에서 메시지만 amend 하면 막지 않는다 (C-05) |
| TC-H22 | 요청 전 Controller 커밋을 amend 하며 대상 밖 파일만 더하면 막지 않는다 (C-05) |
| TC-H23 | 요청 전 받아둔 원격 위로 요청 안에서 리베이스하면 원격 변경도 이전 커밋도 막지 않는다 (C-05) |
| TC-H24 | 요청 전 받아둔 원격을 요청 안에서 merge 커밋으로 합쳐도 원격 변경은 막지 않는다 (C-05) |
| TC-H25 | jq 가 없어도 막는다 |
| TC-H26 | jq 가 없어도 stop_hook_active 를 읽고 systemMessage 를 올바른 JSON 으로 낸다 (C-08) |
| TC-H27 | 상태 · ACK 는 Gradle 루트의 .claude/kotlin-spring-aitest-coverage/ 에 두고 git status 에 나오지 않는다 |
| TC-H28 | Gradle Kotlin DSL 이 아니면 조용히 통과하고 상태를 만들지 않는다 |
| TC-H29 | 판정 도구(javap)가 없으면 막는다 (C-09) |
| TC-H30 | 아직 커밋하지 않은 환경 블록도 환경으로 본다 |

### E. Docker 준비 템플릿 (ensure-docker-for-aitest.sh.tmpl)

`docker` · `colima` · `open` 은 호출만 남기는 스텁, `HOME` 은 임시 디렉터리다.

| ID | 케이스 |
|---|---|
| TC-E01 | 데몬이 이미 응답하면 기동 · context 변경 · ~/.testcontainers.properties 수정을 하지 않는다 |
| TC-E02 | 데몬이 없으면 colima 를 띄우고 reuse 설정을 만든다 |

## 수동 확인 — 실제 Gradle · testcontainer

템플릿 · Gradle 연동은 샘플 프로젝트로 확인한다. 0.1.0 에서 확인한 조합은 둘이다(지원 하한 · 상한). 템플릿을 고치면 둘을 다시 돌린다. 둘 다 Docker 데몬이 응답하는 머신에서 실제 컨테이너로 돌렸다.

| 조합 | Boot | Gradle | Kotlin | JDK | TC | 구성 | 인프라 · 분기 | 결과 |
|---|---|---|---|---|---|---|---|---|
| A | 3.5.16 | 8.14.4 | 2.2.21 | 17 | 1.21 (Boot BOM) | 멀티 모듈 `app` + 라이브러리 `core` + 지원 모듈 · 루트 `subprojects` 저장소 | PostgreSQL · `LIBRARIES` · SpringMockK 이미 있음 | 1 ~ 8 전부 |
| B | 4.1.1 | 9.8.0 | 2.4.21 | 17 | 2.0.5 (Boot BOM) | 단일 모듈 + 지원 모듈 · 패키지 ≠ 디렉터리(공통 루트 생략) · 파일 이름 ≠ Controller | MySQL · Redis · `BOOT4` · `TC2` · `ADD_MOCKK` · `COROUTINES` · `CUSTOM_PROPS` | 1 ~ 8 전부 (`suspend` 는 `discount$suspendImpl` 로 판정) |

순서:

1. `kotlin-aitest-environment-create` 순서대로 템플릿을 채운다 — `{{` 잔재 0
2. `./gradlew --warning-mode all :<앱>:compileAiTestKotlin` 이 경고 없이 성공 (`associateWith` · `testing` · `JacocoReport` 블록)
3. `:<앱>:aiTest --tests '*TestSupportSmokeAiTest*' -PskipAiTestCoverage` PASS — 운영 URL(`db.internal` · `redis.internal`)이 `@ServiceConnection` 컨테이너로 덮이고, 메타 애노테이션의 `@TestConstructor` · `@Import` 가 동작한다
4. 훅 `snapshot` → main 메서드 변경 → 훅(Stop) 이 `C-01` 로 exit 2. 상태 디렉터리는 `git status` 에 나오지 않는다
5. 분기 일부만 덮는 aiTest → `diff-coverage-validate.sh <ref>` 가 그 메서드를 100% 미만으로 FAIL (A `bar` 75%, B `price` 50% · `discount$suspendImpl` 91%)
6. 남은 분기를 덮음 → PASS, 훅 통과. 컨텍스트 설정이 다른 두 테스트(NONE · MOCK)가 재사용 컨테이너로 같이 돈다
7. main 을 다시 고치면 `C-03` 재차단 · aiTest 만 바꾸면 `--tests <패키지>.<클래스>` 로 그 클래스만 돌고 리포트가 갱신된다
8. (A) `core` 를 고치면 `C-04` → `libraryModules` 설정 뒤 `C-03` → `core` 클래스가 `app` 리포트에 나와 `C-02` 판정 (`internal` 의 `secret$core` 를 `secret` 으로 표시)

같은 샘플에서 본 Kotlin 바이트코드 사실 (판정 규칙의 근거):

| 사실 | A (2.2.21) | B (2.4.21) |
|---|---|---|
| `@JvmStatic` 브리지 | companion 메서드는 본문 줄, 브리지는 닫는 `}` 줄 — JaCoCo 0.8.15 에서 `mi=1` 로 남는다 | - |
| 람다 · 로컬 함수 이름 | `runner$lambda$0` · `withLocal$helper` | `tagger$lambda$0` · `withLocal$helper` (같다) |
| `internal` 이름 | 서브프로젝트 `core` → `secret$core` (group 을 줘도 같다) | 루트 프로젝트 `shopb` + group `demo` → `hidden$demo_shopb`, group 이 없으면 `hidden$shopb` |
| inline 함수 | 호출부에 파일 길이(63줄)를 넘는 줄 65 ~ 69 가 남고, 리포트는 inline 함수 자체를 100% 로 잰다 | - |
| data class | `copy` · `componentN` 은 줄 표가 없고 리포트에도 없다. 헤더 줄에 `<init>` · `getX` 만 | - |
| open 클래스의 `suspend` | - | 본문은 `name$suspendImpl` 에 있고 `name` 은 줄 표가 없다 |

실측 중 Docker 데몬이 한 번 응답을 멈췄다가 돌아왔다(직접 띄우지 않았다). 그사이 B 의 5단계가 `Connection refused` 로 실패했고, 데몬이 돌아온 뒤 같은 테스트가 통과했다.

## 수동 확인 — 실제 Claude Code 세션의 Stop 게이트

`evals/coverage-blocked` 는 Bash 샌드박스가 필요해 막힌 머신에서는 ⚠️ 로 건너뛴다. 그때는 같은 픽스처로 헤드리스 세션을 직접 돌린다. 0.1.0 에서는 돌리지 않았다.

```bash
mkdir /tmp/live && cd /tmp/live && bash <plugin>/evals/coverage-blocked/fixture.sh
claude -p "PriceController 의 price 에서 percent 가 100 이상이면 0 을 돌려주게 고쳐줘. 테스트는 쓰지 마." \
  --plugin-dir <plugin> --setting-sources project --permission-mode acceptEdits --allowedTools "Read,Edit" \
  --output-format stream-json --verbose > live.jsonl
grep -c '완료 보류(kotlin-spring-aitest-coverage)' live.jsonl      # 1 이상
```
