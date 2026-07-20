# Repo File Audit - 2026-07-20

## Active Main-Line Pages

- `app/StartupPage`
- `pages/LoginPage`
- `pages/RegisterPage`
- `features/onboarding/pages/GoalSetupPage`
- `pages/HomePage`
- `features/exercise/pages/ExerciseLibraryPage`
- `features/exercise/pages/ExerciseDetailPage`
- `features/monetization/pages/MonetizationHubPage`
- `features/workout/pages/TrainingPlanDetailPage`
- `features/workout/pages/WorkoutPreviewPage`
- `features/workout/pages/ActiveWorkoutPage`
- `features/workout/pages/WorkoutSummaryPage`
- `features/review/pages/ReviewHomePage`

## Legacy or Suspect Files

- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/pages/ProfilePage.ets`
- `entry/src/main/ets/pages/ExerciseDetailPage.ets`
- `0`

## Service Boundary Notes

- `common/services`: persistence, auth, user profile, stable app-level stores.
- `shared/services`: cross-feature content, plan, review, backup, sync, and derived view-model logic.
- `features/workout/services`: compatibility bridges and workout-page-specific orchestration.

## Top-Level Artifact Decisions

- `0`: delete candidate; it is a 14-byte top-level file containing only `1836` and shows no repository-facing purpose.
- `design/`: keep; it contains structured product and design assets that belong with the repository.
- `test_run/`: ignore-or-clean candidate; it currently looks like local test output rather than source-of-truth project input.
- `.gitignore`: defer changes in this pass because the file was already modified before cleanup started.
