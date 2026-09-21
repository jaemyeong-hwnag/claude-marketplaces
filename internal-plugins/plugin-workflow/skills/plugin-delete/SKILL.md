---
name: plugin-delete
description: 플러그인을 지우거나 끌 때 사용한다. 삭제 전에 누가 기대는지 보고, 의존을 먼저 끊고, 디렉터리와 등록을 정리하거나 비활성화만 할 때 적용한다. 트리거 — "플러그인 삭제", "플러그인 제거", "플러그인 지워", "플러그인 꺼", "disable". 역참조 확인과 삭제 순서를 강제한다.
---

# 플러그인 삭제 · 비활성화

지우는 것은 되돌리기 어렵다. **시작 전에 사용자에게 확인받는다.** 전체는 개발 플로우 안에서 한다 (feature 이슈 — 쓰는 쪽의 판정이 바뀐다).

## 1. 끌 것인가 지울 것인가

| | 비활성화 | 삭제 |
|---|---|---|
| 언제 | 잠시 쓰지 않는다, 다시 켤 수 있다 | 더는 쓰지 않는다 |
| 방법 | `.claude/settings.json` 의 `enabledPlugins["<이름>@plugin-marketplace"]` 를 `false` 로 (또는 `claude plugin disable`) | 아래 순서 |
| 엔트리 · 디렉터리 | 그대로 | 지운다 |
| 태그 | 그대로 | 그대로 |

내부 플러그인도 `false` 로 두면 SessionStart 훅이 되돌리지 않고 설치도 건너뛴다.
`marketplace.json` 에서 엔트리만 지우는 "비활성화"는 쓰지 않는다 — 내부 플러그인은 훅이 다시 등록하고, public 은 배치 검사가 막는다.

## 2. 삭제 순서

1. **누가 기대는지 본다**

   ```bash
   internal-plugins/plugin-dependency/scripts/validate-dependency.sh --dependents <이름> .
   ```

2. 기대는 플러그인이 있으면 그쪽 `dependencies` 에서 먼저 빼고 **그쪽 버전을 올린다** — 쓰는 쪽이 할 일이 생기므로 MAJOR (`0.x` 면 MINOR). `version-update` 스킬
3. 디렉터리를 지운다

   | public | internal |
   |---|---|
   | `public-plugins/<이름>/` 을 지우고 `marketplace.json` 엔트리를 직접 지운다 | `internal-plugins/<이름>/` 만 지운다 — 엔트리 · 활성화 키 · 설치본은 다음 세션에 훅이 치운다 (지금 치우려면 `.claude/hooks/sync-internal-plugins.sh`) |

4. 루트 `CHANGELOG.md` 의 `## 미출시` 에 "`<이름>` 플러그인 제거 — 이유" 를 적는다
5. **태그는 지우지 않는다.** 과거의 릴리즈이고, 그 버전에 기대던 설치본이 `no-matching-tag` 로 깨진다. `V-12` 는 없는 플러그인의 태그도 형식만 본다
6. `verify-all.sh` → 커밋 `feat(<이름>): 플러그인 제거` → PR → 머지. public 은 **푸시해야** 배포본에서 사라진다

## 하지 않을 것

- 역참조를 보지 않고 지우지 않는다
- 태그를 지우지 않는다
- `git branch -D` · `rm -rf` 를 사용자 확인 없이 쓰지 않는다
