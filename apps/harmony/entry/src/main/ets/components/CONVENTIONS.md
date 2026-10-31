# Components 目录约束

> **层级**：L2 展开
> **最后核对**：2026-10-27
> **上位文档**：`docs\process\engineering-constraints.md`（L1）
> **状态**：现行
> **路径基准**：文中路径相对 `apps\harmony\entry\src\main\ets\`
> **适用端**：仅鸿蒙

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
- 保持 `AppButton` 主按钮使用 `ColorTokens.PRIMARY`，ghost 变体不添加阴影。主按钮可用 `DuTokens.PRESS_DEPTH` 做硬边厚底（**只借形态、不改配色**，底边取 `ColorTokens.PRIMARY_PRESSED`）；有厚底时不要再叠加 `scale` 按压。
- 交互控件满足最小触控尺寸；不要用硬编码尺寸替代 `TouchTokens`、`SpacingTokens` 和 `RadiusTokens`。
