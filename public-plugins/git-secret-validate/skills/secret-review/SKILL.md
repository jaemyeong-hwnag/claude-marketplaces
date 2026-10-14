---
name: secret-review
description: 커밋 전에 키 · 토큰 · 비밀번호가 들어갔는지, .env · 키 파일이 ignore 됐는지 확인할 때 사용한다. 훅이 시크릿으로 커밋을 막았을 때, 키가 이미 커밋 · 푸시됐을 때도 적용한다. 트리거 — "키 들어갔나", "시크릿", "비밀번호 커밋", "gitignore 됐나", "토큰 유출", "gitleaks". 오탐 · 실제 유출을 판단하고 조치한다.
---

# 시크릿 검토와 조치

규칙 원본: [`references/secret-rules.md`](../../references/secret-rules.md)
기계 검증: [`scripts/validate-git-secret.sh`](../../scripts/validate-git-secret.sh)

찾는 것은 스크립트가 한다. 이 스킬은 **찾은 것이 무엇이고 어떻게 할지**를 정한다.

## 1. 찾는다

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-git-secret.sh" --all .       # 작업 트리
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-git-secret.sh" --history .   # 커밋 이력 — 이미 들어간 것
```

결과에 `GS-05` 알림이 있으면 gitleaks 가 없어 내장 패턴만 본 것이다. 사용자에게 `brew install gitleaks` (또는 각 OS 패키지)를 권한다.

## 2. 하나씩 판단한다

| 질문 | 예 → | 아니오 → |
|---|---|---|
| 실제로 쓰이는 값인가 (테스트 픽스처 · 문서 예시 · 공개 키가 아닌가) | 다음 질문 | **오탐** — 5절 |
| 아직 커밋되지 않았는가 | **작업 중 노출** — 3절 | 다음 질문 |
| 원격에 푸시되지 않았는가 (`git branch -r --contains <커밋>` 이 비었나) | **로컬 커밋** — 4절 1 · 2 | **유출** — 4절 전체 |

값을 출력하거나 대화에 다시 적지 않는다. 파일 · 줄 · 규칙 이름으로만 말한다.

## 3. 작업 중 노출 — 코드에서 뺀다

1. 값을 환경 변수 읽기로 바꾼다 (`os.environ["API_KEY"]`, `process.env.API_KEY`, `System.getenv("API_KEY")`, 설정 프레임워크의 플레이스홀더)
2. 로컬 값은 `.env` 같은 ignore 된 파일에 둔다. `.gitignore` 에 없으면 넣는다
3. 필요한 변수 이름을 `.env.example` 에 값 없이 적는다
4. 민감 파일이 이미 추적되면 `git rm --cached <파일>` 로 빼고 `.gitignore` 에 넣는다 — 파일은 지우지 않는다

```gitignore
.env
.env.*
!.env.example
*.pem
*.key
```

## 4. 이미 커밋 · 푸시됨 — 폐기가 먼저다

1. **키를 폐기 · 재발급한다.** 푸시된 키는 이미 복제됐다고 본다. 이력에서 지워도 폐기를 대신하지 못한다. 폐기는 사용자가 서비스 콘솔에서 한다 — 어느 키를 어디서 폐기할지 알려 준다
2. 3절로 코드에서 뺀 커밋을 새로 만든다
3. 이력 정리(`git filter-repo` · BFG)는 **사용자가 정한다.** 강제 푸시가 필요하고 다른 사람의 클론이 깨진다. 묻지 않고 하지 않는다

푸시 전 로컬 커밋이면 1 대신 `git reset --soft` · `git commit --amend` 로 커밋에서 빼도 된다. 그래도 값이 다른 곳(로그 · 공유 채널)에 갔다면 폐기한다.

## 5. 오탐

- 줄 하나면 그 줄 끝에 `gitleaks:allow` 주석
- 테스트 픽스처처럼 파일 · 디렉터리 전체면 저장소 루트 `.git-secret-allow` 에 경로 한 줄
- **탈출구는 사용자에게 확인받고 넣는다.** 훅이 막았다고 스스로 넣지 않는다

## 하지 않을 것

- 훅을 피하려고 `--no-verify` · 다른 명령 형태 · 탈출구를 쓰지 않는다
- 시크릿 값을 출력 · 커밋 메시지 · PR 본문에 적지 않는다
- 사용자 확인 없이 이력을 다시 쓰거나 강제 푸시하지 않는다
