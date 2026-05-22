# Startup Migration Record

- `EntryAbility` now loads `app/StartupPage` as the application entry page.
- `main_pages.json` keeps legacy routes but registers `app/StartupPage` first.
- `StartupPage` routes into `StartupDecision.getInitialRoute(false)`, which currently opens the goal setup flow until goal persistence is implemented.
- Startup routing tests in `entry/src/test` and `entry/src/ohosTest` now assert the new startup entry.

## Goal Persistence Step

- `GoalRepository` now stores the current goal in memory and mirrors it to the `fit_tracker_goal` preferences store.
- `StartupPage` calls `GoalRepository.hasSavedGoal(...)` and routes returning users with a saved goal to `pages/HomePage`.
- `GoalSetupPage` includes a minimal default-goal save action that writes the goal and enters the new home page.

## Goal Questionnaire Step

- `GoalSetupService` now maps onboarding selections into a typed `UserGoal`.
- `GoalSetupPage` now captures goal type, experience level, weekly training days, session duration, and available equipment.
- The save action persists the selected goal and routes into the new home page.
