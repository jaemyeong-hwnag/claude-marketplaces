# Python 레시피

선행 조건 공통: `pyproject.toml` / `setup.py` / `requirements.txt` 중 하나가 존재할 것.
패키지 매니저는 `uv.lock` → uv, `poetry.lock` → poetry, `Pipfile.lock` → pipenv, 그 외 pip 순으로 감지한다.

> **레이아웃 확인이 먼저다.** 아래 레시피는 표준 src 레이아웃(`src/<패키지명>/…`)을 전제한다.
> `src/module.py` 처럼 패키지 디렉터리 없이 모듈이 흩어져 있으면 mypy·pytest·mutmut 이 **전부 실패한다.**
> ```bash
> ls src/*/__init__.py 2>/dev/null || echo "표준 레이아웃 아님 — 아래 경로 설정을 프로젝트에 맞게 조정할 것"
> ```

---

## Ruff — 린트 + 포맷

- **메우는 항목**: `code.lint-ci` 린터·포매터 CI 강제
- **설치**: `uv add --dev ruff` (또는 `pip install ruff`)
- **설정** — `pyproject.toml`:
  ```toml
  [tool.ruff]
  line-length = 100
  target-version = "py311"
  exclude = ["build", "dist", ".venv", "migrations"]

  [tool.ruff.lint]
  # E,F=pycodestyle/pyflakes  I=isort  UP=pyupgrade  B=bugbear  SIM=simplify
  select = ["E", "F", "I", "UP", "B", "SIM"]
  ignore = ["E501"]   # 포매터가 줄 길이를 처리한다
  ```
- **검증**: `ruff check .` — 에러가 많으면 `ruff check . --statistics` 로 규칙별 분포를 보고 `select` 를 좁힌다
- **CI**: `- run: ruff check .` / `- run: ruff format --check .`
- **롤백**: `[tool.ruff]` 블록 삭제

---

## mypy — 타입 체크

- **메우는 항목**: `code.type-strict` strict 타입 통과
- **설치**: `uv add --dev mypy`
- **설정** — `pyproject.toml`:
  ```toml
  [tool.mypy]
  python_version = "3.11"
  strict = true
  warn_unreachable = true
  exclude = ["build/", "dist/", "tests/fixtures/"]
  # 이 줄이 없으면 src 레이아웃에서 "Source file found twice under different module names"
  # 로 즉시 실패하고 타입 검사가 아예 수행되지 않는다.
  explicit_package_bases = true

  # 타입 스텁이 없는 서드파티는 개별 면제
  [[tool.mypy.overrides]]
  module = ["some_untyped_lib.*"]
  ignore_missing_imports = true
  ```
- **검증**: `mypy .` → 모듈 매핑 오류 없이 타입 에러만 보고되면 성공
- **CI**: `- run: mypy .`
- **롤백**: `[tool.mypy]` 블록 삭제
- ⚠️ `mypy_path` 를 함께 지정하지 마라. `src` 를 mypy_path 에 넣으면 같은 파일이
  `calc` 와 `src.calc` 로 이중 인식되어 오히려 실패한다.
- **비고**: 기존 프로젝트에서 `strict = true` 는 에러가 폭발한다.
  `strict = false` + `disallow_untyped_defs = true` 부터 시작해 순차 강화한다.

---

## Bandit — 보안 정적 분석

- **메우는 항목**: `security.sast` SAST
- **설치**: `uv add --dev bandit`
- **설정** — `pyproject.toml`:
  ```toml
  [tool.bandit]
  exclude_dirs = ["tests", ".venv", "build"]
  skips = ["B101"]   # assert 사용 — 테스트 코드에서 정상
  ```
- **검증**: `bandit -c pyproject.toml -r .`
- **CI**: `- run: bandit -c pyproject.toml -r . -ll` (`-ll` = MEDIUM 이상만)
- **롤백**: `[tool.bandit]` 블록 삭제
- **비고**: Semgrep 을 이미 쓴다면 중복이다. 둘 중 하나만 쓴다.

---

## pytest + 커버리지

- **메우는 항목**: `test.unit-coverage` 커버리지
- **설치**: `uv add --dev pytest pytest-cov`
- **설정** — `pyproject.toml`:
  ```toml
  [tool.pytest.ini_options]
  testpaths = ["tests"]
  # 이 줄이 없으면 tests 에서 프로젝트 모듈을 import 할 때 ModuleNotFoundError 가 난다.
  # src 레이아웃이면 ["src"], 플랫 레이아웃이면 ["."].
  pythonpath = ["src"]
  addopts = "-q --strict-markers"

  [tool.coverage.run]
  source = ["src"]
  branch = true
  omit = ["*/migrations/*", "*/tests/*"]

  [tool.coverage.report]
  show_missing = true
  # 현재 값으로 시작해 점진 상향. 임의의 80 을 넣으면 항상 실패한다.
  fail_under = 0
  ```
- **검증**: `pytest --cov --cov-report=term --cov-report=xml` → 현재 % 를 `fail_under` 에 반영
- **CI**: `- run: pytest --cov --cov-report=xml` + Codecov 업로드
- **롤백**: coverage 블록 삭제

---

## mutmut — 뮤테이션 테스트

- **메우는 항목**: `test.mutation-score` 뮤테이션 스코어
- **선행 조건**: 동작하는 pytest 스위트 **+ 표준 src 레이아웃**(`src/<패키지>/__init__.py` 존재).
  mutmut 3.x 는 모듈 경로가 `src.` 로 시작하면 `Failed trampoline hit` 로 거부한다.
- **설치**: `uv add --dev mutmut`
- **설정** — `pyproject.toml`:
  ```toml
  [tool.mutmut]
  # 3.x 는 리스트를 요구한다. 문자열을 주면 TypeError 로 죽는다.
  # paths_to_mutate 는 deprecated — source_paths 를 쓴다.
  source_paths = ["src/mypkg"]
  tests_dir = ["tests/"]
  ```
- **검증**: `mutmut run` → `mutmut results`
  ```
  8/8  🎉 1  🫥 7      # killed 1, no-tests 7
  ```
- **CI**: 전체 실행은 느리다. **야간 스케줄(`schedule: cron`)로 분리**하고 PR 에서는 돌리지 않는다.
- **롤백**: `[tool.mutmut]` 블록과 `mutants/` 삭제
- **gitignore 추가**: `mutants/` — 3.x 는 `.mutmut-cache` 가 아니라 `mutants/` 디렉터리를 만든다.
  빠뜨리면 pre-commit 의 `end-of-file-fixer` 가 생성 파일을 건드려 실패한다.
- **게이트**: 🟢 리포트만

## Schemathesis — API 속성 기반 테스트

- **메우는 항목**: `test.contract-test` 계약/스펙 검증
- **선행 조건**: OpenAPI 스펙 + 실행 가능한 서버
- **설치**: `uv add --dev schemathesis`
- **검증**: `st run openapi.yaml --checks all --base-url <앱 주소>`
- **CI**:
  ```yaml
  - run: |
      uvicorn app.main:app --port 8000 &
      npx wait-on tcp:8000
      st run openapi.yaml --checks all --base-url "$BASE_URL" --max-failures 5   # BASE_URL = 8000 포트 앱 주소
  ```
- **롤백**: CI step 과 의존성 제거
- **비고**: 처음 돌리면 500 에러가 무더기로 나온다. `--max-failures` 로 제한하고 하나씩 정리한다.

---

## pre-commit — 로컬 훅

- **메우는 항목**: `security.secret-scan` pre-commit 시크릿 스캔, `code.lint-ci`
- **설치**: `uv add --dev pre-commit` → `pre-commit install`
- **설정** — `.pre-commit-config.yaml`:
  ```yaml
  repos:
    - repo: local                  # 프로젝트 의존성의 ruff · 로컬 gitleaks 를 쓴다
      hooks:
        - id: ruff
          name: ruff
          entry: uv run ruff check --fix
          language: system
          types: [python]
        - id: ruff-format
          name: ruff-format
          entry: uv run ruff format
          language: system
          types: [python]
        - id: gitleaks
          name: gitleaks
          entry: gitleaks protect --staged --redact --no-banner
          language: system
          pass_filenames: false
  ```
- **검증**: `pre-commit run --all-files`
- **CI**: `- uses: pre-commit/action@v3.0.1`
- **롤백**: `pre-commit uninstall` + 설정 파일 삭제
- **비고**: 원격 훅 저장소(`ruff-pre-commit` · `pre-commit-hooks`)를 쓰면 `rev` 를 설치 시점 최신 태그로 갱신한다 — `pre-commit autoupdate`.
