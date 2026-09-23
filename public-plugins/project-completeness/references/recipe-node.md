# Node.js / TypeScript / 프론트엔드 레시피

선행 조건 공통: 저장소 루트에 `package.json` 이 존재할 것.
패키지 매니저는 `packageManager` 필드 → lockfile 순으로 감지한다
(`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm, `bun.lockb` → bun).

---

## ESLint (flat config) — 린트

- **메우는 항목**: `code.lint-ci` 린터·포매터 CI 강제
- **설치**: `npm i -D eslint @eslint/js typescript-eslint`
- **설정** — `eslint.config.js`:
  ```javascript
  import js from '@eslint/js';
  import ts from 'typescript-eslint';

  export default [
    js.configs.recommended,
    ...ts.configs.recommended,
    { ignores: ['dist/**', 'build/**', 'coverage/**', '.next/**'] },
  ];
  ```
- **package.json**: `"lint": "eslint ."`
- **검증**: `npm run lint` — 에러가 많으면 먼저 `--max-warnings=999` 로 시작해 점진 축소
- **CI**: `- run: npm run lint -- --max-warnings=0`
- **롤백**: `eslint.config.js` 삭제, 의존성 제거

> 이미 `.eslintrc*` 가 있으면 **flat config 로 마이그레이션하지 말고** 기존 설정을 유지한 채 CI 에만 붙인다.

---

## Biome — 린트 + 포맷 (ESLint 대안)

- **메우는 항목**: `code.lint-ci`
- **설치**: `npm i -D @biomejs/biome`
- **설정**: `npx biome init` → `biome.json`
- **package.json**: `"lint": "biome check ."`, `"format": "biome format --write ."`
- **검증**: `npx biome check .`
- **롤백**: `biome.json` 삭제
- **선택 기준**: 속도 우선 + 규칙 커스터마이즈가 적으면 Biome, 플러그인 생태계가 필요하면 ESLint.

---

## TypeScript strict — 타입 완성도

- **메우는 항목**: `code.type-strict` strict 통과
- **선행 조건**: `tsconfig.json`
- **설정** — `tsconfig.json` 의 `compilerOptions`:
  ```json
  {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true
  }
  ```
- **검증**: `npx tsc --noEmit`
- **CI**: `- run: npx tsc --noEmit`
- **롤백**: 옵션 되돌리기
- **비고**: 기존 프로젝트에서 에러가 수백 개 나오면 **한 번에 켜지 말고** `strict` 만 먼저,
  나머지는 에러 정리 후 순차 적용한다.

---

## type-coverage — 타입 커버리지 계량

- **메우는 항목**: `code.type-strict`
- **설치**: `npm i -D type-coverage`
- **package.json**: `"typecov": "type-coverage --detail"`
- **검증**: `npx type-coverage` → 현재 % 확인 후 `--at-least <현재값>` 으로 CI 에 고정 (하락 방지)
- **CI**: `- run: npx type-coverage --at-least 95`
- **롤백**: 의존성 제거

---

## Knip — 미사용 파일·export·의존성

- **메우는 항목**: `code.unused-code` 미사용 코드 0 수렴
- **설치**: `npm i -D knip`
- **설정** — `knip.json` (모노레포가 아니면 대개 불필요):
  ```json
  {
    "entry": ["src/index.ts"],
    "project": ["src/**/*.{ts,tsx}"],
    "ignoreDependencies": []
  }
  ```
  `entry` 에는 **실제 존재하는 파일만** 넣는다. 없는 경로를 넣으면
  `Refine entry pattern (no matches)` 힌트가 계속 출력된다.
- **검증**: `npx knip` — 초기 오탐이 많으면 `ignoreDependencies` 로 조정
- **CI**: `- run: npx knip --no-exit-code` (초기) → 정리 후 `npx knip`
- **롤백**: `knip.json` 삭제, 의존성 제거
- **비고**: 완성도 진단에 가장 직접적인 도구. 처음 돌리면 대개 놀랄 만큼 나온다.

---

## Vitest 커버리지

- **메우는 항목**: `test.unit-coverage` 커버리지 80%
- **설치**: `npm i -D vitest @vitest/coverage-v8`
- **설정** — `vitest.config.ts`:
  ```typescript
  import { defineConfig } from 'vitest/config';

  export default defineConfig({
    test: {
      coverage: {
        provider: 'v8',
        reporter: ['text', 'lcov'],
        exclude: ['**/*.config.*', '**/dist/**', '**/*.d.ts'],
        // 현재 값으로 시작해 점진 상향. 임의의 80 을 넣으면 항상 실패한다.
        thresholds: { lines: 0, functions: 0, branches: 0, statements: 0 },
      },
    },
  });
  ```
- **package.json**: `"test": "vitest run"`, `"test:cov": "vitest run --coverage"`
- **검증**: `npm run test:cov` → 현재 % 를 thresholds 에 반영
- **CI**: `- run: npm run test:cov`
- **롤백**: coverage 블록 삭제

---

## Codecov — 변경분 커버리지 게이트

- **메우는 항목**: `test.unit-coverage`
- **선행 조건**: lcov 리포트 생성 (위 레시피)
- **설정** — CI step:
  ```yaml
  - uses: codecov/codecov-action@v4
    with:
      files: ./coverage/lcov.info
      token: ${{ secrets.CODECOV_TOKEN }}
  ```
  `codecov.yml`:
  ```yaml
  coverage:
    status:
      project: { default: { target: auto, threshold: 1% } }
      patch:   { default: { target: 80% } }   # 변경분만 80% — 레거시 면제
  ```
- **검증**: PR 에 Codecov 코멘트가 달리는지 확인
- **롤백**: step 과 `codecov.yml` 삭제
- **비고**: `patch` 게이트가 핵심이다. 전체 커버리지 목표는 레거시 때문에 달성 불가능한 경우가 많다.

---

## Stryker — 뮤테이션 테스트 (테스트 품질)

- **메우는 항목**: `test.mutation-score` 뮤테이션 스코어 80%
- **선행 조건**: 동작하는 테스트 스위트
- **설치**: `npm i -D @stryker-mutator/core @stryker-mutator/vitest-runner`
- **설정** — `stryker.config.json`:
  ```json
  {
    "$schema": "./node_modules/@stryker-mutator/core/schema/stryker-schema.json",
    "testRunner": "vitest",
    "coverageAnalysis": "perTest",
    "incremental": true,
    "incrementalFile": ".stryker-tmp/incremental.json",
    "mutate": ["src/**/*.ts", "!src/**/*.spec.ts", "!src/**/*.test.ts"],
    "thresholds": { "high": 80, "low": 60, "break": null }
  }
  ```
- **package.json**: `"test:mutation": "stryker run"`
- **검증**: `npm run test:mutation` → 첫 실행은 오래 걸린다. 이후 증분 모드로 1~5분.
- **CI**: `- run: npx stryker run --incremental` + `continue-on-error: true`
- **롤백**: `stryker.config.json`, `.stryker-tmp/` 삭제
- **gitignore 추가**: `.stryker-tmp/`, `reports/`
- **게이트**: 🟢 리포트만. `break` 를 설정하면 초기에 반드시 실패한다.

---

## Playwright — E2E + 접근성

- **메우는 항목**: `test.e2e-flow` E2E, `ux.a11y-automated` axe 위반 0
- **설치**: `npm init playwright@latest` → `npm i -D @axe-core/playwright`
- **설정** — `e2e/a11y.spec.ts` (접근성 검사를 E2E 에 얹는다):
  ```typescript
  import { test, expect } from '@playwright/test';
  import AxeBuilder from '@axe-core/playwright';

  test('홈 페이지 접근성 위반 없음', async ({ page }) => {
    await page.goto('/');
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
      .analyze();
    expect(results.violations).toEqual([]);
  });
  ```
- **검증**: `npx playwright test`
- **CI**: `- run: npx playwright install --with-deps` → `- run: npx playwright test`
- **롤백**: `e2e/`, `playwright.config.ts` 삭제
- **gitignore 추가**: `test-results/`, `playwright-report/`, `blob-report/`
- **비고**: 자동 검사는 WCAG 이슈의 30~40% 만 잡는다. **수동 스크린리더 테스트는 별도로 필요**하며,
  이 레시피만으로 `ux.a11y-manual` 항목을 통과 처리하면 안 된다.

---

## Lighthouse CI — 성능 예산

- **메우는 항목**: `perf.lighthouse-budget` 성능 예산 PR 게이트
- **선행 조건**: 빌드 산출물 또는 실행 가능한 dev 서버
- **설치**: `npm i -D @lhci/cli`
- **설정** — `lighthouserc.json`:
  ```json
  {
    "ci": {
      "collect": {
        "staticDistDir": "./dist",
        "numberOfRuns": 3
      },
      "assert": {
        "assertions": {
          "categories:performance":   ["warn", { "minScore": 0.8 }],
          "categories:accessibility": ["error", { "minScore": 0.9 }],
          "largest-contentful-paint": ["warn", { "maxNumericValue": 2500 }],
          "cumulative-layout-shift":  ["warn", { "maxNumericValue": 0.1 }],
          "total-blocking-time":      ["warn", { "maxNumericValue": 300 }]
        }
      },
      "upload": { "target": "temporary-public-storage" }
    }
  }
  ```
  SPA/서버 렌더링이면 `staticDistDir` 대신 `"startServerCommand": "npm run preview"` + `"url": ["<앱 주소>"]`.
- **검증**: `npx lhci autorun` → 현재 점수를 보고 `minScore` 를 그 값 기준으로 조정
- **CI**: `- run: npm run build` → `- run: npx lhci autorun`
- **롤백**: `lighthouserc.json` 삭제
- **비고**: CI 러너 성능에 따라 점수가 흔들린다. `numberOfRuns: 3` 은 필수.
  Lab 점수는 실사용자 경험이 아니므로 **RUM(web-vitals) 을 별도로 붙여야** `perf.web-vitals` 이 채워진다.

---

## Size Limit — 번들 예산

- **메우는 항목**: `perf.bundle-budget` 번들 예산 CI
- **설치**: `npm i -D size-limit @size-limit/preset-app` (라이브러리면 `preset-small-lib`)
- **설정** — `package.json`:
  ```json
  {
    "size-limit": [
      { "name": "main bundle", "path": "dist/assets/*.js", "limit": "0 KB" }
    ],
    "scripts": { "size": "size-limit" }
  }
  ```
- **검증**: `npm run build && npx size-limit` → **출력된 현재 크기를 `limit` 에 기입**한다. 임의값 금지.
- **CI**:
  ```yaml
  - uses: andresz1/size-limit-action@v1
    with: { github_token: "${{ secrets.GITHUB_TOKEN }}", build_script: build }
  ```
- **롤백**: `size-limit` 필드 삭제

---

## Pa11y CI — 접근성 배치 검사

- **메우는 항목**: `ux.a11y-automated`
- **설치**: `npm i -D pa11y-ci`
- **설정** — `.pa11yci.json`:
  ```json
  {
    "defaults": {
      "standard": "WCAG2AA",
      "runners": ["axe"],
      "timeout": 30000,
      "threshold": 0
    },
    "urls": ["<앱 주소>"]
  }
  ```
- **검증**: 서버 기동 후 `npx pa11y-ci`
- **CI**: `- run: npm run preview & npx wait-on tcp:4173 && npx pa11y-ci`
- **롤백**: `.pa11yci.json` 삭제
- **비고**: 처음에는 `threshold` 를 현재 위반 수로 두고 점진 축소한다.

---

## web-vitals — 실사용자 CWV 수집 (RUM)

- **메우는 항목**: `perf.web-vitals` 필드 데이터 수집
- **설치**: `npm i web-vitals`
- **설정** — `src/vitals.ts`:
  ```typescript
  import { onCLS, onINP, onLCP, onFCP, onTTFB, type Metric } from 'web-vitals';

  function report(metric: Metric) {
    const body = JSON.stringify({
      name: metric.name, value: metric.value, rating: metric.rating,
      id: metric.id, path: location.pathname,
    });
    // sendBeacon 은 페이지 이탈 중에도 전송된다
    navigator.sendBeacon?.('/api/vitals', body) ??
      fetch('/api/vitals', { body, method: 'POST', keepalive: true });
  }

  onCLS(report); onINP(report); onLCP(report); onFCP(report); onTTFB(report);
  ```
  엔트리에서 `import './vitals'`.
- **검증**: 브라우저에서 페이지를 열고 `/api/vitals` 로 요청이 가는지 네트워크 탭에서 확인
- **롤백**: `src/vitals.ts` 와 import 삭제
- **비고**: 수집 엔드포인트가 없으면 무료 대안 — **Microsoft Clarity** 스니펫(완전 무료) 또는
  PostHog·Sentry SDK 로 대체할 수 있다.
