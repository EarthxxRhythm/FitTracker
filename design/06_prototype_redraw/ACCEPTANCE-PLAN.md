# 全屏验收计划与到达路径（ACCEPTANCE-PLAN）

> 15 设计屏的设备验收：渲染参照帧 → seed/路径到屏 → 截图 → `--crop` 内容区对比。
> 命令模板：`powershell -ExecutionPolicy Bypass -File tools/restore-accept.ps1 -Html <file> -FrameIndex <i> -Name <name> -Seed <seed> -Crop 100,740 [-SkipInstall] [-IgnoreRect x0,y0,x1,y1;...]`

## 参照帧与到达

| 屏 | src file | frame index | seed/到达 | 备注 |
|---|---|---|---|---|
| welcome | fittracker-welcome-home.html | 0 | 清数据冷启 | 参考页 |
| home | fittracker-welcome-home.html | 1 | today_flow | Tab 首页 |
| login | fittracker-auth.html | 0 | 清数据（无会话） | |
| register | fittracker-auth.html | 1 | 清数据 → welcome → 注册 | |
| plan | fittracker-plan.html | 0 | today_flow → Tab 计划 | |
| workout(preview) | fittracker-training-preview.html | 0 | today_flow → 查看预览 | |
| plans | fittracker-plan-detail.html | 0 | today_flow → 计划组入口 | 新页注册后 deep-link 也可 |
| planGroup | fittracker-plan-group-detail.html | 0 | plans 点击进入 | |
| active | fittracker-training.html | 0 | today_flow → 开始训练 | |
| complete | fittracker-training-complete.html | 0 | 走完训练闭环 | |
| review | fittracker-review.html | 0 | review_metrics | Tab 回顾 |
| library | fittracker-exercise-library.html | 0 | today_flow → 动作库入口 | |
| body | fittracker-body-data.html | 0 | profile 快捷「身体数据」 | 新页 |
| profile | fittracker-personal.html | 0 | today_flow/review_metrics | Tab 我的 |
| settings | fittracker-settings.html | 0 | profile 设置钮 | 新页 |

## 度量口径（2026-09-07 修正，诚实可落地）

- 内容区裁剪：`--crop 100,740`（状态栏与底部系统带不计入）。
- 文本掩码：`--ignore-rect`（a11y 像素 bounds÷3.3846−y偏移100 换算）——字体栅格化差异**不进入指标**。
- **指标 = 非文本内容区像素一致性**，达标线：
  - 无几何/配色/间距错误（热力图仅剩 1px 边缘 AA）→ `超过阈值` 应≤8%；
  - 不再以“≤2% 原始像素”为目标——跨渲染器（浏览器 vs ArkUI）字体齿化 + 边缘 AA 无法经像素 diff 消除，
    2% 是**不可达成**的伪门槛。
- 判定以**视觉复核**（人眼/midscene 看 heatmap）为主：深色=匹配，仅描边/字迹微亮=达标。

## 说明（诚实约束）

- 模拟器为固定 390vp；320/360/430 响应式冒烟当前只能做**静态代码审计**（无 >390 硬编码宽，
  已扫描干净）+ 真机多机型抽测（设备在列时补）；字号 ≤1.3× 不破版需 CodeLinter/人工抽验。
- 像素收敛迭代依赖人眼/视觉模型看 heatmap 定位（文本报告只能给到“行带/象限”粒度）。

## 垂直对齐口径（2026-09-12 新增，修正系统错位）

**问题**：设备截图是**整屏**（含系统状态栏），原型参照帧是 `.phone` 画布（无状态栏）。
`compare.py` 原先对两张图使用同一组裁剪坐标，页面元素整体错开，制造大面积**伪差**。

**实测偏移（三条独立锚点，像素级）**：

| 锚点 | 原型帧 y | 设备帧 y | 差 |
|---|---|---|---|
| 日期文字带 | 58 | 94 | 36 |
| 问候文字带 | 84 | 118 | 34 |
| 今日卡上边框 | 141 | 176 | **35** |

取 **35vp** 为默认对齐量（今日卡边框是纯色 1px 线，几何量最可靠）。

⚠️ 注意：a11y 布局树 root 节点 `bounds` 从 132px 起（132 ÷ 3.3846 = 39.0vp），
**与像素锚点实测的 35vp 不一致**。**像素锚点为准**；a11y 的 132px 不能直接当对齐量用。

**用法**：`compare.py --align-y 35`（默认 0 = 旧行为，历史数字可复现）；
`restore-accept.ps1 -AlignY 35`（默认）；`genmask.py <ui.json> 35`（掩码同步偏移）。

**已知限度**：设备侧文本行高（ArkUI 默认）与 Chrome 的 `line-height: normal` 不同，
导致页面内部**累积收缩**——同一页顶部元素需偏移 35，而今日卡内 CTA 只需 30。
单一 `--align-y` 值无法逐元素对齐。因此验收时**同时记录两组数字**：

- **物理对齐（35）**：锚点法，可解释、可复现，含渲染器行高收缩残差。**达标判据以此为准。**
- **best-fit（扫描 0–50 取最优）**：排除累积收缩后的还原度参考值，仅供定位参考，不作达标依据。

home 屏实测：物理 35 → 超阈 11.66%；best-fit 30 → 超阈 9.22%（`--align-y 0` 时 22.66%）。

**数据驱动元素豁免（显式登记）**：进度环外环带（设备 a11y `Progress [878,677][1203,1002]`
→ 对齐后约 x 259–355 / y 61–157）由 `weeklyProgressPercent` 决定，原型是静态示例值，
验收时列入 `--ignore-rect`。环之外的部分（inner 圆、阴影、背景）**仍计入**。
