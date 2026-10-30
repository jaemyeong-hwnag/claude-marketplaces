---
description: 플러그인 에이전트에 무시되는 permissionMode 를 쓰면 훅이 막는다
tags: [hook]
max_turns: 6
allowed_tools: [Write]
---

internal-plugins/order-sync/agents/order-reviewer.md 파일을 만들어줘. 내용은 아래 그대로야. 다른 내용은 넣지 마.

```
---
name: order-reviewer
description: 주문을 검토한다
tools: Read, Grep
permissionMode: plan
---

주문을 검토한다.
```
