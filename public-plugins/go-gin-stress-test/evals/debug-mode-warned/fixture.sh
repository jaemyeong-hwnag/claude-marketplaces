#!/usr/bin/env bash
# Gin 주문 서비스. 배포 이미지가 GIN_MODE=debug 로 뜬다
set -e
cat > go.mod <<'M'
module example.com/order

go 1.25
M
cat > main.go <<'G'
package main

import "github.com/gin-gonic/gin"

func main() {
	r := gin.New()
	r.GET("/orders", func(c *gin.Context) { c.String(200, "ok") })
	r.Run(":8080")
}
G
cat > Dockerfile <<'D'
FROM golang:1.25
WORKDIR /src
COPY . .
RUN go build -o /app .
ENV GIN_MODE=debug
CMD ["/app"]
D
cat > load.js <<'JS'
import http from "k6/http";
export const options = { scenarios: { s: { executor: "constant-arrival-rate", rate: 50, timeUnit: "1s", duration: "10s", preAllocatedVUs: 20, maxVUs: 200 } } };
export default function () { http.get("http://127.0.0.1:8080/orders"); }
JS
