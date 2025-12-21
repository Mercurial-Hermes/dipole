# TS2-002 — Projection Identity & Registry
## Naming and Referencing Semantic Meaning

### Architectural Role

TS2-002 introduces identity for semantic meaning without introducing:
- execution
- scheduling
- ordering
- causality
- authority
- consumption semantics

It answers a single question:

> How is semantic meaning named and referred to — without changing what a projection is or does?

TS2-002 does not introduce new meaning. It introduces structure around existing meaning.

### Anchors
- semantic identity
- meaning stability
- downstream-only reference
- non-operational structure

### Relationship to TS2-001

- TS2-001 proves that semantic interpretation is possible and safe.
- TS2-002 proves that semantic interpretation can be named and catalogued.

Critically: TS2-002 adds referential structure, not behavioural structure. All TS2-001 invariants remain intact and enforceable.

### Types Touched
- `ProjectionId`
- `SemanticVersion` (optional)
- `ProjectionDef`
- `ProjectionRegistry`

⚠️ No projection behaviour, execution logic, or planners are introduced.

### Explicit Non-Dependencies

TS2-002 introduces no dependency on:
- controller
- driver
- repl
- tmux
- planner
- runtime execution
- event ordering
- subscriptions
- allocators or heap state
- global mutable state

The registry is static and declarative.

### Semantic Objects Introduced

#### Projection Identity
```zig
pub const ProjectionId = struct {
    /// Stable semantic identifier
    name: []const u8,

    /// Optional semantic version
    version: ?SemanticVersion = null,
};
```
Notes:
- Identity names meaning, not code.
- Identity is independent of execution or lifecycle.
- Identity must be stable across rebuilds and replays.

#### Semantic Version (Optional)
```zig
pub const SemanticVersion = struct {
    major: u16,
    minor: u16,
};
```
Rules:
- Versioning is explicit and sparse
- Unversioned projections are valid
- Version bumps represent semantic meaning changes, not refactors

Examples:
- `event.kind`
- `event.kind@1`

Unversioned and versioned meanings may coexist.

#### Projection Definition (Declarative)

A projection definition describes what a projection means, not how it runs.
```zig
pub const ProjectionDef = struct {
    id: ProjectionId,
    description: []const u8,
    output_kind: type,
    permitted_fields: []const EventField,
};
```
Notes:
- `output_kind` is opaque to the registry
- `permitted_fields` defines the semantic dependency surface
- No function pointers or execution hooks are included

#### Projection Registry

The registry is a static catalogue of semantic meaning.
```zig
pub const ProjectionRegistry = struct {
    projections: []const ProjectionDef,

    pub fn lookup(
        self: *const ProjectionRegistry,
        id: ProjectionId,
    ) ?*const ProjectionDef { ... }
};
```
Properties:
- No runtime behaviour
- No ordering between projections
- No dependency graphs
- No mutation
- No scheduling
- No execution

The registry is closer to a symbol table than a system component.

### Naming Rules (Normative)

Projection names must:
- be lowercase
- be dot-separated
- describe semantic interpretation
- avoid verbs or execution hints

Examples:
- `event.kind`
- `session.lifecycle.phase`
- `engine.activity.class`

Registry entries must be unique by `(name, version)`. Uniqueness is enforced at build or test time, not runtime.

### Registry Enforcement Model

- The registry does not enforce semantic rules at runtime.
- `permitted_fields` is a contract, enforced by tests, review, and architectural discipline.
- Runtime enforcement is explicitly forbidden.

### Required Properties

**Referential Stability**
- Projection identity must not depend on: code layout, build order, memory addresses, execution context.

**Non-Operational**
- The registry must not: run projections, schedule work, cache results, track consumers.

**Orthogonality**
- Projection identity must be independent of: event ordering, other projections, planners or UI.

**Downstream-Only**
- Identity exists only to be referenced by consumers.
- No upstream system may depend on semantic identity.

### TS2-002 intentionally does not specify:
- projection execution
- projection composition
- planners or subscribers
- semantic state accumulation
- caching or materialization
- UI or debugger interaction
- dependency resolution

Those concerns are deferred to TS3+.

### Behavioural Tests (TS2-002 Scope)

TS2-002 tests validate semantic identity structure, not projection execution.

These tests assert that meaning is:
- referable
- stable
- non-operational
- contractually described

They must not execute projections over event logs.

#### Test 1 — Registry Contains Declared Projection
Purpose

Proves that semantic meaning is explicitly named and discoverable.

Given

- A statically constructed ProjectionRegistry
- A known projection definition (e.g. event.kind)

When

- The registry is queried by ProjectionId

Then

- The projection definition is found
- The returned definition is stable and non-null

Assertion
```zig
const id = ProjectionId{ .name = "event.kind" };
const def = registry.lookup(id);
try expect(def != null);
```

Enforces

- No implicit or anonymous semantic meaning
- Naming is required to reference meaning

#### Test 2 — Projection Identity Is Stable and Pure Data
Purpose

Ensures projection identity does not encode behaviour.

Given

- A ProjectionDef

Then

It contains:
- ProjectionId
- description
- output type
- permitted fields

It contains no:
- function pointers
- allocators
- runtime state
- mutable references

This test is largely compile-time / review driven, but can be reinforced by:
```zig
comptime {
    // ensure ProjectionDef has no fn fields
}
```

Enforces

- Identity ≠ execution
- Registry remains declarative

#### Test 3 — Projection Names Are Unique
Purpose

Prevents semantic ambiguity.

Given

- A registry containing multiple projections

Then

- No two entries share the same (ProjectionId.name, ProjectionId.version) pair.

Assertion (illustrative)
```zig
try expectUniqueProjectionIds(registry);
```

Enforces

- One name → one meaning
- Registry is a truthful catalogue

#### Test 4 — Unversioned and Versioned Projections May Coexist
Purpose

Confirms explicit semantic versioning rules.

Given
- event.kind
- event.kind@1

Then

- Both entries may exist simultaneously
- Lookup resolves them independently

Assertion
```zig
try expect(registry.lookup(.{ .name = "event.kind" }) != null);
try expect(registry.lookup(.{
    .name = "event.kind",
    .version = .{ .major = 1, .minor = 0 },
}) != null);
```

Enforces

- No silent semantic replacement
- Explicit opt-in to new meaning

#### Test 5 — Permitted Fields Are Explicitly Declared
Purpose

Locks down the semantic dependency surface.

Given

- A projection definition

Then

- permitted_fields is non-empty
- It lists only fields allowed by TS2-001

Example:
```zig
try expect(def.permitted_fields.len > 0);
try expectOnlyAllowedEventFields(def.permitted_fields);
```

Enforces

- Semantic firewall is explicit
- Meaning dependencies are visible and reviewable

⚠️ This test does not inspect projection code — that remains TS2-001 / review territory.

#### Test 6 — Registry Is Non-Operational (Documented Invariant)
Status: Intentionally not implemented as an automated test.

Purpose

Ensures TS2-002 does not smuggle in execution.

Given

- The ProjectionRegistry API surface

Then

It exposes only:
- lookup
- enumeration

It exposes no:
- execution helpers
- scheduling hooks
- allocators
- caching APIs

This is best enforced via:
- API surface inspection
- absence of allocator parameters
- absence of fn(Event...) members

Enforces

- Registry cannot “accidentally” become runtime infrastructure

#### Explicitly Out of Scope for TS2-002 Tests

The following must not appear in TS2-002 tests:
- executing a projection
- iterating over an event log
- asserting derived values
- planner or UI references
- ordering between projections
- dependency graphs
- composition

Those belong to TS3+.

### Summary Statement

TS2-002 tests validate that semantic meaning is named, stable, unique, and non-operational.
They do not validate how meaning is computed — only how it is referred to.
