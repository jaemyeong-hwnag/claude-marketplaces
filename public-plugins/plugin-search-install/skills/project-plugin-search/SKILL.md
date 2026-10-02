---
name: project-plugin-search
description: 이 프로젝트에 필요한 이 마켓의 public 플러그인을 조회할 때 사용한다. 프로젝트 설정에 선언됐는데 안 깔린 것, 그 의존, 파일 신호(언어 · 프레임워크 · CI · Docker …)로 추천하는 것을 상태와 근거와 함께 낸다. 트리거 — "이 프로젝트에 뭐 깔아야 해", "필요한 플러그인", "빠진 플러그인", "플러그인 추천", "온보딩".
---

# 프로젝트에 필요한 플러그인

규칙 원본: [`references/search-rules.md`](../../references/search-rules.md) — 5절.

대상은 이 플러그인이 설치되어 온 마켓의 public 플러그인뿐이다. MCP 도구 `list_project_plugins` 가 보이면 그것을 쓴다.

```bash
PSI="${CLAUDE_PLUGIN_ROOT}/scripts/plugin-search-install.sh"
"$PSI" project .                       # 전부
"$PSI" project . --only missing        # 선언됐는데 없는 것 · 그 의존 중 없는 것
"$PSI" project . --only recommended    # 신호로 추천한 것만
"$PSI" detect .                        # 신호 · 선언만 (근거 확인용)
```

## 1. 세 갈래를 나눠 말한다

| 그룹 | 뜻 | 사용자에게 |
|---|---|---|
| `declared` | 프로젝트 `.claude/settings*.json` 에 켜져 있다 | **필수**. `missing` 이면 설치, `disabled` 면 켜기 |
| `dependency` | 선언된 것이 기댄다 | 필수의 일부. `requiredBy` 를 같이 말한다 |
| `recommended` | 파일 신호와 맞는다 | **선택**. `why` 의 신호(Java (이름) · GitHub (태그) …)를 근거로 말한다 |

- `status: off` 는 프로젝트가 일부러 끈 것이다. 추천하지 않는다
- `대상 불일치` 가 `why` 에 있으면 감지되지 않은 언어를 대상으로 한다. 낮은 순위로만 말한다
- `outOfScope` 는 다른 마켓 · internal 선언이다. 이 플러그인이 다루지 않는다고 짧게 말하고 넘어간다
- `settingsErrors` 가 있으면 그 설정 파일이 JSON 이 아니라 읽지 못했다고 먼저 말한다

## 2. 신호를 확인한다

`signals[].evidence` 가 근거 파일이다. 신호가 틀렸으면(예제 디렉터리의 `pom.xml`) 사용자에게 말하고 그 추천을 뺀다. 신호가 없으면 "파일로 알 수 있는 게 없다" 고 말하고 `plugin-search` 로 기능 검색을 제안한다.

## 3. 보여주고 다음을 묻는다

```
필수 (선언 n · 없음 m)
  # | 플러그인 | 상태 | 근거
추천 (k)
  # | 플러그인 | 설치 | 신호
```

번호는 `rank` 그대로. 설치를 원하면 `plugin-install` 로 넘긴다 — 필수 중 `missing` 만, 추천 전부, 골라서, 조회만 중 고르게 한다.

## 하지 않을 것

- 신호 없이 "보통 이런 프로젝트엔" 으로 추천하기
- 사용자 확인 없이 설치하기
- 프로젝트 설정 파일을 직접 고치기
