#!/usr/bin/env bash
# Dockerfile 이 개발 서버(nest start --watch)로 띄우는 NestJS 앱
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src load
cat > package.json <<'JSON'
{
  "name": "orders",
  "scripts": { "build": "nest build", "start": "nest start", "start:dev": "nest start --watch", "start:prod": "node dist/main" },
  "dependencies": { "@nestjs/common": "^12.1.2", "@nestjs/core": "^12.1.2", "@nestjs/platform-express": "^12.1.2" }
}
JSON
printf 'FROM node:22-slim\nWORKDIR /app\nCOPY . .\nRUN npm ci\nCMD ["npm", "run", "start:dev"]\n' > Dockerfile
printf "import { NestFactory } from '@nestjs/core';\nimport { AppModule } from './app.module';\nNestFactory.create(AppModule, { logger: ['error', 'warn', 'log'] }).then((app) => app.listen(3000));\n" > src/main.ts
cat > load/smoke.js <<'JS'
import http from 'k6/http';
export const options = { vus: 1, iterations: 1 };
export default function () { http.get('http://localhost:3000/orders/1'); }
JS
git add -A
git commit -qm init
