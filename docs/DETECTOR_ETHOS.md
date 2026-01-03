# Dipole: The Detector Ethos

## Purpose

This document captures the **detector ethos** that underpins Dipole’s long-term ambitions.

Dipole is not a debugger in the traditional sense.  
It is not a profiler.  
It is not an oracle.

Dipole is a **scientific instrument**: a detector, a probe, a lens — designed to observe execution under real constraints, especially those imposed by macOS, Apple Silicon, and modern GPU/Metal systems.

This ethos is foundational. It should guide design, implementation, language, and pedagogy over the lifetime of the project.

---

## Core Premise

Modern macOS systems are **not fully observable**.

Apple intentionally hides large portions of kernel, scheduler, VM, and GPU driver behavior. This is not a temporary limitation or an undocumented gap — it is a structural property of the platform.

Dipole does not fight this reality.  
Dipole is built **for** it.

---

## Dipole as a Detector

In experimental science, a detector does not show reality directly.

Instead, it:
- records events
- measures timing and magnitude
- exposes boundaries
- introduces known distortion
- preserves raw data
- enables inference, not certainty

Dipole adopts this exact stance toward computation.

### Dipole does **not**:
- trace execution end-to-end
- reveal hidden kernel paths
- explain internal driver decisions
- invent causality
- collapse uncertainty

### Dipole **does**:
- record observable events faithfully
- preserve timing with high integrity
- surface transitions and boundaries
- mark opaque regions explicitly
- enable disciplined inference
- support experimental reasoning

---

## Event Logs as Experimental Data

Dipole’s event log is not a trace.  
It is a **dataset**.

Properties:
- Immutable once recorded
- Replayable
- Interpretable by multiple models
- Valuable long after capture
- Honest about gaps

Just as in physics:
- raw detector hits are never rewritten
- reconstruction algorithms evolve
- interpretations improve over time

Dipole’s power grows by **reinterpreting existing evidence**, not by pretending to see more than it can.

---

## Epistemic Classes

Dipole encodes epistemic status directly into its outputs.

This is non-negotiable.

### 1. Facts

What Dipole can stand behind forever.

Characteristics:
- Directly observed
- Timestamped
- Replayable
- Independent of interpretation

Language:
- *Observed*
- *Measured*
- *Recorded*

If facts are wrong, Dipole is wrong.

---

### 2. Inferences

Disciplined, probabilistic reasoning derived from facts.

Characteristics:
- Explicitly labeled
- Evidence-cited
- Confidence-scored
- Retractable
- Accompanied by alternatives

Language:
- *Likely*
- *Consistent with*
- *Hypothesis*

Dipole never states inference as truth.

---

### 3. Unknowns (Opaque Regions)

Named absence of information.

Characteristics:
- Explicitly marked
- Explained (why unobservable)
- Preserved as first-class objects
- Never hidden or glossed over

Language:
- *Opaque*
- *No evidence available*

Opacity is not failure.  
It is structural reality.

---

## Opaque Regions Are a Feature

In macOS (and especially GPU / Metal execution):

- kernel scheduling is opaque
- VM fault attribution is opaque
- GPU driver execution is opaque
- hardware scheduling is opaque

Dipole treats these as **event horizons**.

What happens beyond them is not guessed.  
It is inferred only through effects.

This aligns with how professional engineers actually work.

---

## Probabilistic Truth, Not Absolute Truth

Dipole embraces **probabilistic inference** — but only when earned.

Inference must:
- cite evidence
- state confidence
- list competing hypotheses
- describe what would falsify it

This is not weakness.
This is scientific rigor.

Dipole never says:
> “This is why it happened.”

Dipole says:
> “This explanation fits the observed evidence better than alternatives.”

---

## Experiment Over Explanation

When behavior lies in opaque regions, Dipole shifts the engineer’s mindset:

From:
> “Explain the system.”

To:
> “Design an experiment.”

Dipole supports:
- run-to-run comparison
- invariant detection
- controlled variation
- hypothesis exclusion
- evidence accumulation

This is how real understanding is built on opaque platforms.

---

## The Lens Metaphor

Dipole is a lens.

A good lens:
- sharpens some regions
- blurs others
- declares its focal limits
- never invents structure

Dipole’s UI, language, and projections must always reflect:
- where focus is high
- where resolution drops
- where uncertainty dominates

If Dipole ever hides blur, it is lying.

---

## Alignment with macOS Reality

Apple’s implicit contract with developers is:

- You get outcomes, timing, and boundaries.
- You do not get internal mechanisms.
- You are expected to reason anyway.

Dipole aligns perfectly with this contract.

It does not promise impossible insight.
It teaches disciplined work within real constraints.

---

## Long-Term Ambition

Dipole’s ambition is not breadth of access.

It is **depth of trust**.

A professional engineer should be able to say:

> “Dipole never lies to me.  
> It shows me what it can see, names what it cannot,  
> and helps me reason honestly with the rest.”

That trust is cumulative.
It is fragile.
It is worth protecting above all else.

---

## Closing Principle

**Dipole is a detector for execution.**

It magnifies evidence.  
It labels uncertainty.  
It preserves raw truth.  
It enables inference without illusion.

This is not a limitation.  
It is the source of Dipole’s value.
