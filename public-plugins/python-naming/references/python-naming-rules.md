# Python 네이밍 규칙 (단일 원본)

Python 코드의 **식별자 모양**을 정한다. 기계 검증은 [`scripts/validate-python-naming.sh`](../scripts/validate-python-naming.sh).

근거는 PEP 8 (Style Guide for Python Code) 의 "Naming Conventions" 절과, 그 절을 검사하는 flake8 플러그인 pep8-naming 의 `N8xx` 규칙이다.
기계는 PEP 8 이 **분명히 정한 것만** 막는다. 관례가 갈리거나 오탐 가능성이 있는 것은 경고하고, 단어를 고르는 일은 AI 가 판단한다 (4절).

## 1. 조항

| 조항 | 대상 | 규칙 | 판정 | pep8-naming |
|---|---|---|---|---|
| `PY-01` | 모듈 파일 이름 | 소문자 snake_case — `^[a-z_][a-z0-9_]*\.py$` (`order_service.py`, `__init__.py`). 하이픈은 `import` 할 수 없고 대문자는 관례 위반이다 | 차단 | (PEP 8 "Package and Module Names") |
| `PY-02` | `class` | CapWords — `OrderService`, `HTTPServer`. 앞 밑줄 허용 (`_Private`) | 차단 | `N801` |
| `PY-03` | `def` · `async def` | snake_case — `create_order`. 앞 밑줄 · dunder 허용 (`_helper`, `__init__`) | 차단 | `N802` |
| `PY-04` | 함수 · 메서드의 매개변수 | snake_case. 대소문자가 섞이면(`orderId`) 경고. 대문자만인 이름(`X`)은 보지 않는다 | 경고 | `N803` |
| `PY-05` | 대입문의 대상 이름 (`a = …` · `a: T = …` · `a, b = …` · `self.a = …`) | 대소문자가 섞인 mixedCase(`userName`)면 경고. UPPER_SNAKE 상수 · CapWords 별칭(`UserId = NewType(…)`)은 보지 않는다 | 경고 | `N806` · `N815` · `N816` |
| `PY-06` | 예외 클래스 (베이스 이름이 `Exception` · `Error` 로 끝나는 class) | 이름이 `Error` 로 끝난다 — `OrderNotFoundError` | 경고 | `N818` |

```python
# order_service.py                              # PY-01
MAX_RETRY_COUNT = 3                             # PY-05 (상수 허용)


class OrderNotFoundError(LookupError):          # PY-02 · PY-06
    pass


class OrderService:                             # PY-02
    def __init__(self, repository):
        self._repository = repository           # PY-05

    def cancel_order(self, order_id: int):      # PY-03 · PY-04
        is_paid = self._repository.is_paid(order_id)
```

### 예외 — 막지 않는 것

| 경우 | 이유 |
|---|---|
| unittest 의 `setUp` · `tearDown` · `setUpClass` · `tearDownClass` · `setUpModule` · `tearDownModule` · `asyncSetUp` · `asyncTearDown`, Django 의 `setUpTestData` | 프레임워크가 정한 이름이다 (pep8-naming 의 기본 `ignore-names`) |
| `ast.NodeVisitor` 의 `visit_X` (`visit_FunctionDef`) | 노드 클래스 이름을 그대로 붙이는 규약이다 |
| `http.server` 의 `do_GET` · `do_POST` | 표준 라이브러리가 메서드 이름으로 HTTP 메서드를 찾는다 |
| `@override` · `@typing.override` 가 붙은 `def` | 부모(외부 라이브러리)의 이름을 따라야 한다 — `paintEvent` |
| 줄 끝 `# noqa` (코드 없이) · `# noqa: N8xx` 가 있는 줄 | pep8-naming 과 같은 탈출구다. `# noqa: E501` 처럼 N8 코드가 없으면 건너뛰지 않는다 |
| `self` · `cls` | 첫 매개변수의 관례 이름이다 |
| 다른 객체의 속성 대입 — `request.userId = …` | 그 이름은 이 파일이 정하지 않는다 |
| 대문자만인 매개변수 — `X`, `y` (scikit-learn 관례) | PEP 8 이 금지하지 않고 분야 관례다 |
| `venv/` · `.venv/` · `site-packages/` · `__pycache__/` · `build/` · `dist/` · `.tox/` · `.eggs/` · `node_modules/` · `.git/` | 가상환경 · 생성물 · 의존성이다 |
| `migrations/` · `alembic/versions/` | 생성 코드이고 파일 이름이 숫자 · 해시로 시작한다 (`0001_initial.py`) |

주석 · 문자열 리터럴 · 삼중 따옴표 docstring 안의 단어는 코드로 읽지 않는다.
여러 줄에 걸친 시그니처 `def f(\n    a,\n    b,\n):` 는 괄호가 닫힐 때까지 모아 본다. 괄호 안에서 이어지는 줄(호출의 `key=value` 인자, 딕셔너리)은 대입문으로 보지 않는다.

### PEP 8 이 허용하지만 기계가 막는 것

PEP 8 은 "주로 호출 가능한 것으로 문서화 · 사용되는 클래스" 는 함수 이름 규칙(소문자)을 따라도 된다고 한다 (`class cached_property:` 처럼 내장 이름을 흉내 내는 경우). 기계는 이 의도를 모르므로 `PY-02` 로 막는다. 그 경우는 그 줄에 `# noqa: N801` 을 붙인다.

외부 라이브러리의 camelCase 메서드를 `@override` 없이 재정의하는 경우(`keyPressEvent`)도 같다 — `@override` 를 붙이거나 `# noqa: N802` 를 붙인다.

## 2. 새로 생긴 위반만 막는다

훅은 편집 **전** 파일과 편집 **뒤** 내용을 둘 다 검사해 **늘어난 위반만** 막는다.

- `Write` — `content` 가 편집 뒤 내용이다. 파일이 이미 있으면 그 내용과 비교한다
- `Edit` — 현재 파일에 `old_string` → `new_string` 치환을 적용해 편집 뒤 내용을 만든다

레거시 파일의 다른 줄을 고치다가 기존 이름 때문에 막히지 않는다. 이미 있는 `orderService.py` 를 고칠 때도 `PY-01` 로 막지 않는다 (편집 전에도 있던 위반이다). 기존 위반을 고치고 싶으면 CLI 로 찾는다 (5절).

## 3. 차단과 경고

| | 훅 | CLI |
|---|---|---|
| 차단 조항 | 종료 코드 `2` + stderr — Claude 가 제안한 이름으로 다시 쓴다 | `❌` + 종료 코드 `2` |
| 경고 조항 | `additionalContext` 로 알린다 | `⚠️` + 종료 코드 `0` |

`PY-04` · `PY-05` 가 경고인 이유 — 외부 API(JSON 필드, ORM 컬럼, 프레임워크 콜백)의 이름을 그대로 받는 매개변수 · 변수가 흔하고, 문법 없이 대입 대상을 가려내면 오탐이 난다.
`PY-06` 이 경고인 이유 — PEP 8 은 "예외가 오류라면" `Error` 접미사를 쓰라고 한다. 흐름 제어용 예외(`StopProcessing`)는 오류가 아니다.

## 4. 기계가 판정할 것 / AI 가 판단할 것

| | 담당 | 무엇을 |
|---|---|---|
| 정량 | `validate-python-naming.sh` | `PY-01` ~ `PY-06` — 모양 |
| 판단 | AI (`python-name-create` 스킬) | 이름이 무엇을 가리키는지 말하는가, 단어 선택, 줄임말, 밑줄 접두사의 뜻, 내장 이름 가리기, boolean · 컬렉션 이름, TypeVar |

AI 가 판단할 것:

1. **이름만 보고 무엇인지 말할 수 있는가.** `process()`, `data`, `info`, `manager`, `utils.py` 는 무엇을 다루는지 말하지 않는다
2. **줄임말을 쓰지 않았는가.** `cnt` → `count`, `usr` → `user`. 업계 표준 약어(`id`, `url`, `http`, `api`)와 관용 이름(`i`, `df`, `np`)만
3. **밑줄 접두사가 공개 범위와 맞는가.** `_name` 은 모듈 · 클래스 내부용 (from … import * 에서 빠진다). `__name` 은 서브클래스와 충돌을 피하려는 이름 맹글링일 때만 — 단순히 "private" 이라는 뜻으로 쓰지 않는다. `__name__` 형태는 새로 만들지 않는다
4. **내장 이름을 가리지 않는가.** `list`, `dict`, `id`, `type`, `input`, `filter`, `format`, `hash` 를 변수 · 매개변수로 쓰지 않는다 — 더 구체적인 이름(`order_ids`)이 먼저고, 꼭 그 이름이어야 하면 뒤 밑줄(`id_`, `type_`)
5. **boolean 은 참/거짓으로 읽히는가.** `is_active`, `has_items`, `can_cancel` — `flag`, `status` X. 부정형(`is_not_valid`) 피하기
6. **컬렉션은 복수형인가.** `orders`, `order_ids_by_user` — `order_list` 보다 `orders`
7. **함수는 동사로 시작하는가.** `cancel_order`, `find_by_email`, `to_dict`. 프로퍼티는 명사 (`@property def total`)
8. **TypeVar 는 짧은 CapWords.** `T`, `KT`, `VT`, `AnyStr`. 공변 · 반공변은 `T_co` · `T_contra`
9. **같은 개념에 같은 단어를 쓰는가.** 한 코드베이스에서 `fetch` · `get` · `retrieve` 를 섞지 않는다
10. **모듈 · 패키지 이름은 짧게.** 패키지 디렉터리는 밑줄 없이 쓸 수 있으면 그렇게 (`orderservice` 보다 `orders`)

## 5. 검증

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-python-naming.sh" app/orders/service.py   # 파일
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-python-naming.sh" app                     # 디렉터리
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-python-naming.sh" --all .                 # 프로젝트 전체
```

종료 코드 `2` 가 위반이다. 경고만 있으면 `0` 이다.
