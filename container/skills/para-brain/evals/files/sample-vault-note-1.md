---
title: "Domain-Driven Design의 Aggregate 패턴"
source: "https://martinfowler.com/bliki/DDD_Aggregate.html"
source_type: web
captured: 2026-03-10T14:30:00+09:00
processed: 2026-03-10T14:30:05+09:00
status: classified
ai_distill_depth: 4
distill_layer: 1
content_hash: "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
captured_via: telegram
contexts:
  - resources/ddd-patterns
tags: [ddd, aggregate, domain-modeling, consistency-boundary]
related: []
ai_summary: "Aggregate는 트랜잭션 일관성 경계를 정의하는 DDD의 핵심 전술 패턴. Entity와 Value Object의 클러스터로 구성되며, 외부에서는 Aggregate Root를 통해서만 접근해야 한다."
ai_suggested_category: "resources/ddd-patterns"
---

> **Executive Summary**: Aggregate는 트랜잭션 경계를 정의하는 DDD 핵심 패턴으로, 작게 유지하고 ID 참조로 연결하는 것이 실전 핵심.

# Domain-Driven Design의 Aggregate 패턴

*출처*: Martin Fowler | 2026-03-10

---

## 핵심 주장

- **Aggregate는 트랜잭션 일관성 경계를 정의하는 클러스터**: 하나의 트랜잭션에서 하나의 Aggregate만 수정해야 한다
- **외부 참조는 Aggregate Root를 통해서만**: 내부 Entity에 직접 접근하면 일관성이 깨진다

## 주요 논거 및 근거

- Aggregate를 작게 유지해야 ==동시성 충돌이 줄어든다==
- 다른 Aggregate는 ID로만 참조 — 객체 참조 금지

## 인사이트

DDD에서 가장 흔한 실수는 Aggregate를 너무 크게 잡는 것. 거대한 Aggregate는 락 경합의 원인이 된다.

## 실용적 시사점

- **하나의 트랜잭션 = 하나의 Aggregate 수정** 원칙을 준수
- Aggregate 간에는 ID 참조만 사용

## 한계 및 열린 질문

- 어디까지가 "하나의 트랜잭션"인지 도메인마다 다름
- 이벤추얼 컨시스턴시와의 트레이드오프
