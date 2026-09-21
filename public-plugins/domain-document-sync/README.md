# domain-document-sync

도메인 지식 문서를 **3계층**(카탈로그 `_index` → 도메인 메타 `_meta` → 개념 concept)으로 두고 코드와 맞춰 둔다 — 언어 · 프레임워크 무관한 코드 분석으로 문서 생성, 필요한 도메인만 읽기, 편집 규약 주입, 코드 변경 시 문서 동기 게이트.

어떤 코드가 어느 도메인인지는 스크립트가 아니라 각 도메인의 `_meta.md` 프런트매터 `code:` 글롭이 말한다. 그래서 Java · TypeScript · Python · Go … 무엇이든, 모노레포든 단일 모듈이든 같은 규칙으로 돈다.

```
docs/domain/
  _index.md            # 카탈로그 — 도메인당 1행, 트리거(말 · 식별자 · 경로 · 증상)
  order/
    _meta.md           # code: 글롭 · 관계 · 파트 표(언제 어느 파일)
    entities.md        # concept — 규칙 · 엔티티 · 흐름
    flows.md
```

## 설치

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install domain-document-sync@plugin-marketplace --scope project
```

설치한 뒤 문서가 없으면 "도메인 문서 만들어줘" 로 `domain-document-create` 를 부른다. 문서 루트가 없는 동안 훅은 아무것도 하지 않는다.

필요한 것: `git`, `jq`. 없으면 훅이 조용히 통과한다 (fail-open).

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| domain-document-get | 도메인 규칙 · 어느 도메인 · 영향 도메인 | `_index → _meta → concept` 순으로 필요한 파트만 읽는다 |
| domain-document-create | 도메인 문서 만들기 · 도메인 정리 · 새 도메인 | 코드베이스를 언어 무관하게 분석해 도메인을 나누고 3계층을 만든다 |
| domain-document-update | 문서 갱신 · 동기 게이트 차단 | 코드 변경을 concept 에 반영하고 바뀐 경우만 `_meta` · `_index` 를 맞춘다. 면제 절차 |
| /domain-document-validate | 직접 호출 | 문서 트리 검증 (`D-01` ~ `D-08`) + 도메인별 코드 매핑 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| domain-document-sync.sh snapshot | UserPromptSubmit | 요청 시작 때 도메인별 코드 지문을 저장하고 지난 면제를 지운다 |
| domain-document-sync.sh pre-edit | PreToolUse (Edit\|Write\|MultiEdit) | 문서 루트를 고칠 때 3계층 규약을 **주입** (카탈로그 · 메타 · concept · 새 도메인별) |
| domain-document-sync.sh post-edit | PostToolUse (Edit\|Write\|MultiEdit) | concept 이 300줄을 넘거나(`D-07`) `_meta` 파트 표에 없으면(`D-05`) **알림** |
| domain-document-sync.sh stop | Stop | 이번 요청에서 코드가 바뀐 도메인에 문서 변경이 없으면 완료를 **차단** (`S-01`). 한 번 되돌린 뒤에는 경고만 |

## 주의

- `S-01` 은 git 작업 트리(HEAD 대비 변경 + untracked)로 판정한다. 커밋과 무관하고, 질문만 한 요청은 막지 않는다
- 도메인 지식이 그대로인 변경(리팩터 · 테스트 · 포맷)은 사용자에게 알린 뒤 면제한다 — 차단 메시지에 면제 파일 경로가 나온다. 면제는 그 요청에만 유효하다
- `code:` 를 넓게 쓰면(`src/**`) 모든 변경이 그 도메인 문서를 요구한다. `map` 으로 걸리는 파일 수를 보고 좁힌다
- 설정은 프로젝트 `.claude/settings.json` 의 `env` 에 — `DOMAIN_DOCUMENT_ROOT`(기본 `docs/domain`), `DOMAIN_DOCUMENT_MAX_LINES`(기본 `300`)

## 무엇을 막나

| | 조항 |
|---|---|
| 트리 (`validate`) | `D-01` 루트 · `_index.md` · `D-02` 도메인마다 `_meta.md` · `D-03` slug kebab-case · `D-04` 카탈로그 등재 · `D-05` 메타 파트 표 등재 · `D-06` 상대 링크 |
| 경고 | `D-07` concept 300줄 · `D-08` 걸리는 파일이 없는 `code:` 글롭 |
| 동기 (Stop 훅) | `S-01` 도메인 코드가 바뀌면 그 도메인 문서도 바뀐다 |

## 파일

| 경로 | 역할 |
|---|---|
| `references/domain-document-rules.md` | 규칙 원본 — 3계층, 조항, `code:` 글롭 문법, 게이트 동작, 읽기 · 쓰기 절차, 설정 |
| `references/templates.md` | `_index` · `_meta` · concept 골격, concept 나누는 법 |
| `scripts/domain-document-sync.sh` | 훅 네 모드 + CLI `validate` · `map` |
| `test/` | 회귀 테스트와 TC 명세 |
| `evals/` | `claude plugin eval` 케이스 — 조회 스킬 발동 · 문서 편집 규약 주입 |

## 사용

```bash
scripts/domain-document-sync.sh validate .   # 문서 트리 검증
scripts/domain-document-sync.sh map .        # 도메인 → code 글롭 → 걸리는 파일 수
test/domain-document-sync.test.sh            # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
