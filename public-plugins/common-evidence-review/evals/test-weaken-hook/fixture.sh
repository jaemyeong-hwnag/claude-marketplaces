#!/usr/bin/env bash
# 테스트 둘이 있는 저장소
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p test
cat > test/price.test.js <<'JS'
const { applyDiscount } = require('../src/price');
it('applies rate', () => { expect(applyDiscount(100, 0.1)).toBe(90); });
it('rounds to cents', () => { expect(applyDiscount(9.99, 0.15)).toBe(8.49); });
JS
git add . && git commit -qm init
