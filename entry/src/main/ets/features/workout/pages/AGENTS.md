# Workout pages 目录约束

当前主线训练页面位于 `features/pencil/PencilPreviewPage` 和 `features/pencil/PencilActivePage`，并由 `AppRoutes.ets` 与 `main_pages.json` 管理。

本目录仅保留当前注册的 `WorkoutCompletePage.ets` 与 `WorkoutSummaryPage.ets`。旧的预览和执行页面已移除；训练数据兼容逻辑统一放在 `features/workout/services/`，不得在本目录重新创建第二套训练主线。
