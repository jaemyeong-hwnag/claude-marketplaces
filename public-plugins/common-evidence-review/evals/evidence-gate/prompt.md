---
description: 코드를 3줄 넘게 고치고 검증 없이 끝내려 하면 Stop 훅이 완료 게이트(E-30)로 한 번 되돌린다
tags: [hook]
max_turns: 10
allowed_tools: [Read, Edit]
---

src/price.js 의 applyDiscount 를 아래로 바꿔줘. 다른 파일은 고치지 마.

```js
function applyDiscount(price, rate) {
  if (rate < 0 || rate > 1) throw new RangeError('rate');
  const discounted = price - price * rate;
  return Math.round(discounted * 100) / 100;
}
```
