---
title: "Bounded Context와 도메인 경계 설정"
source: "https://martinfowler.com/bliki/BoundedContext.html"
source_type: web
captured: 2026-03-08T10:00:00+09:00
processed: 2026-03-08T10:00:05+09:00
status: classified
ai_distill_depth: 4
distill_layer: 1
content_hash: "sha256:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
captured_via: telegram
contexts:
  - resources/ddd-patterns
tags: [ddd, bounded-context, domain-modeling, microservices]
related: []
ai_summary: "Bounded Context는 DDD에서 모델의 적용 범위를 명시적으로 정의하는 패턴. 같은 용어가 다른 컨텍스트에서 다른 의미를 가질 수 있음을 인정하고, 컨텍스트 간 통합은 명시적 번역 레이어를 통해 수행."
ai_suggested_category: "resources/ddd-patterns"
---

> **Executive Summary**: Bounded Context는 모델의 적용 범위를 정의하여, 같은 용어의 다른 의미를 체계적으로 관리하는 DDD 핵심 전략 패턴.

# Bounded Context와 도메인 경계 설정

*출처*: Martin Fowler | 2026-03-08

---

## 핵심 주장

- **모든 모델은 컨텍스트 안에서만 유효하다**: 경계 밖에서 같은 용어가 다른 의미를 가질 수 있음
- **컨텍스트 간 통합은 반드시 명시적 번역을 거쳐야 한다**

## 주요 논거 및 근거

- ==대규모 시스템에서 단일 통합 모델을 유지하려는 시도는 반드시 실패한다==
- 마이크로서비스 아키텍처는 Bounded Context의 물리적 구현

## 실용적 시사점

- **서비스 경계 = Bounded Context 경계** 원칙으로 마이크로서비스 분리
- Anti-Corruption Layer로 레거시 통합
