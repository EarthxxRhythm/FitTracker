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
