# FitTracker Pencil 原型恢复包

本目录用于保存基于现有工程证据重建的可编辑 Pencil 原型。

## 当前文档

- Pencil 文档：`FitTracker-rebuilt.pen`
- 当前已恢复：Welcome、Home、Plan、Workout Preview、Active Workout、Review、Profile、Splash、Login、Register、Workout Complete
- 目标 viewport：`390 x 844`
- 不绘制手机外框、Notch、伪状态栏、设备阴影
- 不创建响应式断点；页面使用固定目标尺寸

## 证据来源

- 全页面几何：`../docs/pencil-all-pages-geometry-spec.md`
- Welcome 几何：`../docs/pencil-welcome-geometry-spec.md`
- 页面链路：`../docs/pencil-prototype-flow.md`
- 现有 ArkUI 页面：`../entry/src/main/ets/features/pencil/`
- SVG 资源：`../entry/src/main/resources/rawfile/`
- 设备回归截图：`../midscene_run/report/screenshots/`

## 恢复策略

1. 先建立页面级顶层 Frame，保持页面名称和链路稳定。
2. 先恢复 Welcome、Home、Plan、Preview、Active、Review、Profile。
3. 再补充 Login、Register、Splash、Workout Complete。
4. 每完成一个页面，使用 Pencil 截图和节点结构检查尺寸、层级、裁剪及文本。
5. 任何无法由现有证据确认的内容都标记为待核验，不伪造为原始设计。

几何证据分级见 `geometry-status.md`。原始 `.pen` 丢失后，非 Welcome 页面采用现有 ArkUI、设备截图和几何摘要进行可编辑恢复，不宣称为原始节点的逐像素复原。
