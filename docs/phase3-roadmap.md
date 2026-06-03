# FitTracker Phase 3 Roadmap

更新时间：2026-06-03

## 结论先行

Phase 3 结束后，`phase3.5` 建议只放入“低耦合、能直接提升留存与内容可用性”的两件事，顺序如下：

1. **本地备份/恢复 MVP**
   - 目标是备份和恢复用户数据，不碰 `.ets` 页面重构，不引入账号体系。
   - 推荐先做“应用内手动导出/导入 JSON 包”，再评估是否补齐 `EntryBackupAbility` 的系统级接入。
2. **动作详情媒体能力的最小闭环**
   - 先补齐媒体元数据、授权信息、占位与降级策略。
   - 在资源来源和包体策略明确后，再接轻量播放器。

不建议进入 `phase3.5` 的内容：

- **完整内容库数据库备份**：当前内容库可由种子数据重新导入，收益低于复杂度。
- **大规模离线视频内置**：包体、缓存、版权风险都偏高。
- **训练草稿跨版本恢复正式化**：当前已经有 `WorkoutDraftService` 本地持久化和首页恢复入口，但还没有进入备份 schema、版本迁移与冲突处理链路。

## 当前状态摘要

### 已经落本地的用户数据

- `goal`
  - `entry/src/main/ets/shared/services/GoalRepository.ets`
  - `fit_tracker_goal` / `current_goal`
- `plan`
  - `entry/src/main/ets/common/services/TrainingPlanService.ets`
  - `fit_tracker_plans` / `my_plans` / `current_plan_id`
- `session`
  - `entry/src/main/ets/common/services/WorkoutSessionService.ets`
  - `fit_tracker_sessions` / `sessions`
- `draft`
  - `entry/src/main/ets/common/services/WorkoutDraftService.ets`
  - `fit_tracker_active_workout` / `workout_draft`
  - 当前仅用于应用内恢复，不建议直接进入 phase3.5 备份范围

### 已有但不完整的备份接入点

- `entry/src/main/ets/entrybackupability/EntryBackupAbility.ets`
  - 已注册 Backup Extension，但 `onBackup()` / `onRestore()` 目前只有日志，没有真实数据搬运逻辑。
- `entry/src/main/resources/base/profile/backup_config.json`
  - 当前仅打开 `allowToBackupRestore: true`。

### 内容层现状

- 本地动作内容可由 JSONL 种子导入 `fittracker_content.db`。
- `SyncService` 仍是占位实现，说明远端内容同步与缓存策略尚未成立。
- 当前动作数据里已经存在 `videoUrl` / `coverUrl` 字段，但多数仍是空值或 `local://` 占位。
- 回顾页已经接入目标调整预览，说明 phase3.5 在体验层更适合优先推进“可解释的调整”和“可恢复的数据”，而不是继续扩张页面数量。

## Phase 3.5 推荐范围

### P1：本地备份/恢复 MVP

推荐进入 `phase3.5`，但范围要收紧为：

- 只备份用户自产数据：`goal`、`plan`、`session`
- 可选备份轻量元数据：内容版本号、当前计划指针
- 不备份内容种子、整库动作数据、媒体缓存

推荐实施顺序：

1. 定义统一备份包结构与版本号
2. 支持手动导出
3. 支持校验后导入
4. 处理重复 session、旧版本字段兼容、失败回滚
5. 再评估是否把同一套数据模型接到 `EntryBackupAbility`

### P2：动作详情媒体最小闭环

推荐进入 `phase3.5`，但先做资源治理，再做播放：

1. 统一媒体字段和授权字段
2. 补齐封面/占位/空状态
3. 小范围接入短视频播放器
4. 最后再看缓存与预下载

不建议一上来做：

- 多角度视频
- 大规模本地离线包
- 自动缓存整库视频
- 第三方未授权素材接入

## 延后项

以下内容建议放到 `phase4` 或更晚：

- 系统级自动备份/系统恢复的正式交付
- 训练中断草稿的稳定持久化与跨版本恢复
- 内容增量同步
- CDN 媒体缓存策略
- 媒体审核流与版权台账

## 关联文档

- [phase3.5 候选评估](./phase3.5-candidate-evaluation.md)
- [内容数据库适配与本地数据库表设计](./content-database-schema.md)
- [动作视频自建数据库方案](./动作视频自建数据库方案.md)
- [内容导入说明](./内容导入说明.md)
