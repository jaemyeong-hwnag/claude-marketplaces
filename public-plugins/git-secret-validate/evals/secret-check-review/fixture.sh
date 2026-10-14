#!/usr/bin/env bash
# .env 가 ignore 되지 않았고 settings.py 에 비밀번호가 직접 들어 있다
set -e
git init -q -b work .
git config user.email eval@example.com
git config user.name eval
printf 'print("hello")\n' > app.py
git add app.py
git commit -qm init
printf 'DEBUG=1\n' > .env
printf 'DB_PASSWORD = "%s"\n' "s3cr3t""P4ssw0rd!" > settings.py
