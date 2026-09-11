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
scripts/check_sync.py           # 上游 Open Design 目录 <-> src/ 对账（exit 0=同步）
MANIFEST.md                     # 15 路由 → 屏文件/frame → 仓库落点清单
MOTION.md                       # 逐屏动效声明（@keyframes/transition/animation/:active）
TOKENS.md                       # 逐屏 :root 令牌 + 与 DesignTokens/MotionTokens 对照
README.md                       # 本文件
```

## 使用规则

1. `src/` 与三个 md 是**只读规格**；页面还原时逐字引用其中的中文文案、颜色、尺寸、动效值。
2. **上游设计源**：`C:\Users\19308\AppData\Roaming\Open Design\namespaces\release-stable-win\data\projects\56d6b0af-ac55-498d-9942-c02a4d35cc71`
   （Open Design 应用的项目数据目录；路径可用环境变量 `FITTRACKER_OPENDESIGN_DIR` 覆盖）。
   上游更新 HTML 后按此链路同步：

   ```bash
   python design/06_prototype_redraw/scripts/check_sync.py      # ① 对账 exit 0=同步 / 1=有漂移 / 2=源缺失
   # ② 逐文件核对后把变化复制回 src/（勿整体覆盖）
   python design/06_prototype_redraw/scripts/extract_specs.py   # ③ 重生成 MANIFEST.md + MOTION.md
   # ④ 只重截受影响屏并回归
   ```

   对账范围：上游**顶层** `*.html` / `*.artifact.json` + `assets/` 递归（当前 64 项；
   2026-09-11 核对结论为同步）。**有意不纳入 `src/` 的上游内容**（已在 `check_sync.py`
   的 `EXCLUDED` 登记，不计为漂移）：

   - `index.html` —— 2026-08-19 的早期单文件原型，无 `data-od-id` 规格帧，已被
     `fittracker-webapp.html` 壳 + 各分屏 html 取代。
   - 上游根目录的**设计意图文档与图片资产**：`training-complete-plan.md`、`today-plan-card-arc.md`、
     `review-stats-merge-plan.md`、`exercise-library-differentiation-plan.md`、`fittracker-logo-identity.md`、
     logo / drawing PNG 等 —— 属设计过程记录而非规格屏；需要设计意图时按路径直接查阅上游。

   > 遗留：`src/index.html.artifact.json` 是早期复制流程的副产物（对应 html 未纳入），非规格文件。
3. 还原约束、画布口径、token 映射见 `docs/opendesign-1to1-rules.md`；
   动效 ArkUI 映射与验收见 `docs/motion-restore-workflow.md`。

## 画布口径（重要）

- 除 `screen-welcome`（430×900 画布 × `scale(0.90698)` ≈ 390×816 视口）外，
  **其余全部 390×844 直绘 = 设备 vp 1:1**；模拟器截图像素 ÷ 3.3846 对齐后做像素对比。
- 每屏 frame 是否含底部 tab、是否绝对定位/流式（`.appshell` flex），以 src 内 markup 为准，
  还原前先读对应 frame，不凭旧实现猜测。
