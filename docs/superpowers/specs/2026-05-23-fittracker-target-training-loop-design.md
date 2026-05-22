# FitTracker Target Training Loop Redesign

Date: 2026-05-23
Status: Approved for documentation draft

## Decision Summary

FitTracker will be redesigned as a goal-driven training loop app, not just a workout logger. The product can learn from MuscleWiki's interaction model: muscle map, exercise encyclopedia, instructional media, exercise substitution, and plan guidance. It will not integrate the official MuscleWiki API. Exercise data, videos, plan templates, and replacement relationships will be owned by a future FitTracker content database.

The new project should be initialized as a clean ArkUI structure. The current codebase remains a reference for local storage, workout recording, statistics, and ArkTS constraints, but new product modules should not be built by piling more behavior into the old page structure.

## Product Loop

The core user path is:

1. Goal configuration
2. Plan generation
3. Workout execution
4. Training review
5. Next-session adjustment

This loop guides the PRD, prototype, code organization, services, data models, and MVP scope.

## MVP Scope

MVP includes:

- Goal questionnaire: training goal, level, weekly frequency, session length, available equipment, restricted body parts.
- Rule-based plan generation: training days, muscle split, exercise selection, target sets and reps, substitution candidates.
- Exercise encyclopedia: muscle map entry, search, muscle/equipment filtering, exercise detail, video placeholder, instructions, common mistakes, safety notes.
- Workout execution: planned exercise list, instructional preview, set logging, rest timer, temporary exercise replacement, volume and estimated 1RM calculation.
- Review: completion rate, personal records, weekly volume, muscle coverage, fatigue feedback, next-session adjustment notes.
- Local-first content: seed exercise and plan content bundled with the app, with later support for content updates from FitTracker's own backend.

Out of scope for MVP:

- MuscleWiki official API integration.
- Social feeds, coach booking, ecommerce, and public leaderboards.
- Real AI model plan generation.
- Full video production workflow and content management UI.
- Multi-user backend auth as a dependency for workout recording.

## Architecture

Recommended clean project structure:

```text
entry/src/main/ets/
+-- app/
+-- features/
|   +-- onboarding/
|   +-- planner/
|   +-- exercise/
|   +-- workout/
|   +-- review/
|   +-- profile/
+-- shared/
|   +-- components/
|   +-- styles/
|   +-- models/
|   +-- services/
|   +-- utils/
+-- mock/
```

Data layers:

- Seed content layer: bundled exercise, muscle, equipment, media placeholder, and plan-rule data.
- Local user layer: user goals, generated plans, sessions, sets, records, content version, and sync status.
- Remote content layer: future FitTracker-owned backend for exercise library, videos, plan templates, and content version updates.

Training records must always save locally first. Content updates must never block a workout.

## Core Services

- `ContentRepository`: reads seeded and synced exercise content, muscle groups, equipment, videos, common mistakes, safety notes, and exercise replacement groups.
- `PlanEngine`: generates rule-based plans from user goal, level, equipment, frequency, session length, and restrictions.
- `WorkoutRepository`: stores workout sessions, sets, notes, replacement events, and draft sessions.
- `ReviewService`: calculates completion rate, volume, PRs, estimated 1RM, muscle coverage, and next-session suggestions.
- `SyncService`: checks content version, downloads incremental content updates, validates schema versions, and falls back to local content.

## Prototype Map

Five primary tabs:

- Home: today's workout, goal progress, recent PR, continue workout.
- Plan: goal setup, generated plan, cycle view, training day detail, exercise replacement.
- Exercise: muscle map, search, filters, exercise list, exercise detail, video teaching.
- Workout: workout recorder, rest timer, exercise instruction, completion summary.
- Review: stats dashboard, muscle coverage, personal records, fatigue and recovery feedback.

Main flows:

- First use: Launch -> Goal questionnaire -> Equipment and restriction setup -> Generated plan -> Home.
- Training day: Home -> Workout preview -> Active workout -> Completion summary -> Review suggestion.
- Exercise exploration: Muscle map -> Muscle exercise list -> Exercise detail -> Add to plan or replace current exercise.
- Content update: Seed content available -> Check content version -> Incremental update -> Cached fallback on failure.

## Code Standards Direction

The new code standard should enforce:

- Feature-first folders with shared cross-feature utilities.
- ArkTS strict-mode safe data modeling: no `any`, no `unknown`, no `as any`, no `as const`, no untyped object literals.
- Factory functions or classes for seed and mock data.
- Dot property access instead of dynamic index access.
- Design tokens for all colors, typography, spacing, radius, shadow, motion, and touch targets.
- Chinese UI copy as centralized resources/constants.
- Strict separation between content data and user training data.

## Initialization Strategy

The first implementation phase should initialize a clean skeleton rather than fully rewrite all behavior in one pass:

- Create new feature-first folders.
- Add typed models for goals, exercises, plan rules, workouts, records, and sync metadata.
- Add seed/mock content files aligned with the future self-owned database schema.
- Add placeholder pages for the five tabs and onboarding flow.
- Add route registration.
- Add repository and service stubs with local-first contracts.
- Keep existing project files available for reference until the new structure has equivalent behavior.

## Open Risks

- The future video and exercise content database requires its own schema, versioning, copyright policy, and content review workflow.
- HarmonyOS media playback and caching constraints must be verified before final video UX.
- Full clean initialization can temporarily reduce feature completeness unless implemented in milestones.
- Existing docs and code contain mojibake in Chinese strings; rewriting documents and seed content in clean UTF-8 is required.
