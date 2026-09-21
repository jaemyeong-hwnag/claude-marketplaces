# plugin-workflow

플러그인 마켓플레이스가 GitHub 플로우에 **더하는 단계**를 맡는다 — 플러그인 생성 · 삭제 순서, 검증 전체 실행, 설치 확인 뒤 플러그인별 태그 · 릴리즈, eval 실행.

이슈 · 브랜치 · PR · 머지 규칙(`W-01` ~ `W-10`)과 그 훅은 의존하는 `github-workflow` 가 본다. 이름 · 위치 · 버전 · 작성 형식 · 의존 관계는 각 플러그인이 본다.

## 설치

이 저장소에서는 SessionStart 훅(`.claude/hooks/sync-internal-plugins.sh`)이 등록·활성화·설치한다. 의존성 `github-workflow` 는 설치할 때 Claude Code 가 같이 설치한다.
internal 플러그인이라 다른 저장소에 배포하지 않는다.

## 의존성

| 플러그인 | 왜 |
|---|---|
| `github-workflow` | 이슈 · 브랜치 · PR · 머지 단계와 훅. 이 플러그인은 그 사이에 단계를 더한다 |

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| release-create | 릴리즈, 태그, 배포 | 9 · 10 단계 — main 에서 설치 확인, 버전이 바뀐 플러그인마다 태그 · 릴리즈 |
| plugin-create | 새 플러그인 만들기 | 필요성 판단 → 이름 → 디렉터리 → 버전 → README → 의존성 → 등록 → eval → 검증 → 설치 확인 |
| plugin-delete | 플러그인 삭제 · 비활성화 | 역참조 확인 → 의존 끊기 → 디렉터리 · 등록 정리. 태그는 남긴다 |

## 파일

| 경로 | 역할 |
|---|---|
| `references/workflow-rules.md` | 이 마켓플레이스가 더하는 단계 (`github-workflow` 단계와의 순서) |
| `scripts/verify-all.sh` | 검증기 · 회귀 테스트 · `claude plugin validate` 를 경로 규칙으로 찾아 전부 |
| `scripts/release-plugins.sh` | 버전이 바뀐 플러그인마다 태그 · 릴리즈 (`--dry-run`) |
| `scripts/eval-all.sh` | 모든 플러그인의 eval 케이스를 케이스 단위로 — 필요한 권한만 주고, 리포트는 게시하지 않는다 (`--quick`) |
| `test/` | 회귀 테스트와 TC 명세 |
| `evals/` | `claude plugin eval` 케이스 — 생성 · 삭제 스킬 발동 |

## 주의

- 워크트리 세션에서 도는 스킬 · 훅은 **메인 체크아웃의 것**이다. 워크트리에서 고친 것은 머지 뒤에 반영된다
- 이 플러그인과 `.github/` 가 main 에 들어가기 전의 브랜치(`feature/plugin-creater-setting`)는 부트스트랩 예외로 한 번만 이슈 없이 머지했다

## 사용

```bash
scripts/verify-all.sh .
scripts/release-plugins.sh --dry-run
scripts/eval-all.sh --quick .
test/workflow-scripts.test.sh
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
