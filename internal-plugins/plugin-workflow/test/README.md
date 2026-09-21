# 개발 플로우 테스트

`validate-workflow.sh`(훅 · CLI) · `branch-create.sh` · `release-plugins.sh` · `verify-all.sh` · `eval-all.sh` 의 회귀 테스트. `eval-all.sh` 는 `claude plugin eval` 을 스텁으로 대신해 모델을 부르지 않는다.

## 실행

```bash
test/validate-workflow.test.sh          # 전체 (~15초)
test/validate-workflow.test.sh TC-W5    # ID 접두사로 필터
```

**실제 git 저장소**로 돈다 — 임시 bare 저장소를 `origin` 으로 두고 클론해서 main · 작업 브랜치 · 원격이 앞서 나간 상태를 만든다. `gh` · `claude` 는 PATH 스텁이라 GitHub 과 설치 상태를 건드리지 않는다.

## 자동 TC (94건)

### A. 템플릿 (W-01 · W-02)

| ID | 케이스 |
|---|---|
| TC-W01 | 이 저장소의 템플릿이 통과한다 |
| TC-W02 | 규칙을 지킨 템플릿은 조용히 통과한다 |
| TC-W03 | feature.yml 이 없으면 막는다 (W-01) |
| TC-W04 | 이슈 폼 라벨이 타입과 다르면 막는다 (W-01) |
| TC-W05 | labels 를 문자열로 적어도 읽는다 |
| TC-W06 | body 가 없는 템플릿(마크다운식)은 막는다 (W-01) |
| TC-W07 | config.yml 이 없으면 막는다 (W-01) |
| TC-W08 | 빈 이슈를 허용하면 막는다 (W-01) |
| TC-W09 | PR 템플릿 feature.md 가 없으면 막는다 (W-02) |
| TC-W10 | feature.md 에 Closes # 가 없으면 막는다 (W-02) |
| TC-W11 | bugfix.md 에 Fixes # 가 없으면 막는다 (W-02) |
| TC-W12 | 단일 기본 PR 템플릿이 있으면 막는다 (W-02) |

### B. 브랜치 이름 (W-03 · W-04)

| ID | 케이스 |
|---|---|
| TC-W20 | feature/{번호}-{slug} 는 통과한다 |
| TC-W21 | bugfix/{번호}-{한 단어} 는 통과한다 |
| TC-W22 | 이슈 번호가 없으면 막는다 |
| TC-W23 | develop 을 막는다 |
| TC-W24 | 대문자를 막는다 |
| TC-W25 | slug 여섯 단어를 막는다 |
| TC-W26 | slug 다섯 단어는 통과한다 |
| TC-W27 | hotfix/ 같은 다른 타입을 막는다 |
| TC-W28 | 훅: git checkout -b 잘못된 이름을 막는다 |
| TC-W29 | 훅: git switch -c 올바른 이름은 통과한다 |
| TC-W30 | 훅: git worktree add -b 잘못된 이름을 막는다 |
| TC-W31 | 훅: git branch 새 이름을 검사한다 |
| TC-W32 | 훅: git branch 목록 · 삭제는 통과한다 |
| TC-W33 | 훅: git branch -m 새 이름을 검사한다 |
| TC-W34 | 훅: 기존 브랜치로 checkout 은 통과한다 |
| TC-W35 | 훅: 저장소 밖 워크트리는 알리기만 한다 (W-04) |
| TC-W36 | 훅: .claude/worktrees/ 워크트리는 조용하다 |

### C. main 보호 (W-08 · W-09)

| ID | 케이스 |
|---|---|
| TC-W40 | main 에서 git commit 을 막는다 |
| TC-W41 | main 에서 git merge 를 막는다 |
| TC-W42 | main 에서 --ff-only 는 통과한다 |
| TC-W43 | main 에서 refspec 없는 git push 를 막는다 |
| TC-W44 | main 에서 태그만 푸시하는 것은 통과한다 |
| TC-W45 | 원격 develop 을 지우는 푸시는 통과한다 |
| TC-W46 | 작업 브랜치에서 git commit 은 통과한다 |
| TC-W47 | 어디서든 git push origin main 을 막는다 |
| TC-W48 | HEAD:main · refs/heads/main 도 막는다 |
| TC-W49 | 작업 브랜치 푸시는 통과한다 |
| TC-W50 | --force 를 막는다 (W-08) |
| TC-W51 | -f 와 -uf 를 막는다 (W-08) |
| TC-W52 | --force-with-lease 는 통과한다 |
| TC-W53 | +refspec 을 막는다 (W-08) |

### D. 태그 (W-10)

| ID | 케이스 |
|---|---|
| TC-W60 | 작업 브랜치에서 git tag 를 막는다 |
| TC-W61 | 작업 브랜치에서 태그 목록 · 삭제는 통과한다 |
| TC-W62 | main 에서 git tag 는 통과한다 |
| TC-W63 | 작업 브랜치에서 claude plugin tag 를 막는다 |
| TC-W64 | main 에서 claude plugin tag 는 통과한다 |

### E. PR · 머지 (W-05 · W-06 · W-07)

| ID | 케이스 |
|---|---|
| TC-W70 | --fill 을 막는다 (W-05) |
| TC-W71 | 템플릿 · body-file 이 없으면 막는다 (W-05) |
| TC-W72 | 라벨이 없으면 막는다 (W-05) |
| TC-W73 | 템플릿 · 라벨이 있고 최신이면 통과한다 |
| TC-W74 | 브랜치가 최신 origin/main 을 포함하지 않으면 막는다 (W-06) |
| TC-W75 | 리베이스하면 통과한다 |
| TC-W76 | --web 은 검사하지 않는다 |
| TC-W77 | 스쿼시 머지를 막는다 (W-07) |
| TC-W78 | 리베이스 머지(-r)를 막는다 (W-07) |
| TC-W79 | 머지 방식이 없으면 막는다 (W-07) |
| TC-W80 | PR 브랜치가 최신이면 --merge 는 통과한다 |
| TC-W81 | PR 브랜치가 오래됐으면 막는다 (W-06) |
| TC-W82 | PR 을 조회할 수 없으면 막는다 (W-06) |

### F. 명령 파싱

| ID | 케이스 |
|---|---|
| TC-W90 | cd 로 main 저장소에 들어가서 커밋하면 막는다 |
| TC-W91 | git -C 로 main 저장소를 가리키면 막는다 |
| TC-W92 | 앞의 환경변수 대입을 건너뛰고 git 명령을 본다 |
| TC-W93 | ; 로 이은 두 번째 명령도 본다 |
| TC-W94 | echo 안의 git 은 명령이 아니다 |
| TC-W95 | 관심 없는 명령은 조용히 통과한다 |
| TC-W96 | Bash 가 아닌 도구에는 반응하지 않는다 |
| TC-W97 | stdin 이 비면 통과시킨다 |

### G. 스크립트

| ID | 케이스 |
|---|---|
| TC-W100 | branch-create 는 잘못된 이름을 거부한다 |
| TC-W101 | branch-create 는 (받아온) origin/main 에서 브랜치와 워크트리를 만든다 — 로컬 main 이 뒤처져 있어도 |
| TC-W102 | branch-create 는 이미 있는 워크트리를 거부한다 |
| TC-W103 | release: main 이 아니면 거부한다 |
| TC-W104 | release: 작업 트리가 더러우면 거부한다 |
| TC-W105 | release: HEAD 가 origin/main 과 다르면 거부한다 |
| TC-W106 | release: 버전이 바뀐 플러그인이 없으면 할 것이 없다 |
| TC-W107 | release --dry-run: 대상을 보여주고 아무것도 하지 않는다 |
| TC-W108 | release: 태그를 달고 CHANGELOG 절을 노트로 릴리즈한다 |
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

## 수동 TC (새 세션 필요)

| ID | 케이스 | 입력 | 기대 |
|---|---|---|---|
| TC-WM01 | 훅이 등록된다 | `/hooks` | PreToolUse(Bash) 에 `validate-workflow.sh` |
| TC-WM02 | 스킬이 등록된다 | `/skills` | `issue-create` · `pull-request-create` · `release-create` |
| TC-WM03 | main 에서 커밋을 막는다 | main 체크아웃에서 "이거 커밋해줘" | 차단 후 브랜치를 만들자고 제안 |
| TC-WM04 | 스킬이 자동 발동한다 | "작업 끝났어 PR 올려줘" (스킬 이름 언급 금지) | `pull-request-create` 발동 — 버전 · verify-all · 리베이스 순서 |

## 변이 테스트

아래 변이는 모두 실패로 검출되는 것을 확인했다.

| 변이 | 검출된 실패 |
|---|---|
| M1 `W-01` 빈 이슈 검사 제거 | 1 |
| M2 `W-02` 단일 기본 템플릿 검사 제거 | 1 |
| M3 `W-03` 이름 규칙을 느슨하게 | 4 |
| M4 `W-09` main 커밋 검사 제거 | 4 |
| M5 `W-09` main 푸시 검사 제거 | 3 |
| M6 `W-08` `-f` 검사 제거 | 1 |
| M7 `W-10` git tag 검사 제거 | 1 |
| M8 `W-10` claude plugin tag 검사 제거 | 1 |
| M9 `W-05` 라벨 검사 제거 | 1 |
| M10 `W-06` PR 전 최신 검사 제거 | 1 |
| M11 `W-06` 머지 전 최신 검사 제거 | 1 |
| M12 `W-07` 스쿼시 검사 제거 | 1 |
| M13 `cd` 추적 제거 | 1 |
| M14 앞의 환경변수 대입 건너뛰기 제거 | 1 |
| M15 복합 명령 나누기 제거 | 2 |
| M16 release 깨끗한 트리 검사 제거 | 1 |
| M17 release 태그 중복 검사 제거 | 1 |
| M18 release 노트 절 끊기 제거 | 1 |
| M19 release 대상 고르기(버전 변경) 제거 | 1 |
| M20 branch-create 가 origin/main 대신 로컬 HEAD 기준 | 1 (TC-W101 — 처음엔 살아남아 TC 를 보강했다) |
| M21 eval: Bash 를 git 으로 좁히지 않음 | 1 (TC-W130 — 처음엔 살아남아 TC 를 보강했다) |
| M22 eval: scaffold 의 git 권한 누락 | 1 |
| M23 eval: 환경 제한 구분 제거 | 1 |
| M24 eval: `--no-publish` 빠짐 | 1 |

## 알려진 한계

- 명령 파싱은 따옴표 안의 `;` · `&&` 까지 나눈다. `git commit -m "a; b"` 는 두 조각으로 보지만 판정은 같다
- `bash -c "…"` · 스크립트 파일 안의 git 명령은 보지 않는다 — 훅은 Claude 가 친 명령 한 줄만 본다
- 웹 UI 의 머지 · 푸시는 막지 못한다 (브랜치 보호를 켤 수 없는 저장소)
