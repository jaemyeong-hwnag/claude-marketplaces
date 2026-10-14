---
description: 커밋 전에 키 · 비밀번호와 .env ignore 여부를 봐 달라는 요청에 secret-review 가 발동하고 .env 를 짚는다
tags: [trigger]
max_turns: 10
allowed_tools: [Read, Glob, Grep, Bash, Skill]
---

커밋하기 전에 이 프로젝트에 API 키나 비밀번호 같은 게 코드에 들어가 있는지, 그리고 환경 변수 파일이 gitignore 돼 있는지 확인해줘. 고치지는 말고 결과만 짧게.
