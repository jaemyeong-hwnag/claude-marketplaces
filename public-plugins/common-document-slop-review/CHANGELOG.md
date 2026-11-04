# CHANGELOG

## 0.1.7

### Fixed
- Anthropic 디렉터리 검증기가 막는 표기를 같은 동작의 표기로 바꿨다 — 따옴표 안에 `>` 가 많은 판정 awk 프로그램은 `scripts/document-slop-signal-list.sh` 로 옮겨 훅 스크립트가 bash 로 부르고, 경고 문구의 `>` 는 실행 때 만든 값으로, `$'…'` 는 맨 위에서 만든 변수로, `${…}` 안에 겹친 따옴표 5곳은 풀어 썼다. 판정 · 출력은 그대로다 (#284, `TC-D70`)

## 0.1.6

### Fixed
- 훅 스크립트 `scripts/document-slop-validate.sh` 를 Anthropic 디렉터리 검증기가 읽을 수 있게 따옴표 안 명령 치환 · here-document · here-string 을 변수 · 줄 단위 루프로 바꿨다. 판정은 그대로다 (#258)

## 0.1.5

### Changed
- README 에 `DS-01` ~ `DS-04` 차단은 저장된 뒤 되돌려 고치게 하는 것이고 쓰기를 취소하지 않는다고 적었다 (#249)

## 0.1.4

### Fixed
- 다른 플러그인의 Stop 훅이 먼저 막아 `stop_hook_active` 가 true 이면, 이 훅이 막은 적이 없어도 `DS-30` 기록을 지우고 리뷰 없이 통과시키던 것 (#241). 이 훅이 막은 표시가 있을 때만 통과시키고, 표시는 `UserPromptSubmit` 에서 지운다

## 0.1.3

### Changed
- `plugin.json` 에 `license`(MIT)를 적었다 — Anthropic 디렉터리 제출 조건 (#233)

## 0.1.2

### Changed
- README 를 영어(기본) `README.md` · 한국어 `README.ko.md` · 중국어 간체 `README.zh-CN.md` 로 나눴다 (#229)

### Fixed
- README 서술 1건을 코드에 맞췄다 — 전수 검토 (#229)

## 0.1.1

### Fixed
- 백그라운드로 띄운 `document-slop-reviewer` 를 띄운 순간(`PostToolUse` 의 `status: "async_launched"`)에 리뷰함으로 쳐서, 판정이 오기 전에 `DS-30` 기록을 지우던 것 (#183). 끝났을 때(`SubagentStop`)만 기록을 지운다. 리뷰 중에 완료 알림을 기다리며 끝나는 응답은 막지 않고 기록을 남긴다

## 0.1.0

### Added
- 규칙 원본 `references/document-slop-rules.md` (`DS-01` ~ `DS-30`), 패턴 `document-slop-patterns.json`, 근거 `document-slop-methods.md` (#114)
- `document-slop-validate.sh` — 이번에 쓴 줄에서 대화 잔재 · 플레이스홀더 · 챗봇 토큰 · 깨진 상대 링크를 차단하고, 근거 · 불필요한 내용 · 정리 신호 12종을 알린다 (PostToolUse `Write|Edit|MultiEdit`, CLI `--diff` · `--strict`)
- 완료 게이트 `DS-30` — 문서를 고친 세션이 리뷰 없이 끝나면 한 번 되돌린다 (Stop, `DOCUMENT_SLOP_REVIEW_GATE=0` 으로 끔)
- `document-slop-review` 스킬, `document-slop-reviewer` 에이전트 (작성 맥락 없이 사실 대조), `/document-slop-validate` 커맨드
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 차단)
