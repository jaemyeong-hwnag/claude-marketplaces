---
name: document-create
description: 플러그인의 SKILL.md · 커맨드 · 에이전트 · README 를 새로 쓰거나 고칠 때 사용한다. 스킬 description 을 쓸 때, 스킬이 길어져 나눌지 정할 때, README 를 만들거나 구성요소를 추가한 뒤 README 를 맞출 때 적용한다. 트리거 — "스킬 작성", "SKILL.md", "description", "README", "프런트매터". 작성 규칙과 README 템플릿을 강제한다.
---

# 플러그인 문서 쓰기

규칙 원본: [`references/authoring-rules.md`](../../references/authoring-rules.md)
기계 검증: [`scripts/validate-authoring.sh`](../../scripts/validate-authoring.sh)

스크립트는 **형식과 일치**만 본다. description 이 정확한지, 트리거가 다른 스킬과 겹치는지는 이 스킬이 판단한다.

## 1. 스킬 프런트매터

```markdown
---
name: {디렉터리명과 같게}
description: {무엇을 하는가 한 문장}. {~할 때 사용한다}. 트리거 — "{관찰 가능한 단어}", …
---
```

- `name` 은 디렉터리명과 같다 (`A-02`). 이름 자체는 `name-create` 로 먼저 정한다
- description 에 "언제 쓰는가" 가 반드시 있다 — `~할 때 사용한다` (`A-04`)
- 300자를 넘기지 않는다 (`A-05`). description 은 **매 세션 상시 비용**이다 — 스킬 하나가 ~250 토큰

### description 판단

쓰고 나서 셋을 본다.

1. **무엇을 하는가** 한 문장이 이 스킬만의 일을 말하는가. "규칙을 강제한다" 만으로는 어떤 규칙인지 모른다
2. **트리거가 관찰 가능한가.** "~일 때" 같은 추상 조건보다 사용자가 실제로 칠 단어·명령·파일명
3. **다른 스킬과 겹치지 않는가.** 같은 저장소의 스킬 description 을 훑어 같은 트리거 단어가 있으면 한쪽을 좁힌다. 겹치면 두 스킬이 같이 로드된다

줄일 때는 트리거의 **동의어**부터 뺀다. "언제 쓰는가" 는 줄이지 않는다.

## 2. 커맨드 · 에이전트

| | 프런트매터 |
|---|---|
| `commands/{이름}.md` | `description` — 한 문장 |
| `agents/{이름}.md` | `name` (파일명과 같게) · `description` |

커맨드도 스킬 목록에 올라가고 상시 비용이 든다. description 을 짧게.

## 3. 스킬 본문

- 200줄을 넘으면 템플릿 · 예시 · 체크리스트를 **플러그인 루트 `references/`** 로 옮기고 상대 경로로 링크한다 (`A-06`)
- 링크는 실제로 있는 파일을 가리킨다 (`A-08`)
- 외부 URL 을 쓰지 않는다 — 내용을 직접 넣는다. 출처는 "저장소 · 경로" 를 글로 적는다 (`A-09`)
- `references/` 파일 하나는 500줄 이내 (`A-07`)

## 4. README

순서대로. 템플릿에 없는 절은 `## 변경 이력` 앞 어디든 둘 수 있다.

```markdown
# {plugin-name}

{한 줄 설명 — plugin.json description 과 같은 뜻}

## 설치
## 의존성              없으면 "없음"
## 포함된 스킬          스킬·커맨드가 있을 때. 커맨드는 /{이름}
## 포함된 에이전트       에이전트가 있을 때
## 포함된 훅            hooks/hooks.json 이 있을 때. 이벤트 이름을 적는다
## 주의                같이 쓰면 안 되는 조합이 있을 때
## (자유 절)
## 변경 이력            CHANGELOG.md 참조
```

**표는 실제 구성요소와 같아야 한다** (`A-24` ~ `A-27`). 스킬 · 커맨드 · 에이전트 · 훅 이벤트 · 의존성을 추가하거나 지웠으면 README 표도 같이 고친다.
저장하면 `PostToolUse` 훅이 어긋난 것을 알려 준다.

설치 절 — internal 은 "SessionStart 훅이 설치한다", public 은 `/plugin install {name}@plugin-marketplace` (`A-28`).

## 5. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-authoring.sh" --all "${CLAUDE_PROJECT_DIR:-.}"
```

종료 코드 0 이어야 끝난 것이다. 경고(`A-05` · `A-06` · `A-07`)는 막지 않지만 이유 없이 남기지 않는다.

## 하지 않을 것

- 이름을 여기서 정하지 않는다 — `name-create`
- 파일을 어디에 둘지 여기서 정하지 않는다 — `plugin-directory-create`
- README 표를 맞추려고 실제 구성요소를 지우지 않는다. 표가 틀렸으면 표를 고친다
