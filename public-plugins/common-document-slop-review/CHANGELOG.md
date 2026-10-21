# CHANGELOG

## 0.1.0

### Added
- 규칙 원본 `references/document-slop-rules.md` (`DS-01` ~ `DS-30`), 패턴 `document-slop-patterns.json`, 근거 `document-slop-methods.md` (#114)
- `document-slop-validate.sh` — 이번에 쓴 줄에서 대화 잔재 · 플레이스홀더 · 챗봇 토큰 · 깨진 상대 링크를 차단하고, 근거 · 불필요한 내용 · 정리 신호 12종을 알린다 (PostToolUse `Write|Edit|MultiEdit`, CLI `--diff` · `--strict`)
- 완료 게이트 `DS-30` — 문서를 고친 세션이 리뷰 없이 끝나면 한 번 되돌린다 (Stop, `DOCUMENT_SLOP_REVIEW_GATE=0` 으로 끔)
- `document-slop-review` 스킬, `document-slop-reviewer` 에이전트 (작성 맥락 없이 사실 대조), `/document-slop-validate` 커맨드
- 회귀 테스트 `test/`, eval 케이스 둘 (스킬 발동 · 훅 차단)
