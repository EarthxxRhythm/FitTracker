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

## Validation Notes

- `git diff --check`: passed for this cleanup pass with CRLF normalization warnings only.
- `hvigorw assembleHap --mode module -p product=default`: could not run on July 20, 2026 because `hvigorw` was not available in the current shell environment (`CommandNotFoundException`).

## Final Boundary Summary

### Safe to clean now

- `entry/src/main/ets/pages/ExerciseDetailPage.ets` (already removed in this pass)
- `0` (top-level stray file; delete candidate after one last owner check if desired)

### Must wait until current dirty feature work is isolated

- `.gitignore`
- `entry/src/main/ets/app/StartupPage.ets`
- `entry/src/main/ets/common/services/TrainingPlanService.ets`
- `entry/src/main/ets/common/services/WorkoutSessionService.ets`
- `entry/src/main/ets/features/exercise/pages/ExerciseDetailPage.ets`
- `entry/src/main/ets/features/exercise/pages/ExerciseLibraryPage.ets`
- `entry/src/main/ets/features/onboarding/pages/GoalSetupPage.ets`
- `entry/src/main/ets/features/review/pages/ReviewHomePage.ets`
- `entry/src/main/ets/features/workout/pages/ActiveWorkoutPage.ets`
- `entry/src/main/ets/features/workout/pages/TrainingPlanDetailPage.ets`
- `entry/src/main/ets/features/workout/pages/WorkoutPreviewPage.ets`
- `entry/src/main/ets/features/workout/pages/WorkoutSummaryPage.ets`
- `entry/src/main/ets/shared/services/PlanEngine.ets`
- `entry/src/main/ets/shared/services/ReviewDashboardService.ets`
- `entry/src/main/ets/shared/services/ReviewInsightsService.ets`
- `entry/src/main/ets/shared/services/WorkoutPreviewService.ets`
- `entry/src/main/ets/shared/services/WorkoutSummaryService.ets`

### Follow-up candidates after the workspace is clean

- `docs/项目重新初始化方案.md` (still documents the removed `pages/ExerciseDetailPage.ets`)
- `docs/superpowers/plans/2026-05-23-fittracker-clean-arkui-skeleton.md` (historical plan still mentions the removed page path)
- `test_run/` (decide whether to ignore or purge generated output)
- `entry/src/main/ets/pages/Index.ets` and `entry/src/main/ets/pages/ProfilePage.ets` (keep as legacy shells unless product explicitly retires them)
