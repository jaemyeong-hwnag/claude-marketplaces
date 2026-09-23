---
description: 스킬 이름 없이 서비스 완성도 점검을 요청하면 completeness-review 가 발동해 위험도와 실천 범위를 따로 낸다
tags: [trigger]
max_turns: 15
allowed_tools: [Read, Glob, Grep, Skill, Bash]
---

이 API 서버, 운영에 내놔도 될 만큼 갖춰졌는지 점검해줘. 질문은 하지 말고 저장소만 보고 자동으로 판정할 수 있는 범위만 봐.
