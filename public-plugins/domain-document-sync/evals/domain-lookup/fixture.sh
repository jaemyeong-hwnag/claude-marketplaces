#!/usr/bin/env bash
# 주문 · 결제 두 도메인 문서가 있는 저장소. 환불 규칙은 order/cancel.md 에만 있다
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src/order src/billing docs/domain/order docs/domain/billing
echo 'export function cancelOrder() {}' > src/order/cancel.ts
echo 'export function charge() {}' > src/billing/charge.ts
cat > docs/domain/_index.md <<'MD'
# 도메인 카탈로그

| 도메인 | 한 줄 | 트리거 | 경로 |
|---|---|---|---|
| **주문 (order)** | 주문 생성 · 취소 · 환불 | **말**: 주문 · 취소 · 환불 · **식별자**: `cancelOrder` · **경로**: `/orders/{id}/cancel` | [order/](order/_meta.md) |
| **결제 (billing)** | 카드 결제 승인 · 정산 | **말**: 결제 · 승인 · 정산 · **식별자**: `charge` | [billing/](billing/_meta.md) |
MD
cat > docs/domain/order/_meta.md <<'MD'
---
code:
  - "src/order/**"
---

# 주문 (order) — 도메인 메타

| 파트 | 파일 | 언제 본다 |
|---|---|---|
| 취소 · 환불 | [cancel.md](cancel.md) | 주문 취소, 환불 금액 계산 |
MD
cat > docs/domain/order/cancel.md <<'MD'
# 주문 — 취소 · 환불

- 출고 전 취소는 전액 환불한다.
- 출고 뒤 취소는 배송비 3,000원을 뺀 부분 환불이다.

> 코드: `src/order/cancel.ts` `cancelOrder`
MD
cat > docs/domain/billing/_meta.md <<'MD'
---
code:
  - "src/billing/**"
---

# 결제 (billing) — 도메인 메타

카드 승인과 정산. 환불 금액은 주문 도메인이 정한다.
MD
git add -A
git commit -qm init
