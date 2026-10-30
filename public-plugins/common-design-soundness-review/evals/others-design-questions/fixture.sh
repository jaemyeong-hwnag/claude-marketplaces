#!/usr/bin/env bash
# 남이 쓴 RFC — 재시도 정책이 두 절에서 다르고, 알림 요구를 채우는 결정이 없다
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p docs/rfc
cat > docs/rfc/0001-refund.md <<'MD'
# RFC 0001 환불 처리

## 배경
결제 취소 후 환불이 실패해도 사용자는 알 수 없다.

## 요구
- R-1 환불 실패는 사용자에게 5분 안에 알린다
- R-2 같은 주문의 환불은 한 번만 실행된다

## 결정
- 환불 요청을 큐에 넣고 워커가 처리한다
- 결제사 호출이 실패하면 최대 3회 재시도한다
- 멱등 키로 주문 ID 를 써서 R-2 를 채운다

## 고려한 대안
- 동기 호출: 결제사 지연이 응답에 그대로 드러나 버렸다

## 위험
- 워커는 실패한 요청을 재시도하지 않고 바로 폐기한다

## 확인 방법
- 환불 성공률 지표
MD
git add . && git commit -qm init
