# node-naming

Node.js 프로젝트의 이름을 npm 규칙과 JavaScript 관례로 강제한다 — package.json name, 환경 변수 UPPER_SNAKE_CASE, 클래스 PascalCase, 변수·함수 camelCase, 파일 kebab-case.

모양은 훅이 막고, 어떤 단어를 쓸지는 `node-name-create` 스킬이 판단한다. 근거는 npm 의 package.json `name` 규칙 · Airbnb JavaScript Style Guide 의 Naming Conventions · Node.js 와 POSIX 환경 변수 관례다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install node-naming@jaemyeong-hwnag-plugins
```

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| node-name-create | package.json · npm 패키지 이름 · npm script · 환경 변수 이름 · `.js` · `.mjs` | 모양 표와 단어 선택 판단 (환경 변수 접두사 · 모듈 파일과 export · CLI bin · 이벤트 이름) |
| /node-naming-validate | 직접 호출 | 프로젝트 전체의 `package.json` · JS 파일 · 환경 변수를 검증해 조항별로 보고한다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-node-naming.sh | PreToolUse (Write\|Edit) | `package.json` · `*.js` · `*.mjs` · `*.cjs` · `*.jsx` (와 TS 의 환경 변수) 편집이 **새로 만든** 위반이면 **차단**, 경고 조항은 알림 |

## 주의

- 훅은 편집 전과 뒤를 비교해 **늘어난 위반만** 막는다. 레거시 파일의 다른 줄을 고칠 때 기존 이름 때문에 막히지 않는다. 기존 위반은 `/node-naming-validate` 로 찾는다
- TS 파일(`*.ts` · `*.tsx` · `*.mts` · `*.cts`)은 환경 변수(`ND-03`)만 본다. 식별자는 `typescript-naming` 이 맡는다
- 변수 · 함수는 `let` · `const` · `var` · `function` 선언의 첫 이름만 본다. 메서드 · 객체 속성 · 매개변수 · 구조 분해는 스킬이 판단한다
- `const { dbHost } = process.env` 처럼 구조 분해로 읽는 환경 변수는 보지 않는다
- 편집 뒤 `package.json` 이 올바른 JSON 이 아니면 판정하지 않는다
- `node_modules/` · `dist/` · `build/` · `out/` · `coverage/` · `.next/` · `generated/` · `vendor/`, `*.min.js` 는 보지 않는다
- `jq` 가 필요하다

## 규칙 요약

| 조항 | 대상 | 규칙 | 판정 |
|---|---|---|---|
| `ND-01` | `package.json` 최상위 `name` | npm 규칙 (214자 이하 · 소문자 · `.` `_` 로 시작 X · URL-safe · `@scope/name`) | 차단 |
| `ND-02` | `package.json` 의 `scripts` 키 | 소문자 · 숫자를 `-` 와 `:` 로 (`test:unit`) | 경고 |
| `ND-03` | `process.env.NAME` · `process.env['NAME']` | UPPER_SNAKE_CASE (`npm_*` · 프록시 변수 예외) | 차단 |
| `ND-04` | JS 클래스 | PascalCase | 차단 |
| `ND-05` | JS `let` · `const` · `var` · `function` | 소문자가 섞인 snake_case 금지 → camelCase | 차단 |
| `ND-06` | JS 파일 이름 | kebab-case, 또는 export 이름을 딴 camelCase · PascalCase. 밑줄만 경고 | 경고 |

원본: [`references/node-naming-rules.md`](references/node-naming-rules.md)

## 사용

```bash
scripts/validate-node-naming.sh src package.json     # 파일 · 디렉터리
scripts/validate-node-naming.sh --all .              # 프로젝트 전체
test/validate-node-naming.test.sh                    # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
