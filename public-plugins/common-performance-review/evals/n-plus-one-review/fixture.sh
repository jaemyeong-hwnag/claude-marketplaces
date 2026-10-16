#!/usr/bin/env bash
# 주문마다 고객을 따로 조회하는 변경이 커밋되지 않은 채 있다
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p orders
printf 'from .models import Order\n\n\ndef order_rows():\n    return []\n' > orders/views.py
git add . && git commit -qm init
cat > orders/views.py <<'PY'
from .models import Order, Customer


def order_rows():
    rows = []
    for order in Order.objects.all():
        customer = Customer.objects.get(id=order.customer_id)
        rows.append({"id": order.id, "customer": customer.name})
    return rows
PY
