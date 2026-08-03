# Pencil 原型完整链路

```text
Pencil Splash
  -> 未登录：Pencil Welcome
      -> 开始使用：Pencil Login
          -> 立即注册：Pencil Register
              -> 注册成功：Pencil Login
          -> 登录成功：Pencil Splash（读取本地会话）
              -> Pencil Home
  -> 已登录：Pencil Home

Pencil Home
  -> 计划：Pencil Plan
      -> 开始今日训练：Pencil Workout Preview
          -> 开始训练：Pencil Active Workout
              -> 完成本组：Rest 状态 / 下一组
              -> 完成训练：现有 Workout Summary
                  -> 查看训练回顾：Pencil Review
  -> 训练：Pencil Active Workout
  -> 回顾：Pencil Review
  -> 我的：Pencil Profile
      -> 返回首页：Pencil Home
```

实现约束：

- 所有页面都使用固定 `390x844` 目标 viewport，不实现额外 responsive 行为。
- 不绘制 Pencil 中的手机外框、Notch、伪状态栏和设备阴影。
- 页面间通过 `AppRoutes` 和 `main_pages.json` 注册，训练服务与本地持久化保持原项目实现。
- `PencilActivePage` 内部用 `rest` 状态复现 `sS03p`，不新增独立页面壳。


当前视觉实现入口：entry/src/main/ets/features/pencil/PencilHomePage.ets；注册入口：entry/src/main/ets/features/pencil/PencilRegisterPage.ets。

