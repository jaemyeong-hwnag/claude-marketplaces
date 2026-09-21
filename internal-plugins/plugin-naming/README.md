# plugin-naming

플러그인·스킬·커맨드·에이전트의 이름을 공통 규칙과 사전으로 강제한다.

다루는 것은 **이름 하나뿐**이다. 어느 디렉터리에 두는지, 어떻게 배포하는지는 이 플러그인의 관심사가 아니다.

## 설치

이 저장소에서는 SessionStart 훅(`.claude/hooks/sync-internal-plugins.sh`)이 등록·활성화·설치한다.
internal 플러그인이라 다른 저장소에 배포하지 않는다. 다른 곳에서 쓰려면 `public-plugins/` 로 옮긴다.

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| name-create | 이름 짓기·바꾸기, 플러그인·스킬·커맨드 만들기 | `{대상}-{범위}-{관심사}-{목적}` 슬롯과 사전으로 이름을 정한다 |
| glossary-update | 사전에 단어 추가·수정, "이 단어 써도 되나" | 중복·정렬·카테고리 규칙을 지키며 사전을 고친다 |
| /naming-review | 직접 호출 | 이름 하나 또는 저장소 전체를 검증하고 판정한다 |

## 포함된 에이전트

| 에이전트 | 설명 |
|---|---|
| naming-reviewer | 기계 규칙을 통과한 이름이 무엇을 가리키는지 알 수 있는지 판정한다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-naming.sh | PreToolUse (Write\|Edit) | 경로에서 이름을 뽑아 규칙 위반이면 **차단**, 통과하면 AI 판단 요청 |
| validate-naming.sh | PostToolUse (Write\|Edit) | `glossary.json` 을 저장하면 사전 구조를 검증 |

## 파일

| 경로 | 역할 |
|---|---|
| `references/naming-rules.md` | 네이밍 규칙 원본. 단일 기준 |
| `references/glossary.json` | 기본 단어 사전 (`use` / `deny` / `meaning`) |
| `scripts/validate-naming.sh` | 기계 검증. 훅과 CLI 겸용 |
| `test/` | 회귀 테스트와 TC 명세 |

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

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
