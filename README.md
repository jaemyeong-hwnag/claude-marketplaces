# claude-marketplaces

Claude Code 플러그인 마켓플레이스 저장소. 마켓플레이스 이름은 `plugin-marketplace` 다.

| 경로 | 성격 | 배포 | 반영 시점 |
|---|---|---|---|
| [`public-plugins/`](public-plugins) | 배포용 플러그인 | github 마켓플레이스 | 커밋·푸시해야 반영 |
| [`internal-plugins/`](internal-plugins) | 이 저장소가 내부에서 쓰는 플러그인 | 하지 않음 | 로컬 디렉터리 소스. 고치면 세션 시작 시 재설치 |

둘 다 같은 `.claude-plugin/marketplace.json` 에 등록되고, `category` (`public` / `internal`) 로 구분한다.
디렉터리와 선언이 어긋나면 `.claude/hooks/validate-plugin-scope.sh` 가 막는다 — 미등록, `category` 불일치, `source` 불일치, 유령 항목.

```bash
.claude/hooks/validate-plugin-scope.sh .   # 배치·배포 정책
test/validate-plugin-scope.test.sh         # 배치 정책 회귀 테스트
test/sync-internal-plugins.test.sh         # 동기화 훅 회귀 테스트
```

> 이름 규칙은 `plugin-naming` 플러그인이, 배치·배포 정책은 저장소가 담당한다. 서로 섞지 않는다.

## 수록 플러그인

| 이름 | 위치 | 설명 |
|---|---|---|
| [`plugin-naming`](internal-plugins/plugin-naming) | `internal-plugins/` | 플러그인·스킬·커맨드·에이전트 이름을 네이밍 규칙과 glossary 사전으로 강제한다 |

## 배포용 플러그인 설치 (다른 저장소에서)

```
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install <이름>@plugin-marketplace
```

프로젝트에 고정하려면 `.claude/settings.json` 에 넣는다.

```json
{
  "extraKnownMarketplaces": {
    "plugin-marketplace": {
      "source": { "source": "github", "repo": "jaemyeong-hwnag/claude-marketplaces" }
    }
  },
  "enabledPlugins": { "<이름>@plugin-marketplace": true }
}
```

github 소스는 **푸시된 커밋만 읽는다.** `public-plugins/` 를 고쳤으면 푸시해야 배포된다.

## 이 저장소에서 작업할 때

`internal-plugins/` 하위 플러그인은 **세션 시작 시 자동으로 확인·설치된다.**
`.claude/settings.json` 의 SessionStart 훅이 [`sync-internal-plugins.sh`](.claude/hooks/sync-internal-plugins.sh) 를 실행해서

1. 마켓플레이스가 등록돼 있는지
2. `marketplace.json` 에 각 플러그인이 등록돼 있는지
3. `settings.json` 에서 활성화돼 있는지
4. 실제로 설치돼 있는지

5. 설치본이 작업 트리와 같은지

를 확인하고 빠진 것을 채운다. 커밋·푸시는 필요 없다.

> 설치된 플러그인은 `~/.claude/plugins/cache/` 로 **복사**된다. 로컬 디렉터리 소스라도 작업 트리를 실시간으로 읽지 않고, `claude plugin update` 는 버전이 같으면 갱신하지 않는다.
> 그래서 훅이 설치본과 작업 트리를 비교해 어긋나면 재설치한다. **플러그인을 고쳤으면 다음 세션부터 적용된다.**

```bash
.claude/hooks/sync-internal-plugins.sh   # 수동 실행도 된다
```

## 네이밍 규칙

플러그인을 추가하기 전에 규칙을 읽는다. 규칙은 `plugin-naming` 이 훅으로 강제하므로, 어기는 이름으로는 파일이 만들어지지 않는다.

- 규칙: [`naming-rules.md`](internal-plugins/plugin-naming/references/naming-rules.md)
- 사전: [`glossary.json`](internal-plugins/plugin-naming/references/glossary.json)

```bash
internal-plugins/plugin-naming/scripts/validate-naming.sh --all .   # 저장소 전체 이름
internal-plugins/plugin-naming/test/validate-naming.test.sh          # 이름 규칙 회귀 테스트
```

## 플러그인 추가 절차

1. 이름을 정한다 (`name-create` 스킬).
2. 배포용은 `public-plugins/<이름>/`, 내부용은 `internal-plugins/<이름>/` 에 만든다.
3. `.claude-plugin/plugin.json` 을 작성한다.
   - 배포용: `marketplace.json` 에 `category: "public"` 으로 등록하고 푸시한다.
   - 내부용: SessionStart 훅이 알아서 등록·설치한다.
4. 검증과 테스트를 돌린다.

> 마켓플레이스 이름은 `claude` 로 시작할 수 없다. 공식 마켓플레이스 사칭으로 거부된다.
