---
name: plugin-directory-create
description: 플러그인의 디렉터리와 파일 위치를 정할 때 사용한다. 스킬·커맨드·에이전트·훅·스크립트·eval 을 어디에 둘지, 파일을 어느 디렉터리에 넣을지 헷갈릴 때 적용한다. 트리거 — "어디에 둬야", "스킬 어디에", "디렉터리 구조", "폴더 구조", "where to put". 플러그인 생성 절차 전체는 plugin-create 가 맡는다. 마켓플레이스 루트와 플러그인의 디렉터리 구조 규칙을 강제한다.
---

# 플러그인 디렉터리 만들기

규칙 원본: [`references/directory-structure-rules.md`](../../references/directory-structure-rules.md)

이름을 정하는 것은 이 스킬의 일이 아니다. 먼저 `name-create` 로 이름을 정하고 온다.

## 순서

1. **이름을 정한다.** `name-create` 스킬. 정해지기 전에는 디렉터리를 만들지 않는다.
2. **배치를 고른다.** 배포용이면 `public-plugins/<이름>/`, 이 저장소 전용이면 `internal-plugins/<이름>/`.
3. **필수 세 가지를 먼저 만든다.**

   | 파일 | 내용 |
   |---|---|
   | `.claude-plugin/plugin.json` | `name` 은 디렉터리명과 같아야 한다. `hooks` 필드로 `./hooks/hooks.json` 을 가리키지 않는다 (P-09) |
   | `README.md` | 템플릿(설치 · 의존성 · 포함된 스킬/에이전트/훅 · 변경 이력)을 따른다 — `document-create` 스킬 (`plugin-authoring`) |
   | `CHANGELOG.md` | `## 0.1.0` 초기 항목 |

4. **구성요소를 필요한 것만 추가한다.** 아래 표에 없는 디렉터리는 만들지 않는다.

   | 두려는 것 | 위치 | 확장자 |
   |---|---|---|
   | 절차·판단 기준 | `skills/<스킬명>/SKILL.md` | 디렉터리마다 `SKILL.md` 필수 |
   | 훅 매니페스트 | `hooks/hooks.json` | `*.json` |
   | 훅·커맨드가 실행할 코드 | `scripts/<이름>.sh` | `*.sh` |
   | 슬래시 커맨드 | `commands/<이름>.md` | `*.md` |
   | 규칙 원본·사전 | `references/<이름>.md` `.json` | `*.md` `*.json` |
   | 서브에이전트 | `agents/<이름>.md` | `*.md` |
   | 회귀 테스트 | `test/<대상>.test.sh` + `test/README.md` | `*.test.sh` `README.md` |

   플러그인 루트에 둘 수 있는 파일은 `README.md` · `CHANGELOG.md` · `LICENSE` · `.gitignore` 뿐이다.
   설계 메모·작업 문서는 플러그인 안이 아니라 저장소의 `.agent-tasks/<주제>/` 에 둔다.

5. **등록한다.**
   - 배포용: 루트 `.claude-plugin/marketplace.json` 에 `source: "./public-plugins/<이름>"`, `category: "public"` 으로 직접 등록하고 커밋·푸시한다.
   - 내부용: 손대지 않는다. SessionStart 훅이 등록·활성화·설치한다.
6. **검증한다.**

   ```bash
   internal-plugins/marketplace-directory-structure/scripts/validate-directory-structure.sh --all .
   internal-plugins/plugin-naming/scripts/validate-naming.sh --all .
   internal-plugins/plugin-versioning/scripts/validate-versioning.sh --all .
   internal-plugins/plugin-authoring/scripts/validate-authoring.sh --all .
   .claude/hooks/validate-plugin-scope.sh .
   claude plugin list    # 설치 후 Error 줄이 없어야 한다. --strict 검증이 못 잡는 훅 로딩 실패가 여기 나온다
   ```

## 자주 틀리는 것

| 하려던 것 | 틀린 위치 | 맞는 위치 |
|---|---|---|
| 설계 메모를 플러그인에 둔다 | `<플러그인>/NOTES.md` | `.agent-tasks/<주제>/*.md` |
| 스킬에 딸린 스크립트 | `skills/<스킬명>.md` 옆 | `skills/<스킬명>/` 안 (스킬 디렉터리 안쪽은 자유) |
| 훅 스크립트 | `hooks/<이름>.sh` | `scripts/<이름>.sh`, `hooks/` 는 매니페스트만 |
| 훅 매니페스트 연결 | `plugin.json` 에 `"hooks": "./hooks/hooks.json"` | 적지 않는다. `hooks/hooks.json` 은 자동 로드되고, 적으면 중복으로 훅 전체가 죽는다 (P-09) |
| 테스트 픽스처 | `test/fixture.json` | 테스트 스크립트가 임시 디렉터리에 만든다 |
| 문서 모음 | `docs/` | `references/` |

## 하지 말 것

- 규칙에 없는 디렉터리를 만들지 않는다. 필요하면 `references/directory-structure-rules.md` 를 먼저 고치고 TC 를 추가한다.
- 훅이 위치를 막으면 경로를 우회하지 않는다. 규칙이 지시한 위치로 옮긴다.
- 내부용 플러그인을 `marketplace.json` 에 손으로 등록하지 않는다. 훅과 충돌한다.
