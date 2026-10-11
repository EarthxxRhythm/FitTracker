# Proposal: Add Comment Feature

> **2026-09-11 状态校准（部分实现）**
> - **已实现**：训练会话持久化 —— `common/services/WorkoutSessionService.ets`
>   （`saveSession` / `updateSession` / `replaceSessions` / `getSessions`）；`WorkoutSession` 模型含 `notes` 字段。
> - **未落地**：训练完成页的备注输入 UI（`features/workout/pages/WorkoutCompletePage.ets` 内无备注输入控件）。
> - **引用失效**：本文提到的 `WorkoutRecorderPage.ets`、`StatsPage.ets` 均已删除。
> - 结论：保留记录，但不作为现成任务；若继续该功能，须按 pencil 主线页面结构重写。

## Summary

Add the ability for users to write and save training session notes (训练感受备注) when completing a workout. This is Feature #26 from the feature checklist, currently marked as implemented but missing the notes input and session persistence in the WorkoutRecorderPage.

## Motivation

- **Feature Gap**: Feature #26 describes "用户可添加训练感受备注文字后保存" — users should be able to add training feeling notes and save them. Currently the WorkoutRecorderPage shows a summary with only duration, sets, and volume, then routes back without saving anything.
- **No Session Persistence**: Workout sessions are never persisted, meaning the StatsPage always shows zero stats and ExerciseDetailPage always shows "尚未记录" (not yet recorded). Saving sessions with notes is the foundation for all statistics and history features.
- **User Value**: Training notes help users track how they felt during a workout, note injuries, mark progress milestones, and reflect on effectiveness over time.

## Scope

### In Scope
- Add a multi-line text input field for training notes to the workout completion summary screen
- Persist completed workout sessions (exercises, sets, duration, volume, notes) to local preferences
- Create a `WorkoutSessionService` for session persistence and retrieval
- Connect saved sessions to the StatsPage weekly stats display
- Connect saved sessions to the ExerciseDetailPage personal records display

### Out of Scope
- Exercise-level notes (plan_day_exercises.note) — separate feature for plan editing
- Social/sharing features (comments between users) — V1.4
- Editing or deleting historical notes — can be added later
- Server-side storage — this is a local-only app

## Impact

- **New file**: `WorkoutSessionService.ets` — service for session CRUD via preferences
- **Modified**: `WorkoutRecorderPage.ets` — add notes input, save session on completion
- **Modified**: `StatsPage.ets` — read real stats from saved sessions
- **Modified**: `ExerciseDetailPage.ets` — read personal records from saved sessions
