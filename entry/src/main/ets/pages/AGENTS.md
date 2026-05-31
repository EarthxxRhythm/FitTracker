# Pages — Knowledge Base

## OVERVIEW

`pages/` now contains the auth entry pages, `HomePage`, and legacy page shells kept out of the main route. The active product flow lives in `app/` and `features/`, and `main_pages.json` should only point at those main-line screens plus the explicit auth entry points.

## STRUCTURE

```
pages/
├── RegisterPage.ets         # Phone/password registration
├── LoginPage.ets            # Phone/password login
├── HomePage.ets             # Today's training entry + current plan summary
├── Index.ets                # Legacy homepage shell, not part of the main route
├── ProfilePage.ets          # Legacy personal center shell, not part of the main route
├── PlanDetailPage.ets       # Legacy plan detail shell, not part of the main route
├── ExerciseLibraryPage.ets  # Legacy exercise library shell, not part of the main route
├── ExerciseDetailPage.ets   # Current exercise detail page under features/
├── WorkoutRecorderPage.ets  # Legacy workout recorder shell, not part of the main route
├── StatsPage.ets            # Legacy stats shell, not part of the main route
└── RudderStyleTab.ets       # Legacy tab shell, not part of the main route
```

## WHERE TO LOOK

| Page | Registered As | Key Features |
|------|--------------|--------------|
| `LoginPage` | `pages/LoginPage` | Phone/password login entry |
| `RegisterPage` | `pages/RegisterPage` | Phone/password registration entry |
| `HomePage` | `pages/HomePage` | Today's training entry, current plan summary, start workout |
| `ExerciseDetailPage` | `features/exercise/pages/ExerciseDetailPage` | Exercise info tabs, muscle groups, personal records (best 1RM) |

## CONVENTIONS

- **Page structure**: `@Entry @Component struct XxxPage { @State variables; async aboutToAppear() { load data }; build() { Column() { ... } } }`
- **Navigation**: main-line routes should use `AppRoutes` or feature paths. Legacy page shells stay out of new navigation. Params read via `router.getParams() as Record<string, T>` in `aboutToAppear()`.
- **Navigation params**: Always wrapped in `try-catch`. Use type assertion with fallback defaults.
- **Data loading**: Async operations in `aboutToAppear()`, not in constructors. Results stored in @State.
- **Services**: Imported as singletons (e.g., `import WorkoutSessionService from '...'`). Call with `getContext(this)`.
- **Builder methods**: Use `@Builder` for repeated UI fragments (e.g., `summaryItem`, `statItem`).

## ANTI-PATTERNS

- **DO NOT** create pages without registering in `main_pages.json`.
- **DO NOT** use `router.replaceUrl` for normal navigation — use `pushUrl`.
- **DO NOT** forget to stop timers/intervals in `aboutToDisappear()`.
- **DO NOT** hardcode navigation URLs — always reference from `main_pages.json` entries.
- **DO NOT** re-register legacy page shells such as `Index`, `WorkoutRecorderPage`, or `StatsPage` into the main route.
