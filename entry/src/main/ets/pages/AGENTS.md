# Pages — Knowledge Base

## OVERVIEW

`pages/` now contains the auth entry pages, `HomePage`, and two retained legacy shells. The active product flow lives in `app/` and `features/`, and `main_pages.json` should only point at those main-line screens plus the explicit auth entry points.

## STRUCTURE

```
pages/
├── RegisterPage.ets         # Phone/password registration
├── LoginPage.ets            # Phone/password login
├── HomePage.ets             # Today's training entry + current plan summary
├── Index.ets                # Legacy homepage shell, not part of the main route
└── ProfilePage.ets          # Legacy personal center shell, not part of the main route
```

## WHERE TO LOOK

| Page | Registered As | Key Features |
|------|--------------|--------------|
| `LoginPage` | `pages/LoginPage` | Phone/password login entry |
| `RegisterPage` | `pages/RegisterPage` | Phone/password registration entry |
| `HomePage` | `pages/HomePage` | Today's training entry, current plan summary, start workout |
| `Index` | `pages/Index` | Historical shell that points back to HomePage |
| `ProfilePage` | `pages/ProfilePage` | Historical shell that points back to HomePage |
| `ExerciseDetailPage` | `features/exercise/pages/ExerciseDetailPage` | Exercise info tabs, muscle groups, personal records (best 1RM) |

## CONVENTIONS

- **Page structure**: `@Entry @Component struct XxxPage { @State variables; async aboutToAppear() { load data }; build() { Column() { ... } } }`
- **Navigation**: main-line routes should use `AppRoutes` or feature paths. Legacy page shells stay out of new navigation. Use `this.getUIContext().getRouter()` for route params and navigation, and wrap param reads in `try-catch`.
- **Navigation params**: Always wrapped in `try-catch`. Use type assertion with fallback defaults.
- **Data loading**: Async operations in `aboutToAppear()`, not in constructors. Results stored in @State.
- **Services**: Imported as singletons (e.g., `import WorkoutSessionService from '...'`). When persistence or system APIs need a context, prefer `this.getUIContext().getHostContext()` with a null guard.
- **Builder methods**: Use `@Builder` for repeated UI fragments (e.g., `summaryItem`, `statItem`).

## ANTI-PATTERNS

- **DO NOT** create pages without registering in `main_pages.json`.
- **DO NOT** import deprecated page-level `router` helpers or call `getContext(this)` in active pages.
- **DO NOT** forget to stop timers/intervals in `aboutToDisappear()`.
- **DO NOT** hardcode navigation URLs — always reference from `main_pages.json` entries.
- **DO NOT** re-register legacy page shells such as `Index` or `ProfilePage` into the main route.
