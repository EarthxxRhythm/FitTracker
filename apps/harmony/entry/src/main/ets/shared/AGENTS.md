# Shared Services - Knowledge Base

> **层级**：L2 展开
> **最后核对**：2026-10-27
> **上位文档**：仓库根 `AGENTS.md`（L1）
> **状态**：现行
> **路径基准**：文中路径相对 `apps\harmony\entry\src\main\ets\`
> **适用端**：仅鸿蒙

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
