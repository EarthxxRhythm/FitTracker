# Workout pages 目录约束

> **层级**：L2 展开
> **最后核对**：2026-10-27
> **上位文档**：仓库根 `AGENTS.md`（L1）
> **状态**：现行
> **路径基准**：文中路径相对 `apps\harmony\entry\src\main\ets\`
> **适用端**：仅鸿蒙

当前主线训练页面位于 `features/pencil/PencilPreviewPage` 和 `features/pencil/PencilActivePage`，并由 `AppRoutes.ets` 与 `main_pages.json` 管理。

本目录仅保留当前注册的 `WorkoutCompletePage.ets` 与 `WorkoutSummaryPage.ets`。旧的预览和执行页面已移除；训练数据兼容逻辑统一放在 `features/workout/services/`，不得在本目录重新创建第二套训练主线。
