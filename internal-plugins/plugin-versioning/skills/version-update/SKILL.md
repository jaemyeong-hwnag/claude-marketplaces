---
name: version-update
description: 플러그인 버전을 올리거나 릴리즈할 때 사용한다. 변경을 커밋·배포하기 전에 버전을 얼마나 올릴지 정할 때, CHANGELOG 를 쓸 때, 태그를 달 때, 1.0.0 으로 올릴 시점을 판단할 때 자동으로 적용한다. 트리거 — "버전 올려", "릴리즈", "배포", "태그 달아", "CHANGELOG", "버전 뭐로", "patch minor major", "bump version", "release". semver 등급 판정과 plugin.json · CHANGELOG · marketplace 엔트리 · git 태그의 정합성을 강제한다.
---

# 버전 올리기

규칙 원본: [`references/versioning-rules.md`](../../references/versioning-rules.md)
기계 검증: [`scripts/validate-versioning.sh`](../../scripts/validate-versioning.sh)

스크립트는 **값과 정합성**만 본다. **등급 판정은 기계가 하지 않는다.** 그것이 이 스킬의 일이다.

## 1. 등급을 판단한다

"파일을 몇 줄 고쳤는가"가 아니라 **쓰는 쪽이 무엇을 다시 해야 하는가**로 판단한다.

| 이번 변경 | 등급 |
|---|---|
| 버그 수정, 오타, 메시지 문구 | PATCH |
| 스킬·커맨드·에이전트·조항 추가, 새 검사 추가 | MINOR |
| 기존 조항의 판정이 달라짐, 옵션·출력 형식 변경, 통과하던 것이 막힘 | MAJOR |

애매하면 **위로 올린다.** 되돌릴 때 비용이 더 크다.

`0.x` 구간에서는 호환성을 깨도 `1.0.0` 으로 가지 않고 **MINOR 를 올린다**. `1.0.0` 은 안정화 선언에만 쓴다.

### 1.0.0 으로 올릴 때인가

둘 다 참일 때만 올린다.

- 조항이 더 뒤집히지 않는다 — 규칙 원본의 항목이 최근 변경에서 제거·재정의되지 않았다
- TC 가 그 조항들을 덮고 있다

하나라도 아니면 `0.x` 를 유지한다. 성급한 `1.0.0` 은 그 다음 변경을 전부 MAJOR 로 만든다.

## 2. 순서대로 고친다

순서를 바꾸면 중간 상태가 커밋에 남는다.

```
1. CHANGELOG.md 의 ## {새 버전} 항목   (## 미출시 가 있었으면 그것을 새 버전으로 바꾼다)
2. plugin.json 의 version
3. marketplace.json 엔트리가 version 을 선언하고 있으면 같이 올린다
4. 검증 — --all 과 --since origin/main
5. 커밋 → PR → 머지
6. 태그 — main 에서, 머지 뒤, 설치 확인 뒤
```

CHANGELOG 를 먼저 쓰면 중간 상태가 규칙을 한 번도 어기지 않는다. 거꾸로 `plugin.json` 을 먼저 저장하면 `PostToolUse` 훅이 CHANGELOG 항목이 없다고 알린다 — 그 알림이 안전망이다.

## 3. CHANGELOG 를 쓴다

```markdown
## 0.2.0

### Added
- 무엇이 추가됐는지

### Changed
- 무엇이 달라졌는지 — 쓰는 쪽이 무엇을 다시 해야 하는지까지
```

`### Added` / `Changed` / `Removed` / `Fixed` 로 나누면 등급이 드러난다. `Removed` 나 판정이 바뀐 `Changed` 가 있으면 MAJOR (`0.x` 면 MINOR).

- "수정", "개선", "리팩터링" 만 적지 않는다. 무엇이 어떻게 달라졌는지 적는다.
- MAJOR 항목에는 **무엇이 깨지는지**를 먼저 적는다.
- 아직 버전을 정하지 않은 변경은 `## 미출시` 에 모아두고, 릴리즈할 때 버전 제목으로 바꾼다.

## 4. 검증한다

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-versioning.sh" --all "${CLAUDE_PROJECT_DIR:-.}"
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-versioning.sh" --since origin/main "${CLAUDE_PROJECT_DIR:-.}"
```

둘 다 종료 코드 0 이어야 커밋한다. `--since` 는 이번 변경에서 파일이 바뀐 플러그인이 모두 버전을 올렸는지 본다 (`V-14`). `V-09`(엔트리 불일치)가 나오면 **엔트리 쪽을 고친다** — 설치 시점에는 `plugin.json` 이 이긴다.

## 5. 태그를 단다

**main 에서, PR 이 머지된 뒤, 설치 확인이 끝난 뒤에** 단다. 절차 전체는 `release-create` 스킬(`plugin-workflow`)이 한다.

```bash
claude plugin tag --push
```

CLI 가 `{플러그인명}--v{버전}` 형식으로 만들고, `plugin.json` 과 marketplace 엔트리가 일치하는지 함께 검증한다.
직접 달아야 하면 형식을 지킨다: `git tag plugin-versioning--v0.1.0`.

브랜치에서 달지 않는다. 리베이스가 SHA 를 바꿔서 태그가 머지 뒤 어디에도 없는 커밋을 가리키게 된다. 태그가 매니페스트보다 앞서면 `V-13` 에 걸린다.

## 하지 않을 것

- 검증을 건너뛰고 커밋하지 않는다.
- `version` 만 올리고 CHANGELOG 를 비워두지 않는다.
- 등급이 애매하다고 PATCH 로 내리지 않는다.
- 이 스킬에서 이름·디렉터리 구조를 고치지 않는다. 각각 `name-create` · `plugin-directory-create` 의 몫이다.
