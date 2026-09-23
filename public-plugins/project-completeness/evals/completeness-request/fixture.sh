#!/usr/bin/env bash
# express API 하나 — 린트 CI 만 있다. 저장소 초기화를 하지 않는다 (하면 eval-all 이 Bash 를 줘 샌드박스가 필요하다)
set -e
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
