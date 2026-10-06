---
name: plugin-create
description: 새 플러그인을 만들 때 사용한다. 새 플러그인이 정말 필요한지 판단하고 이름 · 디렉터리 · 버전 · README · 의존성 · 등록 · 검증 · 설치 확인까지 순서대로 밟을 때 적용한다. 트리거 — "플러그인 만들어", "플러그인 추가", "새 플러그인". 각 단계는 해당 관심사의 스킬에 맡기고 순서와 체크리스트를 강제한다.
---

# 플러그인 생성

이 스킬은 **순서**만 정한다. 각 단계의 검사는 해당 관심사의 플러그인이 한다. 전체는 개발 플로우(`issue-create` → … → `release-create`)의 "작업" 단계 안이다.

## 1. 새 플러그인이 필요한가

| 질문 | 예 → | 아니오 → |
|---|---|---|
| 기존 플러그인의 관심사 한 줄(CLAUDE.md 관심사 분리 표)에 들어가는가 | 기존 플러그인에 스킬·조항을 더한다. **여기서 멈춘다** | 다음 질문 |
| 기계로 막을 조항이 여럿 나오는가 | 새 플러그인 (훅 + 스크립트 + TC) | 스킬 하나 또는 CLAUDE.md 한 절 |
| 이미 CLI 가 하는 일인가 (`claude plugin tag` · `validate` …) | 만들지 않는다 | 새 플러그인 |

이름이 같거나 기능이 겹치는 플러그인이 있는지 먼저 본다.

```bash
jq -r '.plugins[] | "\(.name)\t\(.description)"' .claude-plugin/marketplace.json
```

판단 결과는 feature 이슈의 "기존 플러그인으로 안 되는 이유" 에 적는다.

## 2. 순서

| # | 단계 | 맡는 스킬 | 확인 |
|---|---|---|---|
| 1 | 이름 | `name-create` — 비슷한 이름은 `naming-reviewer` | `validate-naming.sh <이름>` |
| 2 | 배치 — `public-plugins/` 또는 `internal-plugins/` | 이 스킬 (3절) | - |
| 3 | 디렉터리 · 필수 파일 | `plugin-directory-create` | `validate-directory-structure.sh <디렉터리>` |
| 4 | 버전 `0.1.0` · CHANGELOG `## 0.1.0` | `version-update` | `validate-versioning.sh <디렉터리>` |
| 5 | 스킬 · 커맨드 · 에이전트 · README | `document-create` | `validate-authoring.sh <디렉터리>` |
| 6 | 의존성 (있으면) | `dependency-update` | `validate-dependency.sh --all .` |
| 7 | 등록 | 이 스킬 (3절) | `.claude/hooks/validate-plugin-scope.sh .` |
| 8 | eval 케이스 — 스킬 발동 1 · 훅 차단 1 | 이 스킬 (4절) | `eval-all.sh --quick --plugin <이름>` |
| 9 | 전체 검증 · 테스트 | `pull-request-create` | `verify-all.sh .` |
| 10 | 설치 확인 | 이 스킬 (5절) | `claude plugin list` 에 `Error:` 없음 |

## 3. 배치와 등록

| | public | internal |
|---|---|---|
| 위치 | `public-plugins/<이름>/` | `internal-plugins/<이름>/` |
| 언제 | 다른 저장소가 설치한다 | 이 저장소만 쓴다 |
| 등록 | `marketplace.json` 에 직접 — `category: "public"`, `description` 은 `plugin.json` 과 같게, `tags` | 손대지 않는다. SessionStart 훅이 등록 · 활성화 · 설치한다 |
| common | `common-*` 은 여기만 | 둘 수 없다 |

`tags` 는 `.claude-plugin/tags.json` 에 있는 것만, 2개까지 (domain 1 + technology 1). `version` · `author` 는 엔트리에 쓰지 않는다.

## 4. eval 케이스

`evals/<케이스>/prompt.md` + `graders/*.md`. 판정 모델 없이 결정적으로 채점한다.

- 스킬 발동 — 스킬 이름을 말하지 않는 자연스러운 요청 + `tool_used: Skill` 그레이더 + 답에 대한 `regex`
- 훅 차단 — 규칙을 어기는 작업 요청 + `trace` 에서 훅 메시지를 찾는 `regex`

## 5. 설치 확인

```bash
.claude/hooks/sync-internal-plugins.sh                                    # internal
claude plugin install <이름>@jaemyeong-hwnag-plugins --scope project           # public — 훅이 설치하지 않는다 (internal 의 의존성이면 같이 설치된다)
claude plugin list | grep -A3 '<이름>@jaemyeong-hwnag-plugins'
claude plugin details <이름>@jaemyeong-hwnag-plugins    # Hooks (N) 이 hooks.json 이벤트 수와 같은가
```

`Error:` 가 있으면 끝난 것이 아니다. 정적 검증을 모두 통과하고도 훅이 죽어 있던 적이 있다 (`"hooks": "./hooks/hooks.json"` — 구조 규칙 `P-09`).

## 체크리스트

- [ ] 기존 플러그인에 더하는 것으로 안 되는 이유가 있다
- [ ] 이름 — 규칙 통과, 기존 이름과 헷갈리지 않는다
- [ ] 배치 — public / internal, common 이면 public
- [ ] 필수 파일 셋, 버전 `0.1.0`, CHANGELOG `## 0.1.0`
- [ ] README 템플릿, 표 = 실제 구성요소
- [ ] 의존성 — common 은 없음, 층 방향, public → internal 없음
- [ ] 등록 — category · tags · description
- [ ] eval 케이스 둘
- [ ] `verify-all.sh` 전부 ✅
- [ ] `claude plugin list` 에 `Error:` 없음
