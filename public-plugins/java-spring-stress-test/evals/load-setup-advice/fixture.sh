#!/usr/bin/env bash
# Spring Boot 주문 서비스. Prometheus 레지스트리는 있지만 히스토그램 · Tomcat 지표 설정이 없다. 저장소 초기화를 하지 않는다 (하면 Bash 샌드박스가 필요하다)
set -e
mkdir -p src/main/java/com/example/order src/main/resources
cat > build.gradle <<'G'
plugins {
  id 'java'
  id 'org.springframework.boot' version '3.5.16'
  id 'io.spring.dependency-management' version '1.1.7'
}
dependencies {
  implementation 'org.springframework.boot:spring-boot-starter-web'
  implementation 'org.springframework.boot:spring-boot-starter-actuator'
  implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
  runtimeOnly 'io.micrometer:micrometer-registry-prometheus'
  runtimeOnly 'org.postgresql:postgresql'
}
G
cat > src/main/resources/application.yml <<'Y'
management:
  endpoints:
    web:
      exposure:
        include: health,prometheus
spring:
  datasource:
    url: jdbc:postgresql://db:5432/orders
Y
cat > src/main/java/com/example/order/OrderController.java <<'J'
package com.example.order;

import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class OrderController {
    private final OrderRepository repository;

    public OrderController(OrderRepository repository) { this.repository = repository; }

    @GetMapping("/orders")
    public List<Order> orders() { return repository.findTop20ByOrderByIdDesc(); }
}
J
