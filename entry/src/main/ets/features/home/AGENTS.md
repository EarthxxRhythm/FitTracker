# Home feature 迁移兼容区

`features/home/` 当前承载新版首页原型及其展示层服务，属于从 `pages/HomePage.ets` 迁移到 `features/pencil/PencilHomePage` 期间的兼容实现。

- `pages/HomePage.ets` 是兼容包装，不在这里新增主线路由。
- `HomePageV2.ets`、`HomeDashboardService.ets` 和 `HomeResumeService.ets` 保留给现有原型与测试使用。
- 新版主线页面、路由和页面注册以 `features/pencil/`、`AppRoutes.ets` 与 `main_pages.json` 为准。
- 未完成引用核验前，不要删除或移动本目录文件；迁移完成后再统一清理兼容层。
