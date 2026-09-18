# plugin-naming

플러그인·스킬·커맨드·에이전트의 이름을 공통 규칙과 사전으로 강제한다.

다루는 것은 **이름 하나뿐**이다. 어느 디렉터리에 두는지, 어떻게 배포하는지는 이 플러그인의 관심사가 아니다.

## 구성

| 경로 | 역할 |
|---|---|
| `references/naming-rules.md` | 네이밍 규칙 원본. 단일 기준 |
| `references/glossary.json` | 기본 단어 사전 (`use` / `deny` / `meaning`) |
| `scripts/validate-naming.sh` | 기계 검증. 훅과 CLI 겸용 |
| `hooks/hooks.json` | Write/Edit 에 PreToolUse·PostToolUse 로 연결 |
| `skills/name-create/` | 이름 짓는 절차 |
| `skills/glossary-update/` | 사전 고치는 절차 |
| `agents/naming-reviewer.md` | 기계가 못 잡는 부분을 판정하는 에이전트 |
| `commands/naming-review.md` | `/naming-review` |
| `test/` | 회귀 테스트 60건과 TC 명세 |

## 설치

이 저장소에서는 SessionStart 훅이 자동으로 확인·설치한다. 다른 저장소에서 쓰려면:

```
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install plugin-naming@plugin-marketplace
```

프로젝트에서 자동으로 켜려면 `.claude/settings.json` 에 넣는다.

```json
{
  "extraKnownMarketplaces": {
    "plugin-marketplace": {
      "source": { "source": "github", "repo": "jaemyeong-hwnag/claude-marketplaces" }
    }
  },
  "enabledPlugins": { "plugin-naming@plugin-marketplace": true }
}
```

## 동작

`Write` / `Edit` 시 경로에서 이름을 뽑아 검사하고, 위반이면 종료 코드 2 로 차단한다.

| 경로 패턴 | 검사 대상 |
|---|---|
| `*plugins/<이름>/...` | 플러그인명 |
| `.../skills/<이름>/...` | 스킬명 |
| `.../commands/<이름>.md` | 커맨드명 |
| `.../agents/<이름>.md` | 에이전트명 |

그 외 경로에는 반응하지 않는다. `plugins/`, `public-plugins/`, `my-own-plugins/` 처럼 **이름이 `plugins` 로 끝나는 디렉터리**면 무엇이든 플러그인 위치로 본다. 그 디렉터리들이 어떤 의미인지는 저장소가 정할 일이다.

## 프로젝트별 사전

사전은 아래 순서로 해석된다.

1. `$NAMING_GLOSSARY`
2. `$CLAUDE_PROJECT_DIR/references/glossary.json` ← 프로젝트 전용
3. `${CLAUDE_PLUGIN_ROOT}/references/glossary.json` ← 플러그인 기본

프로젝트 사전을 두면 플러그인 사전을 **대체한다.** 병합이 아니므로 기본 사전을 복사한 뒤 도메인 단어를 더한다.

## CLI

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" <이름 또는 경로>
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" --all .
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" --glossary
```

## 테스트

```bash
test/validate-naming.test.sh
```

TC 명세는 [`test/README.md`](test/README.md).
