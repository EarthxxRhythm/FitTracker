# Active Workout Page Spec

## Page Role
The Active Workout page is the **recording control console** of FitTracker.

It is the moment where the product proves it is not just a planner, but a usable training tool.
This page must make recording feel fast, clear, and reliable.

---

## Primary UX Goal
The user should always know:
1. what exercise they are working on now
2. where to enter weight and reps
3. what has already been completed
4. what the next action is

The page must minimize hesitation and recording friction.

---

## Core Visual Goal
This page should feel like a **premium training control panel**.
Not a generic form. Not a long content page. Not a table with fields.

It should feel:
- focused
- technical
- controlled
- stable
- high-confidence

---

## Information Hierarchy

### Level 1: Current workout state
This should make the overall state obvious:
- session in progress
- progress through the workout
- what matters right now

### Level 2: Current exercise and set-entry area
This is the heart of the page.
The user’s eye should be drawn immediately to:
- current exercise identity
- current set context
- input fields for weight and reps
- completion status

### Level 3: Supporting guidance
This includes:
- reference 1RM
- supporting labels
- lower-priority helper information

These should help, not distract.

---

## Interaction Rules
- Recording a set should feel immediate.
- Completed vs in-progress sets must be unmistakable.
- Active input focus must be visually clear.
- The user should not need to scan the entire page to find the next field.
- Any progress or completion feedback must feel confident and calm, not flashy.

---

## Required Aesthetic Outcomes
The page should not look like:
- a form screen
- a spreadsheet-like entry page
- a list of inputs with weak grouping
- a generic dark UI with green highlights

The page should look like:
- a controlled workout terminal
- a high-end training system interface
- a purposeful data-entry panel

---

## Surface and Color Rules
- Use deep background layers to make the recording surfaces feel grounded.
- Use stronger cards or panels to frame the active training area.
- Use `ACCENT_PRIMARY` and `ACCENT_HOVER` only for active state, progress, or high-value focus.
- Use muted surfaces for supporting information.
- Reference values like 1RM should not visually overpower the input flow.

---

## Layout Priorities
The first viewport should ideally make the following visible or strongly implied:
- current workout status
- current exercise section
- at least one clear recording row
- the main action path for continuing and saving progress

The page should feel dense enough to be efficient, but not cramped.

---

## Page Success Criteria
The Active Workout redesign is successful only if:
- it feels faster to use than before
- the user can identify the active recording area immediately
- completed and incomplete states are easy to distinguish
- the page feels more like a premium control surface than a form
- the visual language clearly matches Home and Review

---

## Failure Signs
The redesign is not acceptable if:
- the page still reads like a dark form screen
- input fields dominate without hierarchy
- everything has similar emphasis
- the user must search for the next action
- the page is prettier but not more usable
