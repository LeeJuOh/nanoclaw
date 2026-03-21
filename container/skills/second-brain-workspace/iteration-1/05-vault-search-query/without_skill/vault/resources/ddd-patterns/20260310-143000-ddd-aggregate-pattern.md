# Domain-Driven Design의 Aggregate 패턴

## 핵심 개념

Aggregate는 DDD(Domain-Driven Design)에서 데이터 변경의 트랜잭션 경계(transaction boundary)를 정의하는 클러스터 패턴이다. 관련된 도메인 객체들을 하나의 단위로 묶어 일관성(consistency)을 보장한다.

## Aggregate Root

Aggregate 내부의 모든 객체에 대한 접근은 반드시 Aggregate Root를 통해서만 이루어져야 한다. 외부에서 Aggregate 내부 객체를 직접 참조하거나 수정하는 것은 허용되지 않는다. Aggregate Root는 전체 Aggregate의 불변식(invariant)을 보호하는 게이트키퍼 역할을 한다.

## 설계 원칙

### Aggregate를 작게 유지하라
Aggregate는 가능한 한 작게 설계해야 한다. 큰 Aggregate는 동시성 문제를 야기하고, 트랜잭션 충돌 가능성을 높인다. 하나의 Aggregate에 너무 많은 엔티티를 포함시키면 성능과 확장성에 악영향을 미친다.

### ID로만 참조하라 (Reference by ID Only)
다른 Aggregate를 참조할 때는 객체 참조가 아닌 ID(식별자)로만 참조해야 한다. 이는 Aggregate 간의 결합도를 낮추고, 각 Aggregate가 독립적인 트랜잭션 경계를 유지할 수 있게 해준다.

### 하나의 트랜잭션에서 하나의 Aggregate만 수정하라
단일 트랜잭션 내에서 여러 Aggregate를 동시에 수정하는 것은 피해야 한다. 여러 Aggregate 간의 최종 일관성(eventual consistency)은 도메인 이벤트를 통해 달성한다.

## 참고

- Vaughn Vernon, "Implementing Domain-Driven Design"
- Eric Evans, "Domain-Driven Design: Tackling Complexity in the Heart of Software"
