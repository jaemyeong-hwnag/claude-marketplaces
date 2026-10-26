#!/usr/bin/env bash
# 빈 배열 처리를 고친 변경에 요청과 무관한 util.js 정리가 섞여 있다 (커밋 안 됨)
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
cat > parse.js <<'JS'
function parse(items) {
  return items[0].split(',');
}
module.exports = { parse };
JS
cat > util.js <<'JS'
function pad(s, n) { return String(s).padStart(n, '0'); }
module.exports = { pad };
JS
git add . && git commit -qm init
cat > parse.js <<'JS'
function parse(items) {
  if (items.length === 0) return [];
  return items[0].split(',');
}
module.exports = { parse };
JS
cat > util.js <<'JS'
/**
 * Pads a value with leading zeros.
 */
function pad(value, width) {
  const text = String(value);
  return text.padStart(width, '0');
}

module.exports = { pad };
JS
