# plugin-authoring

플러그인 파일의 **내용 형식**을 강제한다 — 스킬·커맨드·에이전트 프런트매터, 스킬 본문·참조 문서 크기, README 절 구성과 실제 구성요소의 일치.

이름은 `plugin-naming`, 파일 위치는 `marketplace-directory-structure`, 버전은 `plugin-versioning` 이 본다. 여기서는 **이미 올바른 자리에 있는 파일의 안쪽**만 본다.

## 설치

이 저장소에서는 SessionStart 훅(`.claude/hooks/sync-internal-plugins.sh`)이 등록·활성화·설치한다.
internal 플러그인이라 다른 저장소에 배포하지 않는다. 다른 곳에서 쓰려면 `public-plugins/` 로 옮긴다.

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| document-create | SKILL.md · description · README 쓰기 | 프런트매터·description 판단, README 템플릿 |
| /authoring-validate | 직접 호출 | 저장소 전체 플러그인의 작성 규칙을 검증한다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-authoring.sh | PreToolUse (Write) | 새 SKILL.md · 커맨드 · 에이전트의 프런트매터가 틀렸으면 **차단** (`A-01` ~ `A-04`) |
| validate-authoring.sh | PostToolUse (Write\|Edit) | 플러그인 파일 저장 뒤 그 플러그인 전체를 검사해 **알림** |

## 파일

| 경로 | 역할 |
|---|---|
| `references/authoring-rules.md` | 작성 규칙 원본 (`A-01` ~ `A-09` 스킬·참조, `A-20` ~ `A-28` README) |
| `scripts/validate-authoring.sh` | 기계 검증. 훅과 CLI 겸용 |
| `test/` | 회귀 테스트와 TC 명세 |

## 무엇을 막나

| | 조항 |
|---|---|
| 프런트매터 | `A-01` 열고 닫힘 · `A-02` name = 디렉터리명·파일명 · `A-03` description · `A-04` "~할 때 사용한다" |
| 크기 (경고) | `A-05` description 300자 · `A-06` SKILL.md 200줄 · `A-07` references 500줄 |
| 참조 | `A-08` 상대 링크가 가리키는 파일 존재 · `A-09` skills·references 에 외부 URL 금지 |
| README | `A-20` 첫 제목 · `A-21` 필수 절 · `A-22` 구성요소별 절 · `A-23` 순서 · `A-24` ~ `A-27` 표 ↔ 실제 · `A-28` public 설치 명령 |

## 훅이 두 갈래인 이유

스킬을 만들고 README 를 맞추는 데 두 번의 편집이 필요하다. README 불일치로 첫 편집을 막으면 아무것도 못 만든다.
그래서 **프런트매터처럼 파일 하나만 보면 판정되는 것**만 `PreToolUse` 로 막고, 플러그인 전체를 봐야 하는 것은 저장 뒤 알린다. `--all` 은 전부 막는다.

## 사용

```bash
scripts/validate-authoring.sh internal-plugins/plugin-authoring   # 플러그인 하나
scripts/validate-authoring.sh --all .                             # 저장소 전체
test/validate-authoring.test.sh                                   # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
