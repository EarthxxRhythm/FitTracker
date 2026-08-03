# 几何证据状态

## 已达到节点级证据

- Welcome：有完整节点坐标、尺寸、字体、颜色、圆角、阴影、资源和 z-order；已按 `430 → 390` 固定比例重建。

## 由现有 ArkUI 与设备截图反推

- Home、Plan、Workout Preview、Active Workout、Review、Profile
- Splash、Login、Register、Workout Complete

这些页面当前是可编辑的证据驱动恢复页，不应被表述为原始 Pencil 节点的逐像素恢复。原始 `.pen` 已丢失，非 Welcome 页缺少原始逐节点数据，因此仍需用户提供新截图或原始备份后再做最终逐项比对。

## 已验证

- 11 个顶层页面 Frame 均为 `390 x 844`。
- 所有页面都不包含手机外框、Notch 或伪状态栏。
- Home 壳层的 `BottomTabBar (AppShell-owned)` 固定在页面底部；内容层与底栏分离。
- Pencil 节点扫描无残留裁剪或 flex 布局问题。
- PNG 与 HTML 已导出到 `exports/`。
