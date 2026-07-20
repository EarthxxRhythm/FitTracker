# Inputs Spec

## Role
Inputs in FitTracker are most critical on the Active Workout page, where they directly affect recording speed and trust. They must feel stable, efficient, and intentional.

An input should never feel like a generic web form field pasted into a dark theme. It should feel like a refined training data-entry control.

---

## Core Principles

1. Inputs are tools, not decoration.
2. The active field must be immediately visible.
3. Completed and incomplete states must be clearly distinguishable.
4. Density should support fast recording without becoming cramped.
5. Inputs must support confidence: the user should feel sure what to type and where.

---

## Visual Tone
Inputs should feel:
- precise
- calm
- responsive
- premium
- efficient

They should not feel:
- like office software
- like admin forms
- like giant rounded mobile consumer fields
- like glowing sci-fi widgets

---

## Base Input Rules
- Background: `SURFACE_INPUT`
- Text: `TEXT_PRIMARY`
- Placeholder: `TEXT_TERTIARY`
- Border: `BORDER_DEFAULT`
- Radius: `RADIUS_SM` or `RADIUS_MD`
- Surface contrast should be strong enough to separate the field from the surrounding card

---

## Focus State
The active field is one of the most important visual states in the product.

Use:
- stronger edge emphasis
- emerald accent edge or focus ring
- optional restrained glow using `ACCENT_GLOW`

Focus should communicate:
- this is the current working control
- you can act here now

It should not become neon, noisy, or game-like.

---

## Completed State
When a field or row is completed, the UI should communicate confidence and closure.

Possible cues:
- softer emerald-tinted edge
- success-tinted supporting label
- row-level completion treatment

Completed state should be calm and trustworthy, not celebratory.

---

## Error / Invalid State
Errors should be clear without becoming hostile.

Use:
- muted error tone
- localized field emphasis
- short, readable supporting message when needed

Do not turn the whole section bright red or visually panic the interface.

---

## Numeric Entry Guidance
Many core FitTracker inputs are numeric:
- weight
- reps
- duration-related fields
- count-based values

Numeric fields should feel especially stable and readable.
Key rules:
- high contrast
- enough padding for tap comfort
- strong alignment with nearby labels and reference values
- clear grouping inside set-entry rows

---

## Grouping Rules
Inputs should rarely appear alone without context.
They should typically be grouped with:
- a label
- row identity
- current state
- reference/supporting value where useful

If fields are visually isolated, recording flow becomes slower.

---

## Active Workout Intent
On the Active Workout page, inputs should contribute to a "recording console" feeling:
- the next field is easy to spot
- current row is obvious
- completion is visible
- values are easy to scan even during repetitive entry

---

## Success Criteria
Inputs are correct when:
- users can identify the active entry area instantly
- fields feel integrated with the premium dark system
- numeric entry feels fast and clear
- completed vs incomplete entry states are obvious

---

## Failure Signs
Inputs are not acceptable if:
- they look like standard dark form fields
- focus state is weak
- every field has equal visual emphasis
- completed rows are hard to distinguish
- the input system makes the workout page feel like a form instead of a control surface
