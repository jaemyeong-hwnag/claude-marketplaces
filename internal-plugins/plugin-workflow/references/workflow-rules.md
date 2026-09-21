# 플러그인 개발 플로우 (단일 원본)

이 마켓플레이스에서 플러그인 변경이 **이슈에서 릴리즈까지** 가는 경로. 기본 흐름(이슈 · 브랜치 · PR · 머지와 `W-01` ~ `W-10`)은 의존하는 `github-workflow` 가 맡는다.
여기서는 그 흐름에 **플러그인 마켓플레이스가 더하는 단계**만 정한다.

## 1. 순서

`github-workflow` 의 단계에 ★ 를 더한다.

| # | 단계 | 스킬 · 스크립트 | 담당 |
|---|---|---|---|
| 1 | 이슈 발행 | `issue-create` | github-workflow |
| 2 | 워크트리 + 브랜치 | `issue-create` · `branch-create.sh` | github-workflow |
| 3 | 작업 — 새 플러그인 · 삭제면 해당 스킬 | `plugin-create` · `plugin-delete` | ★ plugin-workflow |
| 4 | ★ 버전 올림 — 파일이 바뀐 플러그인마다 CHANGELOG → `plugin.json` | `version-update` | ★ plugin-versioning |
| 5 | 검증 · 테스트 — **`verify-all.sh`** | `pull-request-create` | github-workflow (명령은 ★) |
| 6 | 리베이스 → 5 다시 | `pull-request-create` | github-workflow |
| 7 | PR | `pull-request-create` | github-workflow |
| 8 | 머지 | `pull-request-merge` | github-workflow |
| 9 | ★ 설치 확인 — main 에서 `claude plugin list` 에 `Error:` 없음 | `release-create` | ★ plugin-workflow |
| 10 | ★ 태그 + 릴리즈 — 버전이 바뀐 플러그인마다 | `release-create` · `release-plugins.sh` | ★ plugin-workflow |
| 11 | 정리 | `pull-request-merge` | github-workflow |

버전 올림(4)이 PR 안에 있고 태그(10)가 머지 뒤에 있는 이유: 버전도 리뷰 대상이고, 리베이스가 SHA 를 바꾸므로 브랜치에서 단 태그는 머지 뒤 어디에도 없는 커밋을 가리킨다.
설치 확인(9)이 태그 앞에 있는 이유: 훅이 로드되지 않는 버전을 릴리즈하지 않는다.

## 2. 이슈 타입과 버전 등급

| 이슈 타입 | 기본 등급 | 예외 |
|---|---|---|
| `feature` | MINOR | 기존 판정이 바뀌면(전에 통과하던 것이 막히면) MAJOR — `0.x` 면 MINOR |
| `bugfix` | PATCH | - |

## 3. 스크립트

| 스크립트 | 단계 | 무엇을 |
|---|---|---|
| `verify-all.sh` | 5 · 6 | 검증기 · 회귀 테스트 · `claude plugin validate --strict` 를 경로 규칙으로 찾아 전부 |
| `release-plugins.sh` | 10 | 머지 커밋의 첫 부모와 비교해 `version` 이 바뀐 플러그인마다 `claude plugin tag --push` → `gh release create` |
| `eval-all.sh` | 필요할 때 | 모든 플러그인의 eval 케이스를 케이스 단위로, `--no-publish` |

## 4. 부트스트랩 예외

플로우는 자기 자신을 만들 수 없다. 이 플러그인과 `.github/` 템플릿이 `main` 에 들어가기 전의 브랜치(`feature/plugin-creater-setting`)는 이슈 번호 없이 한 번만 예외로 머지했다. 이후는 예외가 없다.

## 5. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/verify-all.sh" .                 # 5 · 6 단계
"${CLAUDE_PLUGIN_ROOT}/scripts/release-plugins.sh" --dry-run     # 10 단계 미리보기
```
