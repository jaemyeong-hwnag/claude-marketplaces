# 플러그인 개발 플로우 테스트

`release-plugins.sh` · `verify-all.sh` · `eval-all.sh` 의 회귀 테스트. `eval-all.sh` 는 `claude plugin eval` 을 스텁으로 대신해 모델을 부르지 않는다.
브랜치 · main 보호 · PR · 머지 훅의 TC(`TC-W01` ~ `TC-W102`)는 `github-workflow` 로 옮겼다.

## 실행

```bash
test/workflow-scripts.test.sh           # 전체 (~10초)
test/workflow-scripts.test.sh TC-W12    # ID 접두사로 필터
```

**실제 git 저장소**로 돈다 — 임시 bare 저장소를 `origin` 으로 두고 클론해서 머지 커밋 · 태그 상태를 만든다. `gh` · `claude` 는 PATH 스텁이라 GitHub 과 설치 상태를 건드리지 않는다.

## 자동 TC (29건)

### G. release · verify-all

| ID | 케이스 |
|---|---|
| TC-W103 | release: main 이 아니면 거부한다 |
| TC-W104 | release: 추적 중인 파일에 변경이 있으면 거부한다 |
| TC-W114 | release: 플러그인 디렉터리의 미추적 파일은 거부한다 |
| TC-W115 | release: 플러그인 밖 미추적 파일(.idea/ 같은)은 막지 않는다 |
| TC-W105 | release: HEAD 가 origin/main 과 다르면 거부한다 |
| TC-W106 | release: 버전이 바뀐 플러그인이 없으면 할 것이 없다 |
| TC-W107 | release --dry-run: 대상을 보여주고 아무것도 하지 않는다 |
| TC-W108 | release: 태그를 달고 CHANGELOG 절을 노트로 릴리즈한다 |
| TC-W116 | release: 직전 태그가 있으면 그 뒤의 절만 노트에 담는다 |
| TC-W117 | release: 여러 절을 담으면 뒤 절의 제목을 남기고 첫 제목은 뺀다 |
| TC-W118 | release: 날짜가 붙은 제목도 경계로 읽는다 |
| TC-W109 | release: 설치본에 로드 에러가 있으면 거부한다 (--json 의 errors) |
| TC-W113 | release: --json 을 못 받으면 텍스트의 Error 줄로 대신한다 |
| TC-W110 | release: 태그가 이미 있으면 거부한다 |
| TC-W111 | release: CHANGELOG 에 그 버전 절이 없으면 거부한다 |
| TC-W112 | verify-all: 전부 통과하면 0, 실패가 있으면 1 과 ❌ 줄 |

### H. eval 러너

| ID | 케이스 |
|---|---|
| TC-W120 | eval-all: 케이스마다 따로 돌리고 게시하지 않는다 |
| TC-W121 | eval-all: 읽기 전용 케이스에는 권한을 주지 않는다 |
| TC-W122 | eval-all: Write 케이스에는 Write 만 준다 |
| TC-W123 | eval-all: git 을 쓰는 scaffold 케이스에는 Bash(git *) 와 --scaffold 를 준다 |
| TC-W130 | eval-all: allowed_tools 의 Bash 는 git 명령으로만 좁혀 준다 |
| TC-W124 | eval-all: 결과를 플러그인 밖에 쓴다 |
| TC-W125 | eval-all: --quick 은 1회 · 기준선 없이 |
| TC-W126 | eval-all: 기준 미달이면 ❌ 와 종료 코드 1 |
| TC-W127 | eval-all: Bash 샌드박스를 못 쓰는 환경은 실패가 아니라 환경 제한이다 |
| TC-W128 | eval-all: 결과 JSON 이 없으면 실행 실패다 |
| TC-W129 | eval-all: --plugin 으로 한 플러그인만 |

### I. 워크트리 안에서 (#3)

| ID | 케이스 |
|---|---|
| TC-W131 | verify-all: 루트가 .claude/worktrees/ 안이어도 플러그인을 찾는다 |
| TC-W132 | eval-all: 루트가 .claude/worktrees/ 안이어도 케이스를 찾는다 |

## 수동 TC (새 세션 필요)

| ID | 케이스 | 입력 | 기대 |
|---|---|---|---|
| TC-WM05 | 의존성이 같이 설치된다 | main 에서 세션 시작 → `claude plugin list` | `github-workflow@plugin-marketplace` 가 enabled, `Error:` 없음 |
| TC-WM06 | 스킬이 등록된다 | `/skills` | `release-create` · `plugin-create` · `plugin-delete` |

## 변이 테스트

아래 변이는 모두 실패로 검출되는 것을 확인했다.

| 변이 | 검출된 실패 |
|---|---|
| M16 release 깨끗한 트리 검사 제거 | 1 |
| M17 release 태그 중복 검사 제거 | 1 |
| M18 release 노트 절 끊기 제거 | 1 |
| M19 release 대상 고르기(버전 변경) 제거 | 1 |
| M21 eval: Bash 를 git 으로 좁히지 않음 | 1 (TC-W130 — 처음엔 살아남아 TC 를 보강했다) |
| M22 eval: scaffold 의 git 권한 누락 | 1 |
| M23 eval: 환경 제한 구분 제거 | 1 |
| M24 eval: `--no-publish` 빠짐 | 1 |
| M25 release 노트를 현재 절만 (#2 의 옛 동작) | 2 |
| M26 release 직전 태그 무시 | 2 |
