#!/usr/bin/env bash
# express API 하나 — 린트 CI 만 있고 시크릿 스캔 · SLO · 롤백은 없다
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src .github/workflows
cat > package.json <<'JSON'
{ "name": "orders-api", "private": true,
  "scripts": { "lint": "eslint .", "test": "node --test" },
  "dependencies": { "express": "^4.19.0" },
  "devDependencies": { "eslint": "^9.0.0" } }
JSON
cat > .github/workflows/ci.yml <<'YAML'
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm run lint && npm test
YAML
cat > src/app.js <<'JS'
import express from 'express';
const app = express();
app.get('/health', (req, res) => res.send('ok'));
app.get('/orders', async (req, res) => res.json([]));
app.listen(3000);
JS
git add -A
git commit -qm init
