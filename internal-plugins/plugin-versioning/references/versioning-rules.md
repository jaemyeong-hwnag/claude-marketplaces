# 버전 관리 규칙 (단일 원본)

이 문서가 플러그인 버전에 대한 유일한 기준이다. 스킬·커맨드·훅은 모두 이 문서를 참조한다.
기계 검증은 [`scripts/validate-versioning.sh`](../scripts/validate-versioning.sh).

이름은 `plugin-naming`, 디렉터리 구조는 `marketplace-directory-structure`, 배치·배포는 저장소 `.claude/hooks/` 가 본다.
여기서는 **버전 값과 그 값이 남는 자리(`plugin.json` · `CHANGELOG.md` · marketplace 엔트리 · git 태그)의 정합성**만 본다.

## 1. 버전 값

| 조항 | 내용 |
|---|---|
| `V-01` | 버전은 `MAJOR.MINOR.PATCH` 세 자리 숫자다. `v` 접두사·prerelease·build 접미사·선행 0 을 쓰지 않는다 |
| `V-02` | `plugin.json` 에 `version` 이 있어야 한다 |
| `V-03` | 신규 플러그인은 `0.1.0` 부터 시작한다. `0.0.x` 는 쓰지 않는다 |

```
1.0.0   0.1.0   2.13.4      O
v1.0.0  1.0     1.0.0-rc.1  01.0.0   0.0.1      X
```

`0.x` 구간은 호환성을 약속하지 않는 개발 구간이다. 안정화되면 `1.0.0` 으로 올린다.

### 올림 등급

| 변경 | 등급 | 예 |
|---|---|---|
| 버그 수정, 오타 | PATCH | `0.1.0` → `0.1.1` |
| 스킬·커맨드·조항 추가 | MINOR | `0.1.0` → `0.2.0` |
| 기존 조항 변경, 호환성 깨짐 | MAJOR | `0.2.0` → `1.0.0` |

**등급 판정은 기계가 하지 않는다.** 무엇이 "호환성을 깨는 변경"인지는 플러그인마다 다르다 → 5절.

### 0.x 구간

`0.x` 에서는 호환성을 깨도 `1.0.0` 으로 가지 않고 **MINOR 를 올린다** (`0.2.0` → `0.3.0`). `1.0.0` 은 안정화 선언에만 쓴다.
조항 추가·새 검사도 MINOR, 버그 수정은 PATCH 다.

## 2. CHANGELOG

| 조항 | 내용 |
|---|---|
| `V-04` | `CHANGELOG.md` 는 `# CHANGELOG` 로 시작한다 |
| `V-05` | 항목 제목은 `## {버전}` 또는 `## 미출시` 다 |
| `V-06` | `plugin.json` 의 현재 `version` 이 항목으로 있어야 한다 |
| `V-07` | 버전 항목은 내림차순이다. `## 미출시` 는 맨 위에만 올 수 있다 |
| `V-08` | 같은 버전을 두 번 쓰지 않는다 |

마켓플레이스 루트 `CHANGELOG.md` 도 같은 규칙이다. 루트의 "현재 버전"은 `marketplace.json` 의 `metadata.version` 이다 (`--marketplace` 가 본다).

```markdown
# CHANGELOG

## 미출시

### Added
- 아직 버전이 정해지지 않은 변경

## 0.2.0

### Added
- 무엇이 추가됐는지

### Changed
- 무엇이 달라졌는지 — 쓰는 쪽이 무엇을 해야 하는지까지

## 0.1.0

- 첫 릴리즈
```

`### Added` / `### Changed` / `### Removed` / `### Fixed` 로 나누는 것을 **권장**한다. 강제하지 않는다 (`V-05` 는 `###` 를 보지 않는다).
`Removed` 와 판정이 바뀐 `Changed` 가 있으면 MAJOR 다 (`0.x` 면 MINOR).

`V-06` 이 이 플러그인의 핵심이다. 버전만 올리고 CHANGELOG 를 잊는 것이 가장 흔한 사고다.

## 3. 선언 위치 정합성

| 조항 | 내용 |
|---|---|
| `V-09` | marketplace 엔트리가 `version` 을 선언하면 `plugin.json` 의 `version` 과 같아야 한다 |
| `V-10` | 마켓플레이스 루트 `marketplace.json` 의 `metadata.version` 도 `V-01` 을 따른다 |
| `V-11` | `dependencies` 의 `version` 은 Claude Code 가 받는 semver 범위다 — `~1.0.0` · `^1.2` · `>=1.0.0 <2.0.0` · `=2.1.0` · `1.2.3 - 2.3.4` · `2.x` · `*` · `^2.0.0-0` · `a \|\| b` |

설치 시점에는 `plugin.json` 이 이긴다. 그래서 엔트리 쪽이 어긋나면 **엔트리를 고친다.**

## 4. 태그

| 조항 | 내용 |
|---|---|
| `V-12` | 릴리즈 태그는 `{플러그인명}--v{버전}` 이다 |
| `V-13` | 태그의 버전은 그 플러그인 `plugin.json` 의 버전보다 클 수 없다 |

`V-12` 는 **형식만** 본다. 지금은 없는 플러그인의 태그도 통과한다 — 태그는 과거의 릴리즈이고, 지운 플러그인의 태그를 지우면 그 버전에 의존하던 설치본이 `no-matching-tag` 로 깨진다.

```bash
claude plugin tag --push            # 형식대로 만들고 엔트리 정합성까지 검증한다
git tag plugin-versioning--v0.1.0   # 직접 만들 때의 형식
```

태그는 `claude plugin tag` 로 만드는 것을 권한다. CLI 가 `V-09` 를 함께 검증한다.
`V-13` 은 "태그가 매니페스트보다 앞서가지 않는다"는 뜻이다 — 올리지도 않은 버전에 태그를 달면 설치본과 어긋난다.

## 5. 바뀌었으면 올린다

| 조항 | 내용 |
|---|---|
| `V-14` | 기준 ref 이후 플러그인 디렉터리의 **어떤 파일이든** 바뀌었으면 `version` 이 올라가야 한다. 내려가도 안 된다 |

- 기준 ref 는 PR 의 부모다: `--since origin/main`
- ref 에 없던 플러그인은 새 플러그인이다 — `V-03` 이 본다
- 아직 add 하지 않은 새 파일도 변경이다
- `--all` 에는 들어가지 않는다. 비교할 ref 가 있어야 하기 때문이다. PR 을 열기 전에 돌린다 (`plugin-workflow`)

## 6. 기계가 판정할 것 / AI 가 판단할 것

| | 담당 | 무엇을 |
|---|---|---|
| 정량 | `validate-versioning.sh` | `V-01` ~ `V-14` |
| 판단 | AI (`version-update` 스킬) | 올림 등급, `1.0.0` 시점, CHANGELOG 문장 |

AI 가 판단할 것은 셋이다.

1. **이번 변경이 PATCH 인가 MINOR 인가 MAJOR 인가.** 조항을 추가했으면 MINOR, 기존 조항의 판정이 달라졌으면 MAJOR 다.
   "파일을 몇 줄 고쳤는가"가 아니라 **쓰는 쪽이 무엇을 다시 해야 하는가**로 판단한다.
2. **`1.0.0` 으로 올릴 때인가.** 조항이 더 뒤집히지 않고 TC 가 그 조항들을 덮고 있으면 올린다.
3. **CHANGELOG 항목이 무엇이 바뀌었는지 말하는가.** "수정", "개선" 같은 말만 적지 않는다.

## 7. 릴리즈 순서

**CHANGELOG 를 먼저 쓴다.** 그러면 중간 상태가 규칙을 한 번도 어기지 않는다 — `## 새 버전` 이 먼저 생기고 `plugin.json` 은 아직 이전 버전이지만, 이전 버전 항목도 있으므로 `V-06` 을 만족한다.
반대로 `plugin.json` 을 먼저 올리면 CHANGELOG 를 쓰기 전까지 `V-06` 위반 상태가 한 번 생긴다.

1. 등급을 판단한다 (6절 1번)
2. `CHANGELOG.md` 에 `## {새 버전}` 항목을 쓴다 (`## 미출시` 가 있었으면 그것을 새 버전으로 바꾼다)
3. `plugin.json` 의 `version` 을 올린다
4. marketplace 엔트리가 `version` 을 선언하고 있으면 같이 올린다
5. `validate-versioning.sh --all .` 와 `--since origin/main` 으로 검증한다
6. 커밋 → PR → 머지 (`plugin-workflow`)
7. **main 에서, 머지 뒤, 설치 확인 뒤에** `claude plugin tag --push` — 리베이스가 SHA 를 바꾸므로 브랜치에서 단 태그는 머지 뒤 어디에도 없는 커밋을 가리킨다

## 8. 검증

```bash
# 플러그인 하나
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-versioning.sh" internal-plugins/plugin-versioning

# 저장소 전체 (루트 + 모든 플러그인 + 태그)
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-versioning.sh" --all .

# 태그만
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-versioning.sh" --tag .

# PR 범위 — origin/main 이후 바뀐 플러그인이 버전을 올렸는가 (V-14)
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-versioning.sh" --since origin/main .
```

종료 코드 `2` 는 규칙 위반이다.

훅은 두 갈래로 건다.

- `PreToolUse(Write|Edit)` — `plugin.json` 에 들어가는 `version` 값이 `V-01` · `V-03` 을 어기면 **차단**한다.
- `PostToolUse(Write|Edit)` — `plugin.json` · `CHANGELOG.md` 를 저장한 뒤 `V-06` 이 어긋나면 **알린다**. 막지 않는다.

버전을 올리고 CHANGELOG 를 쓰는 데는 두 번의 편집이 필요하다. 7절 순서(CHANGELOG 먼저)를 지키면 중간 위반이 없지만, 순서를 거꾸로 밟는 경우까지 `PreToolUse` 로 막으면 첫 편집부터 막혀 아무것도 못 한다. 그래서 `V-06` 은 알리기만 한다.
