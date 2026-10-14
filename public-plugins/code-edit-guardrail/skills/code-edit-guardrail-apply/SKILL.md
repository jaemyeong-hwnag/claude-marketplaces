---
name: code-edit-guardrail-apply
description: 프로젝트에 코드 편집 가드레일 설정(.claude/code-edit-guardrail.json)을 처음 쓰거나 고칠 때 사용한다. 스택을 감지해 코드 · 테스트 글롭과 품질 lane 명령을 채우고, 공유자원은 후보만 내 사용자가 확정한다. 트리거 — "테스트 없이 못 끝내게", "끝날 때 린트 돌려", "마이그레이션 고치면 물어봐", "가드레일 설정".
---

# 코드 편집 가드레일 설정

규칙 원본: [`references/code-edit-guardrail-rules.md`](../../references/code-edit-guardrail-rules.md) — 설정 형식 · 글롭 · 조항

## 1. 스택을 감지한다

루트와 한 단계 아래 디렉터리에서 마커를 찾는다. 스택이 둘 이상이면(루트 Kotlin + `web/` TypeScript) 스택마다 lane 을 하나씩 둔다.

| 마커 | 코드 | 테스트 | 품질 명령 후보 (있는 것만) |
|---|---|---|---|
| `build.gradle(.kts)` · `pom.xml` | `src/main/**` | `src/test/` | `./gradlew ktlintCheck` · `spotlessCheck` · `checkstyleMain` · `mvn -q spotless:check` |
| `package.json` | `src/**/*.ts` · `src/**/*.tsx` … 확장자마다 따로 | `**/*.test.*` · `**/*.spec.*` · `__tests__/` | `npm run lint` · `npx tsc --noEmit` · `npx prettier --check` |
| `pyproject.toml` · `setup.cfg` | 패키지 디렉터리 `**/*.py` | `tests/` · `test_*.py` · `*_test.py` | `ruff check` · `ruff format --check` · `mypy` |
| `go.mod` | `*.go` | `*_test.go` | `gofmt -l . \| (! grep .)` · `go vet ./...` · `golangci-lint run` |
| `Cargo.toml` | `src/**/*.rs` | `tests/` | `cargo fmt --check` · `cargo clippy -- -D warnings` |

- 명령은 **설정 파일 · 스크립트에 실제로 있는 것**만 쓴다. `package.json` 의 `scripts` · Gradle 플러그인 · `pyproject` 의 도구 절을 읽고 고른다. 없는 도구를 지어내지 않는다
- 테스트 디렉터리가 코드 디렉터리 안에 섞여 있으면 테스트 글롭이 이긴다 (규칙 1절) — `code` 에 `!` 를 따로 쓰지 않아도 된다
- 생성 코드 · 빌드 산출물(`generated/` · `build/` · `dist/`)은 `code` 에서 `!` 로 뺀다
- Rust 처럼 테스트가 같은 파일에 있는 스택은 `tests/` 만 테스트로 잡힌다. 사용자에게 알리고 면제로 다룬다

## 2. 품질 lane 을 고른다

Stop 마다 돈다. **빠르고 결정적인** 명령만 넣는다.

- 린트 · 포맷 검사 · 타입 검사 — 넣는다
- 전체 테스트 · 전체 빌드 · 네트워크가 필요한 것 — 넣지 않는다. 600초 제한에 걸리고 매번 느리다
- 고치는 명령(`--fix` · `format`)이 아니라 검사 명령(`--check`)을 쓴다. Claude 가 결과를 보고 고친다
- 명령을 한 번 직접 돌려 지금 통과하는지 본다. 이미 실패하는 명령은 넣기 전에 사용자에게 알린다 — 모든 요청이 막힌다

## 3. 공유자원 후보를 낸다 — 확정은 사용자

다른 팀 · 서비스 · 배포가 같이 쓰는 자원이다. 오탐이면 매 편집마다 확인 창이 뜨므로 **스스로 확정하지 않는다.**

| 찾을 곳 | 후보 |
|---|---|
| DB 마이그레이션 | `db/migration/` · `migrations/` · `alembic/versions/` · `prisma/schema.prisma` |
| 서비스 간 계약 | `*.proto` · `openapi*.yaml` · `*.graphql` · `*.avsc` |
| 배포 · 인프라 | `.github/workflows/` · `Dockerfile` · `k8s/` · `*.tf` · `helm/` |
| 공용 모듈 | 여러 모듈이 의존하는 `common/` · `shared/` (빌드 설정의 의존 관계로 확인) |
| 내용 패턴 | `DROP[[:space:]]+TABLE` · `ALTER[[:space:]]+TABLE` 같은 파괴적 변경 |

후보를 표로 보여주고 사용자가 고른 것만 넣는다. 아무것도 고르지 않으면 `shared` 를 빼고 그렇게 알린다.

## 4. 쓰고 검증한다

1. `.claude/code-edit-guardrail.json` 을 쓴다. 이미 있으면 덮지 않고 바뀌는 절만 보여주고 고친다
2. 검증한다 — 종료 코드 0 이어야 끝이다. `C-05` 경고(걸리는 파일이 없는 글롭)는 오타인지 본다

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/code-edit-guardrail.sh" validate .
   ```

3. 설정을 커밋하라고 알린다. 팀 전체가 같은 선을 쓴다

## 하지 않을 것

- 공유자원을 사용자 확인 없이 넣지 않는다
- 품질 lane 에 전체 테스트 · 빌드를 넣지 않는다
- 훅에 막혔을 때 설정을 넓혀서(글롭 삭제 · lane 삭제) 통과시키지 않는다 — 테스트를 쓰거나, 사용자에게 알리고 면제한다
