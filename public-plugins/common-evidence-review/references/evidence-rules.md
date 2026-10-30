# 근거 리뷰 규칙 (단일 원본)

AI 가 한 변경과 주장마다 **필요한가 · 맞는가**를 작업 맥락을 모르는 검증자가 실행 근거로 판정한다. 기계 판정은 [`scripts/evidence-validate.sh`](../scripts/evidence-validate.sh), 조항의 출처는 [`evidence-methods.md`](evidence-methods.md).

다루지 않는 것:
- 문서의 사실 대조 · 군더더기 → `common-document-slop-review`
- 테스트를 같이 고쳤는가 · 린트 통과 → `code-edit-guardrail`
- 결함 탐색 → `/code-review`
- 성능 → `common-performance-review`

## 1. 판정 — AI

| 조항 | 내용 |
|---|---|
| `E-01` | 검증은 작성한 문맥 밖에서 한다 — `evidence-reviewer` 에이전트. 작성자가 자기 결과를 다시 읽는 것은 검증으로 치지 않는다 |
| `E-02` | 검증자에게는 **요청 원문 · 바뀐 파일 목록 · 질문 목록**만 넘긴다. 작성자의 결론 · 이유 · 요약 · 커밋 메시지 · PR 설명은 넘기지 않는다. "무시하라" 고 덧붙여도 끌림은 줄지 않는다 |
| `E-03` | 작성자의 주장은 결론을 뺀 열린 질문으로 바꿔 넘긴다. 예/아니오 질문, 주장을 그대로 옮긴 질문은 쓰지 않는다 |
| `E-04` | 판정마다 근거를 **먼저** 쓴다 — 실행한 명령과 출력 발췌, 또는 `파일:줄`. 근거가 없으면 `판정 불가` 다 |
| `E-05` | 필요성은 변경마다 판정한다: `필요함` · `불필요함` · `판정 불가`. 기준은 "되돌리면 요청의 어느 문장이 충족되지 않는가, 무엇이 깨지는가" 다. 답이 없으면 `불필요함` 이다 (요청 밖 · 예방성 · 정리성 변경). 테스트 통과는 필요성의 근거가 아니다 |
| `E-06` | 정확성은 필요성과 따로 판정한다: `맞음` · `틀림` · `판정 불가` |
| `E-07` | "버그다 · 오류다 · 원인은 X 다" 는 재현으로만 확정한다. 수정 전 실패와 수정 후 통과를 둘 다 실행 출력으로 받는다. 수정 후에도 실패하면 기각한다. 재현이 없으면 `판정 불가` 다. 합의 · 그럴듯함은 근거가 아니다 |
| `E-08` | "테스트 통과 · 완료" 는 테스트 자체를 본다 — 단언을 지웠는가, skip · only 를 넣었는가, 기대값을 바꿨는가, 이번 변경을 되돌리면 새 테스트가 실패하는가 |
| `E-09` | 영향 없는 지적(스타일 · 취향 · "더 좋게")은 쓰지 않는다. "문제 없음" 이 정상 결과다 |
| `E-10` | 검증자는 작업 트리를 바꾸지 않는다. 수정 전 동작은 `git worktree add --detach <임시 경로> HEAD` 로 만든 임시 워크트리에서 돌리고, 끝나면 `git worktree remove --force` 로 지운다 |
| `E-11` | 판정을 받은 뒤 처리한다. `틀림` 은 고친다. `불필요함` 은 되돌린다 — 사용자가 원하는지 애매하면 묻는다. `판정 불가` 는 답에 `미확인` 으로 밝힌다. 다른 실행 근거 없이 작성자의 기억으로 판정을 뒤집지 않는다. 고친 부분만 다시 검증하고, 재검증은 2회까지다. 그래도 남으면 사용자에게 넘긴다 |

검증자는 하나다. 여러 검증자를 두거나 토론시키지 않는다 — 같은 비용이면 근거의 질이 먼저다.

## 2. 기계 검사

### `E-20` 테스트 약화 신호 — 알림

테스트 파일을 고친 내용에서 아래를 찾는다. 막지 않고 알린다. 의도한 변경일 수 있어서 판단은 `E-08` 이 한다.

| 신호 | 판정 |
|---|---|
| skip · focus 표지가 늘었다 | `@Disabled` · `@Ignore` · `.skip(` · `.only(` · `xit(` · `xdescribe(` · `xtest(` · `fit(` · `fdescribe(` · `.todo(` · `@pytest.mark.skip` · `@pytest.mark.xfail` · `@unittest.skip` · `t.Skip(` · `t.Skipf(` · `t.SkipNow(` · `#[ignore]` · `[Ignore]` · `(Skip =` 개수가 고치기 전보다 많다 |
| 단언이 줄었다 | `assert*(` · `assert*!(` · `assert.*(` · `Assert.*(` · `assert x` · `assert_equal x` · `expect(` · `should*` · `verify(` · `XCTAssert*` · `require.*(` 개수가 고치기 전보다 적다 |

고치기 전은 `Edit` · `MultiEdit` 이면 `old_string`, `Write` 면 `HEAD` 의 그 파일(추적되지 않으면 빈 파일)이다.

테스트 파일 — 프로젝트(`cwd`) 기준 경로로 판정한다:
- 경로: `test/` · `tests/` · `__tests__/` · `spec/` · `e2e/` · `cypress/` · `src/*Test/` 아래
- 파일명: `*_test.*` · `*.test.*` · `*.spec.*` · `*-spec.*` · `*_spec.*` · `*Spec.*` · `*.cy.*` · `*.e2e.*` · `test_*.py` · `*Test.*` · `*Tests.*` · `tests.rs`

### `E-30` 완료 게이트

한 요청에서 프로젝트 안 코드 · 설정을 바꾼 줄이 `EVIDENCE_REVIEW_MIN_LINES`(기본 3) 이상인데 `evidence-reviewer` 가 돌지 않았으면, 종료를 **한 번** 되돌린다.

- 바꾼 줄은 편집마다 비어 있지 않은 줄 수를 고치기 전 · 후 중 큰 쪽으로 센다.
- 되돌림 메시지에 넣는 것:
  - 바꾼 파일
  - 요청 기록 경로
  - 최종 답(`last_assistant_message`)에서 뽑은 주장 후보 — 완료 · 고침 · 통과 · 원인 · 버그 · 필요 같은 단어가 든 줄, 10개까지
  - 기록된 `E-20` 신호
- 이 훅이 되돌린 뒤의 종료(`stop_hook_active`)는 막지 않고 기록을 지운다. 그래서 한 요청에서 두 번 막지 않는다. 다른 플러그인의 Stop 훅이 되돌려 `stop_hook_active` 가 켜졌을 뿐이면 그대로 판정한다.
- `evidence-reviewer` 가 돈 뒤에 또 고치면 검증함 표시를 지우고 그 뒤 편집만 다시 센다 (`E-11` 재검증).
- 검증은 `evidence-reviewer` 가 **끝났을 때** 친다. 백그라운드 실행(`tool_response.status` 가 `async_launched`)은 `SubagentStop` 까지 "검증 중" 이다. 검증 중에 끝나는 응답(완료 알림을 기다림)은 막지 않고 기록을 남긴다.
- 검증할 주장이 없는 변경(이름만 바꿈 · 포맷)이면 그 이유를 한 줄로 말하고 끝내면 된다.
- 세지 않는 것:
  - 문서(`.md` · `.mdx` · `.markdown` · `.rst` · `.txt` · `.adoc`) — `DS-30` 의 몫이다. 단 `requirements*.txt` · `constraints*.txt` · `*-lock.txt` · `CMakeLists.txt` · `robots.txt` 는 설정으로 센다
  - 프로젝트(`cwd`) 밖 파일
  - Bash 로 바꾼 파일 — 훅이 보지 못한다
- 끄기: `EVIDENCE_REVIEW_GATE=0`

### 기록

| 파일 | 쓰는 때 | 내용 |
|---|---|---|
| `<세션>.edits` | PostToolUse `Write` · `Edit` · `MultiEdit` | 파일 경로와 바꾼 줄 수 |
| `<세션>.signals` | 같음 | `E-20` 신호 |
| `<세션>.request` | UserPromptSubmit | 요청 원문. `<task-notification>` 으로 시작하는 백그라운드 알림은 뺀다 |
| `<세션>.reviewed` | PostToolUse `Agent` · `Task` (`evidence-reviewer`, 동기로 끝남) · SubagentStop (`evidence-reviewer`) | 검증함 표시 |
| `<세션>.pending` | PostToolUse `Agent` · `Task` (`evidence-reviewer`, 백그라운드로 뜸) | 검증 중 표시. SubagentStop 이 지운다 |
| `<세션>.blocked` | Stop (되돌릴 때) | 이 훅이 이번 요청에서 되돌렸다는 표시 |

위치는 `${CLAUDE_PLUGIN_DATA}` 이고, 없으면 `${TMPDIR:-/tmp}/common-evidence-review/` 다. 새 요청(UserPromptSubmit)이 오거나 Stop 이 통과하면 모두 지운다. 그래서 판정 단위는 한 요청이다 — 중단돼 Stop 이 돌지 않은 요청의 편집도 다음 요청에 이어지지 않는다.

## 3. 종료 코드

| 상황 | 결과 |
|---|---|
| 훅 · `E-20` | exit 0, `additionalContext` |
| 훅 · `E-30` | exit 0, `decision: block` |
| CLI `--diff` · 신호 없음 · 있음 | exit 0 |
| CLI `--diff --strict` · 신호 있음 | exit 2 |
| CLI · 실행 오류 | exit 1 |

`--diff` 의 기준은 `merge-base HEAD origin/HEAD` 이고, 없으면 `origin/main`, 그것도 없으면 `HEAD` 다.

훅은 fail-open 이다. `jq` 가 없거나 입력이 JSON 이 아니면 조용히 통과한다.
