# plugin-dependency

플러그인 사이의 **의존 관계**를 강제한다 — 존재 · 순환 · common 과 번들의 층 · 마켓플레이스 경계 · public→internal 금지 · 버전 범위 겹침.

범위 문자열의 형식은 `plugin-versioning`(`V-11`), 이름은 `plugin-naming`, 위치는 `marketplace-directory-structure` 가 본다. 여기서는 **관계**만 본다.

## 설치

이 저장소에서는 SessionStart 훅(`.claude/hooks/sync-internal-plugins.sh`)이 등록·활성화·설치한다.
internal 플러그인이라 다른 저장소에 배포하지 않는다. 다른 곳에서 쓰려면 `public-plugins/` 로 옮긴다.

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| dependency-update | 의존성 추가·변경·삭제, common · 번들 구성 | 층 방향과 common 자격을 판단한다 |
| /dependency-validate | 직접 호출 | 저장소 전체 그래프 검증, 이름을 주면 역참조 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-dependency.sh | PostToolUse (Write\|Edit) | `plugin.json` 저장 뒤 저장소 전체 그래프를 다시 검사해 **알림** |

## 파일

| 경로 | 역할 |
|---|---|
| `references/dependency-rules.md` | 의존성 규칙 원본 (`D-01` ~ `D-11`) |
| `scripts/validate-dependency.sh` | 기계 검증. 그래프 계산(순환 · 범위 교집합)은 jq 로 한다 — macOS 기본 bash 3.2 에는 연관 배열이 없다 |
| `test/` | 회귀 테스트와 TC 명세 |

## 무엇을 막나

| | 조항 |
|---|---|
| 그래프 | `D-01` 대상 존재 · `D-02` 자기 의존 · `D-03` 순환 · `D-11` 중복 선언 |
| 층 | `D-04` common 은 의존 없음 · `D-05` 번들 → 번들 금지 · `D-06` 번들은 dependencies 만 |
| 경계 | `D-07` 다른 마켓플레이스 금지 · `D-08` public → internal 금지 |
| 범위 | `D-09` 같은 대상의 범위가 겹쳐야 한다 · `D-10` 정확히 고정은 경고 |

## 훅이 알리기만 하는 이유

순환을 끊거나 범위를 맞추려면 **두 플러그인**을 고쳐야 할 때가 많다. 첫 편집에서 막으면 풀 수 없다. `--all` 은 막는다.

## 사용

```bash
scripts/validate-dependency.sh --all .                       # 저장소 전체
scripts/validate-dependency.sh --dependents common-naming .  # 누가 기대는가
scripts/validate-dependency.sh internal-plugins/order-sync   # 이 플러그인의 선언만
test/validate-dependency.test.sh                             # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
