#!/usr/bin/env bash
# 할인 함수가 있는 작은 저장소
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src
cat > src/price.js <<'JS'
function applyDiscount(price, rate) {
  return price - price * rate;
}
module.exports = { applyDiscount };
JS
git add . && git commit -qm init
