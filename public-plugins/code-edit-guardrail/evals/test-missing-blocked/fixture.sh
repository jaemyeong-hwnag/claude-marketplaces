#!/usr/bin/env bash
# 가드레일 설정이 있는 저장소. src/ 는 코드, *.test.ts 는 테스트
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src .claude
cat > .claude/code-edit-guardrail.json <<'JSON'
{ "test": { "code": ["src/**/*.ts"], "tests": ["*.test.ts"] } }
JSON
echo 'export const VAT = 0.1' > src/price.ts
echo 'import { VAT } from "./price"' > src/price.test.ts
git add -A
git commit -qm init
