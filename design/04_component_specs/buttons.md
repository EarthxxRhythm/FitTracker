# Button Spec

## Role
Buttons in FitTracker are not decorative. They express action priority, training momentum, and system confidence.

A button should never feel like a generic SaaS control. It should feel deliberate, premium, and calm.

---

## Core Principles

1. There should be a clear distinction between primary and secondary actions.
2. The strongest action on a screen must be visually obvious in under 2 seconds.
3. Buttons should feel dense and precise, not toy-like or overly soft.
4. High contrast and clarity matter more than visual tricks.
5. Green is for **meaningful focus**, not for every interactive element.

---

## Primary Button

### Usage
Use for the main action of the current screen, such as:
- start today’s workout
- start workout preview flow
- save workout progress
- complete workout
- confirm a high-confidence action

### Visual Rules
- Background: `ACCENT_PRIMARY`
- Text: `TEXT_INVERTED`
- Hover / active: `ACCENT_HOVER`
- Radius: medium (`RADIUS_MD`)
- Border: none, or a very subtle reinforced edge if needed
- Shadow/glow: extremely restrained; if used, use `ACCENT_GLOW`

### Feel
The primary button should feel:
- alive
- precise
- intentional
- premium

It should not feel neon, soft-plastic, or game-like.

---

## Secondary Button

### Usage
Use for actions that matter but should not compete with the main flow:
- view review page
- view details
- switch context
- secondary confirm paths

### Visual Rules
- Background: `SURFACE_SECONDARY`
- Border: `BORDER_DEFAULT`
- Text: `TEXT_PRIMARY`
- Hover: border may brighten slightly toward emerald; surface may lighten subtly
- Radius: `RADIUS_MD`

### Feel
Secondary buttons should feel stable and premium, like dark system controls.
They should support the action hierarchy without flattening it.

---

## Ghost / Tertiary Button

### Usage
Use for low-priority actions:
- back
- dismiss
- low-cost navigation
- supporting actions that should not visually interrupt

### Visual Rules
- Background: transparent or near-transparent
- Text: `TEXT_SECONDARY`
- Hover: soft dark surface fill
- Border: none by default

### Feel
Ghost actions should be discoverable, but quiet.

---

## Button Size and Density

Buttons should feel compact and confident, not oversized and bubbly.

### Recommended sizing behavior
- full-width on main mobile CTA surfaces
- strong vertical rhythm
- generous enough hit target for touch, but not visually bloated

### Avoid
- oversized pill buttons everywhere
- giant rounded CTA shapes that look childish
- tiny thin controls with weak affordance

---

## Icon Usage

Icons should only be used if they improve scanning or reinforce action.
Do not add icons to every button.

Acceptable icon usage:
- back
- continue / next
- review entry
- action that would otherwise be ambiguous

Do not use decorative icons as a substitute for hierarchy.

---

## Success Criteria
A button system is correct if:
- the primary action is unmistakable
- secondary actions remain visible but do not compete
- the overall button family feels like one product system
- the page looks more premium after button replacement, not merely greener

---

## Failure Signs
The button system is not acceptable if:
- every button is green
- the primary CTA does not stand out enough
- buttons look generic dark SaaS
- buttons feel gaming-like or neon
- radii, padding, and weight vary too much across pages
