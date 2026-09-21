# 개발 플로우 규칙 (단일 원본)

플러그인 변경이 **이슈에서 릴리즈까지 어떤 경로로 가는가**를 정한다. 기계 검증은 [`scripts/validate-workflow.sh`](../scripts/validate-workflow.sh).

이름 · 위치 · 버전 · 작성 형식 · 의존 관계는 각 플러그인이 본다. 여기서는 **git 과 GitHub 에서 밟는 순서**만 본다.

## 1. 순서

| # | 단계 | 어디서 | 스킬 |
|---|---|---|---|
| 1 | 이슈 발행 — `feature` / `bugfix` | GitHub | `issue-create` |
| 2 | 워크트리 + 브랜치 — `origin/main` 에서 | 워크트리 | `issue-create` |
| 3 | 작업 | 워크트리 | (각 관심사 스킬) |
| 4 | 버전 올림 — CHANGELOG → `plugin.json` | 워크트리 | `pull-request-create` → `version-update` |
| 5 | 검증 — 정적 검증 전부 | 워크트리 | `pull-request-create` |
| 6 | 테스트 — 회귀 TC 전부 | 워크트리 | `pull-request-create` |
| 7 | 리베이스 — `origin/main` 위로, 그다음 5 · 6 다시 | 워크트리 | `pull-request-create` |
| 8 | PR — 타입별 템플릿 | GitHub | `pull-request-create` |
| 9 | 머지 — 직전에 최신인지 다시 확인 | GitHub | `release-create` |
| 10 | 설치 확인 — main 에서 `claude plugin list` 에 `Error:` 없음 | 메인 체크아웃 | `release-create` |
| 11 | 태그 + 릴리즈 — 버전이 바뀐 플러그인마다 | 메인 체크아웃 | `release-create` |
| 12 | 정리 — 워크트리 · 로컬 브랜치 | 메인 체크아웃 | `release-create` |

버전 올림(4)이 PR 안에 있고 태그(11)가 머지 뒤에 있는 이유: 버전도 리뷰 대상이고, 리베이스가 SHA 를 바꾸므로 브랜치에서 단 태그는 머지 뒤 어디에도 없는 커밋을 가리킨다.
설치 확인(10)이 태그 앞에 있는 이유: 훅이 로드되지 않는 버전을 릴리즈하지 않는다.

## 2. 한 단어 규칙

| 이슈 타입 | 라벨 | 브랜치 | 이슈 폼 | PR 템플릿 | 커밋 타입 | 기본 등급 | 이슈 연결 |
|---|---|---|---|---|---|---|---|
| 피처 | `feature` | `feature/{이슈}-{slug}` | `feature.yml` | `feature.md` | `feat` | MINOR | `Closes #N` |
| 버그픽스 | `bugfix` | `bugfix/{이슈}-{slug}` | `bugfix.yml` | `bugfix.md` | `fix` | PATCH | `Fixes #N` |

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

저장소가 비공개 + 무료 플랜이라 GitHub 브랜치 보호를 켤 수 없다 (API 403). "최신 main 위에서만 머지", "main 직접 푸시 금지" 를 GitHub 가 대신 해주지 않는다.
그래서 Claude 가 실행하는 `Bash` 명령에 `PreToolUse` 훅을 건다. **웹 UI 에서 하는 머지·푸시는 막지 못한다.**

### 최신 확인(`W-06`)의 동작

- `gh pr create` — 현재 `HEAD` 가 `origin/main` 을 포함하는지 본다
- `gh pr merge [번호]` — 그 PR 의 head 브랜치(`gh pr view --json headRefName`)가 `origin/main` 을 포함하는지 본다
- 둘 다 먼저 `git fetch origin main` 을 한다. 확인할 수 없으면(네트워크 · 인증) **막는다** — 어차피 그 상태로는 PR 도 머지도 안 된다

## 4. 기계가 판정할 것 / AI 가 판단할 것

| | 담당 | 무엇을 |
|---|---|---|
| 정량 | `validate-workflow.sh` | `W-01` ~ `W-10` |
| 판단 | AI (스킬 셋) | 이슈 타입(기존 판정이 바뀌면 feature 여도 MAJOR), slug 가 이슈를 말하는가, PR 본문의 "어떻게 확인했나" 가 실제로 돌린 명령인가, 영향 범위를 찾아봤는가 |

## 5. 부트스트랩 예외

플로우는 자기 자신을 만들 수 없다. 이 플러그인과 `.github/` 템플릿이 `main` 에 들어가기 전의 브랜치(`feature/plugin-creater-setting`)는 이슈 번호 없이 한 번만 예외로 머지한다. 이후는 예외가 없다.

## 6. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-workflow.sh" --templates .                  # W-01 · W-02
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-workflow.sh" --branch feature/12-order-sync  # W-03
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-workflow.sh" --up-to-date .                 # W-06 (로컬 origin/main 기준)
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-all.sh" .                                     # 5 · 6 단계 — 정적 검증 + 회귀 테스트 전부
"${CLAUDE_PLUGIN_ROOT}/scripts/release-plugins.sh" --dry-run                         # 11 단계 미리보기
```
