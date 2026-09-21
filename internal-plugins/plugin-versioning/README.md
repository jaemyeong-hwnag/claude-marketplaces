# plugin-versioning

플러그인 버전 값과 그 값이 남는 자리의 정합성을 강제하는 내부 플러그인이다.

이름은 `plugin-naming`, 디렉터리 구조는 `marketplace-directory-structure`, 배치·배포는 저장소 `.claude/hooks/` 가 본다.
여기서는 **버전만** 본다.

## 무엇을 막나

| | 조항 |
|---|---|
| 버전 값 | `V-01` semver 세 자리 · `V-02` version 필수 · `V-03` 초기 버전 `0.1.0` |
| CHANGELOG | `V-04` 첫 줄 · `V-05` 항목 제목 · `V-06` 현재 버전 항목 존재 · `V-07` 내림차순 · `V-08` 중복 금지 |
| 선언 위치 | `V-09` 엔트리 ↔ plugin.json 일치 · `V-10` marketplace metadata.version · `V-11` dependencies 범위 |
| 태그 | `V-12` `{플러그인명}--v{버전}` · `V-13` 태그가 매니페스트보다 앞설 수 없음 |

규칙 원본은 [`references/versioning-rules.md`](references/versioning-rules.md) 다. 충돌하면 그쪽이 우선한다.

**올림 등급(PATCH/MINOR/MAJOR)은 기계가 판정하지 않는다.** `version-update` 스킬이 판단한다.

## 구성

| 경로 | 역할 |
|---|---|
| `references/versioning-rules.md` | 규칙 원본 |
| `scripts/validate-versioning.sh` | 기계 검증 (훅 모드 + CLI 모드) |
| `hooks/hooks.json` | `Write`/`Edit` PreToolUse(차단) · PostToolUse(알림) |
| `skills/version-update/` | 등급 판단과 릴리즈 절차 |
| `commands/versioning-validate.md` | `/versioning-validate` |
| `test/` | 회귀 테스트 |

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

# 회귀 테스트
test/validate-versioning.test.sh
```

종료 코드 `2` 가 규칙 위반이다.

## 릴리즈

```bash
# 1. 등급 판단 → 2. plugin.json → 3. CHANGELOG → 4. 엔트리 → 5. 검증 → 6. 커밋
claude plugin tag --push
```

`claude plugin tag` 가 `{플러그인명}--v{버전}` 형식으로 만들고 엔트리 정합성까지 검증한다.
