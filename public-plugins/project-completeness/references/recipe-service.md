# 서비스 완성도 측정 레시피

접근성 검사가 통과해도 화면은 깨져 있을 수 있고, 코드 품질이 A등급이어도
명세의 절반이 미구현일 수 있다. 이 두 가지는 **다른 도구로 따로 재야 한다.**

| 묻는 것 | 이 레시피 |
|---|---|
| 화면이 **깨지지 않는가** | 라우트 렌더 스모크 · 콘솔 에러 감시 |
| 기능이 **다 있는가** | 명세↔구현 양방향 대조 |

> 접근성(`ux` 축)은 "쓸 수 있는가"를 묻는다. 여기는 **"안 깨지는가 / 다 있는가"** 를 묻는다.
> 둘 다 통과해야 서비스로서 완성된 것이다.

---

## 라우트 렌더 스모크

- **메우는 항목**: `service.render-smoke` 모든 라우트가 에러 없이 렌더되는가 (핵심 항목)
- **선행 조건**: 라우트 목록을 추출할 수 있을 것 (라우터 정의 파일 또는 파일 기반 라우팅)
- **설치**: `npm i -D @playwright/test` (a11y 레시피와 공유 가능)
- **설정** — 라우트를 **한 곳에서 뽑아** 테스트가 자동으로 늘어나게 한다:
  ```typescript
  // test/routes.ts — 앱의 라우터에서 가져오거나, 파일 라우팅이면 glob 으로 생성
  export const ROUTES = [
    '/', '/login', '/dashboard', '/settings', '/billing',
  ] as const;
  ```
  ```typescript
  // test/render-smoke.spec.ts
  import { test, expect } from '@playwright/test';
  import { ROUTES } from './routes';

  for (const path of ROUTES) {
    test(`렌더 ${path}`, async ({ page }) => {
      const errors: string[] = [];
      // 렌더는 되지만 깨진 상태를 잡는다 — service.console-error
      page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
      page.on('pageerror', (e) => errors.push(String(e)));

      const res = await page.goto(path, { waitUntil: 'networkidle' });
      expect(res?.status(), `${path} HTTP`).toBeLessThan(400);

      // 프레임워크 에러 화면을 잡는다
      const body = await page.locator('body').innerText();
      expect(body, `${path} 에러 화면`).not.toMatch(/Application error|Unhandled|Cannot read|500 Internal/i);

      // 백지 방지 — 의미 있는 콘텐츠가 있는가
      expect(body.trim().length, `${path} 빈 화면`).toBeGreaterThan(20);

      expect(errors, `${path} 콘솔 에러`).toEqual([]);
    });
  }
  ```
- **검증**: `npx playwright test test/render-smoke.spec.ts`
  ```
  ✓ 렌더 /          ✓ 렌더 /dashboard
  ✗ 렌더 /billing   → 콘솔 에러: Cannot read properties of undefined
  ```
  **라우트 수 = 테스트 수** 여야 한다. 적으면 라우트 추출이 빠뜨린 것이다.
- **CI**:
  ```yaml
  - run: npx playwright install --with-deps chromium
  - run: npx playwright test test/render-smoke.spec.ts
  ```
- **롤백**: `test/render-smoke.spec.ts` · `test/routes.ts` 삭제
- **게이트**: 🔴 **차단**. 라우트가 깨지면 서비스가 아니다.
- **비고**: 인증이 필요한 라우트는 `storageState` 로 로그인 세션을 주입한다.
  로그인 없이 접근하면 리다이렉트라 "렌더 성공"으로 잘못 판정된다.
  **이 테스트는 상호작용을 보지 않는다.** 버튼을 눌렀을 때의 동작은 별도 E2E 가 필요하다.

---

## 시각 회귀 (스크린샷 비교)

- **메우는 항목**: `service.screenshot-diff` 핵심 화면의 시각적 회귀를 자동으로 잡는가
- **선행 조건**: 렌더 스모크가 먼저 통과할 것
- **설정** — 렌더 스모크에 스크린샷을 얹는다:
  ```typescript
  test(`시각 ${path}`, async ({ page }) => {
    await page.goto(path, { waitUntil: 'networkidle' });
    await page.addStyleTag({ content: '*,*::before,*::after{animation:none!important;transition:none!important}' });
    await expect(page).toHaveScreenshot(`${path.replace(/\//g, '_') || 'root'}.png`, {
      fullPage: true,
      maxDiffPixelRatio: 0.01,   // 폰트 렌더링 편차 흡수
      mask: [page.locator('[data-testid="timestamp"]')],  // 매번 바뀌는 것은 가린다
    });
  });
  ```
- **검증**: 첫 실행은 기준 이미지를 만든다. 두 번째 실행이 통과해야 한다.
  ```bash
  npx playwright test --update-snapshots   # 기준 생성
  npx playwright test                      # 비교
  ```
- **CI**: 스냅샷은 **OS·브라우저 버전에 민감하다.** 반드시 CI 와 같은 컨테이너에서 생성한다.
  ```bash
  npx playwright docker run --rm -v "$PWD":/w -w /w mcr.microsoft.com/playwright:v1.56.0-noble \
    npx playwright test --update-snapshots
  ```
- **롤백**: 스냅샷 디렉터리와 테스트 삭제
- **게이트**: 🟡 경고부터. 폰트·렌더링 차이로 오탐이 나오면 신뢰를 잃는다.
- **비고**: 도구 선택은 **캡처 위치**로 갈린다.
  - **로컬 캡처** (Playwright 내장 · Argos · reg-suit) —
    테스트가 실제로 본 화면을 그대로 비교한다. diff 가 어긋나지 않는다
  - **클라우드 재렌더링** (Chromatic · Percy) —
    크로스브라우저 매트릭스를 주지만, 비교 대상이 테스트가 만든 이미지가 아니다
  - ⚠️ **BackstopJS 는 유지보수 모드**(v6.x). 신규 프로젝트에는 권하지 않는다
  - 렌더링 편차 오탐이 문제라면 Applitools 같은 AI 판정이 대안이지만 유료다

---

## 명세 대비 미구현 탐지

- **메우는 항목**: `service.spec-implemented` 명세에 적힌 기능이 전부 구현되어 있는가
- **선행 조건**: 명세 문서가 있을 것 (`docs/*.md` 의 엔드포인트·라우트·기능 표, OpenAPI, ADR)
- **설정** — `scripts/spec-gap.mjs`:
  ```javascript
  #!/usr/bin/env node
  /** 명세 문서의 경로·엔드포인트를 뽑아 코드에 존재하는지 대조한다. */
  import { readFileSync, readdirSync } from 'node:fs';
  import { execSync } from 'node:child_process';

  const SPEC_GLOB = process.argv[2] ?? 'docs';            // 명세 디렉터리
  const CODE_GLOB = process.argv[3] ?? 'src';             // 구현 디렉터리

  // 명세에서 경로 후보를 뽑는다: `/api/foo` `GET /bar` 같은 패턴
  const specs = new Set();
  const walk = (d) => readdirSync(d, { withFileTypes: true }).forEach((e) => {
    const p = `${d}/${e.name}`;
    if (e.isDirectory()) return walk(p);
    if (!e.name.endsWith('.md')) return;
    const t = readFileSync(p, 'utf8');
    for (const m of t.matchAll(/`((?:GET|POST|PUT|PATCH|DELETE)\s+)?(\/[a-z0-9\-_/:{}]+)`/gi)) {
      specs.add(m[2].replace(/[{:][^/}]+\}?/g, ':id'));   // 경로 변수 정규화
    }
  });
  walk(SPEC_GLOB);

  const missing = [];
  for (const s of specs) {
    const needle = s.split('/').filter(Boolean)[0];
    if (!needle) continue;
    try {
      execSync(`grep -rq --include='*.{ts,tsx,js,jsx,py,go}' -- '${needle}' ${CODE_GLOB}`, { stdio: 'ignore' });
    } catch { missing.push(s); }
  }

  console.log(`명세 경로 ${specs.size}개 · 코드에서 못 찾은 것 ${missing.length}개`);
  missing.forEach((m) => console.log('  ✗ ' + m));
  process.exit(missing.length ? 1 : 0);
  ```
- **검증**: `node scripts/spec-gap.mjs docs src`
  ```
  명세 경로 24개 · 코드에서 못 찾은 것 3개
    ✗ /api/reports/export
  ```
  **0건이 목표가 아니다.** 나온 것을 하나씩 판정하라 — 미구현인가, 이름이 바뀐 것인가, 명세가 낡은 것인가.
- **롤백**: 스크립트 삭제
- **게이트**: 🟢 리포트만. 명세와 코드는 항상 조금씩 어긋난다. **추세**를 본다.
- **비고**: OpenAPI 가 있다면 이 스크립트 대신 전용 도구가 훨씬 정확하다.
  - **Spectral** 명세 린트 → **Schemathesis** 명세 대비 실동작 검증
  - **oasdiff** — 명세 두 버전의 파괴적 변경 검출.
    ⚠️ 같은 용도의 **Optic 은 2026-01 아카이브**됐다. 신규 도입하지 마라
  이 레시피는 명세가 **산문 마크다운으로만** 존재할 때의 대안이다.

---

## 코드 대비 고아 탐지 (역방향)

- **메우는 항목**: `service.orphan-feature` 코드에 있는데 명세에도 UI 에도 도달 경로가 없는 것
- **선행 조건**: 라우터·핸들러 등록 지점을 특정할 수 있을 것
- **설정** — 등록된 것을 뽑아 명세·UI 링크와 대조한다:
  ```bash
  # ① 등록된 엔드포인트 추출 (프레임워크에 맞게 조정)
  grep -rhoE "(app|router)\.(get|post|put|patch|delete)\(['\"]([^'\"]+)" src \
    | sed -E "s/.*['\"]//" | sort -u > /tmp/registered.txt

  # ② 명세 문서와 프론트엔드 호출에서 언급된 것
  { grep -rhoE "/[a-z0-9/:_-]+" docs --include='*.md';
    grep -rhoE "['\"\`](/api/[a-z0-9/:_-]+)" src --include='*.{ts,tsx}' | tr -d "'\"\`"; } \
    | sort -u > /tmp/referenced.txt

  # ③ 등록됐는데 아무도 참조하지 않는 것 = 고아 후보
  comm -23 /tmp/registered.txt /tmp/referenced.txt
  ```
- **검증**: 출력된 각 항목을 판정한다.
  ```
  /api/internal/reindex     → 운영용 내부 API. 명세에 추가하거나 인증을 확인
  /api/v1/legacy-export     → 사용처 없음. 제거 대상
  ```
  **자동 판정하지 마라.** 내부 운영 API 는 정상적으로 고아처럼 보인다.
- **전용 도구** — 스크립트보다 정확하다
  - JS/TS: **dependency-cruiser** `--validate` 로 고아 모듈을 규칙으로 차단,
    **madge** `--orphans` 로 즉시 목록, **Knip** 은 미사용 export·의존성까지
  - Python: **Vulture** (`--min-confidence 80` 으로 오탐 억제)
  - Go: **deadcode** (`golang.org/x/tools/cmd/deadcode`) — 호출 그래프 기반이라 오탐이 적다
  - ⚠️ **ts-prune 은 유지보수 종료.** Knip 으로 대체한다
- **롤백**: 해당 없음 (일회성 조사)
- **게이트**: 🟢 리포트만
- **비고**: 고아 엔드포인트는 **보안 위험**이기도 하다 — 아무도 안 보는 경로에
  인증이 빠져 있는 경우가 흔하다. 발견하면 인증 여부를 먼저 확인하라.

---

### 무엇을 여전히 못 재는가 (레시피 아님 — 한계 기록)

정직하게 적는다. 아래는 이 레시피로도 자동 판정할 수 없다.

| 못 재는 것 | 왜 | 대신 할 것 |
|---|---|---|
| **이 제품이 무엇이어야 하는가** | 체크리스트는 "품질 실천이 있는가"를 묻지 제품의 의도를 모른다 | 명세 문서를 기준으로 위 대조를 돌린다. 명세 자체가 부실하면 그것부터 |
| 상호작용 플로우의 정확성 | 렌더 스모크는 화면이 뜨는지만 본다 | 핵심 여정 E2E (`test.e2e-flow`) |
| 시각적 "좋음" | 깨짐은 잡아도 디자인 품질은 판단하지 않는다 | 디자인 리뷰 |
| 사용자가 실제로 쓸 만한가 | 코드에 없다 | 사용성 테스트 (`ux.usability-measure` SUS·과업 성공률) |
