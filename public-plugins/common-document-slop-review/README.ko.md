# common-document-slop-review

[English](README.md) · **한국어** · [简体中文](README.zh-CN.md)

AI 가 문서를 만들거나 고칠 때마다 slop 을 막는다 — 대화 잔재 · 플레이스홀더 · 챗봇 토큰 · 깨진 링크는 차단, 출처 없는 주장 · 날짜 없는 시점 · 근거 없는 수치 · 상투 표현 · 형식 과잉은 알림. 주장을 파일 · 코드 · 링크로 대조하는 리뷰를 문서를 고친 세션 끝에 요구한다.

검사는 세 층이다.

| 층 | 언제 | 무엇을 | 하는 것 |
|---|---|---|---|
| 1. 기계 검사 | 문서를 쓸 때마다 | 이번에 쓴 줄 | 명백한 흔적은 막고, 문체 신호는 알린다 |
| 2. 판단 리뷰 | 리뷰할 때 | 문서 전체 | 내용이 맞는지 · 필요한지 · 정리됐는지 본다 |
| 3. 완료 게이트 | 세션이 끝날 때 | 그 세션에서 고친 문서 | 2층을 건너뛰었으면 한 번 되돌린다 |

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install common-document-slop-review@jaemyeong-hwnag-plugins
```

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| document-slop-review | 문서 검토 · README 봐줘 · 사실관계 확인 · 틀린 데 있나 · 쓸데없는 내용 · slop | 기계 검사 → 작성 맥락 없는 사실 대조 → 지워도 되는 문장 · 반복 · 구조 · 형식 · 용어 판정 → 결함만 고친다 |
| /document-slop-validate | 직접 호출 | 바뀐 줄(기본) 또는 지정한 경로에서 `DS-01` ~ `DS-16` 을 찾는다 |

## 포함된 에이전트

| 에이전트 | 설명 |
|---|---|
| document-slop-reviewer | 문서 경로만 받아 사실 주장을 뽑고 저장소 파일 · 명령 · 링크로 대조한다. 판정은 `확인함` · `틀림` · `미확인` 이다. 문서를 고치지 않는다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| document-slop-validate.sh | PostToolUse (Write\|Edit\|MultiEdit) | 이번에 쓴 줄에서 `DS-01` ~ `DS-04` 를 **막고** (exit 2), `DS-05` ~ `DS-16` 을 **알린다** |
| document-slop-validate.sh | PostToolUse (Skill\|Agent\|Task) | `document-slop-review` · `document-slop-reviewer` 가 돌면 게이트 기록을 지운다. 백그라운드로 뜬 `document-slop-reviewer` 는 리뷰 중으로 표시한다 |
| document-slop-validate.sh | SubagentStop | 백그라운드 `document-slop-reviewer` 가 끝나면 게이트 기록을 지운다 |
| document-slop-validate.sh | Stop | 문서를 고쳤는데 리뷰하지 않았으면 종료를 한 번 되돌린다 (`DS-30`) |

## 주의

- **"AI 가 썼는가"를 판정하지 않는다.** 고칠 수 있는 패턴과 그 줄만 지적한다. 사람이 써도 같은 패턴이면 걸린다.
- 차단은 명백한 흔적 넷뿐이다: 대화 잔재, 플레이스홀더, 챗봇 인용 토큰, 없는 경로를 가리키는 상대 링크.
- 경고는 후보다. 판정은 스킬이 한다.
- 근거 경고(`DS-05` ~ `DS-07`)는 **지우라는 뜻이 아니다.** 출처를 달거나 `미확인` 으로 표시하면 통과한다. 간결하게 만들려고 근거를 지우면 오히려 정확도가 떨어진다.
- 보는 파일: `.md` · `.mdx` · `.markdown` · `.rst` · `.txt` · `.adoc`
  - `requirements*.txt` · `constraints*.txt` · `*-lock.txt` · `CMakeLists.txt` · `robots.txt` · `LICENSE*` 는 보지 않는다 (대소문자 무관).
- 보지 않는 곳: 프런트매터, 코드 펜스, 인라인 코드, 인용(`>`), HTML 주석(여러 줄 포함), 4000 바이트를 넘는 줄
- 의도한 줄이면 그 줄이나 바로 윗줄에 `<!-- document-slop-ignore -->` 를 둔다.
- 한국어 어휘 목록(`DS-10`)의 근거는 영어보다 약하다. 그래서 서로 다른 단어 3개 이상이 몰렸을 때만 알린다.
- 완료 게이트는 프로젝트 안 문서를 한 번에 3줄 이상 고쳤을 때만 기록한다.
  - 한 요청에서 두 번 막지 않는다.
  - 끄려면 `DOCUMENT_SLOP_REVIEW_GATE=0`
- 스크립트는 bash · awk · jq 를 쓰고, `--diff` 와 디렉터리 목록에는 git 을 쓴다. jq 가 없으면 훅은 조용히 통과한다.

## 규칙 요약

| 조항 | 내용 | 판정 |
|---|---|---|
| `DS-01` ~ `DS-04` | 대화 잔재 · 플레이스홀더 · 챗봇 토큰 · 깨진 상대 링크 | 차단 |
| `DS-05` ~ `DS-07` | 출처 없는 출처 표현 · 날짜 없는 시점 표현 · 근거 없는 수치 | 경고 |
| `DS-08` ~ `DS-13` | 메타 서술 · 마무리 요약 절 · 과용 어휘 묶음 · 대비 구문 반복 · 과장 어휘 · 헤지 겹침 | 경고 |
| `DS-14` ~ `DS-16` | 형식 과잉 · 제목 수준 건너뜀 · 같은 문장 반복 | 경고 |
| `DS-20` ~ `DS-27` | 사실 대조 · 지워도 되는 문장 · 관련성 · 중복 · 구조 · 형식 적합성 · 받는 쪽 비용 · 용어 일관성 | AI 판단 |
| `DS-30` | 문서를 고친 세션이 리뷰 없이 끝나면 한 번 되돌림 | 게이트 |

원본: [`references/document-slop-rules.md`](references/document-slop-rules.md) · 패턴: [`references/document-slop-patterns.json`](references/document-slop-patterns.json) · 근거: [`references/document-slop-methods.md`](references/document-slop-methods.md)

## 사용

```bash
scripts/document-slop-validate.sh --diff              # 기본 브랜치 대비 바뀐 줄
scripts/document-slop-validate.sh --diff origin/main  # 지정한 기준 대비 바뀐 줄
scripts/document-slop-validate.sh docs/ README.md     # 경로 전체
scripts/document-slop-validate.sh --strict docs/      # 경고가 있어도 exit 2 (CI)
test/document-slop-validate.test.sh                   # 회귀 테스트
```

## 근거

| 조항 | 근거 |
|---|---|
| 차단 기준 | Wikipedia 빠른 삭제 기준 G15 · Signs of AI writing |
| 사전 정의 | Merriam-Webster · Macquarie · American Dialect Society 의 2025 올해의 단어 |
| slop 분류 | Shaib et al. 2025 · Kommers et al. 2025 |
| 과용 어휘 | Kobak et al. 2025 · Liang et al. 2024 · Antislop (ICLR 2026) |
| 사실 대조 | FActScore · SAFE · Chain-of-Verification · Huang et al. ICLR 2024 |
| 문서 지침 | GitLab · Grafana 문서 스타일 가이드, Anthropic · OpenAI 의 작성 지침 |
| 비용 | workslop (HBR 2025) |

각 항목의 출처 · 확인 수준은 `references/document-slop-methods.md` 에 있다.

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
