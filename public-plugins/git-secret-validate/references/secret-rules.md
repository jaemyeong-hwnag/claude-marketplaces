# Git 시크릿 규칙 (단일 원본)

이 문서가 기준이다. 스킬 · 커맨드 · 훅은 이 문서를 참조한다.
기계 검증은 [`scripts/validate-git-secret.sh`](../scripts/validate-git-secret.sh), 내장 패턴과 민감 파일 목록은 [`secret-rules.json`](./secret-rules.json).

## 1. 조항

| 조항 | 언제 | 무엇을 | 판정 |
|---|---|---|---|
| `GS-01` | `git commit` · `git push` 직전 | 커밋 · 푸시될 변경의 **추가된 줄**에 시크릿이 있다 | 차단 |
| `GS-02` | `git commit` · `git push` 직전 | 커밋 · 푸시될 변경에 민감 파일이 있다 | 차단 |
| `GS-03` | 파일 작성(`Write` · `Edit`) 직전 | 편집이 **새로 만든** 시크릿이 ignore 되지 않은 파일에 들어간다 | 경고 |
| `GS-04` | 파일 작성 직전 | 민감 파일이 ignore 되지 않았거나 이미 추적된다 | 경고 |
| `GS-05` | 언제나 | gitleaks 가 없거나 실행에 실패하면 내장 패턴으로 대신 보고 그 사실을 알린다 | 알림 |

커밋은 막고 작성은 경고만 한다. `.env` 에 키를 쓰는 것은 정상이다 — 문제는 그 파일이 저장소에 들어가는 순간이다.

## 2. 무엇이 커밋 · 푸시되는가

| 명령 | 보는 변경 |
|---|---|
| `git commit` | 스테이징된 변경 |
| 같은 명령에 `git add <경로>` | + 그 경로의 바뀐 추적 파일, ignore 되지 않은 새 파일 |
| 같은 명령에 `git add .` · `-A` · `-u` · 경로 없는 `git add` · `git commit -a` | + 바뀐 추적 파일 전체, ignore 되지 않은 새 파일. 아직 스테이징 전이라 범위를 넓게 잡는다 |
| `git add -f <경로>` | + 그 경로 (ignore 된 파일이라도) |
| `git commit <경로>` · `--only` · `-i` | + 그 경로의 바뀐 추적 파일 (작업 트리 내용이 커밋된다) |
| `git push` | 현재 브랜치에서 어떤 원격에도 없는 커밋 (`HEAD --not --remotes`) 전부 |

- 앞쪽 `cd <dir> &&` 와 `git -C <dir>` 을 따라 저장소를 찾는다. `-C` · `-c` 값은 따옴표 문자열이어도 된다
- `/usr/bin/git` 처럼 경로로 부른 git 도 본다. `git add` 경로에 변수 · 명령 치환이 있으면 바뀐 파일 전체를 본다
- `jq` 가 없으면 명령을 읽을 수 없어 `git commit` · `git push` 로 보이는 명령을 막는다
- 바이너리 · 1MB 넘는 파일은 보지 않는다
- 다른 브랜치를 이름으로 푸시하는 경우(`git push origin other`)는 현재 브랜치만 본다

## 3. 시크릿

gitleaks 가 있으면 gitleaks 의 기본 규칙을 쓴다. 저장소 루트의 `.gitleaks.toml` 이 있으면 그 설정을 쓴다.
없으면 `secret-rules.json` 의 `patterns` 로 본다.

| 묶음 | 예 |
|---|---|
| 개인 키 | PEM · OpenSSH · PGP 개인 키 블록 |
| 클라우드 · 서비스 토큰 | AWS 액세스 키, GitHub · GitLab · Slack · npm 토큰, Google API 키, Stripe 라이브 키, Anthropic · OpenAI API 키 |
| 자격 증명이 든 값 | JWT, 사용자 · 비밀번호를 넣은 접속 URL |
| 이름으로 아는 값 | `password` · `secret` · `api_key` · `access_token` · `client_secret` 같은 이름의 변수에 8자 이상 문자열을 직접 넣음 |

- 내장 엔진은 `placeholder` 에 걸리는 값(`${VAR}` · `$VAR` 로 시작하는 값, `<token>` · `example` · `changeme` · `getenv` …)을 보지 않는다
- 보고는 값의 앞 4글자만 보인다

## 4. 민감 파일

`secret-rules.json` 의 `sensitive_files.deny` 에 맞고 `allow` 에 맞지 않는 파일이다. `/` 가 없는 글롭은 파일 이름과 맞춘다.

| 묶음 | 예 |
|---|---|
| 환경 변수 파일 | `.env` · `.env.*` · `*.env` (`.env.example` · `.env.sample` · `.env.template` 은 허용) |
| 키 · 인증서 | `*.pem` · `*.key` · `*.p12` · `*.pfx` · `*.jks` · `*.keystore` · `*.ppk` · `id_rsa` · `id_ed25519` … (`*.pub` 허용) |
| 자격 증명 파일 | `.netrc` · `.pgpass` · `.htpasswd` · `credentials.json` · `client_secret*.json` · `service-account*.json` · `secrets.yml` |
| 상태 파일 | `*.tfstate` · `*.kdbx` |

ignore 판정은 `git check-ignore --no-index` 다. 이미 추적되는 파일은 ignore 에 넣어도 계속 커밋되므로 `git rm --cached` 로 빼야 한다.

## 5. 오탐 탈출구

| 방법 | 범위 |
|---|---|
| 줄 끝에 `gitleaks:allow` 주석 | 그 줄 (두 엔진 모두) |
| 저장소 루트의 `.git-secret-allow` 에 글롭 · 경로 한 줄씩 (`#` 주석) | 그 파일 · 디렉터리 전체 — 시크릿과 민감 파일 둘 다 |
| `.gitleaks.toml` 의 allowlist | gitleaks 엔진 |

탈출구를 쓰는 것은 사용자가 정한다. 막혔다고 Claude 가 스스로 추가하지 않는다.

## 6. 기계가 판정할 것 / AI 가 판단할 것

| | 담당 | 무엇을 |
|---|---|---|
| 정량 | `validate-git-secret.sh` | 패턴 일치, 민감 파일 이름, ignore · 추적 여부, 커밋 · 푸시 범위 |
| 판단 | `secret-review` 스킬 | 진짜 시크릿인가 오탐인가, 어디로 옮길까, 이미 노출됐는가(폐기 · 이력 정리) |
