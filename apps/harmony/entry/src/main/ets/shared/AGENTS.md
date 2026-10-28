# 跨功能服务 · 共享层 约束

> **层级**：L2 展开
> **最后核对**：2026-10-28
> **上位文档**：仓库根 `AGENTS.md`（L1）
> **状态**：现行
> **路径基准**：文中路径相对 `apps\harmony\entry\src\main\ets\`
> **适用端**：仅鸿蒙

## 职责

`shared/services/` 承载跨功能的领域逻辑、内容读取、派生视图模型、同步状态、备份组装，以及当前以功能优先（feature-first）流程使用的内存仓储。

## 归属

- 内容读取链路：`ContentRepository` / `ContentDataSource` / `DatabaseContentDataSource` / `JsonlSeedContentDataSource`
- 训练计划与目标派生：`PlanEngine` / `GoalSetupService` / `GoalAdjustmentPreviewService` / `HomePlanService`
- 回顾与数据分析：`ReviewService` / `ReviewDashboardService` / `ReviewInsightsService` / `WorkoutSummaryService` / `PersonalRecordService`
- 训练会话内存状态：`WorkoutRepository`（为当前流程提供训练会话状态）
- 内容来源与同步状态：`SyncService` / `StartupContentSyncService` / `ContentDatabaseService`
- 备份与降级组装：`UserDataBackupService` / `SystemBackupBridgeService` / `PersistenceFallbackService`

## 反模式

- 不要在本目录加入 preferences 支撑的认证或资料持久化。
- 在用户完成对进行中功能改动的隔离之前，不要把脏文件移出本目录。
