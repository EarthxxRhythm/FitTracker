# Workout Feature Services - Knowledge Base

> **层级**：L2 展开
> **最后核对**：2026-10-27
> **上位文档**：仓库根 `AGENTS.md`（L1）
> **状态**：现行
> **路径基准**：文中路径相对 `apps\harmony\entry\src\main\ets\`
> **适用端**：仅鸿蒙

## OVERVIEW

`features/workout/services/` is reserved for workout-flow orchestration that is too specific to live in `shared/services/`, especially compatibility bridges between the legacy persistence model and the current workout pages.

## OWNERSHIP

- `WorkoutSessionPersistenceBridgeService.ets`: syncs `WorkoutRepository` state with `common/services/WorkoutSessionService`
- `WorkoutSessionEditService.ets`: workout summary editing helpers scoped to the workout feature

## ANTI-PATTERNS

- Do not duplicate plan, review, or content lookup logic here.
- Do not add generic repositories here when they are used by multiple features.
