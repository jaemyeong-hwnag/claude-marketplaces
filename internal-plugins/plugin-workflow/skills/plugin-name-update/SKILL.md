---
name: plugin-name-update
description: 플러그인 이름을 바꿀 때 사용한다. 설치한 사용자가 깨지지 않게 renames 를 남기고, 기대는 플러그인 · 활성화 키 · 문서 속 참조를 같이 바꾸고, 재설치 안내와 새 이름 첫 태그까지 밟을 때 적용한다. 트리거 — "플러그인 이름 바꿔", "플러그인 rename", "이름 변경", "플러그인 이름 마이그레이션". 사용자 확인과 renames 를 강제한다.
---

# 플러그인 이름 변경

`name` 은 설치 id(`<name>@jaemyeong-hwnag-plugins`)이자 사용자 설정 `enabledPlugins` 의 키다. 바꾸면 이미 설치한 사용자가 할 일이 생긴다. **시작 전에 사용자에게 확인받는다.** 전체는 개발 플로우 안에서 한다 (feature 이슈).

## 1. 정말 `name` 을 바꿔야 하나

| 바꾸려는 것 | 할 일 |
|---|---|
| `/plugin` 에 보이는 이름만 | `plugin.json` 에 `displayName` 을 둔다. `name` 은 그대로 — 깨지는 것이 없다. 여기서 끝 |
| 설치 id · 스킬 접두어(`/<이름>:스킬`)까지 | 아래 순서 |

확인받을 때 사용자 쪽 영향을 같이 보여 준다 — public 이면 그 플러그인이나 기대는 플러그인을 설치한 사람은 마켓을 업데이트한 뒤 **새 이름으로 한 번 설치**해야 하고, `/<옛>:스킬` 로 부르던 것은 `/<새>:스킬` 이 된다.

## 2. 순서

1. 새 이름을 `name-create` 스킬로 정하고, 늘 `naming-reviewer` 에 목적 문장과 후보를 넘겨 판정받는다
2. 미리 본다

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/plugin-name-update.sh" --dry-run <옛> <새> .
   ```

   바뀔 것(디렉터리 · `plugin.json` · 엔트리 · public 이면 `renames` · 기대는 플러그인의 `dependencies` · `enabledPlugins` 키)과 남은 참조 후보가 나온다. 사용자에게 보여 준다
3. `--dry-run` 을 빼고 실행한다
4. **남은 참조 후보를 하나씩 본다** — README 설치 명령, `/<옛>:` 접두어, 다른 플러그인 문서 · 스크립트 · 테스트, 루트 `README.md` · `CLAUDE.md`, 이름에 `<옛>` 이 들어간 파일. 다른 단어의 일부로 걸린 것은 두고, 이 플러그인을 가리키는 것만 바꾼다. CHANGELOG 의 옛 이름은 이력이라 둔다
5. 버전 — `version-update` 스킬. 스크립트가 출력한 플러그인마다 CHANGELOG → `plugin.json`. 이름이 바뀐 플러그인은 쓰는 쪽이 할 일이 생기므로 MAJOR (`0.x` 면 MINOR)
6. public 이면 그 플러그인과 기대는 플러그인의 README 에 이미 설치한 사람이 할 일을 적는다

   ```
   /plugin marketplace update jaemyeong-hwnag-plugins
   /plugin install <새>@jaemyeong-hwnag-plugins
   ```

   기대는 플러그인만 설치한 사람도 해야 한다 — `renames` 는 `dependencies` 의 옛 이름을 옮기지 않고, `plugin update` 만으로는 새 의존이 설치되지 않는다 (Claude Code 2.1.314 실측)

7. 루트 `CHANGELOG.md` 의 `## 미출시` 에 "`<옛>` → `<새>` 이름 변경 — 이유"
8. `verify-all.sh` → PR → 머지 → `plugin-release-create` (새 이름의 첫 태그)

## renames

public 만 쓴다. internal 은 배포하지 않으므로 엔트리 · 활성화 키만 바꾸면 sync 훅이 설치를 맞춘다.

- **추가만 한다.** 다시 바꿀 때는 기존 항목을 고치지 말고 `"<중간>": "<새>"` 를 더한다 — Claude Code 가 가장 오래된 이름부터 체인을 따라간다
- 옛 이름은 새 플러그인 이름으로 다시 쓰지 않는다 — 그 이름을 켜 둔 사용자가 어느 플러그인으로 갈지 정해져 있지 않다
- 위 두 가지는 저장소 훅(`validate-plugin-scope.sh`)이, 순환 · 끝 없는 체인은 `claude plugin validate` 가 막는다

## 하지 않을 것

- 사용자 확인 없이 `name` 을 바꾸지 않는다
- public 의 `renames` 를 빼고 바꾸지 않는다
- 옛 태그를 지우지 않는다 — 의존의 버전 범위는 태그로 풀린다. 지웠을 때 기존 설치본에 미치는 영향은 미확인
- 남은 참조 후보를 일괄 치환하지 않는다
