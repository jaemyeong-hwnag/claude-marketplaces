# python-naming

Python 코드의 이름을 PEP 8 로 강제한다 — 모듈 파일 소문자 snake_case, 클래스 CapWords, 함수·메서드 snake_case, 매개변수·변수 mixedCase 경고, 예외 클래스 Error 접미사.

모양은 훅이 막고, 어떤 단어를 쓸지는 `python-name-create` 스킬이 판단한다. 근거는 PEP 8 의 Naming Conventions 절과 pep8-naming(flake8 플러그인)의 `N8xx` 규칙이다.

## 설치

```bash
/plugin marketplace add jaemyeong-hwnag/claude-marketplaces
/plugin install python-naming@jaemyeong-hwnag-plugins
```

## 의존성

없음

## 포함된 스킬

| 스킬 | 트리거 | 설명 |
|---|---|---|
| python-name-create | 파이썬 코드 작성 · 모듈 · 클래스 · 함수 · 변수 이름 짓기 | 모양 표와 단어 선택 판단 (줄임말 · 내장 이름 가리기 · 밑줄 접두사 · boolean · 컬렉션 · TypeVar) |
| /python-naming-validate | 직접 호출 | 프로젝트 전체 `*.py` 를 검증해 조항별로 보고한다 |

## 포함된 훅

| 스크립트 | 이벤트 | 동작 |
|---|---|---|
| validate-python-naming.sh | PreToolUse (Write\|Edit) | `*.py` 편집이 **새로 만든** 위반이면 **차단**, 경고 조항은 알림 |

## 주의

- 훅은 편집 전과 뒤를 비교해 **늘어난 위반만** 막는다. 레거시 파일의 다른 줄을 고칠 때 기존 이름 때문에 막히지 않는다. 기존 위반은 `/python-naming-validate` 로 찾는다
- 줄 끝 `# noqa` 나 `# noqa: N8xx` 가 있는 줄은 보지 않는다 (pep8-naming 과 같은 탈출구). unittest 의 `setUp` 류 · `visit_X` · `do_GET` · `@override` 가 붙은 메서드는 막지 않는다
- 문법 트리가 아니라 줄 단위로 읽는다. 매개변수 · 변수 · 예외 클래스는 오탐 가능성이 있어 경고만 한다
- `venv/` · `.venv/` · `site-packages/` · `__pycache__/` · `build/` · `dist/` · `.tox/` · `.eggs/` · `migrations/` · `alembic/versions/` 는 보지 않는다
- `jq` 가 필요하다

## 규칙 요약

| 조항 | 대상 | 규칙 | 판정 |
|---|---|---|---|
| `PY-01` | 모듈 파일 이름 | 소문자 snake_case (`__init__.py` 허용) | 차단 |
| `PY-02` | `class` | CapWords (앞 밑줄 허용) | 차단 |
| `PY-03` | `def` · `async def` | snake_case (앞 밑줄 · dunder · unittest · `visit_X` 허용) | 차단 |
| `PY-04` | 매개변수 | snake_case — mixedCase 경고 | 경고 |
| `PY-05` | 대입 대상 | mixedCase 경고 (UPPER_SNAKE 상수 허용) | 경고 |
| `PY-06` | 예외 클래스 | `Error` 로 끝난다 | 경고 |

원본: [`references/python-naming-rules.md`](references/python-naming-rules.md)

## 사용

```bash
scripts/validate-python-naming.sh app             # 디렉터리
scripts/validate-python-naming.sh --all .         # 프로젝트 전체
test/validate-python-naming.test.sh               # 회귀 테스트
```

## 변경 이력

[`CHANGELOG.md`](CHANGELOG.md) 참조.
