# 训练功能服务 目录约束

> **层级**：L2 展开
> **最后核对**：2026-10-28
> **上位文档**：`docs\process\engineering-constraints.md`（L1）
> **状态**：现行
> **路径基准**：文中路径相对 `apps\harmony\entry\src\main\ets\`
> **适用端**：仅鸿蒙

## 职责

`features/workout/services/` 只用于承载过于专属于训练流程、不宜放进 `shared/services/` 的编排，尤其是旧持久化模型与当前训练页之间的兼容桥。

## 归属

- `WorkoutSessionPersistenceBridgeService.ets`：把 `WorkoutRepository` 状态与 `common/services/WorkoutSessionService` 同步
- `WorkoutSessionEditService.ets`：训练摘要编辑辅助，作用域限于训练功能

## 反模式

- 不要在此重复训练计划、回顾或内容查找逻辑。
- 多功能共用的通用仓储不要加在本目录。
