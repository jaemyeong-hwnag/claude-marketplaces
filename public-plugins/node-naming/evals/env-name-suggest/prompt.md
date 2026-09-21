---
description: Node 서비스의 환경 변수 · npm script 이름을 지어 달라는 요청에 node-name-create 가 발동하고 UPPER_SNAKE_CASE 로 답한다
tags: [trigger]
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

Express 로 만든 주문 서비스야. 주문 DB 접속 주소랑 결제 API 타임아웃(밀리초)을 process.env 로 받으려고 하는데 환경 변수 이름을 뭐로 할지, 그리고 package.json 에 단위 테스트만 돌리는 npm script 이름도 하나 지어줘. 이름 후보만 짧게.
