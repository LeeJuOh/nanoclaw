# URL Capture Output

## Captured URL
https://martinfowler.com/bliki/ValueObject.html

## Note Created
**File:** `vault/inbox/value-object.md`

### Content

```markdown
---
title: "Value Object - Martin Fowler"
source: "https://martinfowler.com/bliki/ValueObject.html"
tags: [ddd, value-object, domain-modeling, immutability]
captured: 2026-03-21
status: inbox
---

# Value Object - Martin Fowler

## Summary

A Value Object is a small, immutable object whose equality is based on its value rather than its identity. Two Value Objects are considered equal when they hold the same value, even if they are distinct instances. Common examples include Money, Date Range, and Address.

## Key Concepts

- **Equality by value, not identity**: Unlike Entities, Value Objects do not carry a unique identifier. Two instances with the same fields are interchangeable.
- **Immutability**: Value Objects should be immutable. Once created, their state cannot change. Any "modification" produces a new instance.
- **Relationship to Aggregates**: In DDD, Value Objects frequently appear inside Aggregates to model concepts that do not need their own lifecycle or identity.
- **Model simplification**: By replacing unnecessary Entities with Value Objects, the domain model becomes simpler and has fewer objects that require identity tracking.

## Analysis

Fowler argues that Value Objects are **underused** in enterprise applications. Developers habitually model every concept as an Entity, which introduces unnecessary complexity --- identity management, repository lookups, and lifecycle tracking for things that don't need them.

The practical guideline is: if two instances with the same data are interchangeable, model them as a Value Object, not an Entity. This reduces Aggregate complexity, makes reasoning about invariants easier, and often improves performance (immutable objects are inherently thread-safe and cacheable).

### Connection to existing notes

This note directly relates to **Domain-Driven Design의 Aggregate 패턴** (`resources/ddd-patterns/ddd-aggregate-pattern.md`). Value Objects are the building blocks that live *inside* Aggregates alongside Entities.

## Source Quote

> "A Value Object is a small object that represents a simple entity whose equality is not based on identity. Two Value Objects are equal when they have the same value, not necessarily being the same object."
```

---

## Classification Suggestion

**Recommended location:** `resources/ddd-patterns/value-object.md` (existing folder)

### Reasoning

1. **Strong topical match with existing folder**: The vault already contains `resources/ddd-patterns/ddd-aggregate-pattern.md`. This new note covers Value Objects, which is a closely related DDD tactical pattern. Grouping them together in the same folder creates a coherent cluster of DDD pattern references.

2. **Why `resources/` and not `projects/` or `areas/`**:
   - **Resources** are reference material on topics of interest --- this is a conceptual explanation of a DDD building block, not tied to an active project or ongoing area of responsibility.
   - **Projects** would apply if there were a specific, time-bound deliverable using Value Objects.
   - **Areas** would apply if DDD were an ongoing responsibility (e.g., "frontend" is an area). DDD patterns are better classified as reference material unless the user is actively maintaining a DDD practice.

3. **Tag alignment**: The existing note shares tags `ddd` and `domain-modeling`. The new note adds `value-object` and `immutability`, enriching the tag taxonomy within the same resource folder.

4. **Cross-linking opportunity**: After moving, add a bidirectional link between `ddd-aggregate-pattern.md` and `value-object.md`, since Fowler explicitly discusses Value Objects as components within Aggregates.
