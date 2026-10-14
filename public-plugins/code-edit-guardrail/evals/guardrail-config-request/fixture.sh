#!/usr/bin/env bash
# TypeScript 저장소. lint 스크립트가 있고 테스트는 *.test.ts
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src
cat > package.json <<'JSON'
{ "name": "cart", "private": true, "scripts": { "lint": "eslint src", "test": "vitest run" } }
JSON
echo 'export const total = (xs: number[]) => xs.reduce((a, b) => a + b, 0)' > src/cart.ts
echo 'import { total } from "./cart"' > src/cart.test.ts
git add -A
git commit -qm init
