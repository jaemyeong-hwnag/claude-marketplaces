---
type: regex
target: last_message
pattern: "DS-01|훅|[Hh]ook|차단"
---

차단(exit 2 · stderr)은 trace 에 남지 않는다 — 훅이 막은 것을 답이 전하는지로 본다. 본문을 2줄로 둬서 완료 게이트(`DS-30`, 3줄 이상)가 마지막 답을 바꾸지 않게 한다.
