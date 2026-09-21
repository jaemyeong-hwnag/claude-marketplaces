# plugin-versioning

플러그인 버전 값과 그 값이 남는 자리의 정합성을 강제하는 내부 플러그인이다.

이름은 `plugin-naming`, 디렉터리 구조는 `marketplace-directory-structure`, 배치·배포는 저장소 `.claude/hooks/` 가 본다.
여기서는 **버전만** 본다.

## 설치

이 저장소에서는 SessionStart 훅(`.claude/hooks/sync-internal-plugins.sh`)이 등록·활성화·설치한다.
internal 플러그인이라 다른 저장소에 배포하지 않는다. 다른 곳에서 쓰려면 `public-plugins/` 로 옮긴다.

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| version-update | 버전 올리기, 릴리즈, CHANGELOG, 태그 | semver 등급 판정과 릴리즈 순서 |
| /versioning-validate | 직접 호출 | 저장소 전체와 이번 변경 범위(`--since`)의 버전 정합성을 검증한다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-versioning.sh | PreToolUse (Write\|Edit) | `plugin.json` 에 들어가는 `version` 값이 틀렸으면 **차단** (`V-01` · `V-03`) |
| validate-versioning.sh | PostToolUse (Write\|Edit) | `plugin.json` · `CHANGELOG.md` 저장 뒤 `V-06` 이 어긋나면 **알림** |

## 파일

| 경로 | 역할 |
|---|---|
| `references/versioning-rules.md` | 규칙 원본 |
| `scripts/validate-versioning.sh` | 기계 검증 (훅 모드 + CLI 모드) |
| `test/` | 회귀 테스트와 TC 명세 |

## 무엇을 막나

| | 조항 |
|---|---|
| 버전 값 | `V-01` semver 세 자리 · `V-02` version 필수 · `V-03` 초기 버전 `0.1.0` |
| CHANGELOG | `V-04` 첫 줄 · `V-05` 항목 제목 · `V-06` 현재 버전 항목 존재 · `V-07` 내림차순 · `V-08` 중복 금지 |
| 선언 위치 | `V-09` 엔트리 ↔ plugin.json 일치 · `V-10` marketplace metadata.version · `V-11` dependencies 범위 |
| 태그 | `V-12` `{플러그인명}--v{버전}` (형식만) · `V-13` 태그가 매니페스트보다 앞설 수 없음 |
| 변경 | `V-14` 기준 ref 이후 파일이 바뀐 플러그인은 버전을 올려야 한다 (`--since`) |

규칙 원본은 [`references/versioning-rules.md`](references/versioning-rules.md) 다. 충돌하면 그쪽이 우선한다.

**올림 등급(PATCH/MINOR/MAJOR)은 기계가 판정하지 않는다.** `version-update` 스킬이 판단한다.

## 훅이 두 갈래인 이유

버전을 올리고 CHANGELOG 를 쓰는 데는 **두 번의 편집**이 필요하다. 첫 편집에서 `V-06` 으로 막으면 아무것도 못 한다.

- `PreToolUse` — `plugin.json` 에 들어가는 `version` 값이 그 자체로 틀렸을 때만 **차단**한다 (`V-01` · `V-03`)
- `PostToolUse` — 저장 후 `V-06` 이 어긋나면 `additionalContext` 로 **알린다**. 막지 않는다

## 사용

```bash
# 저장소 전체 (루트 + 모든 플러그인 + 태그)
scripts/validate-versioning.sh --all .

# 플러그인 하나
scripts/validate-versioning.sh internal-plugins/plugin-versioning

# 태그만
scripts/validate-versioning.sh --tag .

# PR 범위 — 바뀐 플러그인이 버전을 올렸는가
scripts/validate-versioning.sh --since origin/main .

# 회귀 테스트
test/validate-versioning.test.sh
```

종료 코드 `2` 가 규칙 위반이다.

## 릴리즈

```bash
# 1. 등급 판단 → 2. CHANGELOG → 3. plugin.json → 4. 엔트리 → 5. 검증 → 6. 커밋·PR·머지 → 7. main 에서
claude plugin tag --push
```

`claude plugin tag` 가 `{플러그인명}--v{버전}` 형식으로 만들고 엔트리 정합성까지 검증한다.

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
