# pages 目录约束

`pages/` 不是当前主线页面目录。当前注册页面位于 `features/` 或 `app/`，并由 `main_pages.json` 与 `AppRoutes.ets` 管理。

`pages/HomePage.ets` 目前仅作为迁移期间的兼容包装保留；不要在这里新增登录、注册、首页、个人中心或历史页面。新页面按功能放入对应的 `features/*/pages/`，并完成路由注册与静态引用检查。

页面实现仍需遵守：

- 使用 `getUIContext().getRouter()` 导航，禁止引入旧的页面级 `router` helper。
- 路由参数显式声明类型，并在读取时使用 `try-catch` 和默认值。
- 异步数据加载放在 `aboutToAppear()`，timer/listener 在 `aboutToDisappear()` 清理。
- 业务服务以默认导出的 singleton 使用，不在页面内实例化服务。
