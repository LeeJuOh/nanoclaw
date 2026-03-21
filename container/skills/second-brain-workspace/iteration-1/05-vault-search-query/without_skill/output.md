# DDD에서 Aggregate 경계를 설정할 때 주의할 점

> 질문: "DDD에서 Aggregate 경계를 설정할 때 주의할 점이 뭐야?"

## 볼트 참조 노트

- `resources/ddd-patterns/20260310-143000-ddd-aggregate-pattern.md` — Domain-Driven Design의 Aggregate 패턴

---

## 답변

Aggregate 경계를 설정할 때 주의해야 할 핵심 원칙들을 정리하면 다음과 같습니다.

### 1. Aggregate를 가능한 한 작게 유지하라

볼트 노트에도 기록되어 있듯이, 큰 Aggregate는 **동시성 문제**를 야기하고 **트랜잭션 충돌 가능성**을 높입니다. 하나의 Aggregate에 너무 많은 엔티티를 포함시키면 성능과 확장성 모두에 악영향을 미칩니다. "진짜 불변식(true invariant)"을 함께 보호해야 하는 최소한의 객체만 하나의 Aggregate에 포함시키세요.

### 2. 트랜잭션 경계 = Aggregate 경계

Aggregate는 곧 트랜잭션 경계입니다. **하나의 트랜잭션에서 하나의 Aggregate만 수정**하는 것이 원칙입니다. 만약 하나의 유스케이스에서 여러 Aggregate를 동시에 수정해야 한다면, 경계 설정이 잘못되었을 가능성이 높습니다. 여러 Aggregate 간의 일관성이 필요한 경우에는 **도메인 이벤트(Domain Event)**를 통한 **최종 일관성(eventual consistency)**으로 해결합니다.

### 3. 다른 Aggregate는 ID로만 참조하라 (Reference by ID Only)

Aggregate 간에 객체 참조(object reference)를 사용하면 경계가 모호해지고 결합도가 높아집니다. 반드시 **ID(식별자)로만 참조**하여 각 Aggregate가 독립적인 트랜잭션 경계를 유지하도록 해야 합니다. 이는 마이크로서비스 전환 시에도 자연스러운 분리 단위가 됩니다.

### 4. Aggregate Root를 통해서만 접근하라

외부에서 Aggregate 내부 객체를 직접 참조하거나 수정하면 불변식이 깨질 수 있습니다. 모든 접근은 **Aggregate Root**를 통해서만 이루어져야 하며, Root가 전체 Aggregate의 불변식을 보호하는 게이트키퍼 역할을 합니다.

### 5. 비즈니스 규칙(불변식) 기준으로 경계를 결정하라

기술적 편의가 아니라 **비즈니스 불변식**을 기준으로 경계를 그어야 합니다. "이 데이터가 변경될 때 반드시 함께 일관성을 유지해야 하는 데이터가 무엇인가?"를 질문하고, 그 답이 곧 Aggregate의 경계가 됩니다. 단순히 연관관계가 있다고 해서 같은 Aggregate에 넣어서는 안 됩니다.

### 6. 실용적 관점에서의 추가 고려사항

- **경합(contention) 분석**: 동시에 여러 사용자가 수정할 수 있는 영역이라면 Aggregate를 더 잘게 쪼개야 합니다.
- **결과적으로 일관성이 허용되는가**: 비즈니스적으로 즉시 일관성이 필수가 아니라면 별도 Aggregate로 분리하고 이벤트로 동기화하세요.
- **Aggregate 크기가 커지는 신호**: Repository에서 로딩 시간이 길어지거나, 낙관적 잠금 충돌이 빈번하다면 Aggregate가 너무 큰 것입니다.

---

## 참고 자료

- Vaughn Vernon, "Implementing Domain-Driven Design"
- Eric Evans, "Domain-Driven Design: Tackling Complexity in the Heart of Software"
- Vaughn Vernon, "Effective Aggregate Design" (3-part series)
