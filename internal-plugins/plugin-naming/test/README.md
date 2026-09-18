# 네이밍 규칙 테스트

`scripts/validate-naming.sh` 의 회귀 테스트. 이름 규칙·사전·스크립트를 고치면 여기부터 돌린다.

배치·배포 정책 테스트는 이 플러그인의 관심사가 아니다. 저장소의 `test/validate-plugin-scope.test.sh` 에 있다.

## 실행

```bash
test/validate-naming.test.sh          # 전체
test/validate-naming.test.sh TC-03    # ID 접두사로 필터
VERBOSE=1 test/validate-naming.test.sh  # 통과 케이스의 출력까지 표시
```

종료 코드 0 이면 전체 통과다. 세션 없이 돌아가므로 커밋 전 검증에 그대로 쓴다.

## 자동 TC (64건)

### A. 형식 (kebab-case)

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-001 | kebab-case 정상 이름은 통과한다 | 통과 (0) | - |
| TC-002 | 대문자가 섞이면 막는다 | 차단 (2) | 메시지: `kebab-case 위반` |
| TC-003 | 언더스코어를 쓰면 막는다 | 차단 (2) | 메시지: `kebab-case 위반` |
| TC-004 | 하이픈이 연속되면 막는다 | 차단 (2) | 메시지: `kebab-case 위반` |
| TC-005 | 하이픈으로 시작하면 막는다 | 차단 (2) | 메시지: `kebab-case 위반` |
| TC-006 | 하이픈으로 끝나면 막는다 | 차단 (2) | 메시지: `kebab-case 위반` |
| TC-007 | 단어에 숫자가 붙어도 통과한다 | 통과 (0) | - |

### B. 구조 (단독 사용 금지)

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-010 | 언어명 단독은 막는다 | 차단 (2) | 메시지: `한 단어 이름은 쓸 수 없습니다` |
| TC-011 | 목록에 없던 프레임워크도 막는다 (하드코딩 목록 비의존 회귀) | 차단 (2) | 메시지: `한 단어 이름은 쓸 수 없습니다` |
| TC-012 | 처음 보는 단어도 한 단어면 막는다 | 차단 (2) | 메시지: `한 단어 이름은 쓸 수 없습니다` |
| TC-013 | 범용 단어 단독은 막는다 | 차단 (2) | 메시지: `한 단어 이름은 쓸 수 없습니다` |
| TC-014 | 한 단어 스킬명도 막는다 | 차단 (2) | 메시지: `skill 'coverage'` |
| TC-015 | 한 단어 에이전트명도 막는다 | 차단 (2) | 메시지: `agent 'reviewer'` |
| TC-016 | 한 단어 커맨드명도 막는다 | 차단 (2) | 메시지: `command 'review'` |
| TC-017 | common-{관심사} 는 통과한다 | 통과 (0) | - |
| TC-018 | {역할}-standard 는 통과한다 | 통과 (0) | - |
| TC-019 | 세 단어 이상도 통과한다 | 통과 (0) | - |

### C. 맥락 중복

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-020 | 인접한 단어 중복을 막는다 | 차단 (2) | 메시지: `맥락 중복` |
| TC-021 | 떨어져 있는 단어 중복도 막는다 | 차단 (2) | 메시지: `맥락 중복` |
| TC-022 | 다른 단어끼리는 중복으로 보지 않는다 | 통과 (0) | - |

### D. glossary deny

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-030 | deny 단어를 구성 단어로 쓰면 막고 use 를 알려준다 | 차단 (2) | 메시지: `'document' 를 쓰세요` |
| TC-031 | 다른 카테고리의 deny 도 막는다 | 차단 (2) | 메시지: `'repository' 를 쓰세요` |
| TC-032 | action 카테고리 deny 를 막는다 | 차단 (2) | 메시지: `'validate' 를 쓰세요` |
| TC-033 | 여러 단어로 된 deny 는 이름 전체와 대조해 막는다 | 차단 (2) | 메시지: `'ci' 를 쓰세요` |
| TC-034 | use 단어로 바꾸면 통과한다 | 통과 (0) | - |
| TC-035 | 위반이 여러 개면 모두 보고한다 | 차단 (2) | 메시지: `'document' 를 쓰세요`, `'repository' 를 쓰세요` |

### E. 줄임말

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-040 | 등록되지 않은 3자 이하 단어는 경고하되 막지는 않는다 | 통과 (0) | 메시지: `줄임말이면 사용 금지` |
| TC-041 | glossary 에 등록된 공식 약어는 경고하지 않는다 | 통과 (0) | 경고 없음: `줄임말이면 사용 금지` |
| TC-042 | use 로 등록된 짧은 단어는 경고하지 않는다 | 통과 (0) | 경고 없음: `줄임말이면 사용 금지` |
| TC-043 | 네 글자 이상은 경고 대상이 아니다 | 통과 (0) | 경고 없음: `줄임말이면 사용 금지` |

### F. 경로 분류

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-050 | plugins/<이름> 을 플러그인으로 인식한다 | 차단 (2) | 메시지: `plugin 'java'` |
| TC-050b | public-plugins/ internal-plugins/ 처럼 접두사가 붙어도 인식한다 | 차단 (2) | 메시지: `plugin 'java'`, `plugin 'java'` |
| TC-050c | 임의의 *-plugins 디렉터리도 인식한다 | 차단 (2) | 메시지: `plugin 'java'` |
| TC-050d | 이름에 plugins 가 들어간 무관한 경로는 건드리지 않는다 | 통과 (0) | 출력 없음 |
| TC-051 | skills/<이름> 을 스킬로 인식한다 | 차단 (2) | 메시지: `skill 'utils'` |
| TC-052 | commands/<이름>.md 를 커맨드로 인식한다 | 차단 (2) | 메시지: `command 'utils'` |
| TC-053 | agents/<이름>.md 를 에이전트로 인식한다 | 차단 (2) | 메시지: `agent 'utils'` |
| TC-054 | 검사 대상이 아닌 경로는 아무 말도 하지 않는다 | 통과 (0) | 출력 없음 |
| TC-055 | 한 경로에 여러 대상이 겹치면 각각 검사한다 | 차단 (2) | 메시지: `plugin 'java'`, `skill 'utils'` |
| TC-056 | 이름만 인자로 줘도 검사한다 | 통과 (0) | - |
| TC-057 | 이름만 줬을 때 위반도 잡는다 | 차단 (2) | 메시지: `한 단어 이름은 쓸 수 없습니다` |

### G. 훅 모드 (stdin JSON)

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-060 | PreToolUse 위반이면 종료 코드 2 로 차단한다 | 차단 (2) | - |
| TC-061 | PreToolUse 준수면 통과시킨다 | 통과 (0) | - |
| TC-062 | PreToolUse 무관 파일은 통과시킨다 | 통과 (0) | 출력 없음 |
| TC-063 | PostToolUse 정상 glossary 는 통과시킨다 | 통과 (0) | - |
| TC-064 | PostToolUse 깨진 glossary 는 잡는다 | 차단 (2) | 메시지: `glossary:` |
| TC-065 | PostToolUse 무관 파일은 검사하지 않는다 | 통과 (0) | 출력 없음 |
| TC-066 | stdin 이 비면 통과시킨다 | 통과 (0) | 출력 없음 |
| TC-067 | 경로가 없는 훅 입력은 통과시킨다 | 통과 (0) | 출력 없음 |

### H. glossary 구조 검증

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-070 | 현재 사전은 구조 검증을 통과한다 | 통과 (0) | - |
| TC-071 | 카테고리가 알파벳 순이 아니면 잡는다 | 차단 (2) | 메시지: `카테고리를 알파벳 순으로 정렬` |
| TC-072 | 카테고리 안의 use 가 정렬되지 않으면 잡는다 | 차단 (2) | 메시지: `use 알파벳 순으로 정렬` |
| TC-073 | use 에 대문자가 있으면 잡는다 | 차단 (2) | 메시지: `use 는 비어있지 않은 소문자` |
| TC-074 | deny 가 비어 있으면 잡는다 | 차단 (2) | 메시지: `deny 는 최소 1개` |
| TC-075 | deny 에 대문자가 있으면 잡는다 | 차단 (2) | 메시지: `소문자여야 합니다` |
| TC-076 | meaning 이 비면 잡는다 | 차단 (2) | 메시지: `한 줄짜리 한국어 설명` |
| TC-077 | 같은 단어가 여러 항목에 등록되면 잡는다 | 차단 (2) | 메시지: `중복 등록` |
| TC-078 | use 와 deny 에 같은 단어가 있으면 잡는다 | 차단 (2) | 메시지: `중복 등록` |
| TC-079 | JSON 이 깨져 있으면 잡는다 | 차단 (2) | 메시지: `JSON 파싱 실패` |

### I. 전체 검사

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-080 | 플러그인 자신은 전체 검사를 통과한다 | 통과 (0) | - |
| TC-081 | 전체 검사가 plugins/ 의 위반을 찾아낸다 | 차단 (2) | 메시지: `plugin 'java'` |
| TC-082 | 전체 검사가 스킬·커맨드·에이전트 위반도 찾아낸다 | 차단 (2) | 메시지: `skill 'utils'`, `command 'review'`, `agent 'reviewer'` |
| TC-083 | 전체 검사가 사전 구조도 함께 본다 | 차단 (2) | 메시지: `glossary:` |
| TC-084 | 전체 검사가 접두사 붙은 *-plugins 디렉터리도 본다 | 차단 (2) | 메시지: `plugin 'utils'`, `plugin 'helpers'` |

## 수동 TC (새 세션 필요)

훅 등록·스킬 자동 발동은 세션이 있어야 확인된다. `.claude/settings.json` 은 **세션 시작 시점에 로드**되므로 반드시 새 세션에서 돌린다.

```bash
cd <저장소 루트> && claude
```

| ID | 케이스 | 입력 | 기대 |
|---|---|---|---|
| TC-M01 | 훅이 등록된다 | `/hooks` | PreToolUse / PostToolUse 에 `validate-naming.sh` 가 보인다 |
| TC-M02 | 스킬이 등록된다 | `/skills` | `name-create`, `glossary-update` 가 보인다 |
| TC-M03 | 에이전트가 등록된다 | `/agents` | `naming-reviewer` 가 보인다 |
| TC-M04 | 훅이 위반 이름의 파일 생성을 실제로 막는다 | `plugins/java/.claude-plugin/plugin.json 만들어줘` | 차단 메시지 후 `java-naming` 등 재제안. **`ls plugins/` 에 파일이 없어야 한다** |
| TC-M05 | 훅이 준수 이름은 통과시킨다 | `plugins/kotlin-naming/.claude-plugin/plugin.json 만들어줘` | 차단 없이 생성. 확인 후 `rm -rf plugins` |
| TC-M06 | 훅이 무관한 파일에 반응하지 않는다 | `README.md 맨 아래 한 줄 추가해줘` | 경고 없이 수정 |
| TC-M07 | 사전 훅이 깨진 항목을 잡는다 | `references/glossary.json 의 time 맨 위에 { "use": "Week", "deny": [], "meaning": "" } 추가해줘` | PostToolUse 가 소문자·deny·meaning·정렬 오류를 보고하고 스스로 되돌린다 |
| TC-M08 | 이름 스킬이 자동 발동한다 | `노션에 문서 동기화하는 플러그인 만들려는데 이름 뭐로 하지?` (스킬 이름 언급 금지) | `name-create` 발동, `doc-*` 거절하고 `document-*` 계열 제안 |
| TC-M09 | 사전 스킬이 자동 발동한다 | `사전에 cache 단어 추가하고 싶어` | `glossary-update` 발동, deny 전체 검색부터 안내 |
| TC-M10 | 에이전트가 기계로 못 잡는 걸 잡는다 | `naming-reviewer 로 검토해줘: doc-sync, document-sync, spring-boot-config` | 앞 둘은 훅 기준대로, `spring-boot-config` 는 프레임워크 풀네임으로 지적 |

TC-M07 후 원복 확인:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-naming.sh" --glossary && git diff --stat references/glossary.json
```

TC-M04 / TC-M05 후 정리:

```bash
rm -rf plugins && test/validate-naming.test.sh
```

## 테스트가 헛돌지 않는지 확인 (변이 테스트)

스크립트를 일부러 망가뜨렸을 때 TC 가 실제로 깨지는지 본다.

```bash
cp scripts/validate-naming.sh /tmp/vn.bak

# 변이 1: 단독 사용 금지 검사 무력화 → 다수 실패해야 한다
sed -i '' 's/if \[ "${#segs\[@\]}" -lt 2 \]; then/if false; then/' scripts/validate-naming.sh
test/validate-naming.test.sh; echo "exit=$?"

cp /tmp/vn.bak scripts/validate-naming.sh && test/validate-naming.test.sh
```

변이를 넣었는데 전체 통과가 나오면 그 TC 는 아무것도 검증하지 못하고 있는 것이다.

## TC 추가 규칙

- TC 는 `test/validate-naming.test.sh` 에 추가하고, 이 문서의 표는 거기서 생성한다. 표만 고치지 않는다.
- ID 는 구간을 지킨다. A 형식 `TC-00x` / B 구조 `TC-01x` / C 중복 `TC-02x` / D 사전 `TC-03x` / E 줄임말 `TC-04x` / F 경로 `TC-05x` / G 훅 `TC-06x` / H 사전구조 `TC-07x` / I 전체검사 `TC-08x`.
- 규칙을 바꾸면 "통과해야 하는 케이스"와 "막아야 하는 케이스"를 **쌍으로** 추가한다. 차단 TC 만 늘리면 과잉 차단을 놓친다.
- `references/naming-rules.md` 에 조항을 추가하면 대응 TC 없이 끝내지 않는다.

## 알려진 한계 (실패로 보지 말 것)

- 훅은 `Write` / `Edit` 에만 걸린다. `Bash(mkdir plugins/java)` 로 만든 빈 디렉터리는 못 막는다. 그 안에 파일을 쓸 때 걸린다.
- 3자 이하 미등록 단어는 **경고**만 낸다 (TC-040). 차단이 아니다.
- `spring-boot` 처럼 두 단어짜리 프레임워크 풀네임은 기계로 못 잡는다. `naming-reviewer` 의 몫이다 (TC-M10).
- 코드 식별자(변수·함수명)는 훅이 검사하지 않는다. `name-create` 스킬이 안내할 뿐이다.
