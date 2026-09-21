---
name: github-template-create
description: 저장소에 이 플로우를 처음 도입할 때 사용한다. .github 에 feature·bugfix 이슈 폼과 PR 템플릿을 두고, 빈 이슈를 막고, 라벨을 만들 때 적용한다. 트리거 — "이슈 템플릿", "PR 템플릿", "플로우 도입", "라벨 만들어". 이미 있는 파일은 덮어쓰지 않는다.
---

# 템플릿 · 라벨 준비

규칙 원본: [`references/workflow-rules.md`](../../references/workflow-rules.md) — 0 단계 · `W-01` · `W-02`

## 1. 지금 상태를 본다

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-workflow.sh" --templates .
gh label list --search feature ; gh label list --search bugfix
```

통과하면 할 일이 없다.

## 2. 없는 파일만 복사한다

기본 템플릿: [`templates/`](templates/) — 이슈 폼 `feature.yml` · `bugfix.yml` · `config.yml`, PR 템플릿 `feature.md` · `bugfix.md`.

```bash
T="${CLAUDE_PLUGIN_ROOT}/skills/github-template-create/templates"
mkdir -p .github/ISSUE_TEMPLATE .github/PULL_REQUEST_TEMPLATE
cp -n "$T"/ISSUE_TEMPLATE/*.yml .github/ISSUE_TEMPLATE/
cp -n "$T"/PULL_REQUEST_TEMPLATE/*.md .github/PULL_REQUEST_TEMPLATE/
```

- **이미 있는 파일은 덮어쓰지 않는다** (`cp -n`). 있는 파일이 규칙에 걸리면 무엇이 걸렸는지 보여주고, 고칠지 사용자에게 묻는다
- 단일 기본 PR 템플릿(`.github/pull_request_template.md` 등)이 있으면 폴더 템플릿보다 우선한다 (`W-02`). 내용을 `feature.md` · `bugfix.md` 로 옮기고 지울지 사용자에게 묻는다
- 이슈 폼의 절은 프로젝트에 맞게 더해도 된다. `labels` 와 `body` 는 남긴다 (`W-01`)

## 3. 라벨을 만든다 — 원격

```bash
gh label create feature --color 0E8A16 --description "기능 추가 · 동작 변경"
gh label create bugfix  --color D93F0B --description "의도와 다른 동작 수정"
```

라벨은 원격에 남는다. **사용자에게 확인받고** 만든다.

## 4. 기본 브랜치에 넣는다

GitHub 는 기본 브랜치에 있는 템플릿만 읽는다. 이 변경이 플로우의 첫 PR 이다 — 이슈 번호 없이 들어가도 되는 유일한 예외다 (규칙 원본 5절). 브랜치 이름은 `W-03` 을 따라야 하므로 이슈를 먼저 만들 수 있으면 만든다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-workflow.sh" --templates .   # 통과해야 한다
```
