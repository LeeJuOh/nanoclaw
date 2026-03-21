---
title: "Domain-Driven Design의 Aggregate 패턴"
source: "https://martinfowler.com/bliki/DDD_Aggregate.html"
tags: [ddd, aggregate, domain-modeling]
created: 2026-03-15
---

# Domain-Driven Design의 Aggregate 패턴

Aggregate는 DDD에서 데이터 변경의 단위로 취급되는 관련 객체의 클러스터입니다. 각 Aggregate는 루트 엔티티를 가지며, 외부에서는 이 루트를 통해서만 내부 객체에 접근할 수 있습니다.
