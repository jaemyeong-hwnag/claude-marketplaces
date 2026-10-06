# github-workflow

GitHub 저장소의 변경이 **이슈에서 머지까지 가는 경로**를 강제한다 — feature · bugfix 이슈 · PR 템플릿, 이슈 번호 브랜치, 기본 브랜치 보호, 리베이스 뒤 머지 커밋, 기본 브랜치에서만 태그.

무엇을 검증 · 테스트하고 버전을 어떻게 올리는지는 프로젝트가 정한다. 여기서는 **git 과 GitHub 에서 밟는 순서**만 본다.

## 설치

```bash
claude plugin marketplace add jaemyeong-hwnag/claude-marketplaces
claude plugin install github-workflow@jaemyeong-hwnag-plugins --scope project
```

설치한 뒤 템플릿 · 라벨이 없으면 "이슈 · PR 템플릿 준비해줘" 로 `github-template-create` 를 부른다.

필요한 것: `git`, `jq`, `gh`(로그인된 상태).

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| github-template-create | 플로우 도입, 이슈 · PR 템플릿, 라벨 | 0 단계 — `.github/` 이슈 폼 · PR 템플릿 복사(덮어쓰지 않음), 라벨 `feature` · `bugfix` |
| issue-create | 작업 시작, 이슈 · 브랜치 · 워크트리 만들기 | 1 · 2 단계 — 타입 판단, 이슈 발행, 기본 브랜치에서 브랜치 · 워크트리 |
| pull-request-create | PR 올리기, 리베이스, 검증 | 4 ~ 6 단계 — 프로젝트 검증 · 테스트, 리베이스 뒤 재검증, 템플릿 · 라벨 PR |
| pull-request-merge | 머지, 정리 | 7 · 8 단계 — 머지 커밋, 기본 브랜치 받아오기, 워크트리 · 브랜치 정리, 이슈 닫힘 확인 |
| /workflow-validate | 직접 호출 | 템플릿 · 현재 브랜치 · 최신 여부 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-workflow.sh | PreToolUse (Bash) | `git` · `gh` · `claude plugin tag` 명령이 `W-03` ~ `W-10` 을 어기면 **차단**. 워크트리 위치(`W-04`)는 알림 |

## 주의

- 설치하면 이 저장소의 **기본 브랜치에서 `git commit` · `git merge` · `git push` 가 막힌다** (`W-09`). 작업은 `{feature|bugfix}/{이슈}-{slug}` 브랜치에서 한다
- 기본 브랜치는 `origin/HEAD` 에서 읽는다. 없으면 `main` 으로 본다 — `git remote set-head origin --auto` 로 맞춘다
- 웹 UI 의 머지 · 푸시는 막지 못한다. 브랜치 보호를 켤 수 있으면 같이 켠다

## 무엇을 막나

| | 조항 |
|---|---|
| 템플릿 | `W-01` 이슈 폼 `feature` · `bugfix` + 빈 이슈 금지 · `W-02` PR 템플릿 두 개, 단일 기본 파일 금지 |
| 브랜치 | `W-03` `{feature\|bugfix}/{이슈}-{slug}` · `W-04` 워크트리 위치 (알림) |
| PR · 머지 | `W-05` 템플릿 · 라벨 · `--fill` 금지 · `W-06` 최신 기본 브랜치 포함 · `W-07` 머지 커밋만 |
| 기본 브랜치 | `W-08` 강제 푸시는 `--force-with-lease` 만 · `W-09` 직접 커밋 · 머지 · 푸시 금지 · `W-10` 태그는 기본 브랜치에서만 |

## 파일

| 경로 | 역할 |
|---|---|
| `references/workflow-rules.md` | 규칙 원본 (`W-01` ~ `W-10`, 단계) |
| `scripts/validate-workflow.sh` | 훅 · CLI 겸용 검증 (`--templates` · `--branch` · `--up-to-date`) |
| `scripts/branch-create.sh` | 2 단계 — 규칙에 맞는 브랜치와 워크트리를 기본 브랜치에서 |
| `skills/github-template-create/templates/` | 기본 이슈 폼 · PR 템플릿 |
| `test/` | 회귀 테스트와 TC 명세 |
| `evals/` | `claude plugin eval` 케이스 — PR 스킬 발동 · main 커밋 차단 |

## 사용

```bash
scripts/validate-workflow.sh --templates .
scripts/branch-create.sh feature 12 order-sync
test/validate-workflow.test.sh
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
