# 디렉터리 구조 규칙

마켓플레이스 저장소와 그 안의 플러그인이 **무엇을 어디에 두는가**를 정한다.

다루지 않는 것 — 이름이 올바른가(`plugin-naming`), 어느 쪽에 배치하고 어떻게 배포하는가(저장소 `.claude/hooks/`).

## 1. 마켓플레이스 루트

```
.claude-plugin/
  marketplace.json         # 마켓플레이스 매니페스트 (필수)
  tags.json                # 태그 정의
  categories.json          # 카테고리 정의
  plugins.json             # 플러그인 목록 (중복 체크용)
  keywords.json
.claude/
  settings.json            # 마켓플레이스 등록 · 플러그인 활성화 · 훅 등록
  hooks/
    {hook-name}.sh         # 저장소 정책 훅
.agent-tasks/              # 진행 중인 피처 문서 (git 미추적)
  {주제}/
    {문서}.md
test/                      # 저장소 정책 테스트
  {대상}.test.sh
  README.md
CLAUDE.md
README.md
CHANGELOG.md
.gitignore
public-plugins/            # 배포용 (category: public)
  {plugin-name}/
internal-plugins/          # 내부용 (category: internal)
  {plugin-name}/
```

| 조항 | 내용 | 검증 |
|---|---|---|
| R-01 | `.claude-plugin/marketplace.json` 이 있어야 한다 | 위반 시 차단 |
| R-02 | `README.md`, `CHANGELOG.md` 가 있어야 한다 | 위반 시 차단 |
| R-03 | `.claude-plugin/` 에는 위 다섯 파일만 둔다 | 위반 시 차단 |
| R-04 | 플러그인은 `public-plugins/<이름>/` 또는 `internal-plugins/<이름>/` **바로 아래**에만 둔다 | 위반 시 차단 |
| R-05 | `CLAUDE.md` 가 없으면 경고한다 | 경고 |

루트의 다른 파일·디렉터리(`.git/`, `.idea/`, `.agent-tasks/` …)는 검사하지 않는다. 열거되지 않은 것을 막지 않는다.

## 2. 개별 플러그인

배포용은 `public-plugins/`, 내부용은 `internal-plugins/` 아래에 두며 구조는 같다.

```
{public-plugins|internal-plugins}/{plugin-name}/
  .claude-plugin/
    plugin.json              # 필수
  README.md                  # 필수
  CHANGELOG.md               # 필수
  skills/
    {skill-name}/
      SKILL.md               # 필수
  hooks/                     # 선택
    hooks.json               # 훅 매니페스트
  scripts/                   # 선택
    {script-name}.sh         # 훅·커맨드가 실행하는 스크립트
  commands/                  # 선택
    {command-name}.md
  references/                # 선택
    {ref-name}.md
    {ref-name}.json
  agents/                    # 선택
    {agent-name}.md
  test/                      # 선택
    {대상}.test.sh
    README.md
```

| 조항 | 내용 |
|---|---|
| P-01 | `.claude-plugin/plugin.json`, `README.md`, `CHANGELOG.md` 는 필수다 |
| P-02 | `.claude-plugin/` 에는 `plugin.json` 만 둔다 |
| P-03 | `plugin.json` 은 올바른 JSON 이고 `name` 이 디렉터리명과 같아야 한다 |
| P-04 | `plugin.json` 이 가리키는 상대 경로(`hooks`)의 파일이 실제로 있어야 한다 |
| P-05 | 플러그인 루트에는 `README.md` · `CHANGELOG.md` · `LICENSE` · `.gitignore` 만 둔다 |
| P-06 | 디렉터리는 `.claude-plugin` · `skills` · `hooks` · `scripts` · `commands` · `references` · `agents` · `test` 만 쓴다 |
| P-07 | 각 디렉터리에 두는 파일 확장자는 아래 표를 따른다 |
| P-08 | `skills/` 아래에는 스킬 디렉터리만 두고, 각 디렉터리에 `SKILL.md` 가 있어야 한다 |

| 디렉터리 | 둘 수 있는 것 |
|---|---|
| `.claude-plugin/` | `plugin.json` |
| `skills/` | `{skill-name}/` 디렉터리. 그 안은 `SKILL.md` 필수, 나머지는 자유 |
| `hooks/` | `*.json` |
| `scripts/` | `*.sh` |
| `commands/` | `*.md` |
| `references/` | `*.md`, `*.json` |
| `agents/` | `*.md` |
| `test/` | `*.test.sh`, `README.md` |

`{...}` 자리의 이름이 올바른지는 이 규칙이 판단하지 않는다. `plugin-naming` 의 몫이다.

## 3. 디렉터리 생성 순서

1. `public-plugins/{plugin-name}/` 또는 `internal-plugins/{plugin-name}/` 생성
2. `.claude-plugin/plugin.json` 작성
3. `skills/`, `hooks/`, `agents/`, `commands/` 등 구성요소 추가
4. `README.md` 작성
5. `CHANGELOG.md` 초기화
6. 마켓플레이스 루트 `.claude-plugin/marketplace.json` 에 등록
   - `source` 와 `category` 가 1번에서 고른 디렉터리와 일치해야 한다
     (`public-plugins/` → `public`, `internal-plugins/` → `internal`)
   - 내부용은 저장소 SessionStart 훅이 대신 등록한다
7. 마켓플레이스 루트 `.claude-plugin/plugins.json` 에 등록 (파일을 쓰는 저장소만)

6·7 번의 등록 내용이 맞는지는 저장소 `.claude/hooks/validate-plugin-scope.sh` 가 본다.

## 4. 경계

| 질문 | 담당 |
|---|---|
| 이 파일을 여기에 둬도 되는가 | 이 플러그인 |
| 이 이름을 써도 되는가 | `plugin-naming` |
| public 인가 internal 인가, 등록은 맞는가 | 저장소 `.claude/hooks/validate-plugin-scope.sh` |
| 설치·동기화 | 저장소 `.claude/hooks/sync-internal-plugins.sh` |
