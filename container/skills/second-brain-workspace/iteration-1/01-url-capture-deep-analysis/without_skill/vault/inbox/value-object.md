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
