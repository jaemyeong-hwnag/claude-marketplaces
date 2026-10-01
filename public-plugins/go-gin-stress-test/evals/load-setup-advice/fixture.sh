#!/usr/bin/env bash
# Gin 주문 서비스. gin.Default() · r.Run() 이고 지연 계측이 없다. 저장소 초기화를 하지 않는다 (하면 Bash 샌드박스가 필요하다)
set -e
cat > go.mod <<'M'
module example.com/order

go 1.25

require (
	github.com/gin-gonic/gin v1.12.0
	github.com/jackc/pgx/v5 v5.7.0
)
M
cat > main.go <<'G'
package main

import (
	"database/sql"

	"github.com/gin-gonic/gin"
	_ "github.com/jackc/pgx/v5/stdlib"
)

func main() {
	db, err := sql.Open("pgx", "postgres://db:5432/orders")
	if err != nil {
		panic(err)
	}
	r := gin.Default()
	r.GET("/orders/:id", func(c *gin.Context) {
		var status string
		_ = db.QueryRowContext(c, "select status from orders where id = $1", c.Param("id")).Scan(&status)
		c.JSON(200, gin.H{"status": status})
	})
	r.Run(":8080")
}
G
