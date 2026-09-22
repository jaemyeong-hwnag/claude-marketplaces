---
description: Spring Boot 서비스 메서드 테스트를 써 달라는 요청에 aitest-generate 가 발동하고 실패 · 경계 케이스까지 설계한다
tags: [trigger]
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

Spring Boot 프로젝트에서 OrderService.cancel(Long orderId) 메서드를 방금 고쳤어. 결제 완료 주문만 취소되고, 없는 주문이면 OrderNotFoundException 을 던져. 이 메서드 테스트를 어떤 케이스로 짤지 목록만 보여줘. 파일은 만들지 마.
