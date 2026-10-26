---
description: 스킬 이름 없이 논문과 다른 회사 사례를 같이 찾아 달라고 하면 paper-search 가 발동하고 출처별 에이전트를 띄운다
tags: [trigger]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Bash, Skill, Agent, WebSearch, WebFetch]
---

LLM 에이전트의 장기 기억(long-term memory) 관련 논문 몇 편이랑 다른 회사가 실제로 적용한 사례 찾아줘. 결과는 표로 짧게.
