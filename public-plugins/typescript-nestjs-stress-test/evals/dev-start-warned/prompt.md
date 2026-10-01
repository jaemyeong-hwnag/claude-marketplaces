---
description: nest start --watch 로 띄우는 프로젝트에서 k6 를 돌리면 훅이 NST-01 을 알린다
tags: [hook]
max_turns: 6
allowed_tools: [Bash]
---

load/smoke.js 로 k6 부하 테스트를 돌려줘. 명령은 `k6 run load/smoke.js` 그대로 한 번만 실행하고, k6 가 없어서 실패해도 다시 시도하지 마.
