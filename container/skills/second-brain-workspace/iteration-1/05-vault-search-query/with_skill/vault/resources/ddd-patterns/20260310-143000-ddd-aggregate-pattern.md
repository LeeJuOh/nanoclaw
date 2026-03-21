---
title: "Domain-Driven Design의 Aggregate 패턴"
source: "https://martinfowler.com/bliki/DDD_Aggregate.html"
source_type: web
captured: 2026-03-10T14:30:00+09:00
processed: 2026-03-10T14:30:05+09:00
status: classified
tags: [ddd, aggregate, domain-modeling]
contexts:
  - resources/ddd-patterns
ai_summary: "Aggregate는 DDD에서 데이터 변경의 단위가 되는 클러스터로, 하나의 루트 엔티티를 통해서만 접근 가능하다."
captured_via: telegram
---

# Domain-Driven Design의 Aggregate 패턴

*출처*: Martin Fowler | 2026-03-10

---

## 핵심 주장

- Aggregate는 트랜잭션 일관성의 경계이다: 하나의 트랜잭션에서 하나의 Aggregate만 수정해야 한다
- Aggregate Root를 통해서만 내부 객체에 접근해야 외부에서의 불변성 위반을 방지할 수 있다

## 주요 논거 및 근거

- 주문(Order)과 주문 항목(OrderItem)은 하나의 Aggregate로 묶이며, Order가 Root 역할을 한다

## 인사이트

Aggregate 경계를 잘못 설정하면 성능 문제와 동시성 충돌이 발생한다.

## 실용적 시사점

- Aggregate를 가능한 작게 유지하라
- Aggregate 간 참조는 ID로만 하라
