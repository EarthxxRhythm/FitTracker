# Pages — Knowledge Base

## OVERVIEW

`@Entry @Component` page structs registered in `resources/base/profile/main_pages.json`. Each page handles one screen with `aboutToAppear()` for data loading and `build()` returning the UI tree.

## STRUCTURE

```
pages/
├── Index.ets                # Homepage: plan list + today's training view
├── RegisterPage.ets         # Phone/password registration
├── LoginPage.ets            # Phone/password login (redirects to Index)
├── ProfilePage.ets          # User profile, stats overview, settings placeholders
├── PlanDetailPage.ets       # Plan preview with timeline, "开始此计划" button
├── ExerciseLibraryPage.ets  # Exercise catalog with muscle group filters
├── ExerciseDetailPage.ets   # Exercise details: description, muscles, personal records
├── WorkoutRecorderPage.ets  # Live training: timer, set entry, 1RM, save session
└── StatsPage.ets            # Weekly stats + monthly calendar heatmap
```

## WHERE TO LOOK

| Page | Registered As | Key Features |
|------|--------------|--------------|
| `Index` | `pages/Index` | Preset plans, my plans, today's training → navigates to WorkoutRecorderPage |
| `WorkoutRecorderPage` | `pages/WorkoutRecorderPage` | Timer, accordion exercise list, set weight/reps, 1RM, notes, save session |
| `StatsPage` | `pages/StatsPage` | Weekly stats (count/duration/sets/volume), calendar heatmap |
| `ExerciseDetailPage` | `pages/ExerciseDetailPage` | Exercise info tabs, muscle groups, personal records (best 1RM) |
| `ExerciseLibraryPage` | `pages/ExerciseLibraryPage` | Searchable exercise catalog, muscle group filter |

## CONVENTIONS

- **Page structure**: `@Entry @Component struct XxxPage { @State variables; async aboutToAppear() { load data }; build() { Column() { ... } } }`
- **Navigation**: `router.pushUrl({ url: 'pages/XxxPage', params: { ... } })`. Params read via `router.getParams() as Record<string, T>` in `aboutToAppear()`.
- **Navigation params**: Always wrapped in `try-catch`. Use type assertion with fallback defaults.
- **Data loading**: Async operations in `aboutToAppear()`, not in constructors. Results stored in @State.
- **Services**: Imported as singletons (e.g., `import WorkoutSessionService from '...'`). Call with `getContext(this)`.
- **Builder methods**: Use `@Builder` for repeated UI fragments (e.g., `summaryItem`, `statItem`).

## ANTI-PATTERNS

- **DO NOT** create pages without registering in `main_pages.json`.
- **DO NOT** use `router.replaceUrl` for normal navigation — use `pushUrl`.
- **DO NOT** forget to stop timers/intervals in `aboutToDisappear()`.
- **DO NOT** hardcode navigation URLs — always reference from `main_pages.json` entries.
