# Semantic Derivation Model

## Purpose

The **Semantic Derivation Model** defines how Dipole derives *meaning* from immutable events and snapshots.

Semantic derivation is where Dipole explains *why* something happened, not merely *what* happened.  
It is the foundation of Dipole’s pedagogical value.

Semantics are **derived**, **additive**, and **non-authoritative**.

---

## Core Definition

**Semantic Derivation** is the process of computing explanatory meaning from:
- events
- snapshots
- derived state
- architectural context (architecture, ABI, calling conventions)

Semantic information:
- does not alter history
- does not mutate state
- may evolve over time
- may have multiple valid interpretations

---

## Design Principle

> **Meaning is layered on top of truth, never embedded within it.**

Events and snapshots remain factual.  
Semantics interpret those facts.

---

## What Semantic Derivation Produces

Semantic derivation may produce:

- stop reason explanations
- register change causality
- stack growth or unwinding explanations
- calling convention interpretations
- control-flow explanations
- data movement narratives
- pedagogical annotations

These outputs are **not facts** — they are interpretations.

---

## Semantics Are Not Events

Semantic data must never be recorded as events.

Reasons:
- semantics may change as understanding improves
- multiple explanations may coexist
- pedagogy should evolve independently of captures

Embedding meaning into events would permanently fossilise interpretation.

---

## Semantics Are Not State

Semantic data is **not derived state** in the interactive sense.

Unlike derived state:
- semantics may be persisted
- semantics may be versioned
- semantics may be shared or distributed

But semantics must always remain **separate from truth**.

---

## Determinism and Stability

Semantic derivation is:
- deterministic with respect to a given rule set
- dependent on architectural knowledge
- sensitive to context (e.g. ABI, optimisation level)

Changing the semantic rules must never invalidate the underlying session.

---

## Live vs Recorded Sessions

### Live Sessions
- semantics may be partial
- explanations may be provisional
- meaning may be refined after execution progresses

### Recorded Sessions
- semantics may be complete
- explanations may be carefully curated
- replay enables deliberate narrative pacing

The same derivation pipeline applies in both cases.

---

## Pedagogical Annotations

Semantic derivation supports **annotations**.

Annotations:
- attach to events or snapshots
- never mutate source data
- may be authored by humans or tools
- may exist in multiple layers (beginner, advanced, expert)

Annotations are first-class pedagogical artifacts.

---

## Versioning and Evolution

Semantic derivation logic is expected to evolve.

Therefore:
- semantics must be recomputable
- old captures must remain valid
- explanations must not be hard-coded into truth

This ensures long-term usefulness of recorded sessions.

---

## Relationship to Other Core Models

- **Event Model**  
  Semantics interpret events, but never modify them.

- **Snapshot Model**  
  Semantics explain state captured in snapshots.

- **Derived State Model**  
  Semantics may consume derived state, but must not depend on its persistence.

- **Dataset Model**  
  Semantic annotations may be bundled with datasets, but remain logically separate.

---

## Architectural Constraints (Non-Negotiable)

1. Semantic derivation must never emit events  
2. Semantic derivation must never mutate snapshots  
3. Semantic derivation must remain optional  
4. Semantic derivation must tolerate incomplete data  

Violating these constraints collapses truth and interpretation.

---

## Summary

Semantic derivation is where Dipole transforms debugging data into understanding.

By strictly separating:
- immutable truth (events, snapshots)
- ephemeral interaction (derived state)
- layered meaning (semantics)

Dipole enables explanation, pedagogy, and insight  
without sacrificing correctness or architectural clarity.
