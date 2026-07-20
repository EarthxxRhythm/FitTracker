# Workout Feature Services - Knowledge Base

## OVERVIEW

`features/workout/services/` is reserved for workout-flow orchestration that is too specific to live in `shared/services/`, especially compatibility bridges between the legacy persistence model and the current workout pages.

## OWNERSHIP

- `WorkoutSessionPersistenceBridgeService.ets`: syncs `WorkoutRepository` state with `common/services/WorkoutSessionService`
- `WorkoutSessionEditService.ets`: workout summary editing helpers scoped to the workout feature

## ANTI-PATTERNS

- Do not duplicate plan, review, or content lookup logic here.
- Do not add generic repositories here when they are used by multiple features.
