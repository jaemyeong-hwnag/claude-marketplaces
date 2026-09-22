---
description: 방금 고친 Spring Boot 서비스 메서드의 테스트를 요청하면 aitest-generate 가 발동하고 경계 케이스까지 설계한다
tags: [trigger]
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

Spring Boot 프로젝트 OrderService 의 cancel 메서드를 방금 이렇게 고쳤어. 이 메서드 테스트 작성해줘. 지금은 파일을 만들 수 없으니 테스트 코드를 답변에 보여줘.

```java
@Transactional
public void cancel(Long orderId) {
    Order order = orderRepository.findById(orderId).orElseThrow(() -> new OrderNotFoundException(orderId));
    if (order.getStatus() != OrderStatus.PAID) {
        throw new InvalidOrderStateException(order.getStatus());
    }
    order.cancel();
    paymentClient.refund(orderId);
}
```
