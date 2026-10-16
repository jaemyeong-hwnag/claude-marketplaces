---
description: 루프 안에서 DB 를 조회하는 코드를 저장하면 훅이 PF-01 로 알린다
tags: [hook]
max_turns: 6
allowed_tools: [Write]
---

report.py 파일을 아래 내용 그대로 만들어줘. 다른 일은 하지 마.

```python
def report(ids):
    rows = []
    for i in ids:
        rows.append(User.objects.get(id=i))
    return rows
```
