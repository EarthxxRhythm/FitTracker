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

## 度量口径

- 内容区裁剪：`--crop 100,740`（状态栏与底部系统带不计入）。
- 文本掩码：`--ignore-rect` 可重复传，用于种子数字/日期噪声区（坐标 = 裁剪后 390 宽 vp 空间；
  a11y 像素 bounds ÷3.3846 − y偏移100 换算）。
- 门槛：内容区超阈 ≤2%；残差带定位看 report 行带/象限 + sidebyside/heatmap（人眼或视觉模型复核）。

## 说明（诚实约束）

- 模拟器为固定 390vp；320/360/430 响应式冒烟当前只能做**静态代码审计**（无 >390 硬编码宽，
  已扫描干净）+ 真机多机型抽测（设备在列时补）；字号 ≤1.3× 不破版需 CodeLinter/人工抽验。
- 像素收敛迭代依赖人眼/视觉模型看 heatmap 定位（文本报告只能给到“行带/象限”粒度）。
