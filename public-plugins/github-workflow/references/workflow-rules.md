# GitHub 개발 플로우 규칙 (단일 원본)

GitHub 저장소의 변경이 **이슈에서 머지까지 어떤 경로로 가는가**를 정한다. 기계 검증은 [`scripts/validate-workflow.sh`](../scripts/validate-workflow.sh).

무엇을 검증 · 테스트하고 버전을 어떻게 올리는지는 프로젝트가 정한다 (프로젝트 `CLAUDE.md` 나 다른 플러그인). 여기서는 **git 과 GitHub 에서 밟는 순서**만 본다.

**기본 브랜치**는 `origin/HEAD` 가 가리키는 브랜치다. 없으면 `main` 으로 본다. 이 문서의 `main` 은 기본 브랜치를 뜻한다.

## 1. 순서

| # | 단계 | 어디서 | 스킬 |
|---|---|---|---|
| 0 | 템플릿 · 라벨 준비 — 저장소마다 한 번 | 저장소 | `github-template-create` |
| 1 | 이슈 발행 — `feature` / `bugfix` | GitHub | `issue-create` |
| 2 | 워크트리 + 브랜치 — `origin/main` 에서 | 워크트리 | `issue-create` |
| 3 | 작업 | 워크트리 | - |
| 4 | 검증 · 테스트 — 프로젝트가 정한 명령 전부 | 워크트리 | `pull-request-create` |
| 5 | 리베이스 — `origin/main` 위로, 그다음 4 다시 | 워크트리 | `pull-request-create` |
| 6 | PR — 타입별 템플릿 · 라벨 | GitHub | `pull-request-create` |
| 7 | 머지 — 직전에 최신인지 다시 확인, 머지 커밋 | GitHub | `pull-request-merge` |
| 8 | 받아오기 · 정리 — `main` 을 `--ff-only` 로, 워크트리 · 브랜치 삭제, 이슈 닫힘 확인 | 메인 체크아웃 | `pull-request-merge` |

프로젝트는 단계를 더할 수 있다 (예: 4 앞에 버전 올림, 8 뒤에 태그 · 릴리즈). 더한 단계도 아래 조항을 지킨다 — 특히 태그는 머지 뒤 `main` 에서(`W-10`).

리베이스(5) 뒤에 검증(4)을 다시 하는 이유: 리베이스 전의 결과는 다른 코드의 결과다.
태그를 머지 뒤에 다는 이유: 리베이스가 SHA 를 바꾸므로 브랜치에서 단 태그는 머지 뒤 어디에도 없는 커밋을 가리킨다.

## 2. 한 단어 규칙

| 이슈 타입 | 라벨 | 브랜치 | 이슈 폼 | PR 템플릿 | 커밋 타입 | 이슈 연결 |
|---|---|---|---|---|---|---|
| 피처 | `feature` | `feature/{이슈}-{slug}` | `feature.yml` | `feature.md` | `feat` | `Closes #N` |
| 버그픽스 | `bugfix` | `bugfix/{이슈}-{slug}` | `bugfix.yml` | `bugfix.md` | `fix` | `Fixes #N` |

## 3. 조항

| 조항 | 내용 | 판정 |
|---|---|---|
| `W-01` | `.github/ISSUE_TEMPLATE/` 에 `feature.yml` · `bugfix.yml` 이 있고 라벨이 각각 `feature` · `bugfix` 다. `config.yml` 이 빈 이슈를 막는다 | 차단 (`--templates`) |
| `W-02` | `.github/PULL_REQUEST_TEMPLATE/` 에 `feature.md` · `bugfix.md` 가 있고 각각 `Closes #` · `Fixes #` 를 담는다. 단일 기본 파일(`pull_request_template.md`)은 두지 않는다 — 폴더 템플릿보다 우선해서 타입 구분이 무너진다 | 차단 (`--templates`) |
| `W-03` | 새 브랜치 이름은 `{feature\|bugfix}/{이슈 번호}-{slug}`. slug 는 영문 kebab-case 1 ~ 5 단어. `develop` 같은 장기 브랜치를 만들지 않는다 | 차단 (훅) |
| `W-04` | 워크트리는 `.claude/worktrees/{이슈}-{slug}` 에 만든다 — Claude Code 가 관리하는 위치 | 알림 (훅) |
| `W-05` | PR 은 템플릿(`--template` / `--body-file`)과 라벨(`feature` / `bugfix`)을 붙여 연다. `--fill` 은 쓰지 않는다 | 차단 (훅) |
| `W-06` | PR 을 열거나 머지하기 전에 브랜치가 `origin/main` 을 포함한다 (리베이스됨) | 차단 (훅) |
| `W-07` | 머지는 머지 커밋(`--merge`)으로만. `--squash` · `--rebase` 를 쓰지 않는다 | 차단 (훅) |
| `W-08` | 강제 푸시는 `--force-with-lease` 만 | 차단 (훅) |
| `W-09` | `main` 에 직접 커밋 · 머지 · 푸시하지 않는다. `git pull --ff-only` · `git merge --ff-only` 만 된다 | 차단 (훅) |
| `W-10` | 태그(`git tag` · `claude plugin tag`)는 `main` 에서만 단다 | 차단 (훅) |

### 왜 훅인가

GitHub 브랜치 보호는 비공개 저장소의 무료 플랜에서 켤 수 없다. 켤 수 있는 저장소라도 Claude 가 명령을 치기 **전에** 막는 편이 되돌리기보다 싸다.
그래서 Claude 가 실행하는 `Bash` 명령에 `PreToolUse` 훅을 건다. **웹 UI 에서 하는 머지·푸시는 막지 못한다.** 브랜치 보호를 켤 수 있으면 같이 켠다.

### 최신 확인(`W-06`)의 동작

- `gh pr create` — 현재 `HEAD` 가 `origin/main` 을 포함하는지 본다
- `gh pr merge [번호]` — 그 PR 의 head 브랜치(`gh pr view --json headRefName`)가 `origin/main` 을 포함하는지 본다
- 둘 다 먼저 `git fetch origin main` 을 한다. 확인할 수 없으면(네트워크 · 인증) **막는다** — 어차피 그 상태로는 PR 도 머지도 안 된다

## 4. 기계가 판정할 것 / AI 가 판단할 것

| | 담당 | 무엇을 |
|---|---|---|
| 정량 | `validate-workflow.sh` | `W-01` ~ `W-10` |
| 판단 | AI (스킬) | 이슈 타입(기존 동작이 바뀌면 feature), slug 가 이슈를 말하는가, PR 본문의 "어떻게 확인했나" 가 실제로 돌린 명령인가, 영향 범위를 찾아봤는가 |

## 5. 처음 도입할 때

플로우는 자기 자신을 만들 수 없다. 템플릿(`W-01` · `W-02`)이 기본 브랜치에 들어가는 첫 PR 하나는 이슈 번호 없이 들어가도 된다. 이후는 예외가 없다.

## 6. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-workflow.sh" --templates .                  # W-01 · W-02
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-workflow.sh" --branch feature/12-order-sync  # W-03
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-workflow.sh" --up-to-date .                 # W-06 (로컬 origin/main 기준)
```
