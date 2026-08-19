# Components 目录约束

这里放跨页面复用的 ArkUI `@Component`。页面专属的 builder 和局部展示逻辑留在 feature 页面内；旧的全局标签栏、统计徽章和空状态组件已经移除，不要恢复成第二套导航体系。

当前主要组件：

- `AppButton`：主按钮、次按钮、ghost 按钮和 loading 状态。
- `AppCard`：panel/elevated/outlined 内容容器。
- `AppInput`：表单输入包装。
- `BottomTabBar`：Pencil 应用壳底部导航。
- `PageHeader`、`PrimaryDestinationStrip`、`SearchBar`：内容页布局组件。
- `StageRail`：训练流程展示组件。

约定：

- 配置使用 `@Prop`，回调使用显式函数类型；不要在通用组件里保存业务状态。
- 视觉值优先来自 `DesignTokens.ets` 或 feature 内集中声明的 token。
- 保持 `AppButton` 主按钮使用 `ColorTokens.PRIMARY`，ghost 变体不添加阴影。
- 交互控件满足最小触控尺寸；不要用硬编码尺寸替代 `TouchTokens`、`SpacingTokens` 和 `RadiusTokens`。
