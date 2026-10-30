#!/usr/bin/env bash
# 주문 · 결제 · 재고 모듈만 있는 작은 저장소
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src
cat > src/order.js <<'JS'
// status: CREATED | PAID | SHIPPED
function createOrder(items) { return { id: Date.now(), items, status: 'CREATED' }; }
module.exports = { createOrder };
JS
cat > src/payment.js <<'JS'
async function charge(orderId, amount) { return { paymentId: `p-${orderId}`, amount }; }
async function refund(paymentId) { return { ok: true }; }
module.exports = { charge, refund };
JS
cat > src/stock.js <<'JS'
function reserve(items) { return true; }
function release(items) { return true; }
module.exports = { reserve, release };
JS
git add . && git commit -qm init
