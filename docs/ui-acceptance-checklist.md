# FitTracker UI Acceptance Checklist

Last updated: 2026-08-01

## Purpose

This checklist converts the remaining subjective UI/UX closeout gap into an explicit review pass.

It is intended for a short manual acceptance round after engineering closeout.

Use this checklist together with:

- `docs/ui-final-acceptance-runbook.md`
- `docs/ui-design-review-packet.md`
- `docs/ui-acceptance-record-template.md`
- `node tools/generate-ui-acceptance-record.mjs`

## Review Scope

Review these registered user-facing routes:

- `features/pencil/PencilLoginPage`
- `features/pencil/PencilRegisterPage`
- `features/onboarding/pages/GoalSetupPage`
- `features/pencil/PencilHomePage`
- `features/exercise/pages/ExerciseLibraryPage`
- `features/exercise/pages/ExerciseDetailPage`
- `features/monetization/pages/MonetizationHubPage`
- `features/pencil/PencilPlanPage`
- `features/pencil/PencilPreviewPage`
- `features/pencil/PencilActivePage`
- `features/workout/pages/WorkoutSummaryPage`
- `features/pencil/PencilReviewPage`
- `app/PencilAppShell`

## Acceptance Standard

The UI/UX goal can be treated as accepted only if no reviewed route has a blocking issue in any checklist section below.

Blocking means any issue that makes the route clearly inconsistent with the target style, impairs the primary task flow, or creates visible polish debt that a normal user would notice quickly.

## Section A: Visual Consistency

For each route, confirm:

- page hierarchy is clear within the first viewport
- headings, labels, and supporting text use a consistent scale relationship
- cards, spacing, and dividers feel consistent with the rest of the app
- there is no obviously old visual language mixed into the updated screens
- key actions use a consistent visual priority
- no section looks decorative without serving the workout tool workflow

Fail the route if any of these are true:

- hero, section, or card styling looks like a different product generation
- spacing density is noticeably off compared with adjacent routes
- button emphasis is confusing or inconsistent
- text blocks feel noisy, redundant, or over-explained

## Section B: Flow Clarity

For each route, confirm:

- the primary action is obvious within 3 seconds
- the back / next step behavior is understandable without exploration
- the page supports scanning before detailed reading
- related secondary actions are grouped logically
- the route does not force unnecessary detours to finish its main task

Fail the route if any of these are true:

- the user must guess which button continues the main flow
- the route mixes setup, inspection, and destructive actions without hierarchy
- the main task is buried below low-priority content

## Section C: Interaction Polish

For each route, confirm:

- no visible overlap, clipping, or broken line wrapping
- no blank, dead, or misleading CTA
- no unstable layout shift when tapping common controls
- loading / empty / success / warning states read as intentional
- repeated controls behave consistently across routes

Fail the route if any of these are true:

- text truncates badly in common viewport conditions
- status feedback is missing after an important action
- the route visually "jumps" in a way that feels accidental

## Section D: Product Tone

For each route, confirm:

- the app still reads as a focused training tool, not a marketing page
- visual design feels calm, dense enough, and operational
- monetization surfaces remain secondary to the workout product
- advanced capabilities feel integrated rather than bolted on

Fail the route if any of these are true:

- the route feels like a promo surface instead of a tool surface
- monetization interrupts the core workout path
- visual treatment becomes flashy at the cost of clarity

## Route-Specific Focus Points

### Login / Register

- auth entry should feel compact, clear, and not visually heavier than the main app
- registration handoff should not feel like a disconnected flow

### Goal Setup

- grouped choices should feel structured rather than form-noisy
- the generate-plan action should remain the clear terminal action

### Home

- today's training entry must dominate over secondary destinations
- preset plans should read as secondary exploration, not the primary task

### Exercise Library / Detail

- library filters must feel scannable and operational
- detail media card must feel integrated into the knowledge flow

### Training Plan Detail

- plan structure should be easy to scan before enabling
- advanced variants should remain clearly separate from the default enable flow

### Workout Preview / Active / Summary

- preview, execution, and summary should feel like one continuous product lane
- summary must feel calmer and more reflective than active workout

### Review Home

- trends, recovery insights, backup entry, and profile tools should coexist without feeling cluttered
- advanced insights / membership entry should remain clearly secondary to review content

### Monetization Hub

- must read as a prepared capability surface, not a fake purchase flow
- local preview states must be understandable and clearly non-production

## Review Output Template

Use this template for the final manual acceptance pass:

```text
Route:
Visual consistency: pass | fail
Flow clarity: pass | fail
Interaction polish: pass | fail
Product tone: pass | fail
Notes:
Blocking issue:
```

You can prefill the machine-backed evidence references before the manual pass with:

```powershell
node tools/generate-ui-acceptance-record.mjs
```

## Closeout Rule

The UI/UX objective is considered accepted when:

- every route in scope has been reviewed
- no route has a blocking issue
- any non-blocking notes are polish-only and do not change the product direction
