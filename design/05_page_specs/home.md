# Home Page Spec

## Page Role
The Home page is the **training control hub**.
It is the page that answers, immediately:

1. What should I do today?
2. What is my current plan/status?
3. What is the next action?

If the page fails to answer those three things at a glance, it is not good enough.

---

## Primary UX Goal
The Home page should make the user feel:
- oriented
- ready to act
- confident about what today’s workout is
- aware of current progress without reading too much

The page should reduce hesitation. It must not feel like a generic dashboard of equal-weight cards.

---

## Core Visual Goal
The Home page should feel like a **premium training command surface**.
Not a landing page. Not a social feed. Not a card pile.

Visual tone:
- dark
- structured
- high-confidence
- premium
- clearly focused

---

## Information Hierarchy
The page must have a very clear hierarchy.

### Level 1: Today’s workout focus
This is the dominant area.
It should include:
- today’s workout identity
- current plan context
- strongest primary CTA
- immediate readiness signal

This area should visually read as the page’s main purpose.

### Level 2: Current training context
This includes:
- current plan name
- whether today is a training day or rest day
- lightweight progress or status summary

### Level 3: Secondary navigation / supporting insight
This may include:
- review entry
- adjustment entry
- supporting stats
- other low-priority actions

These areas should support the user, not compete with the main training action.

---

## Required Functional Outcomes
The Home page must:
- show whether a goal exists
- show today’s training status clearly
- show the main action to continue training flow
- provide a visible path to review/history
- provide a visible path to adjust the goal when relevant

---

## Required Aesthetic Outcomes
The Home page should not look like:
- a stack of similar cards with no focal point
- a backend dashboard
- a marketing hero section
- a fitness content feed
- a generic dark utility app

The Home page should look like:
- a deliberate command surface
- a premium training system start point
- a place where the user immediately knows what matters

---

## Preferred Layout Pattern
1. Strong header / state framing
2. Dominant today workout card
3. Supporting context strip or compact status area
4. Secondary actions below the primary action zone
5. Low-noise supporting information after the main decision area

The user should not need to scroll before understanding the page’s main purpose.

---

## CTA Rules
There must be one obvious primary CTA.

Examples of acceptable primary CTA intent:
- start today’s workout
- continue current training flow
- open workout preview for today

Do not create multiple equally loud CTAs in the first screen.

---

## Color and Surface Rules
- The page canvas uses the deepest dark layers.
- The main “today” card may use `SURFACE_STRONG` or equivalent stronger surface treatment.
- The primary CTA uses `ACCENT_PRIMARY`.
- Green should emphasize action and current readiness, not fill the whole screen.
- Supporting cards should stay visually quieter.

---

## Page Success Criteria
The Home page redesign is successful only if:
- the main focus is obvious in under 2 seconds
- the user knows what to press next
- secondary cards do not compete with the main training action
- the page feels more premium and more intentional than before
- the page clearly belongs to the same product family as Active Workout and Review

---

## Failure Signs
The redesign is not acceptable if:
- all cards feel equally important
- the user must read multiple blocks to know what to do
- the main CTA is visually weak
- the page feels like generic dark mode
- the page has activity but no clear focal hierarchy
- the page is prettier but not more actionable
