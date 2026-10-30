# CHANGELOG

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
