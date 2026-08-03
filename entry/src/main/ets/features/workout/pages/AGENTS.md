# Workout pages 目录约束

当前主线训练页面位于 `features/pencil/PencilPreviewPage` 和 `features/pencil/PencilActivePage`，并由 `AppRoutes.ets` 与 `main_pages.json` 管理。

本目录的 `WorkoutCompletePage.ets`、`WorkoutSummaryPage.ets` 属于当前注册的完成/摘要页面；`ActiveWorkoutPage.ets` 与 `WorkoutPreviewPage.ets` 是迁移期间保留的兼容页面。兼容页面可能承载用户本地训练数据或原型行为，除非完成引用、测试和数据迁移核验，不要删除、移动或重新加入主路由。
