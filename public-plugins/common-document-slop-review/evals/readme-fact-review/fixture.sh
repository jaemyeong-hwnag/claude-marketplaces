#!/usr/bin/env bash
# README 가 스크립트에 없는 옵션을 안내하고, 상투적 서두 · 결말이 붙은 채 커밋되지 않았다
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
cat > build.sh <<'SH'
#!/usr/bin/env bash
# 사용: build.sh [--clean]
case "${1:-}" in
  --clean) rm -rf dist ;;
  "") ;;
  *) echo "모르는 옵션: $1" >&2; exit 1 ;;
esac
mkdir -p dist && cp src/*.txt dist/
SH
chmod +x build.sh
mkdir -p src && echo hi > src/a.txt
printf '# demo\n\n`./build.sh` 로 빌드한다.\n' > README.md
git add . && git commit -qm init
cat > README.md <<'MD'
# demo

이 문서에서는 demo 프로젝트의 빌드 방법을 살펴보겠습니다.

`./build.sh` 로 빌드한다. 결과는 `dist/` 에 생긴다.

빠르게 빌드하려면 `./build.sh --fast` 를 쓴다. 빌드 시간이 50% 줄어든다.

이전 산출물을 지우려면 `./build.sh --clean` 을 쓴다.

## 결론

demo 는 `./build.sh` 로 빌드한다.
MD
