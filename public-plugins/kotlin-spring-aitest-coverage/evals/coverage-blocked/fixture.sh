#!/usr/bin/env bash
# @AiTest 환경 블록이 있는 Kotlin DSL 멀티 모듈 저장소 — app 모듈에 Controller 하나, aiTest 는 없다
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p app/src/main/kotlin/com/example/app
printf 'rootProject.name = "eval"\ninclude("app")\n' > settings.gradle.kts
cat > app/build.gradle.kts <<'KTS'
plugins {
    kotlin("jvm")
}

// >>> kotlin-spring-aitest-coverage
// @AiTest 환경
// <<< kotlin-spring-aitest-coverage
KTS
cat > app/src/main/kotlin/com/example/app/PriceController.kt <<'KT'
package com.example.app

import org.springframework.web.bind.annotation.RestController

@RestController
class PriceController {
    fun price(price: Long, percent: Int): Long {
        return price - price * percent / 100
    }
}
KT
git add -A
git commit -qm init
