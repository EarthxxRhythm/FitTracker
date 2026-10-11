# Shared Services - Knowledge Base

## OVERVIEW

`shared/services/` owns cross-feature domain logic, content access, derived view-models, sync state, backup composition, and in-memory repositories used by the current feature-first flow.

## OWNERSHIP

- `ContentRepository`, `ContentDataSource`, `DatabaseContentDataSource`, `JsonlSeedContentDataSource`: content read path
- `PlanEngine`, `GoalSetupService`, `GoalAdjustmentPreviewService`, `HomePlanService`: plan and goal derivation
- `ReviewService`, `ReviewDashboardService`, `ReviewInsightsService`, `WorkoutSummaryService`, `PersonalRecordService`: review and analytics
- `WorkoutRepository`: in-memory workout session state for the new flow
- `SyncService`, `StartupContentSyncService`, `ContentDatabaseService`: content source and sync state
- `UserDataBackupService`, `SystemBackupBridgeService`, `PersistenceFallbackService`: backup and fallback composition

## ANTI-PATTERNS

- Do not add preferences-backed auth or profile persistence here.
- Do not move dirty files out of this folder until the user isolates ongoing feature work.
