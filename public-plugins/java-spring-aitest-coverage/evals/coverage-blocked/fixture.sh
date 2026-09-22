#!/usr/bin/env bash
# @AiTest 환경이 있는 멀티 모듈 저장소 — app 모듈에 Controller 하나, 테스트는 없다
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p gradle app/src/main/java/com/example/app
echo "// @AiTest 환경" > gradle/ai-test.gradle
echo "ext.aiTestModules = ['app']" > build.gradle
cat > app/src/main/java/com/example/app/PriceController.java <<'JAVA'
package com.example.app;

public class PriceController {

    public long price(long price, int percent) {
        return price - price * percent / 100;
    }
}
JAVA
git add -A
git commit -qm init
