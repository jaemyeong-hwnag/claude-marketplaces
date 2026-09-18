# 디렉터리 구조 테스트

`scripts/validate-directory-structure.sh` 의 회귀 테스트. 구조 규칙이나 스크립트를 고치면 여기부터 돌린다.

이름 규칙 테스트는 `internal-plugins/plugin-naming/test/` 에, 배치·배포 정책 테스트는 저장소 `test/` 에 있다. 섞지 않는다.

## 실행

```bash
test/validate-directory-structure.test.sh          # 전체
test/validate-directory-structure.test.sh TC-D1    # ID 접두사로 필터
```

종료 코드 0 이면 전체 통과다. 세션 없이 돌아가므로 커밋 전 검증에 그대로 쓴다.

## 자동 TC (39건)

### A. 플러그인 필수 파일

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-D01 | 이 저장소 전체가 통과한다 | 통과 (0) | - |
| TC-D02 | 필수 세 파일을 갖춘 플러그인은 통과한다 | 통과 (0) | - |
| TC-D03 | plugin.json 이 없으면 막는다 | 차단 (2) | 메시지: `plugin.json 이 없습니다` |
| TC-D04 | README.md 가 없으면 막는다 | 차단 (2) | 메시지: `README.md 가 없습니다` |
| TC-D05 | CHANGELOG.md 가 없으면 막는다 | 차단 (2) | 메시지: `CHANGELOG.md 가 없습니다` |
| TC-D06 | plugin.json 이 깨져 있으면 막는다 | 차단 (2) | 메시지: `JSON 파싱 실패` |
| TC-D07 | plugin.json 의 name 이 디렉터리명과 다르면 막는다 | 차단 (2) | 메시지: `디렉터리명과 같아야 합니다` |
| TC-D08 | plugin.json 의 hooks 가 가리키는 파일이 없으면 막는다 | 차단 (2) | 메시지: `hooks 가 가리키는` |

### B. 파일 위치

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-D10 | 플러그인 루트의 알 수 없는 파일을 막는다 | 차단 (2) | 메시지: `플러그인 루트에는` |
| TC-D11 | LICENSE 와 .gitignore 는 루트에 둘 수 있다 | 통과 (0) | - |
| TC-D12 | 알 수 없는 디렉터리를 막는다 | 차단 (2) | 메시지: `알 수 없는 디렉터리 'docs/'` |
| TC-D13 | .claude-plugin 에 plugin.json 외의 파일을 막는다 | 차단 (2) | 메시지: `.claude-plugin/ 에는 plugin.json 만` |
| TC-D14 | hooks/ 에 스크립트를 두면 막는다 | 차단 (2) | 메시지: `hooks/ 에는 *.json 만` |
| TC-D15 | scripts/ 에 문서를 두면 막는다 | 차단 (2) | 메시지: `scripts/ 에는 *.sh 만` |
| TC-D16 | commands/ 에 스크립트를 두면 막는다 | 차단 (2) | 메시지: `commands/ 에는 *.md 만` |
| TC-D17 | references/ 는 *.md 와 *.json 을 허용한다 | 통과 (0) | - |
| TC-D18 | agents/ 에 *.md 가 아닌 파일을 두면 막는다 | 차단 (2) | 메시지: `agents/ 에는 *.md 만` |
| TC-D19 | test/ 는 *.test.sh 와 README.md 만 허용한다 | 통과 후 차단 (2) | 메시지: `test/ 에는` |

### C. 스킬 디렉터리

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-D20 | 스킬 디렉터리에 SKILL.md 가 없으면 막는다 | 차단 (2) | 메시지: `SKILL.md 가 없습니다` |
| TC-D21 | skills/ 바로 아래 파일을 막는다 | 차단 (2) | 메시지: `스킬 디렉터리만 둡니다` |
| TC-D22 | 스킬 디렉터리 안쪽 파일은 자유다 | 통과 (0) | - |

### D. 마켓플레이스 루트

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-D30 | 정상 루트는 통과한다 | 통과 (0) | - |
| TC-D31 | marketplace.json 이 없으면 막는다 | 차단 (2) | 메시지: `marketplace.json 이 없습니다` |
| TC-D32 | 루트 CHANGELOG.md 가 없으면 막는다 | 차단 (2) | 메시지: `CHANGELOG.md 가 없습니다` |
| TC-D33 | .claude-plugin 의 알 수 없는 파일을 막는다 | 차단 (2) | 메시지: `알 수 없는 파일` |
| TC-D34 | tags/categories/plugins/keywords.json 은 허용한다 | 통과 (0) | - |
| TC-D35 | CLAUDE.md 가 없으면 경고만 한다 | 통과 (0) | 메시지: `CLAUDE.md 가 없습니다` |
| TC-D36 | 플러그인이 *-plugins 밖에 있으면 막는다 | 차단 (2) | 메시지: `아래에 둡니다` |
| TC-D37 | 플러그인이 한 단계 더 깊으면 막는다 | 차단 (2) | 메시지: `바로 아래에 둡니다` |

### E. 훅 모드 (stdin JSON)

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-D40 | 위반 위치에 쓰려 하면 차단한다 | 차단 (2) | 메시지: `알 수 없는 디렉터리 'docs/'` |
| TC-D41 | 규칙에 맞는 위치는 통과시킨다 | 통과 (0) | 출력 없음 |
| TC-D42 | 플러그인 밖 경로에는 반응하지 않는다 | 통과 (0) | 출력 없음 |
| TC-D43 | *-plugins 바로 아래 파일에는 반응하지 않는다 | 통과 (0) | 출력 없음 |
| TC-D44 | stdin 이 비면 통과시킨다 | 통과 (0) | 출력 없음 |
| TC-D45 | 경로가 없는 훅 입력은 통과시킨다 | 통과 (0) | 출력 없음 |

### F. CLI 인자

| ID | 케이스 | 기대 | 추가 확인 |
|---|---|---|---|
| TC-D50 | 파일 경로 하나만 줘도 위치를 검사한다 | 차단 (2) | 메시지: `hooks/ 에는 *.json 만` |
| TC-D51 | 올바른 파일 경로는 조용히 통과한다 | 통과 (0) | 출력 없음 |
| TC-D52 | 마켓플레이스 루트를 주면 플러그인까지 함께 검사한다 | 차단 (2) | 메시지: `CHANGELOG.md 가 없습니다` |
| TC-D53 | 플러그인도 루트도 아닌 디렉터리는 오류를 낸다 | 차단 (2) | 메시지: `마켓플레이스 루트도 아닙니다` |

## 수동 TC (새 세션 필요)

훅 등록·스킬 자동 발동은 세션이 있어야 확인된다. `.claude/settings.json` 은 세션 시작 시점에 로드되므로 반드시 새 세션에서 돌린다.

| ID | 케이스 | 입력 | 기대 |
|---|---|---|---|
| TC-DM01 | 훅이 등록된다 | `/hooks` | PreToolUse 에 `validate-directory-structure.sh` 가 보인다 |
| TC-DM02 | 스킬이 등록된다 | `/skills` | `plugin-directory-create` 가 보인다 |
| TC-DM03 | 커맨드가 등록된다 | `/directory-structure-validate` | 전체 검사가 돈다 |
| TC-DM04 | 훅이 잘못된 위치의 파일 생성을 실제로 막는다 | `internal-plugins/plugin-naming/docs/guide.md 만들어줘` | 차단 후 `references/` 로 재제안. `ls internal-plugins/plugin-naming/docs` 가 없어야 한다 |
| TC-DM05 | 훅이 올바른 위치는 통과시킨다 | `internal-plugins/plugin-naming/references/sample-note.md 만들어줘` | 차단 없이 생성. 확인 후 삭제 |
| TC-DM06 | 스킬이 자동 발동한다 | `플러그인에 에이전트 추가하려는데 파일 어디에 둬야 해?` (스킬 이름 언급 금지) | `plugin-directory-create` 발동, `agents/<이름>.md` 안내 |

## 테스트가 헛돌지 않는지 확인 (변이 테스트)

```bash
cp scripts/validate-directory-structure.sh /tmp/vds.bak

# 변이: 알 수 없는 디렉터리 검사 무력화 → TC-D12 등이 깨져야 한다
sed -i '' 's/if ! has_word "$PLUGIN_DIRS" "$top"; then/if false; then/' scripts/validate-directory-structure.sh
test/validate-directory-structure.test.sh; echo "exit=$?"

cp /tmp/vds.bak scripts/validate-directory-structure.sh && test/validate-directory-structure.test.sh
```

## TC 추가 규칙

- 규칙(`references/directory-structure-rules.md`)에 조항을 추가하면 TC 도 같이 추가한다. 조항 번호를 TC 설명에 남긴다.
- ID 구간을 지킨다. A 필수파일 `TC-D0x` / B 위치 `TC-D1x` / C 스킬 `TC-D2x` / D 루트 `TC-D3x` / E 훅 `TC-D4x` / F CLI `TC-D5x`.
- 막는 TC 만 늘리지 않는다. "허용해야 하는 케이스"를 쌍으로 넣어야 과잉 차단을 잡는다.

## 알려진 한계 (실패로 보지 말 것)

- 훅은 `Write` / `Edit` 에만 걸린다. `Bash(mkdir)` 로 만든 빈 디렉터리는 못 막는다. 그 안에 파일을 쓸 때 걸린다.
- 훅은 **위치만** 본다. 필수 파일 누락은 훅이 아니라 `--all` 에서 잡는다. 파일을 하나씩 만드는 도중에 막으면 아무것도 못 만든다.
- 스킬 디렉터리(`skills/<이름>/`) 안쪽은 검사하지 않는다. 스킬마다 필요한 파일이 다르다.
- 마켓플레이스 루트의 그 밖의 파일·디렉터리(`.idea/`, `.agent-tasks/` …)는 검사하지 않는다. 열거되지 않은 것을 막지 않는다.
- `{...}` 자리의 이름이 옳은지는 판정하지 않는다. `plugin-naming` 의 몫이다.
