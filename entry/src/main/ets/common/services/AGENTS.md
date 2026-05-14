# Services — Knowledge Base

## OVERVIEW

Singleton service classes for business logic and data persistence. All services use `@ohos.data.preferences` for storage, follow `export default new ClassName()` pattern, and receive `context: Context` in async methods.

## STRUCTURE

```
services/
├── AuthService.ets          # Mock auth (in-memory Map), token via SessionManager
├── TrainingPlanService.ets  # 5 preset plans, plan enable/CRUD, today's training
├── WorkoutSessionService.ets# Session save/load, weekly stats, personal records
├── ExerciseService.ets      # Exercise catalog (enum-like: getById, getAll, search)
├── SessionManager.ets       # Token management (generate, validate, clear)
└── UserProfileService.ets   # User profile persistence (name, avatar, stats)
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Auth flow | `AuthService.ets` + `SessionManager.ets` | `register()`, `login()` return `AuthResult { success, message, token }` |
| Training plans | `TrainingPlanService.ets` | `PRESET_PLANS[]`, `enablePlan(context, id)`, `getTodayTraining(plan)` |
| Workout data | `WorkoutSessionService.ets` | `saveSession()`, `getWeeklyStats()`, `getAllExerciseRecords()` |
| Exercise data | `ExerciseService.ets` | `getById(id)`, `getAll()`, `getByMuscle(muscle)` |
| User profile | `UserProfileService.ets` | Store: `fit_tracker_profile`, keys: `name`, `avatar`

## CONVENTIONS

- **Instantiation**: Module-level `export default new ServiceName()`. Callers import the singleton directly.
- **Preferences pattern**:
  ```typescript
  import { preferences } from '@kit.ArkData'
  const STORE_NAME = 'fit_tracker_xxx'
  const prefs = await preferences.getPreferences(context, STORE_NAME)
  await prefs.put(KEY, JSON.stringify(data))
  await prefs.flush()
  ```
- **Store naming**: All use `fit_tracker_` prefix (e.g., `fit_tracker_plans`, `fit_tracker_sessions`).
- **Error handling**: `try-catch` around preferences calls, return fallback defaults (empty array, null).
- **Export interfaces**: Service files export their type interfaces (e.g., `UserPlan`, `WorkoutSession`, `ExerciseRecord`).

## ANTI-PATTERNS

- **DO NOT** instantiate services with `new` — always use the singleton instance.
- **DO NOT** use a store name without the `fit_tracker_` prefix.
- **DO NOT** forget `.flush()` after `.put()` — data won't persist.
