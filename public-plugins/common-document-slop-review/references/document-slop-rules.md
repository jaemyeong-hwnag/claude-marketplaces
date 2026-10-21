# 문서 slop 규칙 (단일 원본)

AI 가 문서를 만들거나 고칠 때 아래 세 가지가 들어가는 것을 막는다.

- 불필요한 내용
- 사실 확인이 안 된 내용
- 정리가 안 된 내용

기계 검사는 [`scripts/document-slop-validate.sh`](../scripts/document-slop-validate.sh) 가 하고, 패턴은 [`document-slop-patterns.json`](document-slop-patterns.json) 에 있다. 근거 출처는 [`document-slop-methods.md`](document-slop-methods.md) 에 있다.

**slop 의 정의**: 독자의 과제를 진척시키는 실질에 비해 길이 · 형식 · 정형 표현이 과다한 생성 콘텐츠.

정의의 근거:
- 사전: 저품질 · 대량 · 요청하지 않음 (Merriam-Webster · Macquarie 2025)
- workslop: 좋은 작업물로 위장했지만 과제를 진척시킬 실질이 없음 (HBR 2025)

**다루지 않는 것**:

| 대상 | 맡는 곳 |
|---|---|
| 플러그인 파일 형식 | `plugin-authoring` |
| `docs/domain` 의 구조와 코드 동기 | `domain-document-sync` |
| 시크릿 | `git-secret-validate` |
| 철자 · 문법 | 외부 린터 (Vale · LanguageTool) |

## 1. 판정 원칙

| # | 원칙 | 근거 |
|---|---|---|
| P1 | 매번 걸러야 하는 것은 훅이 한다. 스킬은 호출되지 않을 수 있다 | Claude Code best practices, Vercel 에이전트 평가 (2026-01) |
| P2 | 명백한 흔적만 막는다. 문체 신호는 알리기만 하고, 하나만 있으면 판정하지 않는다 | Wikipedia 빠른 삭제 기준 G15, Signs of AI writing |
| P3 | "AI 같다"는 점수를 만들지 않는다. 고칠 수 있는 패턴과 그 줄만 지적한다 | Liang et al. 2023 (비원어민 오탐 61%), OpenAI AI Classifier 종료 (2023-07) |
| P4 | 근거 없는 주장은 지우게 하지 않는다. 출처를 달거나 `미확인` 으로 표시하게 한다. `미확인` 은 결함이 아니다 | Grafana Writers' Toolkit, Kalai et al. 2025, Anthropic 환각 줄이기 가이드 |
| P5 | 간결성 규칙이 출처 · `미확인` 표시 · 단서 · 반박 근거를 지우게 만들지 않는다 | Giskard Phare (2025-04): 간결 지시로 환각 저항 최대 20% 하락 |
| P6 | 사실 검증은 초안을 보지 않는 별도 컨텍스트에서, 파일 · 코드 · 링크 같은 외부 신호로 한다 | CoVe (Dhuliawala et al. 2024), Huang et al. ICLR 2024 |
| P7 | 판단 리뷰는 대조할 수 있는 항목부터 본다. 길이 · 문체 인상만으로 지적하지 않는다 | Zheng et al. 2023 (장황함 편향), Sharma et al. 2024 (설득력 편향) |
| P8 | 이번에 쓴 줄만 본다. 기존 문서 전체를 고치라고 하지 않는다 | Vale · alex 의 변경분 검사 관행 |
| P9 | 어휘 목록은 낡는다. 패턴은 JSON 으로 분리해 버전과 함께 갱신한다 | Wikipedia: delve 는 2025 년에 급감, Antislop (2025) |

## 2. 기계 검사 — `DS-01` ~ `DS-16`

공통:
- 대상 확장자: `.md` · `.mdx` · `.markdown` · `.rst` · `.txt` · `.adoc`
- `requirements*.txt` · `constraints*.txt` · `*-lock.txt` · `CMakeLists.txt` · `robots.txt` · `LICENSE*` (대소문자 무관)와 `node_modules/` · `.git/` · `vendor/` 는 보지 않는다.
- 보지 않는 곳: 프런트매터, 코드 펜스(```` ``` ```` · `~~~`), 인라인 코드, 인용(`>`), HTML 주석(여러 줄 포함), 4000 바이트를 넘는 줄(압축된 줄).
- 줄이나 바로 윗줄에 `document-slop-ignore` 가 있으면 그 줄은 보지 않는다.
- 영어는 소문자로 바꿔 맞춘다.

### 차단 — 명백한 흔적

| 조항 | 내용 | 예 |
|---|---|---|
| `DS-01` | 사용자에게 하는 말 · 대화 잔재 | `도움이 되셨길` · `궁금한 점이 있으시면` · `아래와 같이 정리했습니다` · `I hope this helps` · `Let me know if` · `As of my last knowledge update` |
| `DS-02` | 플레이스홀더 · 템플릿 잔재. 마크다운 링크 글자는 빼고 본다 | `[여기에 …]` · `[TODO …]` · `lorem ipsum` · `insert … here` · `내용을 여기에 작성` |
| `DS-03` | 챗봇 인용 토큰 · 흔적 | `oaicite` · `contentReference[` · `【3†source】` · `turn0search0` · `utm_source=chatgpt.com` · `[cite_start]` |
| `DS-04` | 상대 링크 · 참조 링크가 가리키는 경로가 없다. URL · `#앵커` · `/` 로 시작하는 경로 · 템플릿 변수는 보지 않는다 | `[설계](./design.md)` 인데 파일이 없음 |

### 경고 — 근거

| 조항 | 내용 | 통과 조건 |
|---|---|---|
| `DS-05` | 출처 없는 출처 표현: `연구에 따르면` · `전문가들은` · `업계 표준` · `studies show` · `experts say` | 같은 줄에 링크 · 각주(`[^1]` · `[1]`) · `출처` · `근거` · `측정` · `미확인` · `et al` 가 있다 |
| `DS-06` | 날짜 없는 시점 표현: `최근` · `최신 버전` · `요즘` · `오늘날` · `현재로서는` · `지금은` · `currently` · `recently` · `the latest version` | 같은 줄에 연도(`2026`) · `기준일` · `as of <월> <연도>` 가 있다 |
| `DS-07` | 근거 없는 수치 단정: `30%` · `2배 빠르다` · `3x faster` · `reduced by 40` | `DS-05` 와 같다. 표 행은 보지 않는다 (출처가 다른 칸이나 절에 있다) |

### 경고 — 불필요한 내용

| 조항 | 내용 | 기준 |
|---|---|---|
| `DS-08` | 메타 서술 · 구조 예고: `이 문서에서는 … 살펴보겠습니다` · `결론적으로` · `앞서 언급한 바와 같이` · `Let's dive in` · `It's important to note` | 줄마다 |
| `DS-09` | 문서의 **마지막** 제목이 마무리 · 요약 절: `결론` · `요약` · `마치며` · `Key Takeaways` · `Summary` | 마지막 제목 하나 |
| `DS-10` | 생성 모델이 과하게 쓰는 어휘가 몰려 있음: `delve` · `pivotal` · `tapestry` · `underscore` · `시사하다` · `다양한` · `원활한` 등 | 이번에 쓴 줄 안에서 서로 다른 단어 3개 이상 |
| `DS-11` | 대비 구문 반복: `단순히 X 가 아니라 Y` · `X 뿐만 아니라 Y` · `not just X but Y` | 이번에 쓴 줄 안에서 2회 이상 |
| `DS-12` | 과장 · 홍보 어휘: `획기적` · `혁신적` · `완벽한` · `게임 체인저` · `groundbreaking` · `seamless` · `state-of-the-art` | 줄마다 |
| `DS-13` | 헤지 겹침: `할 수도 있을 것으로 보입니다` · `may potentially` · `it could be argued that` | 줄마다 |

### 경고 — 정리

| 조항 | 내용 | 기준 |
|---|---|---|
| `DS-14` | 형식 과잉 (아래 셋) | |
| | 굵게가 많다 | 8곳 이상이면서 산문 줄 대비 0.5 이상 |
| | `- **머리말**: 설명` 목록 | 6줄 이상 연속 |
| | 제목에 이모지 | 제목마다 |
| `DS-15` | 제목 수준을 건너뜀 (`#` 다음 `###`) | 제목마다 |
| `DS-16` | 같은 문장(40 바이트 이상, 제목 · 표 제외)이 문서 안에 또 있다 | 문장마다 |

**한국어 어휘 목록의 근거는 약하다.**
- `DS-10` 의 영어 목록은 연구에 근거한다: Kobak et al. 2025, Liang et al. 2024, Wikipedia Signs of AI writing.
- 한국어는 `시사하다` 만 연구에 근거한다 (KCI 초록 연구 2026-09). 나머지는 영어 목록의 대응어다. 사람이 쓴 기준선으로 아직 재지 않았다.
- 그래서 단어 하나로는 판정하지 않고, 서로 다른 단어 3개 이상이 몰렸을 때만 알린다.

## 3. 판단 리뷰 — `DS-20` ~ `DS-27`

`document-slop-review` 스킬과 `document-slop-reviewer` 에이전트가 한다. 기계 검사 결과를 입력으로 받는다.

| 조항 | 항목 | 근거 |
|---|---|---|
| `DS-20` | 주장과 근거: 사실 주장을 하나씩 뽑는다. 파일 · 코드 · 명령 · 링크로 대조하고, 대조하지 못하면 `미확인` 으로 둔다. 문서에 나온 경로 · 명령 · 옵션 · API · 버전은 실제로 있는지 본다 | FActScore, SAFE, CoVe, GitLab 스타일 가이드 "Do not invent command syntax" |
| `DS-21` | 지워도 되는 문장 · 절: 지워도 독자가 잃는 정보가 없는가. 채움 절, 상투적 서두와 결말, 코드를 보면 아는 설명, 자명한 지시 | Zhang et al. 2024 (장황함 보상), Claude Code CLAUDE.md 지침, Gloaguen et al. 2026 |
| `DS-22` | 관련성: 문서 목적에 기여하지 않는 구간 | Shaib et al. 2025 (Relevance) |
| `DS-23` | 반복 · 중복: 제목이나 서론을 첫 문단에서 되풀이함, 앞 내용 요약, 같은 주제를 다룬 다른 문서와 겹침 | GitLab 스타일 가이드 "Repetition" · "Incorrect scope" |
| `DS-24` | 구조: 문서 유형이 하나인가 (tutorial · how-to · reference · explanation), 핵심이 앞에 있는가 | Diátaxis, Microsoft 스타일 가이드 |
| `DS-25` | 형식 적합성: 목록 · 표는 서로 떨어진 항목에만 쓴다. 산문이 맞는 곳을 목록으로 쪼개지 않는다 | Anthropic 시스템 프롬프트 · 프롬프트 가이드 |
| `DS-26` | 받는 쪽 비용: 결정 없이 선택지만 나열함, 모호한 지시, 독자가 다시 해석해야 하는 문장 | workslop (HBR 2025-09) |
| `DS-27` | 용어 일관성: 같은 개념에 다른 단어를 섞어 씀. 프로젝트 고유 용어가 일반어로 바뀜 | Anthropic 스킬 작성 지침, Agarwal et al. 2025 (균질화) |

리뷰 출력:
- 결함만 낸다. 지적마다 `줄 · 조항 · 무엇이 문제인가 · 고칠 방향` 을 단다.
- `DS-20` 은 "확인함 / 틀림 / 미확인" 중 하나와 확인한 출처(경로 · 명령)를 단다.
- 길이 · 문체 인상만으로는 지적하지 않는다 (P7).
- 사실 판정을 사용자의 확신이나 주장에 맞춰 바꾸지 않는다 (아첨 금지, OpenAI Model Spec).

## 4. 완료 게이트 — `DS-30`

| 조항 | 내용 |
|---|---|
| `DS-30` | 세션에서 프로젝트 안 문서를 실질적으로 고쳤는데(한 번에 비어 있지 않은 줄 3줄 이상) `document-slop-review` 스킬이나 `document-slop-reviewer` 에이전트가 돌지 않았으면, 종료를 **한 번** 되돌린다 |

- 되돌린 뒤의 종료(`stop_hook_active`)는 막지 않고 기록을 지운다. 그래서 같은 요청에서 두 번 막히지 않는다.
- 오탈자처럼 리뷰할 내용이 없는 변경이면, 그 이유를 한 줄로 말하고 끝내면 된다.
- 프로젝트 밖 파일(사용자 메모리 등)은 기록하지 않는다.
- 끄기: 환경 변수 `DOCUMENT_SLOP_REVIEW_GATE=0`
- 기록 위치: `${CLAUDE_PLUGIN_DATA}/gate-<session_id>.list`. `CLAUDE_PLUGIN_DATA` 가 없으면 `${TMPDIR:-/tmp}/common-document-slop-review/` 에 둔다.

## 5. 종료 코드

| 상황 | 종료 코드 |
|---|---|
| 훅 · 차단 | exit 2. stderr 로 Claude 에게 전달한다. 파일은 이미 저장됐으므로 Claude 가 고친다 |
| 훅 · 경고 | `additionalContext` |
| 훅 · `DS-30` | `decision: block` |
| CLI · 차단 있음 | exit 2 |
| CLI · `--strict` 이고 경고 있음 | exit 2 |
| CLI · 실행 오류 | exit 1 |
| CLI · 그 밖 | exit 0 |

`--diff` 의 기준은 `merge-base HEAD origin/HEAD` 이고, 없으면 `origin/main`, 그것도 없으면 `HEAD` 다. 추적하지 않는 새 문서는 파일 전체를 본다.

훅은 fail-open 이다. `jq` 나 규칙 파일이 없으면 조용히 통과한다.
