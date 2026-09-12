# Wave 1 六列理解表（15 屏）

> 依据 `docs\prototype-to-arkui-prompt-template.md` 第 0 步产出。
> 目的：在写任何 ArkTS 之前，把 15 屏的「画布基准 / 滚动边界 / 动效 / 交互状态 / 页面层级 / 唯一主 CTA」逐屏定下来。
> 证据源：`design\06_prototype_redraw\src\*.html`（唯一规格）、`MOTION.md`、`design\05_page_specs\*`。

## 表 A · 画布基准与滚动边界

| # | route | 屏文件 | 画布基准 | 滚动边界 | ArkUI 落点 | 验收基线 |
|---|---|---|---|---|---|---|
| 1 | welcome | `fittracker-welcome-home.html` | **缩放** 430×900×0.90698（`.w-frame:190-194`） | **全固定**（无滚动容器，元素皆 `.w-abs` 绝对定位） | `features\welcome\pages\PencilWelcomePage.ets` | ❌ 16.49% |
| 2 | home | `fittracker-welcome-home.html` | **缩放** 430×900×0.90698（同上） | `.pane-scroll:347` 整页滚（含日期问候），底栏在 `PencilAppShell` 视口外固定 | `PencilHomePage.ets` + `HomeContent.ets` | ❌ 14.19% |
| 3 | login | `fittracker-auth.html` | **缩放** 430×900×0.90698（`.auth-frame:179-181`、`--active-scale:62`） | `.auth-scroll:186-190` 整页滚（brand+标题+表单+CTA+switch） | `PencilLoginPage.ets` | ❌ 10.02%→9.32%（已修） |
| 4 | register | `fittracker-auth.html` | **缩放** 430×900×0.90698（同上） | `.auth-scroll` 整页滚 | `PencilRegisterPage.ets` | ❌ 12.28%→10.00%（已修） |
| 5 | plan | `fittracker-plan.html` | 直绘 390×844（`.phone:150-152`） | `.pane-scroll:182` 声明 auto 但 `.plan-content:186-190` 设 `height:100%` + `flex:2:8`，**内容永不溢出→实际不滚** | `PencilPlanPage.ets` + `PlanContent.ets` | ❌ 8.83% |
| 6 | workout（preview） | `fittracker-training-preview.html` | 直绘 390×844（`.phone:148-150`） | **全固定**（`.pv-frame:172` overflow hidden，`.pv-content:178` 无 overflow） | `PencilPreviewPage.ets` | ❌ 13.83% |
| 7 | plans | `fittracker-plan-detail.html` | 直绘 390×844（`.phone:129-131`） | 固定 `.pd-top` + 滚动 `.pd-scroll:185` | `PencilPlansPage.ets` + `PlansContent.ets` | ✅ 6.74% |
| 8 | planGroup | `fittracker-plan-group-detail.html` | 直绘 390×844（`.phone:102-104`） | 固定 `.pgd-top` + 滚动 `.pgd-scroll:160`/`:211`；`.pgd-days:211` 横向滚 | `PencilPlanGroupDetailPage.ets` + `PlanGroupDetailContent.ets` | ❌ 9.83% |
| 9 | active | `fittracker-training.html` | 直绘 390×844（`.wo-screen:166-170` absolute inset 0） | `.wo-top` 固定 + `.wo-scroll:214` 滚（含 demo-card）+ `.wo-dock` 固定 | `PencilActivePage.ets` + `ActiveContent.ets` | ✅ 6.53% |
| 10 | complete | `fittracker-training-complete.html` | **缩放** 430×930.6×0.90698（`.cf-frame:178-183`，高为 `calc(844px / var(--scale))`、`--scale:75`） | `.cf-scroll:191-198` 滚（overflow-y auto + overflow-x hidden）+ `.cf-dock:269` 固定 | `features\workout\pages\WorkoutCompletePage.ets` | ❌ 14.62% |
| 11 | review | `fittracker-review.html` | 直绘 390×844（`.phone:171-173`） | `.viewport:203-208` overflow hidden + `.pane-scroll:217` 滚（**含 toolbar**） | `PencilReviewPage.ets` + `ReviewContent.ets` | ❌ 11.49%→11.75% |
| 12 | library | `fittracker-exercise-library.html` | 直绘 390×844（`.phone:119-121`） | `.st-top:151` 固定 + `.st-scroll:176` 滚 + 两条 `.cat-row:230` 横向滚 | `features\exercise\pages\ExerciseLibraryPage.ets` | ❌ 26.62% |
| 13 | body | `fittracker-body-data.html` | 直绘 390×844（`.phone:97-98`） | `.bd-top` 固定 + `.bd-scroll:125` 滚 | `features\body\pages\BodyDataPage.ets` + `BodyDataContent.ets` | ✅ 7.76% |
| 14 | profile | `fittracker-personal.html` | 直绘 390×844（`.phone:167-169`） | `.pane-scroll:223` 整页滚（含 `p-head` 页头） | `PencilProfilePage.ets` + `ProfileContent.ets` | ✅ 7.56% |
| 15 | settings | `fittracker-settings.html` | 直绘 390×844（`.phone:141-143`） | `.st-top:366` 固定 + `.st-scroll:377` 滚 | `features\settings\pages\PencilSettingsPage.ets` + `SettingsContent.ets` | ❌ 12.36% |

> 验收基线取自 `test_run\emulator\ACCEPTANCE-2026-09-11.md`（非文本内容区超阈%，达标线 ≤8%）。
> login/register 为本次实测值（`test_run\restore-accept\login2-masked.md` / `register-masked.md`）。

## 表 B · 动效清单

| # | route | `:active` 按压 | 单段 transition | `@keyframes` | 备注 |
|---|---|---|---|---|---|
| 1 | welcome | `.w-cta .btn-primary` `scale(.985)`；`.tab-center .pill` `scale(.96)` | 按钮 filter/box-shadow/transform、`.week-day .dot` 色彩过渡、`.tab` 背景/文字 | 无 | 静态屏，动效最少 |
| 2 | home | 同 welcome | 同 welcome | 无 | |
| 3 | login | `.auth-cta` `scale(.985)` | `.control` 边框/背景/阴影、`.control .toggle` 颜色、`.auth-link` 颜色、`.check` 背景/边框、`.auth-toast` opacity+transform | 无 | 聚焦态过渡是重点 |
| 4 | register | 同 login | 同 login | 无 | |
| 5 | plan | `.tab-center .pill` `scale(.96)` | 牌组/Swipe 相关 | 无 | 牌组左右滑动为手势非动画 |
| 6 | workout | `.pv-icon-btn` `scale(.96)`；`.pv-btn-primary` `scale(.985)` | 按钮过渡 | 无 | |
| 7 | plans | `.pg-card` `scale(.99)` | 卡片 hover/active | 无 | |
| 8 | planGroup | `.pgd-back` `scale(.94)`；`.pgd-day-tab` `scale(.98)`；`.pgd-ex` `scale(.99)`；`.pgd-cta` `scale(.985)` | 日 tab / 卡片过渡 | 无 | 按压系数分四档 |
| 9 | active | `.wo-btn-primary` `scale(.985)` | `.btn-ghost` 背景、`.modal-close`、`.stepper .step` | **10 个**：`livePulse`(1.6s 无限) / `recordIn`(.18s) / `backdropIn`(.22s) / `modalIn`(.22s) / `veilIn`(.22s) / `veilOut`(.3s) / `confettiFly`(1.1s) / `coreIn`(.46s+delay .06s) / `markerPop`(.3s) / `segPop`(.46s) | **关键帧最重的一屏**；含循环脉冲（只核映射表不逐帧截） |
| 10 | complete | `.cf-btn-primary` `scale(.985)` | `.cf-btn` 多属性、`.confetti-layer` opacity、`.cf-toast` | **3 个**：`cf-pop`(.5s+delay .05s) / `cf-rise`(.45s/.5s，多延迟错峰) / `cf-fall`(2.6s) | **错峰入场**：badge→title→sub→streak→dock 依次延迟 |
| 11 | review | `.seg-btn` `scale(.97)`；`.tab-center .pill` `scale(.96)`；`.goal-btn` `scale(.97)` | 分段控件 / 图表过渡 | 无 | |
| 12 | library | `.st-back` `scale(.94)`；`.lib-fav-filter` `scale(.94)`；`.lib-card` `scale(.985)`；`.lib-fav` `scale(.9)`；`.lib-sheet-cta` `scale(.985)` | 卡片 / 筛选 / 弹层 | 无 | 按压系数分五档 |
| 13 | body | `.bd-back` `scale(.94)`；`.bd-cta` `scale(.98)` | 卡片 / CTA / sheet | 无 | |
| 14 | profile | `.p-settings` `scale(.96)`；`.shortcut` `scale(.98)`；`.tab-center .pill` `scale(.96)`；`.sub-back` `scale(.94)`；`.lib-*` 系列 | 卡片 / 快捷入口 | 无 | 含内嵌动作库弹层动效 |
| 15 | settings | `.st-back` `scale(.94)` | 分段行 / toast | 无 | |

## 表 C · 交互状态清单

| # | route | 弹层 | 反馈（toast） | 空态 / 占位态 | 校验错误 | 证据 |
|---|---|---|---|---|---|---|
| 1 | welcome | — | — | — | — | 屏内仅 CTA 与页脚 |
| 2 | home | — | — | — | — | `screen-home` 内仅卡片 |
| 3 | login | — | `auth-toast`（`role=status` `aria-live=polite`） | — | `field-error` ×2（手机号/邮箱、密码） | `auth.html:573,585,622` |
| 4 | register | — | `auth-toast` | — | `field-error` ×4（昵称、手机号、密码≥8位、两次不一致） | `auth.html:653,661,673,685,702` |
| 5 | plan | — | — | — | — | 其他 tab 的 `pane-placeholder` 属占位屏非本屏 |
| 6 | workout | — | — | — | — | |
| 7 | plans | — | `pd-toast` | — | — | `plan-detail.html:392` |
| 8 | planGroup | — | `pgd-toast` | — | — | `plan-group-detail.html:405` |
| 9 | active | **`modal`（记录本组）**：`.modal` + `.modal-card` + backdrop + `.modal-close` + stepper | — | — | — | `training.html` modal 段；`backdropIn`/`modalIn` 关键帧 |
| 10 | complete | — | `cf-toast` | — | — | `training-complete.html:437` |
| 11 | review | — | — | — | — | 其他 tab 的 `pane-placeholder` 属占位屏 |
| 12 | library | **`lib-sheet`（动作详情）**：`backdrop` + `.lib-sheet-card` + handle + close + CTA | `st-toast` | **`lib-empty` 三段式**（图标 + 标题「没有匹配的动作」+ 提示「换个关键词或筛选条件试试」） | — | `exercise-library.html:593-596,603-623,627` |
| 13 | body | **`sheet`（记录今日体重）**：`sheet-layer` + `backdrop` + `.sheet` + grip + title + input + hint + 取消/保存 | — | — | `sheet-hint`（`role=alert`） | `body-data.html:424-437` |
| 14 | profile | **`lib-sheet`**（同 library）+ `sub-scroll` 子页 | `lib-toast` | `lib-empty` + `pane-placeholder` ×4 | — | `personal.html:1557-1560,1565-1568,1588` |
| 15 | settings | — | `st-toast`（文案「已保存」） | — | — | `settings.html:467` |

## 表 D · 页面层级与唯一主 CTA

| # | route | Level 1（主导区域） | Level 2（上下文） | Level 3（次级入口） | 唯一主 CTA |
|---|---|---|---|---|---|
| 1 | welcome | `w-headline`「把训练，变成看得见的进步。」 | `w-sub` 说明 + `w-visual` 视觉 | `w-foot`「本地记录 · 无需注册 · 随时开始」 | **开始使用**（`.btn-primary`） |
| 2 | home | `card-today` 今日训练卡（含 `cta-start`） | `card-week` 本周节奏 | `cta-preview` 查看预览 | **开始训练**（`cta-start`） |
| 3 | login | `auth-form` 表单区 | `auth-head` 欢迎回来 + 说明 | `auth-social` 微信/Apple + `auth-switch` 去注册 | **登录**（`cta-login`） |
| 4 | register | `auth-form` 表单区 | `auth-head` 创建账号 + 说明 | `auth-switch` 去登录 | **注册**（注册按钮） |
| 5 | plan | `master-plan-card` 当前计划卡 | `plan-today` 今日牌组（`plan-deck`） | — | 无独立 CTA（牌组为交互主体） |
| 6 | workout | `pv-*` 训练预览主体 | 动作清单 | 开始训练入口 | **开始训练** |
| 7 | plans | `plan-groups-current` 当前计划 | `plan-groups-list` 计划组列表 | 各卡片点击 | 无独立 CTA（列表为交互主体） |
| 8 | planGroup | `pgd-*` 摘要 + 日面板 | `rhythm` 节奏 + `day-tabs` | 各动作行 | **启用/切换计划**（`.pgd-cta`） |
| 9 | active | `demo-card` 当前动作演示 | `set-count` 组数列表 | — | **提交**（`.wo-dock`，固定） |
| 10 | complete | `cf-*` 完成 hero + `cf-streak` 连续记录 | 完成数据 | — | **继续**（`.cf-dock`，固定） |
| 11 | review | `card-overview` 概览 | `card-stats` 数据 + `card-activity` 节奏 | 各图表卡 | 无独立 CTA（数据阅读页） |
| 12 | library | `lib-groups` 动作列表 | `lib-search` + 两条 `cat-row` 筛选 | 卡片点击开 `lib-sheet` | **加入训练计划**（弹层内 `lib-sheet-cta`） |
| 13 | body | `body-weight-summary` 当前体重卡 | `body-composition` 身体成分 + 趋势 | 测量数据 | **记录今日体重**（`.bd-cta`） |
| 14 | profile | `profile-header` 个人头部 | 周概览 + 连续记录 + 成就 | 快捷入口（身体数据/动作库/设置） | 无独立 CTA（入口聚合页） |
| 15 | settings | `settings-general` 通用设置 | 数据隐私 + 关于 | — | 无 CTA（即时生效设置） |

## 关键发现

### 发现 1：画布基准实测与项目文档冲突（5 屏缩放 / 10 屏直绘）

`design\06_prototype_redraw\README.md` 与 `docs\opendesign-1to1-rules.md` 硬规则 2 均称
「除 welcome 外其余 14 屏 390×844 直绘」。逐屏核实后**实际有 5 屏是缩放画布**：

| 屏 | frame 容器 | 设计画布 | 缩放变量 |
|---|---|---|---|
| welcome / home | `.w-frame`（`welcome-home.html:190-194`） | 430×900 | 硬编码 `scale(0.90698)` |
| login / register | `.auth-frame`（`auth.html:179-181`） | 430×900 | `--active-scale: 0.90698`（`:62`） |
| **complete** | `.cf-frame`（`training-complete.html:178-183`） | **430×930.6** | `--scale: 0.90698`（`:75`），高为 `calc(844px / var(--scale))` |

complete 还引入了**第三种画布高度**（930.6 而非 900），两个不同的变量名（`--scale` vs `--active-scale`），
说明这三组屏是不同时期产出、未统一。

### 发现 2：缩放屏与验收未达标高度重合（强相关）

把表 A 的验收基线按画布类型重排：

| 画布类型 | 屏 | 达标情况 |
|---|---|---|
| **缩放** | welcome 16.49%、complete 14.62%、register 12.28%（→10.00%）、login 10.02%（→9.32%） | **4/4 未达标** |
| 直绘 | plans 6.74% ✅、active 6.53% ✅、body 7.76% ✅、profile 7.56% ✅、plan 8.83%、planGroup 9.83%、review 11.49%、settings 12.36%、preview 13.83%、library 26.62%、home 14.19% | 4 达标 / 7 未达标 |

**全部 4 个缩放屏都未达标**。其中 login/register 已通过补缩放容器改善
（13.46→11.85、18.80→15.36），**强烈提示 complete 与 welcome 存在同一根因**。

### 发现 3：动效重心极不均匀

`@keyframes` 只存在于 2 屏：active（10 个）与 complete（3 个）。其中：

- `livePulse`（1.6s 无限循环）属「持续脉冲」，按口径只核 `MOTION.md` 映射表，不逐帧截图。
- complete 的 `cf-rise` 是**错峰入场**（badge .05s → title .16s → sub .26s → streak .36s → dock .6s），
  必须用 `keyframeAnimateTo` 的 delay 复现，不能只做单段 `animateTo`。
- active 的 `veilIn`/`veilOut` 是成对的进出场，`confettiFly`（1.1s）与 complete 的 `cf-fall`（2.6s）
  是两套不同的彩带参数，不要互相套用。

## 待验证项

1. **`PencilWelcomePage.ets` 与 `WorkoutCompletePage.ets` 是否缺缩放容器**——本表只判定原型侧；
   ArkUI 侧需逐文件核实。两者都是未达标缩放屏，优先核。
2. `plan` 屏 `.pane-scroll:182` 声明了 `overflow-y:auto` 但内容不溢出，**ArkUI 侧是否加了多余的 `Scroll`** 需核。
3. 表 C 的交互状态仅覆盖弹层／反馈／空态／错误四类；**加载态与禁用态**未逐屏核（原型中未见显式 loading 类）。
4. ~~`library` 的 26.62% 根因未定位~~ → **已诊断（2026-09-12）**，结论推翻了既有推测：

   - **GIF 同源性**：两侧各 23 个 GIF，**18 个逐字节相同**（md5 一致），仅 5 个不同
     （`band-lateral-raise` / `face-pull` / `lat-pulldown` / `plank` / `squat`）。
     故 `ACCEPTANCE-2026-09-11.md` 的「20 张 GIF 帧/图差异」推测**不成立**。
   - **卡片布局**：原型 `.lib-grid` 是 `repeat(3, 1fr)` 三列 + `gap: 10px`；
     ArkUI 用 `Grid().columnsTemplate('1fr 1fr 1fr').columnsGap(10).rowsGap(10)` —— **一致**。
   - **内容起点**：原型 `.st-scroll-inner { padding: 8px 16px 30px }` 与 ArkUI
     `padding({ left:16, right:16, top:8, bottom:30+inset })` —— **一致**。
   - **差异定位**：band 2（crop y128-192 / 屏幕 y228-292）mean diff **94.31**、超阈 **56.89%**，
     按坐标推算落在**第一行动作卡片**；其余卡片行为 32-39%。
   - **推断**：卡片主体是**动画 GIF**，原型参照帧（Chrome）与设备截图（模拟器）捕捉的是
     **不同动画帧**，在静态像素口径下天然不可比。5 张不同源 GIF 只涉及 5 张卡片，
     不足以解释 56.89% 的大面积差异。
   - **建议**：library 的像素验收需先**冻结 GIF 动画**，或在 `--ignore-rect` 中掩蔽 GIF 区域，
     否则该屏数字不代表还原质量。

   **未验证**：以上为推断，尚缺「冻结动画后 MAE 显著下降」的实测证据。
   若该实测成立，`library` 26.62% 应从「还原缺陷」重分类为「测量口径问题」。

## 下一步

按 `docs\prototype-to-arkui-prompt-template.md` 第 7 步分片：先核待验证项 1（两个缩放屏的 ArkUI 侧），
再按 `ROUTES` 表切片实现。共享层（`DesignTokens.ets`、`AppRoutes.ets`、`PencilAppShell.ets`、`components\*`）
分片前冻结。
