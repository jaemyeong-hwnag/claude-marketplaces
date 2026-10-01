#!/usr/bin/env bash
# Spring Boot 주문 서비스. 기본 설정이 루트 로그를 DEBUG 로 둔다
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src/main/resources
cat > build.gradle <<'G'
plugins {
  id 'java'
  id 'org.springframework.boot' version '3.5.16'
}
dependencies {
  implementation 'org.springframework.boot:spring-boot-starter-web'
}
G
printf 'logging.level.root=DEBUG\n' > src/main/resources/application.properties
cat > load.js <<'JS'
import http from "k6/http";
export const options = { scenarios: { s: { executor: "constant-arrival-rate", rate: 50, timeUnit: "1s", duration: "10s", preAllocatedVUs: 20, maxVUs: 200 } } };
export default function () { http.get("http://127.0.0.1:8080/orders"); }
JS
git add -A
git commit -qm init
