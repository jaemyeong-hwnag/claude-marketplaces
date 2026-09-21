# 의존성 규칙 (단일 원본)

플러그인끼리 **누가 누구에 기대도 되는가**를 정한다. 기계 검증은 [`scripts/validate-dependency.sh`](../scripts/validate-dependency.sh).

의존 범위 문자열의 **형식**은 `plugin-versioning` 의 `V-11` 이 본다. 여기서는 **관계**만 본다.

## 1. 선언

`plugin.json` 의 `dependencies` 배열. 문자열과 객체 둘 다 쓴다.

```json
"dependencies": [
  "common-naming",
  { "name": "spring-naming", "version": "~1.0.0" }
]
```

- 필요한 의존성만 **직접** 선언한다. 전이 의존성은 Claude Code 가 설치한다
- 의존 대상이 `0.x` 인 동안은 문자열로 최신을 따라간다. `1.0.0` 이 되면 범위로 고정한다

## 2. 층

```
common               독립                      이름: common-{관심사}
  ↑
언어/프레임워크별     common 참조
  ↑
워크플로우           스킬 + 룰 참조
  ↑
번들                 dependencies 만 선언        이름: {역할}-standard
```

이름으로 알 수 있는 층(common · 번들)만 기계가 본다. 가운데 두 층은 AI 가 판단한다 (4절). 층을 선언하는 필드는 만들지 않는다 — 틀린 선언을 믿고 통과시키면 규칙이 없느니만 못하다.

## 3. 조항

| 조항 | 내용 | 판정 |
|---|---|---|
| `D-01` | 선언한 이름의 플러그인이 이 마켓플레이스에 있다 | 차단 |
| `D-02` | 자기 자신에 의존하지 않는다 | 차단 |
| `D-03` | 순환 의존이 없다 (A → B → A, 길이 무관) | 차단 |
| `D-04` | `common-*` 는 어떤 플러그인에도 의존하지 않는다 | 차단 |
| `D-05` | `*-standard`(번들)는 다른 번들에 의존하지 않는다 | 차단 |
| `D-06` | 번들은 `dependencies` 만 가진다 — `skills/` · `commands/` · `agents/` · `hooks/` 가 없다 | 차단 |
| `D-07` | 다른 마켓플레이스에 의존하지 않는다 — 의존 항목에 `marketplace` 필드가 없고, `marketplace.json` 에 `allowCrossMarketplaceDependenciesOn` 이 없다 | 차단 |
| `D-08` | `public-plugins/` 플러그인은 `internal-plugins/` 플러그인에 의존하지 않는다 | 차단 |
| `D-09` | 같은 의존 대상을 둘 이상이 버전 범위로 고정하면, 범위가 겹쳐야 한다 | 차단 |
| `D-10` | `=x.y.z` 로 정확히 고정하면 알린다 — auto-update 가 멈춘다 | 경고 |
| `D-11` | 같은 이름을 두 번 선언하지 않는다 | 차단 |

### 왜 이 조항들인가

- `D-07` 은 Claude Code 기본 동작과 같다 (`allowCrossMarketplaceDependenciesOn` 이 없으면 설치가 `cross-marketplace` 로 실패). 그래도 막는 이유는 **선언 시점에** 잡기 위해서다
- `D-08` 은 이 저장소 배치에서 나온다. 내부 플러그인도 같은 `marketplace.json` 에 있어서 github 로 이 마켓플레이스를 추가한 사람이 설치할 수 있다. public 이 internal 에 기대면 배포본을 설치하는 순간 내부 플러그인이 딸려간다
- `D-09` 는 설치 전에 잡는다. Claude Code 는 같은 대상의 범위를 교집합으로 풀고, 비면 나중에 설치하는 쪽이 `range-conflict` 로 실패한다. 이 저장소 안의 선언은 다 보이므로 미리 계산할 수 있다

### D-09 — 범위 겹침 판정

범위를 구간으로 바꿔 교집합을 본다.

| 범위 | 구간 |
|---|---|
| `~1.2.3` | `[1.2.3, 1.3.0)` |
| `^1.2.3` | `[1.2.3, 2.0.0)` · `^0.2.3` → `[0.2.3, 0.3.0)` · `^0.0.3` → `[0.0.3, 0.0.4)` |
| `=1.2.3` · `1.2.3` | `[1.2.3, 1.2.3]` |
| `>=a` · `>a` · `<b` · `<=b` 와 그 조합 | 각 경계 |
| `1.x` · `1.2.x` · `*` | `[1.0.0, 2.0.0)` · `[1.2.0, 1.3.0)` · 전체 |

`||` · 하이픈 범위 · prerelease 가 섞인 범위는 **판정하지 않고 넘긴다** (거짓 차단보다 놓치는 쪽을 고른다). 설치 때 Claude Code 가 본다.

## 4. 기계가 판정할 것 / AI 가 판단할 것

| | 담당 | 무엇을 |
|---|---|---|
| 정량 | `validate-dependency.sh` | `D-01` ~ `D-11` |
| 판단 | AI (`dependency-update` 스킬) | 가운데 두 층(언어별 ↔ 워크플로우)의 방향, common 의 **멱등성**(설치만으로 프로젝트가 바뀌지 않는가)과 **범위**(언어·프레임워크에 묶이지 않는가), 비-common 이 필요한 common 을 빠뜨렸는가 |

## 5. 역참조

플러그인을 지우거나 이름을 바꾸기 전에 **누가 이 플러그인에 기대는지** 본다.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-dependency.sh" --dependents common-naming .
```

## 6. 훅

| 이벤트 | 대상 | 동작 |
|---|---|---|
| `PostToolUse(Write\|Edit)` | `*plugins/*/.claude-plugin/plugin.json` | 저장소 전체 그래프를 다시 검사해 **알린다** |

차단하지 않는다. 두 플러그인을 서로 고쳐야 풀리는 위반(예: 순환을 끊기)은 한 번의 편집으로 해결되지 않는다. `--all` 은 막는다.

## 7. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-dependency.sh" --all .                     # 저장소 전체
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-dependency.sh" --dependents {이름} .        # 역참조
```

종료 코드 `2` 가 위반이다. 경고(`D-10`)만 있으면 `0` 이다.
