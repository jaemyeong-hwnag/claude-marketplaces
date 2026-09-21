#!/usr/bin/env bash
# main 브랜치에 커밋 하나가 있는 저장소를 만든다
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
echo a > a.txt
git add a.txt
git commit -qm init
