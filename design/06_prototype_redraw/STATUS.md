# 还原进度与证据（STATUS）

> 更新：2026-09-07。每步产物均随 commit 落库；生成物（截图/报告）在 `test_run/`，不入库。

## 完成

- **第 1 步 · 冻结规格源** ✅（commit bcd73c9）
  - `src/`：13 屏 HTML + webapp 壳 + `assets/` 快照（唯一视觉规格源）
  - `MANIFEST.md`：15 路由 → 文件/frame → ArkUI 落点
  - `MOTION.md`：逐屏动效声明（@keyframes/transition/animation/:active）
  - `docs/opendesign-1to1-rules.md` 修订为 390×844 直绘口径
- **第 2 步 · Token 审计与校准** ✅（commit d1f1cc6）
  - `TOKENS.md`：跨屏变量一致性 / 色值语义映射 / MotionTokens 覆盖审计
  - `DesignTokens.ets`：新增 `MotionTokens.DURATION_PROGRESS=350`（进度 .35s fill）
  - 编译门禁通过（assembleHap 产出新 HAP）
- **度量管道验证（端到端）** ✅
  - 参照帧：`python tools/render-prototype-phone.py` → `test_run/prototype-phone/welcome-home.png`
  - 设备帧：hdc 截图 `test_run/welcome-device.jpeg`（1320×2856）
  - 对比：`tools/visual-diff/compare.py`（density 3.3846, threshold 16）→ `test_run/welcome-compare.md`
  - 结果：welcome **基线 MAE=32.91 / 超阈 29.77%**；大差异带 = 状态栏(0-84)、视觉图形带(588-672)、CTA 带(756-844)
  - 结论：参考页 welcome 也未达像素 1:1（页面早于最新 HTML），全部 15 屏都需按新基线收敛

## 下一步（按计划第 3/4 步）

1. 黄金公共组件先行（tab pill/header/button/card/sheet/图表），每组件过组件级像素绿卡。
2. 批次 A：home（welcome-home · screen-home 帧）→ login/register → plan → profile → review 逐屏还原，
   每屏产出 changed_files + 静态帧/动效态帧 + compare 报告（目标：主区域超阈 ≤2%）。
3. 批次 B/C：流程屏与新功能屏（body-data/settings/plans/planGroup/library…），新页双注册
   `main_pages.json` + `AppRoutes`。
4. 动效状态帧策略按已定默认（按压/弹层/celebrate 必截；持续脉冲只核 MOTION.md 映射表）。

## 基线数值速查（convergence 对照）

| 屏 | 参照帧 | MAE | 超阈% | 报告 |
|---|---|---|---|---|
| welcome | test_run/prototype-phone/welcome-home.png | 32.91 | 29.77 | test_run/welcome-compare.md |

## 新需求：页面自适应设备屏幕（2026-09-07 加入）

- 双基准验收：① 390vp 像素基准 diff ≤2% 不变；② 自适应层（320–430vp 无溢出/无截断、安全区、
  字号 ≤1.3× 不破版；>600vp 平板/横屏阶段可选）。
- 结构规则改为流式/弹性优先（Column/Row/Scroll/layoutWeight/百分比），`.position` 仅限装饰层；
  规则已写入 docs/opendesign-1to1-rules.md §3 与「自适应与安全区」节。

## 黄金组件基线（进行中）

- BottomTabBar 对齐 HTML：新增 ShadowTokens.TAB_PILL/TAB_PILL_ACTIVE（HTML 0 6px 14px/.30 与
  0 8px 20px/.34），SURFACE_NAV → rgba(8,12,15,.97)，ShadowTokens.NAV → 0,-8,28,.28；
  pill 阴影按激活态切换 + .16s implicit 色彩/阴影过渡（对应 HTML .tab/.pill transition）。
