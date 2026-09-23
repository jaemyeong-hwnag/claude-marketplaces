#!/usr/bin/env bash
# project-completeness — 결정적 판정은 여기서, 판단은 스킬이 한다.
#
#   detect [디렉터리]                              저장소 흔적으로 항목 판정 (JSON)
#   scope  [--type T] [--na id,…]                  측정할 수 있는 항목 목록
#   score  --type T --pass id,… [--na id,…]         위험도 · 실천 범위 채점
#   health [지표=값 …]                              서비스 건강도 판정 (인자 없으면 지표 목록)
#   recipe <항목 id | 레시피 이름> | --list          도입 레시피 조회
#
# 종료 코드: 0 정상 · 2 잘못된 입력
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="$ROOT_DIR/references"
CHECKLIST="$REF/completeness-checklist.json"
METRICS="$REF/service-health-metrics.json"

die() { echo "project-completeness: $*" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다"

# 쉼표 목록 → JSON 배열
csv_json() { jq -cn --arg s "${1:-}" '$s | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))'; }

# 체크리스트에 없는 id 가 있으면 멈춘다 — 오타가 조용히 미통과로 세어지지 않게
check_ids() { # $1=JSON 배열 $2=옵션 이름
  local bad
  bad="$(jq -r --argjson ids "$1" '[.categories[].items[].id] as $all | $ids - $all | join(", ")' "$CHECKLIST")"
  [ -z "$bad" ] || die "$2 에 모르는 항목 id: $bad (scope 로 id 를 확인하세요)"
}

type_na() { # $1=projectType → JSON 배열
  [ -n "$1" ] || { echo '[]'; return; }
  jq -e --arg t "$1" '.projectTypes | has($t)' "$CHECKLIST" >/dev/null ||
    die "모르는 projectType: $1 ($(jq -r '.projectTypes | keys | join(" · ")' "$CHECKLIST"))"
  jq -c --arg t "$1" '.projectTypes[$t].na' "$CHECKLIST"
}

# ---- detect ----------------------------------------------------------------
cmd_detect() {
  local root="${1:-.}"
  [ -d "$root" ] || die "디렉터리가 아닙니다: $root"
  root="$(cd "$root" && pwd)"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  # 파일 인덱스 — 한 번만 훑는다
  ( cd "$root" && find . -maxdepth 14 \
      \( -name node_modules -o -name .git -o -name dist -o -name build -o -name .next -o -name vendor \
         -o -name target -o -name .venv -o -name venv -o -name __pycache__ -o -name coverage \
         -o -name .gradle -o -name .idea -o -name out -o -name .claude -o -name .worktrees \) -prune -o -type f -print 2>/dev/null ) |
    sed 's|^\./||' | grep -Ev '\.(class|jar|pyc|o|so|dylib|png|jpe?g|gif|webp|ico|woff2?|ttf|mp4|zip|gz)$' > "$tmp/files"
  [ -s "$tmp/files" ] || die "파일이 없습니다: $root"

  has()  { grep -Eq "$1" "$tmp/files"; }
  list() { grep -E "$1" "$tmp/files"; }
  cat_list() { while IFS= read -r f; do cat "$root/$f" 2>/dev/null; echo; done; }

  list '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^Jenkinsfile$|^\.circleci/config\.ya?ml$' | cat_list > "$tmp/ci"
  local ci_count; ci_count="$(list '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$|^Jenkinsfile$|^\.circleci/config\.ya?ml$' | wc -l | tr -d ' ')"
  in_ci() { grep -Eqi "$1" "$tmp/ci"; }

  # 매니페스트 — 의존성 이름이 나오는 곳만
  : > "$tmp/deps"; : > "$tmp/rundeps"; : > "$tmp/scripts"
  if [ -f "$root/package.json" ]; then
    jq -r '(.dependencies // {}) | keys[]' "$root/package.json" 2>/dev/null >> "$tmp/rundeps"
    jq -r '(.scripts // {})[]' "$root/package.json" 2>/dev/null > "$tmp/scripts"
  fi
  # 도구 의존성은 하위 모듈 · 패키지에도 있다 (멀티 모듈 · 모노레포)
  local f
  while IFS= read -r f; do
    case "$f" in
      *package.json) jq -r '((.dependencies // {}) + (.devDependencies // {})) | keys[]' "$root/$f" 2>/dev/null >> "$tmp/deps" ;;
      *) cat "$root/$f" >> "$tmp/deps" ;;
    esac
  done < <(list '(^|/)(package\.json|pyproject\.toml|requirements[^/]*\.txt|go\.mod|build\.gradle(\.kts)?|pom\.xml|Cargo\.toml|libs\.versions\.toml)$' | head -60)
  # 런타임 의존성 — 테스트용 서버 · UI 가 프로젝트 성격을 바꾸지 않게
  [ -f "$root/pyproject.toml" ] && awk '/^\[project\]/{p=1} /^\[/{if($0!="[project]")p=0} p' "$root/pyproject.toml" >> "$tmp/rundeps"
  [ -f "$root/requirements.txt" ] && cat "$root/requirements.txt" >> "$tmp/rundeps"
  [ -f "$root/go.mod" ] && cat "$root/go.mod" >> "$tmp/rundeps"
  while IFS= read -r f; do   # JVM 은 하위 모듈에 서버 의존성이 있다
    case "$f" in
      *pom.xml) cat "$root/$f" >> "$tmp/rundeps" ;;
      *) grep -Ev '^\s*(test|androidTest|testFixtures)[A-Za-z]*[ (]' "$root/$f" >> "$tmp/rundeps" ;;
    esac
  done < <(list '(^|/)(build\.gradle(\.kts)?|pom\.xml)$' | grep -Eiv '(^|/)[^/]*(example|sample|demo)[^/]*/' | head -60)
  dep()    { grep -Eqi "$1" "$tmp/deps"; }
  rundep() { grep -Eqi "$1" "$tmp/rundeps"; }

  local precommit=""; [ -f "$root/.pre-commit-config.yaml" ] && precommit="$(cat "$root/.pre-commit-config.yaml")"
  local golangci=""; for f in .golangci.yml .golangci.yaml; do [ -f "$root/$f" ] && golangci="$golangci$(cat "$root/$f")"; done
  local gradle=""; for f in build.gradle build.gradle.kts; do [ -f "$root/$f" ] && gradle="$gradle$(cat "$root/$f")"; done

  # 소스 — 테스트 · 데이터 · 픽스처는 소스가 아니다 (패턴이 데이터로 들어 있으면 오탐이 된다)
  local data_re='(^|/)(fixtures?|__fixtures__|mocks?|__mocks__|testdata|seed)(/|$)|(^|/)[^/]*(example|sample|demo)[^/]*/'
  local test_re='(\.(test|spec)\.[a-z]+$)|(_test\.(go|py|rb)$)|(^|/)(tests?|__tests__|spec|e2e)/|(^|/)test_[^/]+\.py$|(Test|IT|Tests)\.(java|kt)$|(^|/)src/test/'
  list '\.(ts|tsx|js|jsx|mjs|cjs|py|go|rb|java|kt|rs|php|vue|svelte)$' | grep -Ev "$test_re" | grep -Eiv "$data_re" | head -400 > "$tmp/src"
  list "$test_re" > "$tmp/tests"
  local src_count src_bytes=0
  src_count="$(wc -l < "$tmp/src" | tr -d ' ')"
  [ "$src_count" -gt 0 ] && src_bytes="$( (cd "$root" && tr '\n' '\0' < "$tmp/src" | xargs -0 cat 2>/dev/null) | wc -c | tr -d ' ')"
  local src_enough=0; [ "$src_count" -ge 3 ] && [ "$src_bytes" -gt 2000 ] && src_enough=1
  in_files() { # $1=목록 파일 $2=패턴 → 0 있음 · 1 없음
    (cd "$root" && tr '\n' '\0' < "$1" | xargs -0 grep -Eil -- "$2" 2>/dev/null | head -1 | grep -q .)
  }

  : > "$tmp/out"
  put()  { printf '%s\x1f%s\x1f%s\n' "$1" "$2" "$3" >> "$tmp/out"; }   # id · pass|fail|unknown · 근거
  judge() { if "${@:3}"; then put "$1" pass "$2"; else put "$1" fail "$2"; fi; }
  hint() { # $1=id $2=무엇 $3=패턴 [$4=목록 파일]
    local lst="${4:-$tmp/src}"
    if [ "$lst" = "$tmp/src" ] && [ "$src_enough" -eq 0 ]; then put "$1" unknown "소스가 적어 흔적을 볼 수 없음 — $2"; return; fi
    if in_files "$lst" "$3"; then put "$1" hint "흔적 있음: $2"; else put "$1" hint "흔적 없음: $2"; fi
  }

  # code
  local linters='\b(lint|eslint|ruff|golangci|biome|oxlint|gofmt|clippy|xo|flake8|pylint|standard|checkstyle|spotless|ktlint|detekt|pmd)\b'
  local l_ci=false l_pc=false l_sc=false
  in_ci "$linters" && l_ci=true
  printf '%s' "$precommit" | grep -Eq "$linters" && l_pc=true
  grep -Eq "$linters" "$tmp/scripts" && in_ci 'npm (run )?(lint|test|ci)|pnpm|yarn|nox|tox|make|gradlew?|mvnw?' && l_sc=true
  judge code.lint-ci "CI=$l_ci pre-commit=$l_pc script=$l_sc" \
    test "$l_ci" = true -o "$l_pc" = true -o "$l_sc" = true

  local ts="" ts_ext="" ts_strict=false
  [ -f "$root/tsconfig.json" ] && ts="$(cat "$root/tsconfig.json")"
  ts_ext="$(printf '%s' "$ts" | sed -nE 's/.*"extends"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' | head -1)"
  if printf '%s' "$ts" | grep -Eq '"strict"[[:space:]]*:[[:space:]]*true'; then ts_strict=true
  elif printf '%s' "$ts_ext" | grep -Eiq 'strict|sindresorhus|tsconfig/node|@total-typescript' &&
       ! printf '%s' "$ts" | grep -Eq '"strict"[[:space:]]*:[[:space:]]*false'; then ts_strict=true; fi
  local py_strict=false go_strict=false jvm_strict=false
  [ -f "$root/pyproject.toml" ] && grep -Eq 'strict[[:space:]]*=[[:space:]]*true' "$root/pyproject.toml" && py_strict=true
  printf '%s' "$golangci" | grep -Eq 'staticcheck|govet' && go_strict=true
  printf '%s' "$gradle" | grep -Eq -- '-Werror|allWarningsAsErrors' && jvm_strict=true
  judge code.type-strict "ts=$ts_strict${ts_ext:+ (extends $ts_ext)} mypy=$py_strict golangci=$go_strict jvm=$jvm_strict" \
    test "$ts_strict" = true -o "$py_strict" = true -o "$go_strict" = true -o "$jvm_strict" = true

  local gate=false
  while IFS= read -r f; do
    grep -Eq 'pull_request|merge_request' "$root/$f" 2>/dev/null &&
      ! grep -Eq 'continue-on-error:[[:space:]]*true|allow_failure:[[:space:]]*true' "$root/$f" && gate=true
  done < <(list '^\.github/workflows/.*\.ya?ml$|^\.gitlab-ci\.yml$')
  judge code.quality-gate "PR 트리거 · 실패 허용 없음 = $gate (CI ${ci_count}개)" test "$gate" = true
  judge code.codeowners "$(list '(^|/)CODEOWNERS$' | head -1)" has '(^|/)CODEOWNERS$'
  put code.ai-provenance unknown "커밋 트레일러 · CONTRIBUTING 의 AI 정책 — git log 로 확인"
  judge code.architecture-boundary "dependency-cruiser · import-linter · ArchUnit · depguard" \
    eval 'dep "dependency-cruiser|import-linter|archunit" || printf "%s" "$golangci" | grep -q depguard'
  judge code.adr "$(list '(^|/)(adr|ADR|decisions)/' | head -1)" has '(^|/)(adr|ADR|decisions)/'

  # test
  judge test.e2e-flow "e2e · 통합 테스트 디렉터리 또는 Playwright · Cypress" \
    eval 'has "(^|/)(e2e|integration|it)/|\\.e2e\\.|(IT|IntegrationTest)\\.(java|kt)$" || dep "@playwright/test|cypress|selenium"'
  judge test.integration-real-db "Testcontainers 또는 CI service 컨테이너" \
    eval 'dep testcontainers || in_ci "services:|postgres:|mysql:|redis:"'
  judge test.contract-test "Pact · Spring Cloud Contract · Schemathesis" \
    eval 'dep "pact|spring-cloud-contract|schemathesis" || has "(^|/)pacts?/"'
  judge test.visual-regression "Chromatic · Percy · Argos · reg-suit · toHaveScreenshot" \
    eval 'dep "chromatic|percy|argos|reg-suit|backstop" || in_files "$tmp/tests" toHaveScreenshot'

  # security
  local sc_pc=false sc_ci=false
  printf '%s' "$precommit" | grep -Eq 'gitleaks|trufflehog|detect-secrets' && sc_pc=true
  in_ci 'gitleaks|trufflehog|detect-secrets' && sc_ci=true
  judge security.secret-scan "pre-commit=$sc_pc CI=$sc_ci" test "$sc_pc" = true -a "$sc_ci" = true
  judge security.sast "CI 에 semgrep · codeql · bandit · gosec · spotbugs" \
    eval 'in_ci "semgrep|codeql|bandit|gosec|spotbugs" || printf "%s" "$golangci" | grep -q gosec'
  local sca=false sbom=false
  in_ci 'trivy|osv-scanner|snyk|dependency-check|govulncheck|pip-audit|npm audit' && sca=true
  in_ci 'sbom|syft|cyclonedx' && sbom=true
  judge security.sca-sbom "SCA=$sca SBOM=$sbom" test "$sca" = true -a "$sbom" = true
  judge security.dependency-update "Dependabot · Renovate 설정" \
    has '^\.github/dependabot\.ya?ml$|^(\.github/)?renovate\.json5?$|^\.renovaterc'
  if has '\.tf$|(^|/)Dockerfile|(^|/)(k8s|kubernetes|helm|charts)/'; then
    judge security.iac-scan "IaC 있음 — CI 에 checkov · tfsec · kics · trivy config" in_ci 'checkov|tfsec|kics|trivy config|hadolint'
  else
    put security.iac-scan unknown "IaC 파일이 없다 — 구조적으로 없으면 N/A 로 선언"
  fi

  # perf
  judge perf.web-vitals "web-vitals · RUM SDK" dep 'web-vitals|speed-insights|@sentry/(browser|react|nextjs|vue)'
  judge perf.lighthouse-budget "lighthouserc + CI lhci" eval 'has "(^|/)lighthouserc|(^|/)\\.lighthouserc" && in_ci "lhci|lighthouse"'
  judge perf.bundle-budget "size-limit · bundlewatch + CI" \
    eval '{ dep "size-limit|bundlewatch|bundlesize" || has "^\\.size-limit"; } && in_ci "size-limit|bundlewatch|bundlesize"'
  judge perf.load-test "k6 · Gatling · Locust · JMeter 스크립트" \
    eval 'has "locustfile\\.py$|(^|/)gatling|\\.jmx$" || list "(perf|load-?test|k6)" | grep -Eq "\\.(js|ts)$"'

  # ux
  local both="$tmp/both"; cat "$tmp/src" "$tmp/tests" > "$both"
  hint ux.wcag22 "axe 태그 wcag22aa · wcag21aa" 'wcag22aa|wcag21aa' "$both"
  hint ux.rage-click "Clarity · Hotjar · LogRocket · FullStory" 'clarity\.ms|hotjar|logrocket|fullstory'

  # ops
  judge ops.tracing "OpenTelemetry 의존성" dep 'opentelemetry'
  judge ops.slo "SLO 정의 파일 (openslo · sloth)" has '(openslo|sloth|slo)\.ya?ml$|(^|/)slos?/'
  judge ops.oncall-runbook "런북 · alertmanager" eval 'grep -Eiq "runbook|alertmanager|oncall|on-call" "$tmp/files"'
  judge ops.synthetic-monitoring "Checkly · 합성 모니터링" eval 'dep checkly || has "(^|/)__checks__/"'
  judge ops.rollback "피처 플래그 SDK 또는 롤백 워크플로" \
    eval 'dep "growthbook|unleash|launchdarkly|flagsmith|statsig|openfeature|togglz|ff4j" || in_ci rollback'
  judge ops.postmortem "포스트모템 기록" eval 'grep -Eiq "post-?mortem|incident-review" "$tmp/files"'

  # service — 저장소 밖에 있을 수 있는 것은 흔적만 낸다 (판정이 아니다)
  hint service.payment-failure "결제 실패 · 환불 · 해지 경로" 'refund|환불|cancel_?subscription|payment_?failed|card_?expired|past_due'
  hint service.empty-state "빈 상태 처리" 'EmptyState|empty-state|emptyState|no-?results|데이터가 없'
  hint service.error-state "에러 상태 처리" 'ErrorBoundary|error-boundary|ErrorState|다시 시도|onError'
  hint service.loading-timeout "로딩 · 타임아웃" 'isLoading|Skeleton|Spinner|AbortController'
  hint service.auth-session-offline "권한 · 세션 · 오프라인 구분" "session_?expired|navigator\.onLine|['\"]403['\"]|Forbidden"
  if has '^(admin|backoffice|back-office|apps/admin|packages/admin)/'; then
    put service.admin-tool hint "흔적 있음: 운영 도구 디렉터리 — DB 직접 조작 없이 처리되는지 확인"
  else
    put service.admin-tool hint "흔적 없음: 운영 도구 디렉터리 — 별도 저장소일 수 있다"
  fi
  hint service.audit-log "감사 로그" 'audit_?log|auditLog|audit_?trail|actor_?id'
  hint service.data-deletion "데이터 삭제 · 내보내기" 'data_?export|delete_?account|deleteAccount|gdpr'
  hint service.support-channel "문의 경로" 'helpdesk|intercom|zendesk|channel\.io|support@|문의'
  if grep -Eiq 'terms|privacy|약관|개인정보' "$tmp/files"; then
    put service.terms-privacy hint "흔적 있음: 약관 · 처리방침 문서 — 현재 기능과 일치하는지는 확인"
  else
    put service.terms-privacy hint "흔적 없음: 약관 · 처리방침 문서"
  fi
  hint service.delivery-rate "전달 도달률" 'bounce|deliverability|sendgrid|postmark|\bses\b'
  hint service.screenshot-diff "스크린샷 비교" 'toHaveScreenshot|matchImageSnapshot|chromatic|percy' "$both"

  # product
  hint product.funnel-retention "제품 분석 SDK (수치는 질문)" 'posthog|amplitude|mixpanel|gtag\(|firebase/analytics'
  hint product.experiment "실험 · 플래그 SDK" 'growthbook|unleash|launchdarkly|statsig|optimizely'
  if in_ci 'four-?keys|sleuth|linearb|deployment.*event'; then put product.dora-collect pass "CI 에 DORA 수집"
  else put product.dora-collect unknown "CI 에 DORA 수집 흔적 없음 — 외부 도구일 수 있다"; fi

  # 프로젝트 성격
  local ptype="" why=()
  local mono=false ui=false server=false bin=false lib=false
  { [ -f "$root/package.json" ] && jq -e '.workspaces' "$root/package.json" >/dev/null 2>&1; } && mono=true
  has '^(pnpm-workspace\.yaml|lerna\.json|turbo\.json|nx\.json)$' && mono=true
  grep -Eq '^(react|react-dom|vue|svelte|next|nuxt|astro|@angular/core|solid-js|preact)$' "$tmp/rundeps" && ui=true
  [ "$(list '\.(tsx|jsx|vue|svelte)$' | grep -Evc '\.(test|spec|stories)\.')" -gt 2 ] && ui=true
  rundep 'express|fastify|koa|@nestjs|hono|fastapi|django|flask|gin-gonic|labstack/echo|spring-boot-starter-web|ktor-server' && server=true
  has '^(Dockerfile|docker-compose\.ya?ml|compose\.ya?ml)$' && server=true
  { [ -f "$root/package.json" ] && jq -e '.bin' "$root/package.json" >/dev/null 2>&1; } && bin=true
  rundep 'commander|yargs|click|cobra|clap|picocli' && bin=true
  if [ -f "$root/package.json" ] && jq -e '(.private | not) and (.main or .exports) and (.bin | not)' "$root/package.json" >/dev/null 2>&1 &&
     [ "$ui" = false ] && [ "$server" = false ]; then lib=true; fi
  [ -f "$root/go.mod" ] && [ "$server" = false ] && [ "$bin" = false ] && lib=true
  # JVM 라이브러리는 spring-boot-starter-web 에 기대도 서버가 아니다 — 진입점이 없다
  if rundep 'java-library|maven-publish' && ! in_files "$tmp/src" '@SpringBootApplication|fun main\(|static void main\('; then
    lib=true; server=false
  fi
  local md_count; md_count="$(list '\.md$' | wc -l | tr -d ' ')"
  if [ "$mono" = true ]; then ptype=monorepo; why+=("JS 워크스페이스 · 모노레포 도구 설정")
  elif [ "$md_count" -gt 3 ] && [ "$src_count" -le $(( md_count / 3 > 3 ? md_count / 3 : 3 )) ] && [ "$ui" = false ] && [ "$server" = false ]; then
    ptype=docs-static; why+=("마크다운 ${md_count}개 · 소스 ${src_count}개")
  elif [ "$bin" = true ]; then ptype=cli; why+=("bin 엔트리 또는 CLI 프레임워크")
  elif [ "$lib" = true ]; then ptype=library; why+=("공개 패키지 · UI · 서버 없음")
  elif [ "$ui" = true ] && [ "$server" = true ]; then ptype=fullstack; why+=("UI + 서버")
  elif [ "$ui" = true ]; then ptype=web-frontend; why+=("UI 프레임워크")
  elif [ "$server" = true ]; then ptype=backend-api; why+=("서버 프레임워크 또는 컨테이너")
  else why+=("판정 불가 — 사용자에게 묻는다"); fi

  jq -Rn --arg root "$root" --arg type "$ptype" --arg why "${why[*]}" \
     --argjson files "$(wc -l < "$tmp/files" | tr -d ' ')" --argjson src "$src_count" --argjson ci "$ci_count" '
    [inputs | split("\u001f") | {id: .[0], state: .[1], ev: .[2]}] as $r
    | { root: $root,
        projectType: (if $type == "" then null else $type end),
        projectTypeWhy: $why,
        files: $files, sourceFiles: $src, ciFiles: $ci,
        passed:  [$r[] | select(.state == "pass") | .id],
        failed:  [$r[] | select(.state == "fail") | .id],
        unknown: [$r[] | select(.state == "unknown") | .id],
        hints:   ([$r[] | select(.state == "hint") | {key: .id, value: .ev}] | from_entries),
        evidence: ([$r[] | select(.state != "hint") | {key: .id, value: .ev}] | from_entries),
        note: "passed · failed 는 저장소 구조(파일 · 설정 · 의존성 · CI)로 확인한 것. hints 는 판정이 아니다 — 확인한 뒤에만 통과로 올린다. 목록에 없는 항목은 실행하거나 물어야 한다." }' < "$tmp/out"
}

# ---- scope -----------------------------------------------------------------
cmd_scope() {
  local type="" na=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --type) type="${2:-}"; shift 2 ;;
      --na) na="${2:-}"; shift 2 ;;
      *) die "scope: 모르는 인자 $1" ;;
    esac
  done
  local tna una recipes
  tna="$(type_na "$type")"; una="$(csv_json "$na")"; check_ids "$una" --na
  recipes="$(grep -hoE '메우는 항목\*\*:.*' "$REF"/recipe-*.md | grep -oE '`[a-z]+\.[a-z0-9-]+`' | tr -d '`' | sort -u | jq -R . | jq -sc .)"
  jq -r --argjson na "$(jq -nc --argjson a "$tna" --argjson b "$una" '$a + $b')" --argjson rec "$recipes" --arg type "$type" '
    def icon: {auto: "⚡", run: "▶️", ask: "💬"}[.];
    [.categories[] | . as $c | .items[] | select(.id as $i | $na | index($i) | not) | . + {cat: $c.title}] as $rows
    | "## 측정 범위" + (if $type != "" then " — \(.projectTypes[$type].label) (해당 없는 \($na | length)개 제외)" else "" end),
      "",
      "| 방식 | 개수 | 뜻 |", "|---|---:|---|",
      "| ⚡ 자동 | \([$rows[] | select(.mode == "auto")] | length) | detect 가 저장소로 본다 |",
      "| ▶️ 실행 | \([$rows[] | select(.mode == "run")] | length) | 도구를 돌려야 수치가 나온다 |",
      "| 💬 질문 | \([$rows[] | select(.mode == "ask")] | length) | 저장소에 흔적이 없다 — 사람에게 묻는다 |",
      "",
      (.categories[] | .title as $t | [$rows[] | select(.cat == $t)] | select(length > 0) |
        "### \($t) (\(length))",
        (.[] | "- [x] \(.mode | icon) `\(.id)`\(if .critical then " 🔑" else "" end) \(.text)\(if .cost then " _(\(.cost))_" else "" end)\(if (.id as $i | $rec | index($i)) then " · 레시피" else "" end)"),
        ""),
      "> 🔑 핵심 항목 — 없으면 위험도가 내려간다. `· 레시피` 는 completeness-apply 로 적용할 수 있다."
  ' "$CHECKLIST"
}

# ---- score -----------------------------------------------------------------
cmd_score() {
  local type="" pass="" na=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --type) type="${2:-}"; shift 2 ;;
      --pass) pass="${2:-}"; shift 2 ;;
      --na) na="${2:-}"; shift 2 ;;
      *) die "score: 모르는 인자 $1" ;;
    esac
  done
  local tna una pj
  tna="$(type_na "$type")"; una="$(csv_json "$na")"; pj="$(csv_json "$pass")"
  check_ids "$una" --na; check_ids "$pj" --pass
  jq -r --argjson tna "$tna" --argjson una "$una" --argjson pass "$pj" --arg type "$type" '
    ($tna + $una | unique) as $na
    | ($una - $tna) as $declared
    | [.categories[] | . as $c | {c: $c, app: [$c.items[] | select(.id as $i | $na | index($i) | not)]}
       | . + {done: [.app[] | select(.id as $i | $pass | index($i))]}] as $g
    | ([$g[].app[]] | length) as $applicable
    | ([$g[].done[]] | length) as $done
    | [$g[].app[] | select(.critical)] as $crit
    | [$crit[] | select(.id as $i | $pass | index($i) | not)] as $critMiss
    | (if ($crit | length) == 0 then 1 else (($crit | length) - ($critMiss | length)) / ($crit | length) end) as $cr
    | (if $applicable == 0 then 0 else $done / $applicable end) as $ratio
    | (.risk | map(select($cr >= .min)) | first) as $risk
    | (.grades | map(select($ratio >= .min)) | first) as $grade
    | "## 완성도 진단 결과", "",
      "| | 결과 | 뜻 |", "|---|---|---|",
      "| **위험도** | \($risk.label) — 핵심 \(($crit | length) - ($critMiss | length))/\($crit | length) | \($risk.note) |",
      "| **실천 범위** | \($grade.label) — \($done)/\($applicable) (\($ratio * 100 | round)%) | \($grade.note) |",
      "",
      "> 둘은 다른 질문이다. 범위가 좁은 것과 위험한 것은 다르다.",
      (if ($critMiss | length) > 0 then "", "### 핵심 공백 \($critMiss | length)개 — 여기부터 메운다", "", ($critMiss[] | "- [ ] `\(.id)` \(.text)") else empty end),
      "",
      (if ($na | length) > 0 then "> N/A \($na | length)개 제외" + (if $type != "" then " (\(.projectTypes[$type].label) 기준 \($tna | length)개" else " (" end) + (if ($declared | length) > 0 then " + **사용자 선언 \($declared | length)개**)" else ")" end) else empty end),
      (if ($declared | length) > 0 then "> ⚠️ 사용자 선언 N/A 는 자기 신고다 — 전제가 실제로 없는 근거를 함께 남긴다: \($declared | map("`" + . + "`") | join(" "))" else empty end),
      "",
      "| 축 | ISO 25010 | 통과 | N/A | 달성률 |", "|---|---|---:|---:|---:|",
      ($g[] | "| \(.c.title) | \(.c.iso) | \(.done | length)/\(.app | length) | \((.c.items | length) - (.app | length) | if . == 0 then "-" else . end) | \(if (.app | length) == 0 then "N/A" else "\((.done | length) / (.app | length) * 100 | round)%" end) |"),
      "",
      ([$g[] | select((.app | length) > (.done | length)) | . + {rate: ((.done | length) / (.app | length))}] | sort_by(.rate) | .[:3] as $gaps
        | if ($gaps | length) > 0 then
            "## 가장 비어 있는 축", "",
            ($gaps[] | "### \(.c.title) — \((.app | length) - (.done | length))개 미통과", (.done as $d | .app[] | select(.id as $i | $d | map(.id) | index($i) | not) | "- [ ] `\(.id)` \(.text)"), "")
          else empty end)
  ' "$CHECKLIST"
}

# ---- health ----------------------------------------------------------------
cmd_health() {
  if [ $# -eq 0 ]; then
    jq -r '
      "## 서비스 건강도 — 무엇을 재는가", "",
      "> 모르는 값은 비운다. 추측한 숫자로 판정하면 판정이 무의미해진다.", "",
      (.groups[] | "### \(.group)", "> \(.note)", "",
        "| id | 지표 | 단위 | 좋은 방향 | 최상 기준 | 왜 보는가 |", "|---|---|---|---|---|---|",
        (.metrics[] | "| `\(.id)` | \(.label) | \(.unit) | \(if .dir == "lower" then "낮을수록" else "높을수록" end) | \(if .dir == "lower" then "≤" else "≥" end) \(.tiers[0]) | \(.why) |"), ""),
      "> 판정: `project-completeness.sh health cfr=8 recovery=45 pages_week=12`"
    ' "$METRICS"
    return
  fi
  local pairs="{}" a k v
  for a in "$@"; do
    case "$a" in *=*) ;; *) die "health: '지표=값' 형식이 아닙니다: $a" ;; esac
    k="${a%%=*}"; v="${a#*=}"
    printf '%s' "$v" | grep -Eq '^-?[0-9]+(\.[0-9]+)?$' || die "health: 숫자가 아닙니다: $a"
    jq -e --arg k "$k" '[.groups[].metrics[].id] | index($k)' "$METRICS" >/dev/null ||
      die "health: 모르는 지표 $k (인자 없이 실행하면 목록이 나온다)"
    pairs="$(jq -c --arg k "$k" --argjson v "$v" '. + {($k): $v}' <<< "$pairs")"
  done
  jq -r --argjson val "$pairs" '
    def tier($m; $v): [range(0; 3) | select(if $m.dir == "lower" then $v <= $m.tiers[.] else $v >= $m.tiers[.] end)] | (first // 3);
    .tiers as $T
    | [.groups[] | .group as $g | .metrics[] | select($val[.id] != null) | . + {g: $g, v: $val[.id]} | . + {t: tier(.; .v)}] as $s
    | ($s | map(.t) | add / length) as $avg
    | "## 서비스 건강도 판정", "",
      "| 묶음 | 지표 | 측정값 | 판정 | 최상 기준 |", "|---|---|---:|---|---|",
      ($s[] | "| \(.g) | \(.label) | \(.v)\(.unit) | \($T[.t]) \(.labels[.t]) | \(if .dir == "lower" then "≤" else "≥" end) \(.tiers[0])\(.unit) |"),
      "",
      "**종합: \(if $avg < 0.5 then "🟢 최상" elif $avg < 1.3 then "🔵 양호" elif $avg < 2.2 then "🟡 보통" else "🔴 위험" end)** (측정 \($s | length)개 평균 \($avg * 100 | round / 100) — 0 최상 · 3 위험)",
      ([$s[] | select(.t >= 2)] | sort_by(-.t) | .[:5] | if length > 0 then "", "### 먼저 손볼 지표", "", (.[] | "- \($T[.t]) **\(.label)** \(.v)\(.unit) — \(.why)") else empty end),
      ([.groups[].metrics[] | select($val[.id] == null) | "`\(.id)`"] | if length > 0 then "", "> 재지 않은 지표 \(length)개: \(join(" · ")) — 재지 않은 것은 통과가 아니다" else empty end)
  ' "$METRICS"
}

# ---- recipe ----------------------------------------------------------------
cmd_recipe() {
  local q="${1:-}"
  [ -n "$q" ] || die "recipe: 항목 id 나 레시피 이름을 주세요 (--list 로 목록)"
  if [ "$q" = "--list" ]; then
    local f
    for f in "$REF"/recipe-*.md; do
      awk -v file="$(basename "$f")" '
        /^## / { name = substr($0, 4) }
        /메우는 항목\*\*:/ { items = $0; sub(/.*메우는 항목\*\*: */, "", items); printf "%s\t%s\t%s\n", file, name, items }
      ' "$f"
    done
    return
  fi
  local by=name; case "$q" in *.*) by=id ;; esac
  local f found=0 out
  for f in "$REF"/recipe-*.md; do
    out="$(awk -v q="$q" -v by="$by" '
      function flush() { if (sec != "" && hit) { printf "%s", sec; n++ } sec = ""; hit = 0 }
      BEGIN { lq = tolower(q) }
      /^## / { flush(); head = 0; sec = $0 "\n"; if (by == "name" && index(tolower($0), lq)) hit = 1; next }
      /^---$/ && sec != "" { flush(); next }
      sec == "" && !head { if ($0 != "---") intro = intro $0 "\n"; next }
      { sec = sec $0 "\n"; if (by == "id" && /메우는 항목\*\*:/ && index($0, "`" q "`")) hit = 1 }
      END { flush(); if (n) printf "%s", "\x1e" intro }
    ' "$f")"
    [ -n "$out" ] || continue
    found=1
    printf '<!-- %s -->\n%s\n%s\n' "$(basename "$f")" "${out##*$'\x1e'}" "${out%$'\x1e'*}"
  done
  [ "$found" -eq 1 ] || { echo "레시피 없음: $q — 도구를 임의로 설정하지 말고 사용자에게 알린다" >&2; return 1; }
}

case "${1:-}" in
  detect) shift; cmd_detect "$@" ;;
  scope)  shift; cmd_scope "$@" ;;
  score)  shift; cmd_score "$@" ;;
  health) shift; cmd_health "$@" ;;
  recipe) shift; cmd_recipe "$@" ;;
  *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
