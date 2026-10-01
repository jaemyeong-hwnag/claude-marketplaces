---
name: project-plugin-search
description: 이 프로젝트에 필요한 플러그인을 조회할 때 사용한다. 프로젝트 설정에 선언됐는데 안 깔린 것, 그 의존, 파일 신호(언어 · 프레임워크 · CI · Docker …)로 추천하는 것을 상태와 근거와 함께 낸다. 트리거 — "이 프로젝트에 뭐 깔아야 해", "필요한 플러그인", "빠진 플러그인", "플러그인 추천", "온보딩".
---

# 프로젝트에 필요한 플러그인

규칙 원본: [`references/search-rules.md`](../../references/search-rules.md) — 5절.

```bash
PSI="${CLAUDE_PLUGIN_ROOT}/scripts/plugin-search-install.sh"
"$PSI" project .                       # 전부
"$PSI" project . --only missing        # 선언됐는데 없는 것 + 마켓 미등록
"$PSI" project . --only recommended    # 신호로 추천한 것만
"$PSI" detect .                        # 신호 · 선언만 (근거 확인용)
```

## 1. 세 갈래를 나눠 말한다

| 그룹 | 뜻 | 사용자에게 |
|---|---|---|
| `declared` | 프로젝트 `.claude/settings*.json` 에 켜져 있다 | **필수**. `missing` 이면 설치, `disabled` 면 켜기, `marketplace-missing` 이면 마켓플레이스 추가가 먼저 |
| `dependency` | 선언된 것이 기댄다 | 필수의 일부. `requiredBy` 를 같이 말한다 |
| `recommended` | 파일 신호와 맞는다 | **선택**. `why` 의 신호(Java (이름) · GitHub (태그) …)를 근거로 말한다 |

- `status: off` 는 프로젝트가 일부러 끈 것이다. 추천하지 않는다
- `대상 불일치` 가 `why` 에 있으면 감지되지 않은 언어를 대상으로 한다. 낮은 순위로만 말한다
- `marketplace-missing` 은 설치로 풀리지 않는다 — `extraKnownMarketplaces` 나 `claude plugin marketplace add` 를 안내한다

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
