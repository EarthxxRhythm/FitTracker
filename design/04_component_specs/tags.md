# Tags and Status Spec

## Role
Tags, chips, badges, and status labels are small but critical. They carry state, focus, and semantic weight in a compact space.

In FitTracker they should make the interface feel more precise and premium, not busier.

---

## Core Principles

1. A tag should communicate state or category quickly.
2. Tags should never compete with the page’s primary focus.
3. Visual treatment must be compact, refined, and quiet.
4. Color must reflect hierarchy and meaning, not decoration.

---

## Primary Tag Types

### Active / In-progress
Use for:
- currently selected state
- in-progress session state
- active training context

Visual guidance:
- background: subtle emerald-tinted dark surface
- text: `ACCENT_HOVER` or close equivalent
- edge: optional soft emphasis

### Completed / Success
Use for:
- finished set
- completed step
- successful state

Visual guidance:
- darker success-tinted surface
- text: `STATE_SUCCESS`
- keep it calm, not celebratory neon

### PR / High-value
Use for:
- PR
- standout improvement
- high-value record cue

Visual guidance:
- subtle dark base with gold text or gold-accent edge
- use sparingly so it retains meaning

### Neutral Metadata
Use for:
- low-priority labels
- category markers
- support metadata

Visual guidance:
- muted surface
- `TEXT_SECONDARY` or `TEXT_TERTIARY`
- low contrast relative to key status tags

---

## Size and Density Rules
Tags should be:
- compact
- easy to scan
- visually consistent
- rounded but not bubbly

Do not make tags oversized or highly padded unless they function as a control chip.

---

## Usage Rules
Use tags to clarify:
- state
- progress
- importance
- category
- priority

Do not use tags to compensate for bad layout hierarchy.
If too many tags are needed, the information architecture is probably weak.

---

## Page-Specific Intent
### Home
Tags should clarify:
- current status
- plan readiness
- today / rest / in-progress cues

### Active Workout
Tags should clarify:
- active state
- completion state
- key status changes

### Review
Tags should clarify:
- trend value
- PR significance
- filters or state without clutter

---

## Failure Signs
Tags are not acceptable if:
- everything is tagged
- tags are louder than card titles
- green is used on all chips indiscriminately
- tags feel like SaaS marketing filters rather than system labels

---

## Success Criteria
Tags are correct when:
- they increase scanning speed
- they strengthen state clarity
- they support the premium system feel
- they stay visually disciplined and secondary to the main hierarchy
