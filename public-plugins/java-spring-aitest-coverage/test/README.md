# java-spring-aitest-coverage 테스트

`method-coverage-get.sh` · `diff-coverage-validate.sh` · `aitest-coverage-validate.sh`(훅)의 회귀 테스트.

## 실행

```bash
test/diff-coverage-validate.test.sh          # 전체 (~20초)
test/diff-coverage-validate.test.sh TC-H     # ID 접두사로 필터
```

**실제 git 저장소**로 돈다 — 임시 저장소에 멀티 모듈(`app` 대상 · `core` 라이브러리)을 만들고 소스를 바꾼 뒤, 손으로 만든 JaCoCo XML 로 판정한다. `./gradlew` 는 호출 인자만 남기는 스텁이라 Gradle · Docker 가 필요 없다.

Gradle · testcontainer 까지 태우는 확인은 자동 TC 가 아니다. 아래 "수동 확인" 을 본다.

## 자동 TC (41건)

### A. 메서드 커버리지 (method-coverage-get.sh)

| ID | 케이스 |
|---|---|
| TC-M01 | 변경 메서드가 100% 면 OK |
| TC-M02 | 변경 메서드가 100% 미만이면 FAIL |
| TC-M03 | 바뀌지 않은 메서드는 0% 여도 판정하지 않는다 |
| TC-M04 | untracked 새 파일은 전 줄을 변경으로 본다 |
| TC-M05 | 리포트가 없으면 FAIL |
| TC-M06 | 클래스가 리포트에 없으면 측정 대상 아님 |
| TC-M07 | 같은 이름 클래스가 다른 패키지에 있어도 섞지 않는다 |

### B. diff 판정 (diff-coverage-validate.sh)

| ID | 케이스 |
|---|---|
| TC-D01 | diff 가 없으면 OK |
| TC-D02 | main Java · mapper · AiTest 밖의 변경만 있으면 OK |
| TC-D03 | 변경 Controller 에 AiTest 가 없으면 막는다 (C-01) |
| TC-D04 | 파일명이 <Controller>AiTest 면 인정한다 (C-01) |
| TC-D05 | 본문에 클래스명이 단어로 나오면 인정한다 (C-01) |
| TC-D06 | 부분 문자열(FooControllerHelper)은 인정하지 않는다 (C-01) |
| TC-D07 | report-only: 리포트가 없으면 막는다 (C-03) |
| TC-D08 | report-only: 리포트가 diff 보다 오래되면 막는다 (C-03) |
| TC-D09 | report-only: 최신 리포트 + 100% 면 통과한다 |
| TC-D10 | report-only: 변경 메서드가 100% 미만이면 막는다 (C-02) |
| TC-D11 | aiTestModules 에 없는 모듈의 main 변경은 판정 대상이 아니다 |
| TC-D12 | libraryModules: 라이브러리 변경을 소비 모듈 리포트로 판정한다 |
| TC-D13 | libraryModules: 라이브러리 소스가 소비 모듈 리포트보다 새로우면 막는다 |
| TC-D14 | 단일 모듈 — aiTestModules 가 없으면 루트를 모듈로 본다 |
| TC-D15 | 중첩 모듈(apps:api) — 디렉터리 apps/api/ 로 찾는다 |
| TC-D16 | 설정 .modules 가 build.gradle 보다 우선한다 |
| TC-D17 | AiTest 만 바뀌면 report-only 는 리포트 최신만 본다 |
| TC-D18 | 실행: main 이 바뀐 모듈은 aiTest 전체를 돌린다 |
| TC-D19 | 실행: AiTest 만 바뀌면 그 클래스만 --tests 로 돌린다 |
| TC-D20 | 실행: gradlew 가 실패하면 실패로 끝난다 |
| TC-D21 | 설정 파일이 JSON 이 아니면 실행 오류(2) |
| TC-D22 | macOS 기본 bash 3.2 로도 돈다 |

### C. 훅 (aitest-coverage-validate.sh)

| ID | 케이스 |
|---|---|
| TC-H01 | git 저장소가 아니면 조용히 통과한다 |
| TC-H02 | 이번 요청에서 diff 가 그대로면 막지 않는다 (C-05) |
| TC-H03 | 요청 중 Controller 를 바꾸고 AiTest 가 없으면 막는다 (C-01) |
| TC-H04 | 최신 리포트 + 100% 면 통과한다 |
| TC-H05 | stop_hook_active 면 허용하고 systemMessage 로 남긴다 (C-08) |
| TC-H06 | ACK 면제가 있으면 통과한다 (C-07) |
| TC-H07 | 환경이 없으면 막지 않고 세션당 한 번만 알린다 (C-06) |
| TC-H08 | @interface AiTest 만 있어도 환경으로 본다 |
| TC-H09 | 소비 모듈을 모르는 main 변경에 AiTest diff 가 없으면 막는다 (C-04) |
| TC-H10 | 소비 모듈을 모르는 main 변경이어도 AiTest diff 가 있으면 통과한다 (C-04) |
| TC-H11 | 테스트만 바뀌면 막지 않는다 |
| TC-H12 | 하위 디렉터리에서 호출해도 저장소 루트 기준으로 본다 |

## 수동 확인 — 실제 Gradle · testcontainer

템플릿 · Gradle 연동은 샘플 프로젝트로 확인한다. 0.1.0 에서 확인한 조합은 둘이다.

| 조합 | 구성 | 확인한 것 |
|---|---|---|
| Boot 3.3.1 · Gradle 8.8 · JDK 17 · MySQL 8.0 | 멀티 모듈 `app` + 라이브러리 `core` | 아래 1 ~ 6 전부 |
| Boot 2.5.6 · Gradle 7.2 · JDK 11 · MySQL 8.0 · Testcontainers 1.19.7 | 단일 모듈 (`MULTI=false`, `NEED_REPOS=true`) | 1 ~ 3, 5 (실제 `aiTest` 실행 후 80% FAIL) · 훅 차단 |

멀티 모듈 순서:

1. 멀티 모듈 샘플(`app` = web + data-jpa + mysql, `core` = java-library)에 `aitest-environment-create` 순서대로 템플릿을 채운다
2. `./gradlew :app:compileAiTestJava` → `:app:aiTestFast --tests '*TestSupportSmokeAiTest*' -PskipAiTestCoverage` 가 PASS (운영 datasource URL 이 컨테이너로 덮이는지)
3. `--warning-mode all` 에 이 플러그인 템플릿에서 나온 deprecation 이 없다
4. Controller · core 클래스에 분기를 더하고 훅(Stop) → `C-01` 차단
5. 분기 일부만 덮는 `<Controller>AiTest` → `diff-coverage-validate.sh HEAD` 가 두 클래스 모두 100% 미만으로 FAIL (core 클래스가 app 리포트에 나온다)
6. 남은 분기를 덮음 → PASS, 훅 통과 → core 를 다시 고치면 `C-03` 차단
