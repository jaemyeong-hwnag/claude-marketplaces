---
name: enforcement-effectiveness-review
description: Claude Code 플러그인의 스킬 · 에이전트 · 훅 · MCP 역할 분리가 괜찮은지, 훅이 실제로 막는지 확인할 때 사용한다. 플러그인을 만들거나 고친 뒤 훅 · MCP 를 실제로 돌려 보고, 역할 분리는 검토 에이전트가 재현 명령을 붙여 판정한다. 트리거 — "플러그인 구성 봐줘", "역할 나눈 거 괜찮아", "훅이 실제로 막혀", "강제 되는지 확인".
---

# 강제 실효성 검토

규칙 원본: [`references/enforcement-effectiveness-rules.md`](../../references/enforcement-effectiveness-rules.md)

기계 판정(2 · 3절)은 스크립트가 하고, 역할 분리(4절)는 `enforcement-effectiveness-reviewer` 가 한다. 이 스킬은 둘을 순서대로 돌리고 **재현되는 지적만** 보고한다.

## 1. 범위

| 상황 | 대상 |
|---|---|
| 사용자가 플러그인을 지정했다 | 그 디렉터리 |
| `plugin-create` 의 확인 단계 | 만든 플러그인 |
| 그 밖 | 이번 작업에서 파일이 바뀐 플러그인 — `--since origin/main` |

## 2. 기계 판정

```bash
V="${CLAUDE_PLUGIN_ROOT}/scripts/validate-enforcement-effectiveness.sh"
"$V" <플러그인 디렉터리>                  # 2 · 3.1 · 3.3 절
"$V" --since origin/main "${CLAUDE_PROJECT_DIR:-.}"   # 바뀐 플러그인 + 훅 · MCP 실행 (3.2 절)
```

- 종료 코드 2 면 조항별로 고친다. 고친 뒤 다시 돌린다
- 경고(`EF-07` · `EF-12` · `EF-20` · `EF-31`)는 후보다. 새 플러그인이면 `EF-31` 은 `--since` 에서 차단이다
- `ℹ️ 실행 안 함` 은 검사하지 못한 것이다. 통과로 보고하지 않는다

## 3. 역할 분리 판정

`enforcement-effectiveness-reviewer` 에이전트를 부른다. 프롬프트는 아래 두 줄만 쓴다 — 만든 의도 · 내 판단 · 작업 요약을 넘기지 않는다 (`EF-41`).

```
플러그인: <절대 경로>
규칙 원본: ${CLAUDE_PLUGIN_ROOT}/references/enforcement-effectiveness-rules.md
```

에이전트를 쓸 수 없는 환경이면 4절을 판정하지 못한 것이다. 스스로 읽고 통과시키지 않는다. `판정 불가` 로 보고한다.

## 4. 재현 확인

지적마다 `재현:` 명령을 저장소 루트에서 **직접 다시 실행한다.**

| 결과 | 처리 |
|---|---|
| 출력이 `출력:` 과 같은 내용 | 보고한다 |
| 다르거나 실행되지 않음 | 버린다. 버린 수만 적는다 |
| 재현 · 출력이 없는 지적 | 버린다 |

## 5. 보고

```
강제 실효성 검토 — <플러그인>
- 기계: 위반 N (조항별) · 경고 N (조항별) · 실행 안 함 N
- 역할: 문제 없음 N · 지적 N (재현됨) · 버림 N · 판정 불가 N
- 지적: EF-4x <파일:줄> <한 문장> — 재현: <명령>
```

고치는 것은 사용자가 정한다. 이 스킬은 판정까지만 한다.
