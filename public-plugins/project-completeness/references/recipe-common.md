# 공통 레시피 (언어 무관)

---

## gitleaks — 시크릿 탐지

- **메우는 항목**: `security.secret-scan` 시크릿 스캔이 pre-commit 과 CI 양쪽에 있는가
- **선행 조건**: git 저장소
- **설치**: 로컬 훅은 `brew install gitleaks` (또는 pre-commit 프레임워크), CI 는 액션만으로 충분
- **설정** — 기존 워크플로에 job 추가. `gitleaks-action@v2` 는 **조직 소유 저장소에서
  라이선스 키를 요구**하므로, 공식 컨테이너 이미지로 돌리는 방식이 어디서나 동작한다:
  ```yaml
  secrets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }   # 히스토리 전체 스캔에 필요
      - name: gitleaks
        run: |
          docker run --rm -v "$PWD:/repo" ghcr.io/gitleaks/gitleaks:v8.21.2 \
            detect --source /repo --no-banner --redact --verbose
  ```
  개인 계정 저장소라면 `gitleaks/gitleaks-action@v2` 도 무료로 쓸 수 있다.
  pre-commit 을 함께 쓴다면 `.pre-commit-config.yaml`:
  ```yaml
  repos:
    - repo: local                  # 로컬에 설치한 gitleaks 를 쓴다 (brew install gitleaks)
      hooks:
        - id: gitleaks
          name: gitleaks
          entry: gitleaks protect --staged --redact --no-banner
          language: system
          pass_filenames: false
  ```
- **검증**: `gitleaks detect --source . --no-banner` → `no leaks found`
- **롤백**: 워크플로 job 과 `.pre-commit-config.yaml` 항목 삭제
- **게이트**: 🔴 **처음부터 차단**. 유출은 되돌릴 수 없다.

---

## Trivy — 의존성·컨테이너 취약점 (SCA)

- **메우는 항목**: `security.sca-sbom` SCA, `security.critical-vulnerability` Critical/High 0
- **선행 조건**: 없음 (모든 생태계 지원)
- **설정** — 워크플로 job:
  ```yaml
  sca:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # 서드파티 액션은 태그가 아니라 커밋 SHA 로 고정한다.
      # 태그는 옮겨질 수 있어 공급망 공격의 통로가 된다 (# 뒤에 버전을 주석으로 남긴다).
      - uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0
        with:
          scan-type: fs
          scan-ref: .
          severity: CRITICAL,HIGH
          exit-code: '1'          # 도입 초기에는 '0' 으로 두고 리포트만
          ignore-unfixed: true    # 패치 없는 취약점 제외 — 노이즈 감소
  ```
- **검증**: `docker run --rm -v "$PWD":/src aquasec/trivy fs /src --severity CRITICAL,HIGH`
- **롤백**: job 삭제
- **게이트**: 초기 `exit-code: '0'` → 기존 취약점 정리 후 `'1'` 로 승격

---

## OSV-Scanner — 취약점 교차 검증

- **메우는 항목**: `security.sca-sbom`
- **설정**:
  ```yaml
  osv:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: google/osv-scanner-action/osv-scanner-action@v1
        with: { scan-args: "-r ./" }
  ```
- **검증**: `osv-scanner -r .`
- **롤백**: job 삭제
- **비고**: Trivy 와 데이터 소스가 달라 함께 쓰면 커버리지가 넓어진다. 하나만 쓸 거면 Trivy.

---

## SBOM 생성 (Syft + CycloneDX)

- **메우는 항목**: `security.sca-sbom` SBOM 생성·보관
- **설정**:
  ```yaml
  sbom:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: anchore/sbom-action@aa80c8c5bd439a416a62804f2151ab38c671a638 # v0.24.1
        with: { format: cyclonedx-json, output-file: sbom.cdx.json }
      - uses: actions/upload-artifact@v4
        with: { name: sbom, path: sbom.cdx.json, retention-days: 90 }
  ```
- **검증**: 아티팩트에 `sbom.cdx.json` 이 생성되는지 확인
- **롤백**: job 삭제

---

## Renovate — 의존성 자동 갱신

- **메우는 항목**: `security.dependency-update`
- **설정** — `renovate.json`:
  ```json
  {
    "extends": ["config:recommended", ":semanticCommits"],
    "prConcurrentLimit": 5,
    "schedule": ["before 6am on monday"],
    "minimumReleaseAge": "7 days",
    "packageRules": [
      { "matchUpdateTypes": ["minor", "patch"], "groupName": "non-major", "automerge": false },
      { "matchDepTypes": ["devDependencies"], "groupName": "dev deps" }
    ],
    "vulnerabilityAlerts": { "labels": ["security"], "schedule": ["at any time"] }
  }
  ```
- **검증**: GitHub 앱 설치 후 Dependency Dashboard 이슈 생성 확인
- **롤백**: `renovate.json` 삭제
- **비고**: `prConcurrentLimit` 을 안 두면 PR 폭주로 전부 무시된다.
  `minimumReleaseAge`(Dependabot 은 `cooldown`)를 두면 **갓 배포된 버전을 즉시 채택하지 않는다** —
  npm 계정 탈취로 악성 버전이 올라갔다가 수 시간 내 삭제되는 사고를 피할 수 있다.
- **Dependabot 대안** — `.github/dependabot.yml`:
  ```yaml
  version: 2
  updates:
    - package-ecosystem: npm            # 프로젝트에 맞게: pip / gomod / cargo ...
      directory: "/"
      schedule: { interval: weekly, day: monday }
      open-pull-requests-limit: 5
      cooldown: { default-days: 7 }     # 갓 배포된 버전을 즉시 채택하지 않는다
      groups:
        non-major:
          update-types: [minor, patch]
    - package-ecosystem: github-actions
      directory: "/"
      schedule: { interval: weekly, day: monday }
      open-pull-requests-limit: 3
      cooldown: { default-days: 7 }
  ```

---

## OpenSSF Scorecard — 저장소 보안 점수

- **메우는 항목**: `security.scorecard`
- **선행 조건**: 공개 저장소 또는 `repo` 권한 토큰
- **설정**:
  ```yaml
  scorecard:
    runs-on: ubuntu-latest
    permissions: { security-events: write, id-token: write, contents: read }
    steps:
      - uses: actions/checkout@v4
        with: { persist-credentials: false }
      - uses: ossf/scorecard-action@v2
        with: { results_file: results.sarif, results_format: sarif }
      - uses: github/codeql-action/upload-sarif@v3
        with: { sarif_file: results.sarif }
  ```
- **검증**: `scorecard --repo=github.com/OWNER/REPO` (로컬 CLI)
- **롤백**: 워크플로 삭제
- **게이트**: 🟢 리포트만. 점수는 추세로 본다.

---

## Semgrep — SAST

- **메우는 항목**: `security.sast`
- **설정** — 공식 컨테이너 이미지를 쓴다. `returntocorp/semgrep-action` 은 구식이며
  `semgrep ci` 는 플랫폼 토큰을 요구하므로, 토큰 없이 도는 `semgrep scan` 을 쓴다:
  ```yaml
  sast:
    runs-on: ubuntu-latest
    container:
      image: semgrep/semgrep
    continue-on-error: true       # 도입 초기 리포트 전용
    steps:
      - uses: actions/checkout@v4
      - run: semgrep scan --config=p/default --config=p/secrets --metrics=off
  ```
  룰셋은 언어에 맞게 고른다 — `p/javascript`, `p/python`, `p/golang`, `p/owasp-top-ten`.
  `--metrics=off` 를 빼면 사용 통계가 전송된다.
  MCP 로 에이전트에 붙이려면: `claude mcp add --transport stdio semgrep -- semgrep mcp`
- **검증**: `semgrep scan --config=p/default --metrics=off` (로컬)
- **롤백**: job 삭제
- **게이트**: 초기 리포트만 → 룰셋을 프로젝트에 맞게 좁힌 뒤 차단

---

## k6 — 부하 테스트 기준선

- **메우는 항목**: `perf.latency-baseline` p95/p99 기준선, `perf.load-test` 포화점
- **선행 조건**: 실행 중인 API 엔드포인트
- **설정** — `perf/baseline.js`:
  ```javascript
  import http from 'k6/http';
  import { check } from 'k6';

  export const options = {
    stages: [
      { duration: '30s', target: 10 },   // 램프업
      { duration: '1m',  target: 10 },   // 정상 부하
      { duration: '30s', target: 0 },
    ],
    thresholds: {
      http_req_failed:   ['rate<0.01'],   // 에러율 1% 미만
      http_req_duration: ['p(95)<300', 'p(99)<800'],
    },
  };

  const BASE = __ENV.BASE_URL;   // 앱 주소 — 필수
  if (!BASE) throw new Error('BASE_URL 을 지정한다');

  export default function () {
    const res = http.get(`${BASE}/health`);
    check(res, { 'status 200': (r) => r.status === 200 });
  }
  ```
- **검증**: `k6 run -e BASE_URL=<앱 주소> perf/baseline.js` → thresholds 3개 전부 `✓` 여야 한다
  ```
  ✓ 'rate<0.01'    rate=0.00%
  ✓ 'p(95)<300'    p(95)=326µs
  ```
  ⚠️ k6 를 **Docker 로 실행하면 `localhost` 가 컨테이너 자신을 가리킨다.**
  호스트의 서버를 때리려면 `BASE_URL` 의 호스트를 `host.docker.internal` 로 쓴다.
  이걸 모르면 실패율 100% 가 나오고 앱이 문제라고 오진하게 된다.
- **롤백**: `perf/` 삭제
- **비고**: **먼저 현재 값을 측정하고 thresholds 를 그 값 기준으로 잡는다.** 임의의 숫자를 넣으면 항상 실패한다.

---

## Spectral — OpenAPI 스펙 린트

- **메우는 항목**: 체크리스트 항목 없음 — API 문서 품질 (프로젝트에 스펙이 있을 때만)
- **선행 조건**: `openapi.yaml` / `openapi.json` / `swagger.yaml` 존재
- **설정** — `.spectral.yaml`:
  ```yaml
  extends: ["spectral:oas"]
  rules:
    operation-operationId: error
    operation-description: warn
    operation-tag-defined: error
    oas3-api-servers: warn
  ```
- **검증**: `npx @stoplight/spectral-cli lint openapi.yaml`
- **롤백**: `.spectral.yaml` 삭제

---

## CI 워크플로 골격

기존 워크플로가 없을 때 만드는 최소 골격. **job 을 하나씩 추가**하며 늘린다.

- **메우는 항목**: 없음 (다른 레시피의 선행 조건)
- **선행 조건**: `.github/workflows/` 에 기존 파일이 없을 것

```yaml
name: quality
on:
  push: { branches: [main] }
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  # 여기에 레시피의 job 을 하나씩 추가한다
```

- **검증**: `python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" .github/workflows/quality.yml`
- **롤백**: 워크플로 파일 삭제

> **서드파티 액션은 커밋 SHA 로 고정한다.** `@v4`·`@master` 는 태그가 옮겨질 수 있어
> 공급망 공격의 통로가 된다. GitHub 공식(`actions/*`)은 태그로도 관행상 허용되지만,
> 보안 검사 job 처럼 권한을 갖는 액션은 SHA 고정을 권장한다.

이미 워크플로가 있으면 **새 파일을 만들지 말고 기존 파일에 job 을 추가**한다.
워크플로가 늘어날수록 실행 시간과 알림이 늘어 관리가 어려워진다.
