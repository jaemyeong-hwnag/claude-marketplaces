---
description: 스킬 이름 없이 플로우 설계를 요청하면 설계안을 낸 뒤 design-soundness-review 로 구현 전에 검토한다
tags: [trigger]
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Skill, Agent]
---

src 에 주문 · 결제 · 재고 모듈이 있어. 결제가 끝난 주문을 취소하는 플로우를 설계해줘 — 환불 실패랑 재고 복구도 고려해서. 아직 구현은 하지 말고, 설계가 앞뒤가 맞는지까지 확인한 결과를 짧게 줘.
