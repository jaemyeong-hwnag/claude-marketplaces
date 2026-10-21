# git-secret-validate

Git 에 키 · 토큰 · 비밀번호가 들어가는 것을 막는다 — `git commit` · `git push` 전에 실릴 변경의 시크릿과 민감 파일(`.env` · 키 파일)을 차단하고, 파일을 쓸 때 ignore 되지 않은 파일에 새 시크릿이 들어가거나 민감 파일이 ignore 되지 않았으면 경고한다.

탐지는 gitleaks 에 맡기고, 이 플러그인은 **언제 · 무엇을 볼지**와 ignore 판정을 맡는다. gitleaks 가 없으면 내장 패턴으로 대신 본다. 진짜 유출인지 · 어떻게 고칠지는 `secret-review` 스킬이 판단한다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install git-secret-validate@jaemyeong-hwnag-plugins
brew install gitleaks    # 권장 — 없으면 내장 패턴으로 본다
```

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| secret-review | 키 · 토큰 커밋 확인 · gitignore 확인 · 훅이 막았을 때 · 유출 | 오탐 · 작업 중 노출 · 유출을 가르고 조치 (환경 변수로 옮기기 · ignore · 키 폐기 · 이력 정리는 사용자 판단) |
| /secret-validate | 직접 호출 | 작업 트리(인자 `history` 면 커밋 이력)를 검사해 조항별로 보고한다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-git-secret.sh | PreToolUse (Bash) | `git commit` · `git push` 에 실릴 변경에서 시크릿 · 민감 파일을 찾으면 **차단** |
| validate-git-secret.sh | PreToolUse (Write\|Edit\|MultiEdit) | 편집이 새로 만든 시크릿 · 민감 파일이 ignore 되지 않았으면 **경고** |

## 주의

- 커밋은 막고 작성은 경고만 한다. ignore 된 `.env` 에 키를 쓰는 것은 정상이라 알리지 않는다
- `git add … && git commit` 처럼 한 명령이면 아직 스테이징 전이라 `git add` 에 준 경로를 본다 (`.` · `-A` · `-u` 면 바뀐 파일 · ignore 안 된 새 파일 전체)
- `git push` 는 현재 브랜치에서 어떤 원격에도 없는 커밋만 본다
- Claude 가 실행하는 명령만 본다. 터미널에서 직접 하는 커밋까지 막으려면 pre-commit 과 CI 에 gitleaks 를 따로 둔다
- 오탐은 그 줄의 `gitleaks:allow` 주석이나 저장소 루트 `.git-secret-allow`(글롭 한 줄씩)로 뺀다. 넣는 것은 사용자가 정한다
- 바이너리 · 1MB 넘는 파일은 보지 않는다. `jq` · `git` 이 필요하다 (jq 가 없으면 `git commit` · `git push` 를 막는다)

## 규칙 요약

| 조항 | 언제 | 무엇을 | 판정 |
|---|---|---|---|
| `GS-01` | commit · push | 추가된 줄의 시크릿 | 차단 |
| `GS-02` | commit · push | 민감 파일 (`.env` · `*.pem` · `id_rsa` · `credentials.json` …) | 차단 |
| `GS-03` | Write · Edit | ignore 안 된 파일에 새 시크릿 | 경고 |
| `GS-04` | Write · Edit | ignore 안 됐거나 추적되는 민감 파일 | 경고 |
| `GS-05` | 언제나 | gitleaks 가 없거나 실패하면 내장 패턴으로 보고 알림 | 알림 |

원본: [`references/secret-rules.md`](references/secret-rules.md) · 패턴과 파일 목록: [`references/secret-rules.json`](references/secret-rules.json)

## 사용

```bash
scripts/validate-git-secret.sh --all .                   # 작업 트리
scripts/validate-git-secret.sh --history .               # 커밋 이력
GIT_SECRET_ENGINE=builtin scripts/validate-git-secret.sh --all .   # 엔진 고정
test/validate-git-secret.test.sh                         # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
