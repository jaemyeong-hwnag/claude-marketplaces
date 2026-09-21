---
description: 서로 의존하는 plugin.json 두 개를 만들면 훅이 순환(D-03)을 알린다
tags: [hook]
max_turns: 8
allowed_tools: [Write]
---

파일 두 개를 만들어줘. internal-plugins/a-sync/.claude-plugin/plugin.json 에는 {"name": "a-sync", "version": "0.1.0", "dependencies": ["b-sync"]}, internal-plugins/b-sync/.claude-plugin/plugin.json 에는 {"name": "b-sync", "version": "0.1.0", "dependencies": ["a-sync"]}. 만든 뒤 문제가 있으면 알려줘.
