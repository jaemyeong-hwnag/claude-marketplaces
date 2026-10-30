# common-evidence-review 테스트

`scripts/evidence-validate.sh` 의 회귀 테스트다. 규칙 · 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/evidence-validate.test.sh          # 전체
test/evidence-validate.test.sh TC-E2    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다. bash · jq · git 만 쓴다. 기록은 임시 `CLAUDE_PLUGIN_DATA` 에 쓴다.

## 자동 TC (33건)

조항마다 걸려야 하는 것과 걸리면 안 되는 것을 같이 둔다.

### A. 테스트 약화 신호 (E-20)

| ID | 케이스 |
|---|---|
| TC-E01 | 테스트 파일에 skip 표지를 더하면 알림, 같은 편집이 코드 파일이면 조용 |
| TC-E02 | 단언이 줄면 알림, 그대로거나 늘면 조용 |
| TC-E03 | Write 는 HEAD 의 파일과 비교한다 |
| TC-E04 | 테스트 파일 판정 — 경로 · 이름 규약은 잡고 비슷한 이름은 놓아준다 |
| TC-E04b | 테스트 판정은 프로젝트 기준 경로로 한다 — 프로젝트가 tests/ 아래여도 코드는 코드다 |
| TC-E05 | 이름 안의 fit( · xit( 는 표지가 아니다 |
| TC-E06 | MultiEdit 은 편집 전부를 합쳐 본다 |
| TC-E07 | 언어별 단언 · skip 표지를 센다 |
| TC-E08 | 한글 경로의 추적 파일도 HEAD 와 비교한다 |
| TC-E09 | 경로의 | · & 를 그대로 기록하고 stderr 가 없다 |

### B. 완료 게이트 (E-30)

| ID | 케이스 |
|---|---|
| TC-E10 | 코드를 3줄 바꾸고 검증 없이 끝내면 한 번 되돌린다 |
| TC-E11 | 2줄이면 막지 않고 기록을 지운다 |
| TC-E12 | 바꾼 줄은 요청 전체로 합친다 — 2줄 + 1줄이면 막는다 |
| TC-E13 | 지운 줄도 센다 — 3줄을 지우면 막는다 |
| TC-E14 | 문서만 고쳤으면 막지 않는다 (DS-30 몫) |
| TC-E15 | 프로젝트 밖 파일은 세지 않는다 |
| TC-E16 | 이 훅이 되돌린 뒤의 종료(stop_hook_active)는 통과시키고 기록을 지운다 |
| TC-E16b | 다른 훅이 되돌려 stop_hook_active 가 true 여도 아직 안 막았으면 막는다 |
| TC-E17 | evidence-reviewer 가 돌면 통과, 다른 에이전트는 통과시키지 않는다 |
| TC-E17b | 검증 뒤에 3줄 이상 또 고치면 다시 막는다. 검증 뒤 편집만 센다 |
| TC-E18 | EVIDENCE_REVIEW_GATE=0 이면 기록도 차단도 없다 |
| TC-E19 | 세션마다 따로 센다 |
| TC-E20 | 요청 원문을 기록하고 경로를 알린다. 백그라운드 알림은 뺀다 |
| TC-E20b | 새 요청은 앞 요청(중단돼 Stop 이 안 돈 것)의 기록을 잇지 않는다 |
| TC-E21 | 요청 기록이 없으면 대화의 요청을 쓰라고 알린다 |
| TC-E22 | 최종 답에서 주장 후보를 뽑는다 — 코드 펜스 안은 빼고 10개까지, 문자 단위로 자른다 |
| TC-E23 | 기록된 테스트 약화 신호를 게이트 메시지에 넣는다 |
| TC-E23b | requirements.txt · CMakeLists.txt 는 문서가 아니라 설정으로 센다 |
| TC-E24 | EVIDENCE_REVIEW_MIN_LINES 로 문턱을 바꾼다 |
| TC-E25 | 백그라운드로 띄운 evidence-reviewer 는 끝날 때(SubagentStop)까지 검증으로 치지 않는다 |

### C. CLI --diff

| ID | 케이스 |
|---|---|
| TC-E30 | 기본 브랜치 대비 테스트 약화를 낸다. --strict 면 exit 2 |
| TC-E31 | 인자 없음 · 모르는 인자 · git 밖은 exit 1 |

### D. fail-open

| ID | 케이스 |
|---|---|
| TC-E40 | 훅 입력이 JSON 이 아니거나 jq 가 없으면 조용히 통과 |
