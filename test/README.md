# 저장소 정책 테스트

이 저장소의 **배치·배포 정책**을 검증한다. 이름 규칙 테스트는 여기 있지 않다 —
`internal-plugins/plugin-naming/test/` 가 담당한다. 둘을 섞지 않는다.

## 실행

```bash
test/validate-plugin-scope.test.sh    # 배치 정책 (TC-S)
test/sync-internal-plugins.test.sh    # 내부 플러그인 동기화 (TC-Y)
```

둘 다 종료 코드 0 이어야 한다. `sync` 테스트는 `claude` CLI 를 PATH 스텁으로 대체하므로
실제 설치 상태를 건드리지 않는다.

## TC-S · 배치 정책 (`.claude/hooks/validate-plugin-scope.sh`)

| ID | 케이스 | 기대 |
|---|---|---|
| TC-S01 | 현재 저장소는 통과한다 | 통과 (0) |
| TC-S02 | 배치와 선언이 맞으면 통과한다 | 통과 (0) |
| TC-S03 | public-plugins 인데 등록되지 않으면 막는다 | 차단 (2) |
| TC-S04 | internal 플러그인이 public 으로 등록되면 막는다 | 차단 (2) |
| TC-S05 | public 플러그인이 internal 로 등록되면 막는다 | 차단 (2) |
| TC-S06 | source 가 실제 디렉터리와 다르면 막는다 | 차단 (2) |
| TC-S07 | 등록됐는데 디렉터리가 없으면 막는다 | 차단 (2) |
| TC-S08 | marketplace.json 이 없으면 검사를 건너뛴다 | 통과 (0) |
| TC-S09 | marketplace.json 이 깨져 있으면 막는다 | 차단 (2) |
| TC-S10 | plugin.json 이 없는 디렉터리는 플러그인으로 보지 않는다 | 통과 (0) |
| TC-S11 | 같은 이름이 둘이면 이름 중복으로 보고한다 | 차단 (2) |
| TC-S12 | 중복일 때 엉뚱한 source · category 메시지를 내지 않는다 | 해당 메시지 없음 |
| TC-S13 | categories.json 이 있으면 거기 있는 값만 허용한다 | 차단 (2) |
| TC-S14 | categories.json 에 있으면 통과한다 | 통과 (0) |
| TC-S15 | categories.json 이 정렬되지 않았으면 막는다 | 차단 (2) |
| TC-S16 | categories.json 항목에 description 이 없으면 막는다 | 차단 (2) |
| TC-S17 | tags.json 에 있는 태그는 통과한다 | 통과 (0) |
| TC-S18 | tags.json 에 없는 태그를 막는다 | 차단 (2) |
| TC-S19 | 태그 3개를 막는다 | 차단 (2) |
| TC-S20 | 태그 2개가 둘 다 domain 이면 막는다 | 차단 (2) |
| TC-S21 | domain 1 + technology 1 은 통과한다 | 통과 (0) |
| TC-S22 | tags.json 없이 tags 를 쓰면 막는다 | 차단 (2) |
| TC-S23 | tags.json 의 kind 가 틀리면 막는다 | 차단 (2) |
| TC-S24 | tags.json 의 대문자 이름을 막는다 | 차단 (2) |
| TC-S25 | 엔트리 description 이 plugin.json 과 다르면 막는다 | 차단 (2) |
| TC-S26 | 엔트리 description 이 같으면 통과한다 | 통과 (0) |
| TC-S27 | common 플러그인이 internal 이면 막는다 | 차단 (2) |
| TC-S28 | common 플러그인이 public 이면 통과한다 | 통과 (0) |
| TC-S29 | 엔트리의 author 는 경고만 한다 | 통과 (0) + 경고 |

## TC-Y · 내부 플러그인 동기화 (`.claude/hooks/sync-internal-plugins.sh`)

| ID | 케이스 | 기대 |
|---|---|---|
| TC-Y01 | internal-plugins/ 가 없으면 조용히 끝난다 | 통과, CLI 호출 없음 |
| TC-Y02 | marketplace.json 이 없으면 끝낸다 | 통과 |
| TC-Y03 | plugin.json 이 없는 디렉터리는 세지 않는다 | 통과 |
| TC-Y04 | 마켓플레이스가 미등록이면 등록한다 | `marketplace add` 호출 |
| TC-Y05 | settings.json 의 github repo 선언을 등록 소스로 쓴다 | `marketplace add owner/repo` |
| TC-Y06 | marketplace.json 에 `category: internal` 과 source 경로로 등록한다 | 파일 반영 |
| TC-Y07 | settings.json 의 enabledPlugins 에 추가한다 | 파일 반영 |
| TC-Y08 | 설치되어 있지 않으면 설치한다 | `plugin install` 호출 |
| TC-Y09 | 이미 설치·동기 상태면 아무것도 바꾸지 않는다 | 멱등, CLI 호출 없음 |
| TC-Y10 | 설치본이 작업 트리와 다르면 재설치한다 | `uninstall` + `install` |
| TC-Y11 | 설치에 실패해도 세션을 막지 않는다 | 통과 (0) + 복구 명령 안내 |
| TC-Y12 | 마켓플레이스 등록에 실패해도 세션을 막지 않는다 | 통과 (0) |
| TC-Y13 | 플러그인이 여럿이면 모두 처리한다 | 각각 install |
| TC-Y14 | `--quiet` 는 변경이 없으면 출력하지 않는다 | 출력 없음 |
| TC-Y15 | 명시적 `false` 는 `true` 로 되돌리지 않는다 | 파일 유지 |
| TC-Y16 | 끈 플러그인은 설치하지 않고 알린다 | `install` 호출 없음 |
| TC-Y17 | 디렉터리가 사라진 internal 엔트리를 marketplace.json 에서 지운다 | 파일 반영, 살아 있는 엔트리는 유지 |
| TC-Y18 | 사라진 플러그인의 enabledPlugins 키도 지운다 | 파일 반영 |
| TC-Y19 | 사라진 플러그인의 설치본을 `--prune -y` 로 제거한다 | `uninstall … --prune -y` |
| TC-Y20 | public 엔트리는 디렉터리가 없어도 건드리지 않는다 | 엔트리 유지 (배치 검사의 몫) |
| TC-Y21 | 플러그인이 전부 사라져도 정리는 한다 | 엔트리 0 |
| TC-Y22 | 설치된 적 없는 사라진 플러그인은 uninstall 을 부르지 않는다 | 호출 없음 |
| TC-Y23 | 설치 기준이 다른 디렉터리(워크트리)면 작업 트리 변경으로 재설치하지 않는다 | 호출 없음 |
| TC-Y24 | 설치 기준이 다르면 그 사실을 알린다 | `머지 뒤 반영` |
| TC-Y25 | 설치 기준에 아직 없는 플러그인은 설치하지 않고 알린다 | `install` 호출 없음 |
| TC-Y26 | 설치 기준 쪽이 설치본과 다르면 재설치한다 | `uninstall` + `install` |
| TC-Y27 | 설치 기준 경로가 이 작업 트리면 작업 트리와 비교한다 | 재설치, 알림 없음 |
| TC-Y28 | `claude plugin list` 의 `Error:` 줄을 로드 실패로 보고한다 | `로드 실패` |
| TC-Y29 | 다른 마켓플레이스 플러그인의 `Error:` 는 무시한다 | 보고 없음 |
| TC-Y30 | `Error:` 는 바로 위 플러그인에 붙인다 | 해당 id 만 보고 |
| TC-Y31 | internal 엔트리 description 을 plugin.json 에 맞춘다 | 파일 반영 |
| TC-Y32 | public 엔트리 description 은 건드리지 않는다 | 파일 유지 |
| TC-Y33 | plugin.json 에 description 이 없으면 엔트리를 비우지 않는다 | 파일 유지 |
| TC-Y34 | `enabledPlugins` 키 순서를 정렬해 둔다 | 재설치가 키를 맨 뒤로 보내 생기는 diff 방지 |
| TC-Y35 | 이미 정렬돼 있으면 파일을 다시 쓰지 않는다 | 수정 시각 유지 |

## 등록 메타데이터

| 필드 | 규칙 | 원본 |
|---|---|---|
| `category` | 배치 — `public` / `internal`. 디렉터리와 같아야 한다 | `.claude-plugin/categories.json` (없으면 두 값) |
| `tags` | 주제 — 2개까지, 2개면 `domain` 1 + `technology` 1 | `.claude-plugin/tags.json` |
| `description` | `plugin.json` 과 같다. internal 은 sync 훅이 맞춘다 | `plugin.json` |
| `author` · `version` | 엔트리에 두지 않는다 (`author` 는 경고) | `plugin.json` |

`common-*` 플러그인은 배포가 목적이므로 `public-plugins/` 에만 둔다 (TC-S27).

## 설치 기준과 워크트리

설치는 마켓플레이스 소스 디렉터리에서 복사해 온다. 이 저장소는 마켓플레이스를 메인 체크아웃의 **절대 경로**로 전역 등록한다.
워크트리에서 세션을 열면 설치 기준은 여전히 메인 체크아웃이다. 그래서 설치본은 작업 트리가 아니라 **설치 기준**과 비교한다 (TC-Y23 ~ Y27).
비교 대상을 작업 트리로 두면 워크트리에서 고친 플러그인은 항상 달라 보여 세션마다 재설치하지만, 재설치는 메인 체크아웃에서 받으므로 끝내 같아지지 않는다.

## 끄기와 정리

- `enabledPlugins` 에 키가 **없을 때만** `true` 로 추가한다. 명시적 `false` 는 사용자가 끈 것이다 (TC-Y15 · Y16)
- 디렉터리를 지운 internal 플러그인은 엔트리 · 활성화 키 · 설치본을 훅이 치운다 (TC-Y17 ~ Y22). public 은 배치 검사가 사람에게 알린다

## 왜 재설치가 필요한가

플러그인을 설치하면 `~/.claude/plugins/cache/<마켓플레이스>/<이름>/<버전>/` 으로 **복사**된다.
로컬 디렉터리 소스라도 작업 트리를 실시간으로 읽지 않는다. 그리고 `claude plugin update` 는
버전이 같으면 `already at the latest version` 으로 끝나 캐시를 갱신하지 않는다.

그래서 동기화 훅이 설치본과 작업 트리를 `diff -rq` 로 비교해, 어긋나면 uninstall → install 로
강제 재설치한다 (TC-Y10). 이것이 없으면 플러그인을 고쳐도 낡은 코드가 계속 돈다.

## 변이 테스트

검증기를 일부러 망가뜨렸을 때 TC 가 실제로 깨지는지 확인한다.

| 변이 | 깨져야 할 곳 | 실측 |
|---|---|---|
| 단독 사용 금지 무력화 | 이름 규칙 | 19건 실패 |
| glossary deny 조회 무력화 | 이름 규칙 | 5건 실패 |
| kebab 정규식 무력화 | 이름 규칙 | 5건 실패 |
| category 검사 무력화 | 배치 정책 | 2건 실패 |
| source 검사 무력화 | 배치 정책 | 1건 실패 |
| 드리프트 감지 무력화 | 동기화 | 1건 실패 |

전부 통과가 나오면 그 TC 는 아무것도 검증하지 못하고 있는 것이다.
