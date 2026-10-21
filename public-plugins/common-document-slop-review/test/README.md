# common-document-slop-review 테스트

`scripts/document-slop-validate.sh` 의 회귀 테스트다. 규칙 · 패턴 · 스크립트를 고치면 여기부터 돌린다.

## 실행

```bash
test/document-slop-validate.test.sh          # 전체
test/document-slop-validate.test.sh TC-D6    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다. bash · awk · jq · git 만 쓴다. 게이트 기록은 임시 `CLAUDE_PLUGIN_DATA` 에 쓴다.

## 자동 TC (31건)

조항마다 잡아야 하는 것과 잡으면 안 되는 것을 같이 둔다.

### A. 차단 (DS-01 ~ DS-04)

| ID | 케이스 |
|---|---|
| TC-D01 | 대화 잔재는 차단, 같은 단어의 정상 문장은 통과 (DS-01) |
| TC-D02 | 플레이스홀더는 차단, 같은 글자의 마크다운 링크는 통과 (DS-02) |
| TC-D03 | 챗봇 인용 토큰은 차단 (DS-03) |
| TC-D04 | 없는 상대 링크 · 참조 링크는 차단, 있는 경로(%20 포함) · URL · 앵커 · 절대 경로는 통과 (DS-04) |
| TC-D05 | 코드 펜스 · 인라인 코드 · 인용 · HTML 주석(여러 줄 포함) · 프런트매터 안은 보지 않는다 |
| TC-D06 | document-slop-ignore 는 그 줄과 다음 줄을 뺀다 |

### B. 근거 (DS-05 ~ DS-07)

| ID | 케이스 |
|---|---|
| TC-D10 | 출처 없는 출처 표현은 경고, 같은 줄에 링크 · 미확인 · 각주가 있으면 통과 (DS-05) |
| TC-D11 | 날짜 없는 시점 표현은 경고, 연도 · 기준일이 있으면 통과 (DS-06) |
| TC-D12 | 근거 없는 수치는 경고, 출처 · 측정 · 표 행은 통과 (DS-07) |

### C. 불필요한 내용 (DS-08 ~ DS-13)

| ID | 케이스 |
|---|---|
| TC-D20 | 메타 서술은 경고, 일반 설명은 통과 (DS-08) |
| TC-D21 | 마지막 제목이 요약 절이면 경고, 앞에 있는 요약은 통과 (DS-09) |
| TC-D22 | 과용 어휘는 서로 다른 단어 3개부터 경고 (DS-10) |
| TC-D23 | 대비 구문은 2회부터 경고 (DS-11) |
| TC-D24 | 과장 어휘 · 헤지 겹침은 경고, 단정 문장은 통과 (DS-12 · DS-13) |

### D. 정리 (DS-14 ~ DS-16)

| ID | 케이스 |
|---|---|
| TC-D30 | 머리말 목록 6줄 연속 · 이모지 제목은 경고, 5줄은 통과 (DS-14) |
| TC-D31 | 굵게 남용은 경고, 적으면 통과 (DS-14) |
| TC-D32 | 제목 수준을 건너뛰면 경고, 한 단계씩이면 통과 (DS-15) |
| TC-D33 | 같은 긴 문장이 또 있으면 경고, 짧은 반복은 통과 (DS-16) |

### E. 대상 파일 · CLI

| ID | 케이스 |
|---|---|
| TC-D40 | 문서가 아닌 파일 · requirements.txt 는 보지 않는다 |
| TC-D41 | --strict 는 경고가 있으면 exit 2, 경고가 없으면 0 |
| TC-D42 | --diff 는 바뀐 줄만 본다 |
| TC-D43 | 모르는 옵션 · 없는 경로는 exit 1 |

### F. 훅

| ID | 케이스 |
|---|---|
| TC-D50 | Write 훅 — 차단은 exit 2 + stderr, 경고도 함께 보인다 |
| TC-D51 | Edit 훅 — 경고만 있으면 additionalContext, exit 0 |
| TC-D52 | Edit 훅 — 이번에 쓴 줄이 깨끗하면 다른 줄의 slop 은 알리지 않는다 |
| TC-D53 | 훅 — 문서가 아닌 파일 · 다른 이벤트 · 빈 입력 · 깨진 입력은 조용하다 |
| TC-D54 | 훅은 경고를 10건으로 자른다 |

### G. 완료 게이트 (DS-30)

| ID | 케이스 |
|---|---|
| TC-D60 | 3줄 이상 고치고 리뷰 없이 끝나면 한 번 막고, 두 번째 종료는 통과시킨다 |
| TC-D61 | 리뷰 스킬 · 에이전트가 돌면 기록을 지우고, 다른 스킬은 지우지 않는다 |
| TC-D62 | 2줄 이하 수정 · 프로젝트 밖 문서 · 세션이 다르면 기록하지 않는다 |
| TC-D63 | DOCUMENT_SLOP_REVIEW_GATE=0 이면 게이트가 꺼진다 |

## 수동 확인

| 항목 | 방법 |
|---|---|
| 훅이 설치 상태에서 돈다 | `claude plugin details common-document-slop-review@jaemyeong-hwnag-plugins` 의 Hooks 가 `(2) PostToolUse, Stop` 인가 (hooks.json 의 이벤트 수) |
| 차단 · 스킬 발동 | `evals/` 두 케이스 — `eval-all.sh --quick --plugin common-document-slop-review` |
