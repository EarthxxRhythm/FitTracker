# 06_prototype_redraw — HTML 设计冻结基线与还原规格

本目录是 **Open Design HTML 设计 → ArkUI 代码还原**的规格仓库（唯一视觉事实源副本）。

## 目录结构

```text
src/                  # 冻结基线：从 Open Design 目录整体复制（勿手改）
  fittracker-webapp.html        # 15 路由预览壳（390×844 iframe + 页面目录）
  fittracker-*.html             # 各屏设计（每文件含 1~2 个 data-od-id="screen-*" frame）
  fittracker-*.artifact.json    # Open Design 产物元数据
  assets/                       # ft-stage.js / exercise-gifs/ / opengym-ref/
scripts/extract_specs.py        # 从 src/ 自动生成 MANIFEST.md + MOTION.md
MANIFEST.md                     # 15 路由 → 屏文件/frame → 仓库落点清单
MOTION.md                       # 逐屏动效声明（@keyframes/transition/animation/:active）
TOKENS.md                       # 逐屏 :root 令牌 + 与 DesignTokens/MotionTokens 对照
README.md                       # 本文件
```

## 使用规则

1. `src/` 与三个 md 是**只读规格**；页面还原时逐字引用其中的中文文案、颜色、尺寸、动效值。
2. Open Design 外部目录（`C:\Users\19308\AppData\Roaming\Open Design\...\56d6b0af-...`）
   更新 HTML 后：核对 `src/` 与外部文件 diff → 将变化复制回 `src/` →
   重跑 `python scripts/extract_specs.py` → 只重截受影响屏并回归。
3. 还原约束、画布口径、token 映射见 `docs/opendesign-1to1-rules.md`；
   动效 ArkUI 映射与验收见 `docs/motion-restore-workflow.md`。

## 画布口径（重要）

- 除 `screen-welcome`（430×900 画布 × `scale(0.90698)` ≈ 390×816 视口）外，
  **其余全部 390×844 直绘 = 设备 vp 1:1**；模拟器截图像素 ÷ 3.3846 对齐后做像素对比。
- 每屏 frame 是否含底部 tab、是否绝对定位/流式（`.appshell` flex），以 src 内 markup 为准，
  还原前先读对应 frame，不凭旧实现猜测。
