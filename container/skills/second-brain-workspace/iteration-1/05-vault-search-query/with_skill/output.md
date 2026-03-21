볼트에서 관련 노트를 찾았어요.

**관련 노트**: [Domain-Driven Design의 Aggregate 패턴](resources/ddd-patterns/20260310-143000-ddd-aggregate-pattern.md) (Martin Fowler, 2026-03-10)

---

## DDD에서 Aggregate 경계 설정 시 주의할 점

볼트 노트를 기반으로 정리하면:

### 1. 트랜잭션 일관성의 경계로 설계하라
Aggregate는 트랜잭션 일관성의 경계입니다. **하나의 트랜잭션에서 하나의 Aggregate만 수정**해야 합니다. 여러 Aggregate를 한 트랜잭션에서 동시에 수정하려고 하면 동시성 충돌이 발생하고, 시스템 확장이 어려워집니다.

### 2. Aggregate Root를 통해서만 접근하라
내부 객체에 직접 접근하면 불변성(invariant)이 깨질 수 있습니다. 반드시 Aggregate Root를 통해서만 내부 객체를 조작해야 합니다. 예를 들어 주문(Order)과 주문 항목(OrderItem)이 하나의 Aggregate라면, OrderItem은 반드시 Order를 통해서만 추가/수정해야 합니다.

### 3. Aggregate를 가능한 작게 유지하라
Aggregate가 커지면 성능 문제와 동시성 충돌이 발생합니다. 노트에서도 "Aggregate 경계를 잘못 설정하면 성능 문제와 동시성 충돌이 발생한다"고 강조하고 있습니다. 꼭 함께 변경되어야 하는 객체들만 하나의 Aggregate로 묶으세요.

### 4. Aggregate 간 참조는 ID로만 하라
Aggregate 간에 직접 객체 참조를 갖지 말고, ID(식별자)로만 참조해야 합니다. 이렇게 하면 Aggregate 간 결합도가 낮아지고, 각 Aggregate를 독립적으로 로드하고 수정할 수 있습니다.

---

> 볼트의 `resources/ddd-patterns` 노트를 기반으로 답변했습니다. 더 깊이 알고 싶은 부분이 있으면 말씀해주세요.
