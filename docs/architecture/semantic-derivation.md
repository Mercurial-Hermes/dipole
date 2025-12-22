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

---

## The Semantic Ladder

Not all derivations in Dipole carry the same semantic weight.

Semantic derivation exists along a **ladder of interpretation**, moving from factual reflection to explanatory meaning.

### 1. Factual Truth
Raw events and snapshots represent immutable facts:
- what was observed
- when it was observed
- in what order

These contain no interpretation.

---

### 2. Structural (Reflective) Derivations
Structural derivations reshape truth without adding meaning.

They:
- aggregate
- order
- filter
- summarise

Examples include:
- event counts
- category timelines
- frequency distributions

Structural derivations:
- introduce no new vocabulary
- are lossless with respect to meaning
- answer *“what exists?”* and *“in what shape?”*

They establish projection boundaries and replay determinism.

---

### 3. Interpretive Semantic Derivations
Interpretive derivations assign **meaning not explicitly present in the data**.

They:
- introduce new semantic vocabulary
- collapse many raw facts into conceptual categories
- are intentionally lossy
- require architectural or domain knowledge

Interpretive derivations answer:
- *“what kind of thing is happening?”*
- *“why does this matter?”*

These are the first derivations suitable for:
- subscription
- explanation
- pedagogy
- coordination

---

### Principle

> **All semantics are derived — but not all derivations are semantic.**

Dipole explicitly distinguishes reflective structure from interpretive meaning to prevent accidental semantic leakage into truth.

---

---

## Minimal Worked Example

The following example illustrates the difference between reflective structure and interpretive semantic derivation.

### Input: Raw Events

Assume the event log contains the following transport-level observations:

```zig
Event{ .event_id = 1, .category = .tx,     .payload = "break main" }
Event{ .event_id = 2, .category = .rx,     .payload = "Breakpoint 1 set" }
Event{ .event_id = 3, .category = .prompt, .payload = "(lldb)" }
```

These events are factual:
  - a command was transmitted
  - output was received
  - the debugger became ready

No meaning is asserted beyond what was observed.

### Structural (Reflective) Derivation

A structural projection might produce:
- event count = 3
- category timeline = [tx, rx, prompt]

This reshapes the data, but introduces no new vocabulary.
Nothing is _interpreted_.

### Interpretive Semantic Derivation

A semantic projection may instead derive the following:

```zig
pub const EventKind = enum {
    user_command,
    debugger_output,
    debugger_ready,
};
```
Applying a semantic derivation rule:

```yaml
tx      →   user_command
rx      →   debugger_output
prompt  →   debugger_ready
```
The same event sequence now yields:
```yaml
[user_command, debugger_output, debugger_ready]
```

#### Properties of This Derivation

**Lossy**
The original payloads and ordering details cannot be reconstructed from `EventKind`.

**New Vocabulary**
`debugger_ready` does not exist in the event log.
It is an interpretation.

**Replay-Deterministic**
Replaying the same event log with the same rules produces the same semantic sequence.

**Non-Authoritative**
The event log remains the sole source of truth.
Semantics explain it — they do not replace it.

#### Interpretation Boundary

This semantic meaning could not be embedded into the events themselves
without permanently fossilising an interpretation.

Instead, Dipole derives it downstream, where it may evolve.


---

```yaml
## 🎯 Why This Example Is the Right Size

This example:

- Uses **realistic LLDB-like events**
- Avoids regexes, heuristics, or clever parsing
- Demonstrates **loss**, **interpretation**, and **determinism**
- Introduces exactly *one* new semantic concept
- Makes the boundary *obvious*, not debatable

Importantly, it does **not**:
- prescribe implementation details
- assume concurrency or runtime
- blur semantics with state or control flow

It is documentation that *constrains* future work.

## Optional (Later) Enhancements

Not needed now, but possible later:

- A second example using snapshots (e.g. stack growth)
- A footnote referencing data warehousing semantics
- A diagram showing Event → Semantic Projection → Consumer

```

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
