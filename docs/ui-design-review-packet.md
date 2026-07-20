# FitTracker UI Design Review Packet

Last updated: 2026-06-12

## Design Goal

FitTracker should read as a focused mobile training tool: calm, dense enough to scan quickly, visually consistent across the main workout loop, and clear about what the next action is on every major route. The user should feel that the app is operational rather than decorative, while still giving enough polish and hierarchy to feel deliberate and premium.

## Product Read

- target user
  - a self-directed trainee who wants to open the app, understand today's plan quickly, execute a workout, and review progress without extra ceremony
- main job on these screens
  - move through the workout loop with low friction: auth -> goal/home -> preview -> active -> summary -> review
  - use secondary routes only when needed: exercise detail, preset plan detail, backup entry, membership preview
- comparable pattern cues
  - compact training dashboards rather than social fitness feeds
  - utility-first review surfaces rather than promo-heavy membership walls

## UX Direction

- hierarchy
  - `HomePage` keeps today's training entry as the dominant action
  - `WorkoutPreviewPage`, `ActiveWorkoutPage`, and `WorkoutSummaryPage` behave like one continuous lane
  - `ReviewHomePage` groups trends, records, backup, and upgrade entry as secondary surfaces after workout completion
  - `MonetizationHubPage` remains a side destination and does not interrupt the core workout path
- primary action path
  - auth handoff is compact and direct
  - home exposes the current-plan action without forcing plan browsing first
  - review surfaces advanced capabilities as optional escalation, not required continuation
- empty/loading/success/error states
  - closeout evidence already proves major routes are reachable and non-blank
  - backup and membership flows expose explicit status text rather than silent state changes
  - remaining manual acceptance should focus on whether those states feel intentional, not whether they exist

## Visual Direction

- tone
  - dark, restrained, and work-focused
  - cool emerald is the main control color, cold metal and muted gold stay secondary, and bright green emphasis is reserved for data progress and completion states
- density
  - medium-density layout with clear bands and cards, tuned for a mobile tool rather than a marketing page
  - summary metrics use compact tiles and outlined/panel card variants instead of oversized hero compositions
- emphasis
  - key route actions use the same primary button language
  - secondary exploration routes lean on outlined/panel cards and destination strips rather than louder CTA treatment
- imagery or asset recommendation
  - current product direction is correct without adding decorative image assets
  - media should stay localized to exercise detail and remain instructional, not atmospheric

## Design-System Fit

- reuse
  - major visible routes consistently consume `ColorTokens`, `FontTokens`, `SpacingTokens`, `RadiusTokens`, and shared components such as `AppCard`, `AppButton`, `PrimaryDestinationStrip`, and `PageHeader`
  - no obvious page-level fallback to one-off hex colors or ad hoc visual styling was found in the main visible routes reviewed this round
- extend
  - existing token coverage is already broad enough for the current MVP/Phase 4 surfaces
  - no new token family is justified for closeout
- add new token/component only if necessary
  - only introduce new primitives if a future phase adds a genuinely new surface pattern, such as remote sync state management or richer media playback

## Engineering Constraints

- implementation guardrails
  - keep the current dark operational style and avoid reopening broad visual refactors during closeout
  - do not let monetization styling become louder than workout styling
  - preserve component reuse; do not fork page-local button/card languages
- validation recommendation
  - use `docs/ui-acceptance-checklist.md` for the final human pass
  - keep `node tools/check-closeout-evidence.mjs` as the machine-backed closeout gate for route evidence
  - use short focused smoke runs only when a user-visible regression is suspected
- known risks
  - final aesthetic acceptance is still subjective and requires a human pass across the listed routes
  - the current risk is not a known UI defect but incomplete proof of motion feel, touch smoothness, and page-to-page tactile continuity

## Route Review Notes

### Home

- status: aligned
- read: today-first dashboard with secondary preset-plan exploration
- remaining manual check: confirm the top card still visually dominates over preset plan cards on device

### Workout Preview / Active / Summary

- status: aligned
- read: one continuous execution lane
- remaining manual check: confirm the emotional shift from active to summary feels calmer in live use

### Review Home

- status: aligned but dense
- read: information-rich review surface with optional upgrade and backup tools
- remaining manual check: verify the card stack still scans cleanly on phone viewport and does not feel overloaded

### Exercise Detail

- status: aligned
- read: instructional knowledge page with integrated media availability
- remaining manual check: confirm media card and premium content card feel additive rather than stacked promotion

### Monetization Hub

- status: aligned
- read: preparedness surface, not fake checkout
- remaining manual check: ensure local preview language is always clearly non-production

### Login / Register / Goal Setup

- status: aligned
- read: compact onboarding/auth surfaces consistent with the main app style
- remaining manual check: confirm auth forms do not feel visually heavier than the workout product itself

## Closeout Position

Based on the current repository state, token usage, shared component reuse, and route-level acceptance artifacts, there is no concrete code-level evidence of a major UI/UX style split inside the main registered product routes.

The remaining gap is not broad redesign work. It is final human signoff against `docs/ui-acceptance-checklist.md`.
