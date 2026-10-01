#!/usr/bin/env bash
# 계측이 없고 start 가 nodemon 인 Express 앱
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src
cat > package.json <<'JSON'
{"name":"shop-api","scripts":{"start":"nodemon src/server.js"},"dependencies":{"express":"^5.1.0"},"devDependencies":{"nodemon":"^3.1.0"}}
JSON
cat > src/server.js <<'JS'
const express = require('express');
const app = express();
app.get('/orders/:id', async (req, res) => {
  await new Promise(r => setTimeout(r, 20));
  res.json({ id: req.params.id });
});
app.listen(3000);
JS
git add -A
git commit -qm init
