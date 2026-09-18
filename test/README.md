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
