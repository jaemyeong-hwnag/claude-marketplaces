---
name: plugin-install
description: 조회한 플러그인을 설치할 때 사용한다. 전부 · 번호로 일부 · 제외 · 조회만 중 고르게 하고 범위(project · user · local)를 정해 설치한 뒤 결과와 재시작 필요 여부를 알린다. 트리거 — "깔아줘", "설치해줘", "전부 설치", "1번 3번만", "이거 빼고", "plugin install".
---

# 플러그인 설치

규칙 원본: [`references/search-rules.md`](../../references/search-rules.md) — 6절.

설치 대상은 이 마켓의 public 플러그인뿐이다. MCP 도구 `install_plugins` 가 보이면 그것을 쓴다 — 기본이 dry-run 이라 계획을 먼저 보이고, 사용자가 고른 뒤 `dry_run: false` 로 다시 부른다.

```bash
PSI="${CLAUDE_PLUGIN_ROOT}/scripts/plugin-search-install.sh"
```

## 1. 무엇을 설치할지 정한다

직전 조회(`plugin-search` · `project-plugin-search`)의 결과를 파일로 남겨 두고 그 `rank` 로 고른다.

```bash
"$PSI" search 테스트 커버리지 > /tmp/psi-list.json        # 또는 project . / related …
```

사용자가 이미 말했으면 묻지 않는다 ("전부", "2번 빼고", "1, 3"). 아니면 `AskUserQuestion` 으로 묻는다.

| 옵션 | 명령 |
|---|---|
| 전부 설치 | `--all` |
| 일부만 (번호 · 이름 입력) | `--select 1,3-5` · `--exclude 2` |
| 필수(missing)만 — 프로젝트 조회일 때 | `"$PSI" project . --only missing > …` 후 `--all` |
| 조회만 | 설치하지 않고 끝낸다 |

범위는 기본 `project` (팀이 `.claude/settings.json` 으로 같이 받는다). 개인 도구면 `user` 를 권한다.

## 2. 계획을 보이고 설치한다

```bash
"$PSI" install --from /tmp/psi-list.json --select 1,3 --dry-run       # 계획
"$PSI" install --from /tmp/psi-list.json --select 1,3 --scope project # 실행
"$PSI" install github-workflow java-naming@jaemyeong-hwnag-plugins          # 이름으로 바로
```

- 처음이거나 3개 이상이면 `--dry-run` 결과를 먼저 보이고 확인받는다
- 종료 코드 2 (MCP 는 `isError`) 는 **아무것도 설치하지 않았다** — 이 마켓의 public 이 아님(다른 마켓 · internal · 없는 이름), 목록에 없는 번호 · 범위, 모호한 이름

## 3. 결과를 알린다

`results[].status` — `installed` · `skipped`(이미 설치) · `failed` · `planned`.

- `failed` 의 `message` 를 그대로 전한다. "명령 실행 확인이 필요한 플러그인" 이면 사용자가 직접 실행할 명령을 준다 — 대신 `-y` 로 실행하지 않는다
- `restartRequired: true` 면 **Claude Code 를 다시 시작해야 로드된다** 고 말한다

## 하지 않을 것

- 확인 없이 전부 설치하기 · 범위를 말없이 바꾸기
- `claude plugin install … -y` 를 직접 실행하기
- 실패를 성공으로 요약하기
