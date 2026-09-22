---
description: Controller 를 고치고 테스트 없이 끝내려 하면 Stop 게이트가 완료를 막는다 (C-01)
tags: [hook]
max_turns: 6
allowed_tools: [Read, Edit]
---

app/src/main/java/com/example/app/PriceController.java 의 price 메서드에서 percent 가 100 이상이면 0 을 돌려주도록 고쳐줘. 테스트는 쓰지 말고 그 파일만 고치고 끝내.
