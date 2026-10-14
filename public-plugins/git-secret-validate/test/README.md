# Git 시크릿 테스트

`scripts/validate-git-secret.sh` 의 회귀 테스트. 규칙이나 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/validate-git-secret.test.sh          # 전체
test/validate-git-secret.test.sh TC-S3    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다. 기본은 내장 엔진(`GIT_SECRET_ENGINE=builtin`)으로 돌고, gitleaks 가 있으면 D 절의 gitleaks TC 를 더 돈다.

## 자동 TC

픽스처는 TC 마다 새로 만든 **깨끗한 저장소**(커밋 하나)이고, TC 마다 한 곳만 더한다. 가짜 시크릿은 이 파일이 저장소 검사(TC-S01)에 걸리지 않도록 이어 붙여 만든다.

### A. CLI

| ID | 케이스 |
|---|---|
| TC-S01 | 이 저장소 전체가 통과한다 |
| TC-S02 | 시크릿 · 민감 파일이 없는 저장소는 통과한다 |
| TC-S03 | 추적 파일의 AWS 키 · GitHub 토큰을 찾고 값은 앞 4글자만 보인다 (GS-01) |
| TC-S04 | 개인 키 블록을 찾는다 (GS-01) |
| TC-S05 | 비밀번호 이름의 변수에 넣은 문자열을 찾는다 (GS-01) |
| TC-S06 | 플레이스홀더 · 환경 변수 읽기는 시크릿으로 보지 않는다 (과잉 차단 방지) |
| TC-S07 | gitleaks:allow 주석이 있는 줄은 건너뛴다 |
| TC-S08 | ignore 되지 않은 .env 는 GS-04, ignore 되면 통과한다 |
| TC-S09 | 추적되는 민감 파일은 .gitignore 에 있어도 GS-02 |
| TC-S10 | .env.example · *.pub · 일반 파일은 민감 파일이 아니다 (과잉 차단 방지) |
| TC-S11 | 키 · 인증서 · 자격 증명 파일을 민감 파일로 본다 (GS-04) |
| TC-S12 | .git-secret-allow 의 파일 · 디렉터리는 건너뛴다 |
| TC-S13 | --history 는 나중에 지운 시크릿 · 민감 파일도 찾는다 |
| TC-S14 | 바이너리 파일은 보지 않는다 |
| TC-S15 | git 저장소가 아닌 디렉터리 · 파일 인자도 본다 |
| TC-S16 | 하위 디렉터리를 루트로 주면 그 아래만 본다 |

### B. 훅 — Bash

| ID | 케이스 |
|---|---|
| TC-S30 | 스테이징된 시크릿이 있으면 git commit 을 막는다 (GS-01) |
| TC-S31 | 깨끗한 커밋은 조용히 통과한다 |
| TC-S32 | 같은 명령의 git add 는 스테이징 전이라도 본다 |
| TC-S33 | git add 없는 git commit 은 스테이징되지 않은 파일을 보지 않는다 (과잉 차단 방지) |
| TC-S34 | git commit -am 은 바뀐 추적 파일을 본다 |
| TC-S35 | 스테이징된 .env 는 막는다 (GS-02) |
| TC-S36 | git add -f 로 ignore 된 파일을 넣으면 막는다 (GS-02) |
| TC-S37 | cd <저장소> && · git -C <저장소> 를 따라간다 |
| TC-S38 | 시크릿을 지우는 커밋은 통과한다 (추가된 줄만 본다) |
| TC-S39 | 첫 커밋(HEAD 없음)도 본다 |
| TC-S40 | git push 는 원격에 없는 커밋의 시크릿을 막고, 푸시된 뒤에는 통과한다 |
| TC-S41 | git commit · push 가 아닌 명령은 보지 않는다 |
| TC-S42 | git 저장소 밖 · 빈 입력 · PostToolUse 는 통과한다 |

### C. 훅 — Write · Edit

| ID | 케이스 |
|---|---|
| TC-S50 | ignore 안 된 파일에 시크릿을 쓰면 경고하고 통과한다 (GS-03) |
| TC-S51 | ignore 된 .env 에 시크릿을 쓰면 조용히 통과한다 (과잉 경고 방지) |
| TC-S52 | ignore 안 된 .env 를 만들면 경고한다 (GS-04) |
| TC-S53 | 추적되는 민감 파일은 ignore 에 있어도 경고한다 (GS-04) |
| TC-S54 | 기존 시크릿이 있는 파일의 다른 줄을 고치면 경고하지 않는다 (새로 생긴 것만) |
| TC-S55 | Edit 가 시크릿을 더하면 경고한다 |
| TC-S56 | 아직 없는 하위 디렉터리 · 심볼릭 링크 경로도 저장소 안으로 본다 |
| TC-S57 | 저장소 밖 · .git 안 · .git-secret-allow 경로는 보지 않는다 |

### D. 엔진

| ID | 케이스 |
|---|---|
| TC-S70 | 내장 엔진이면 GS-05 를 알린다 |
| TC-S71 | GIT_SECRET_ENGINE 이 잘못되면 실행 오류다 |
| TC-S72 | gitleaks 엔진도 같은 경로 · 가린 값으로 보고한다 (gitleaks 가 있을 때) |
| TC-S73 | gitleaks 엔진으로 커밋을 막고 gitleaks:allow 를 따른다 (gitleaks 가 있을 때) |
| TC-S74 | gitleaks 엔진도 편집 전후를 비교한다 (gitleaks 가 있을 때) |
