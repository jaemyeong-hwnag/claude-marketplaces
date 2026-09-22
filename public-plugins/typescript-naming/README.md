# typescript-naming

TypeScript 소스의 식별자를 TypeScript 관례로 강제한다 — 타입·클래스·enum PascalCase, 변수·함수 camelCase(snake_case 금지), interface I 접두사·enum 멤버·타입 매개변수·class 멤버 경고.

모양은 훅이 막고, 어떤 단어를 쓸지는 `typescript-name-create` 스킬이 판단한다. 근거는 TypeScript 팀 Coding guidelines 의 Names 절 · TypeScript Handbook · typescript-eslint `naming-convention` 기본값 · Google TypeScript Style Guide 의 Identifiers 절이다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install typescript-naming@plugin-marketplace
```

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| typescript-name-create | `.ts` · `.tsx` 코드 작성 · interface · type · 제네릭 이름 짓기 | 모양 표와 단어 선택 판단 (타입과 값 이름 충돌 · `Props` 접미사 · boolean · 유니언 리터럴 · 약어) |
| /typescript-naming-validate | 직접 호출 | 프로젝트 전체 `*.ts` · `*.tsx` · `*.mts` · `*.cts` 를 검증해 조항별로 보고한다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-typescript-naming.sh | PreToolUse (Write\|Edit) | `*.ts` · `*.tsx` · `*.mts` · `*.cts` 편집이 **새로 만든** 위반이면 **차단**, 경고 조항은 알림 |

## 주의

- 훅은 편집 전과 뒤를 비교해 **늘어난 위반만** 막는다. 레거시 파일의 다른 줄을 고칠 때 기존 이름 때문에 막히지 않는다. 기존 위반은 `/typescript-naming-validate` 로 찾는다
- 파서 없이 줄 단위로 본다. 구조 분해 · 객체 리터럴 키 · interface · type 의 프로퍼티 · 매개변수는 보지 않는다 — 스킬이 판단한다
- class 멤버는 접근 제어자(`public` · `protected` · `private`)나 `readonly` 로 시작하는 선언만 본다. API 페이로드를 그대로 받는 DTO 가 있어 경고만 한다
- 파일 이름 · `package.json` · 환경 변수 이름은 보지 않는다
- `*.d.ts` 와 `node_modules/` · `dist/` · `build/` · `out/` · `coverage/` · `.next/` · `generated/` 는 보지 않는다
- `jq` 가 필요하다

## 규칙 요약

| 조항 | 대상 | 규칙 | 판정 |
|---|---|---|---|
| `TS-01` | class · interface · type · enum · namespace | PascalCase | 차단 |
| `TS-02` | interface | `I` 접두사 없음 (`IUser` X) | 경고 |
| `TS-03` | `let` · `const` · `var` · `function` | 소문자 snake_case 금지 → camelCase (UPPER_SNAKE · PascalCase · 앞 밑줄 허용) | 차단 |
| `TS-04` | enum 멤버 | PascalCase 또는 UPPER_SNAKE_CASE | 경고 |
| `TS-05` | 타입 매개변수 | `T` · `TKey` · PascalCase | 경고 |
| `TS-06` | class 멤버 (접근 제어자 · `readonly`) | snake_case 금지 → camelCase | 경고 |

원본: [`references/typescript-naming-rules.md`](references/typescript-naming-rules.md)

## 사용

```bash
scripts/validate-typescript-naming.sh src           # 디렉터리
scripts/validate-typescript-naming.sh --all .       # 프로젝트 전체
test/validate-typescript-naming.test.sh             # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
