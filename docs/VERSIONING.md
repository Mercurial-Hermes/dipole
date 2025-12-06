# VERSIONING

Dipole uses **two parallel tagging systems**:

1. **Experiment Tags** (`expX.Y`)
2. **Semantic Version Tags** (`vA.B.C`)

These serve different purposes and move at different cadences.  
Together they reflect Dipole’s dual nature as both a **learning journey** and an evolving **software tool**.

---

## 1. Experiment Tags (`expX.Y`)

**Purpose:** Track the progression of understanding, experiments, and insights.

Experiment tags mark the completion of a discrete learning experiment, typically contained in `exp/` and documented in the dev diary.

Use an `exp` tag when:

- a defined experiment runs successfully,  
- it produces insight or clarity,  
- the results are written to `docs/dev-log/`,  
- and it represents a conceptual milestone in Dipole’s evolution.

Examples:

exp0.1 — process listing
exp0.2 — attach + inspect
exp0.3 — stack frames
exp0.4 — first trace step


Experiment tags represent **Dipole’s internal growth of understanding**.  
There should be *one experiment tag per experiment*.

---

## 2. Semantic Version Tags (`vA.B.C`)

Dipole also uses semantic versioning (SemVer-style) to track **external-facing software maturity**.

Semantic version tags evolve more slowly than experiments and represent meaningful changes to Dipole as a tool.

### Version Format  
`MAJOR.MINOR.PATCH`

### What drives each increment?

#### **PATCH** (`v0.0.X`)
Refinements without new conceptual capability:

- bug fixes  
- internal cleanups  
- documentation updates  
- formatting improvements  
- minor refactors  
- new experiments that are *not yet integrated*  

PATCH = stability and refinement.

---

#### **MINOR** (`v0.X.0`)
Represents a new meaningful capability or architectural slice:

- first trace capture  
- a new CLI command  
- improved attach flow  
- visible stepping or register printing  
- abstractions promoted from experiments  
- early `dipoledb` components  
- initial TUI prototypes  

MINOR = *Dipole can now do something new.*

---

#### **MAJOR** (`1.0.0`)
Reserved for the moment when Dipole becomes:

- stable and predictable,  
- usable for real debugging tasks,  
- equipped with a consistent CLI/TUI,  
- backed by a partially or fully native backend,  
- trusted by learners and developers.

This is a long-term milestone.

---

## 3. Dual Tagging

A single commit may receive **both**:

- an `exp` tag (internal conceptual milestone), and  
- a `v` tag (external release milestone).

For example, completing Exp 0.4 might produce:

git tag exp0.4
git tag v0.0.1
git push --tags


This creates two parallel histories:

- **Learning History** (`exp` tags)  
- **Software Evolution History** (`v` tags)

This duality matches Dipole’s purpose as both a debugger **and** a pedagogical instrument.

---

## 4. When to Tag What (Decision Guide)

After completing a meaningful unit of work:

### Step 1 — Did you finish a defined experiment?
- **Yes → tag `expX.Y`**

### Step 2 — Does this commit represent a meaningful improvement to Dipole-as-a-tool?  
Ask:
- Would an external user notice a capability change?  
- Did the architecture take a coherent step forward?  
- Did we integrate insights into the real codebase?

- **Yes → also create or bump a `v` tag**

### Step 3 — If not, skip the semantic version bump.

Think of it like this:

- **Experiments advance the understanding timeline.**
- **Versions advance the software timeline.**

Experiments will usually outpace versions.

---

## 5. Typical Early Sequence (Illustration)

exp0.1 # internal experiment only
exp0.2
exp0.3 → v0.0.1 # first attach + inspect slice
exp0.4 → v0.0.2 # first trace snapshot
exp0.5
exp0.6 → v0.1.0 # coherent MVP 0.1 vertical slice


---

## 6. Summary (The Two Histories of Dipole)

- **Experiment tags** mark *learning progression*.  
- **Version tags** mark *tool progression*.  
- They operate at different cadences.  
- Both may be applied to the same commit.  
- Together they create a clear, durable narrative of Dipole’s evolution.

Dipole grows through the cycle:  
**Experiment → Insight → Abstraction → Architecture**,  
and the versioning strategy preserves that story for contributors, learners, and future maintainers.
