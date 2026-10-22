---
description: 방금 고친 Kotlin Spring Boot 서비스 메서드의 테스트를 요청하면 kotlin-aitest-generate 가 발동하고 경계 케이스까지 설계한다
tags: [trigger]
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

Kotlin Spring Boot 프로젝트 OrderService 의 cancel 함수를 방금 이렇게 고쳤어. 이 함수 테스트 작성해줘. 지금은 파일을 만들 수 없으니 테스트 코드를 답변에 보여줘.

```kotlin
@Transactional
fun cancel(orderId: Long, reason: String? = null) {
    val order = orderRepository.findByIdOrNull(orderId) ?: throw OrderNotFoundException(orderId)
    check(order.status == OrderStatus.PAID) { "취소할 수 없는 상태: ${order.status}" }
    order.cancel(reason ?: "고객 요청")
    paymentClient.refund(orderId)
}
```
