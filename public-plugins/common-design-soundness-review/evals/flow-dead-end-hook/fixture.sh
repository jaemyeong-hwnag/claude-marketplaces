#!/usr/bin/env bash
# ADR 디렉터리만 있는 저장소
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p docs/adr
printf '# ADR\n' > docs/adr/README.md
git add . && git commit -qm init
