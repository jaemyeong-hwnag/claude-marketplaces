#!/usr/bin/env bash
# start 가 nodemon 이고 Dockerfile 이 NODE_ENV=development 인 Express 앱
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src
cat > package.json <<'JSON'
{"name":"shop-api","scripts":{"start":"nodemon src/server.js"},"dependencies":{"express":"^5.1.0"}}
JSON
printf 'FROM node:22-slim\nENV NODE_ENV=development\nCMD ["npm", "start"]\n' > Dockerfile
printf "const app = require('express')();\napp.get('/', (req, res) => res.json({ ok: true }));\napp.listen(3000);\n" > src/server.js
cat > load.js <<'JS'
import http from 'k6/http';
export const options = { scenarios: { s: { executor: 'constant-arrival-rate', rate: 10, timeUnit: '1s', duration: '5s', preAllocatedVUs: 5 } } };
export default function () { http.get('http://localhost:3000/'); }
JS
git add -A
git commit -qm init
