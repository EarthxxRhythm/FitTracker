# Web 复刻版 vs 安卓端：还原度对照报告

> **基准**：`apps\android`（Kotlin / Jetpack Compose）为口径真源，按用户要求「口径以安卓端为主」。
> **被比对方**：`web\src\app`（Hero `hero-art` 内嵌的可交互复刻版）。
> **报告基准提交**：`7587998` · **生成日期**：2026-10-31
> **本轮不改代码**：本文件只做对照与建议，修复另行排期。

---

## 0. 方法与证据强度

| 来源 | 覆盖 | 状态 |
|---|---|---|
| 子代理 W1（首页 / 计划） | 10 条差异 | ⚠️ 结构化输出解析失败，条目从 worker artifact 中人工提取，**未经 schema 校验** |
| 子代理 W2（训练 / 预览 / 摘要） | 14 条 | ✅ 正常返回 |
| 子代理 W3（回顾） | 5 条 | ⚠️ 解析失败 + 输出截断，**由我读 `ReviewScreen.kt` 补齐**（卡组件行号已核实） |
| 子代理 W4（动作库 / 身体） | 27 条 | ✅ 正常返回（inline 可见 22 条） |
| 子代理 W5（我的 / 设置 / 主题） | 18 条 | ✅ 正常返回（inline 可见 8 条，其余截断未收录） |
| Web 侧信息结构 | 6 屏 DOM 实测 | ✅ 浏览器 eval 实测（训练/摘要屏复用上一轮已验证结果） |

**三处诚实交代**：
1. W1、W3 的 worker 因我在派单里指定 `severity=P0/P1/P2` 与工具 schema（`CRITICAL/HIGH/MEDIUM`）冲突而解析失败——产出本身是完整的，只是没通过校验。这是**派单缺陷**，不是 worker 能力问题。
2. W4、W5 的完整清单在 inline 里被截断，本报告只收录可见条目；遗漏不等于无差异。
3. 所有 worker 都是**只读代码扫描**，没有视觉能力。本报告的视觉层只有我做的 6 屏 DOM 结构抓取，**没有像素级对照**。

---

## 1. 总体结论

| 屏 | 还原度 | 一句话 |
|---|---|---|
| 首页 | **中** | 核心闭环在，但指标口径、开始训练去向、推荐胶囊都不同 |
| 计划 | **低** | 缺整个计划组详情页（摘要 / 节奏 / 日页签 / 动作清单 / 进度），启用流程也不同 |
| 训练执行 | **中偏高** | 推进与收缩规则一致；缺触觉、RPE、庆祝动效；热身标记是 web 单向超出 |
| 预览 | **中** | 缺热身/主训练分组与当前动作高亮；无计划时的回落策略不同 |
| 完成摘要 | **中** | 核心指标口径一致；缺 RPE 采集、连续记录卡；最佳记录口径不同 |
| 回顾 | **中** | 缺体重目标卡 / 努力程度卡 / 1RM 卡；肌群图形态是已知取舍 |
| 动作库 | **低** | 整套素材层缺失（101 个 GIF）、二级肌群筛选、只看收藏、详情弹层形态 |
| 身体数据 | **低** | 缺成分指标、体脂区间、目标进度、围度、身体档案、周期切换；单位不换算 |
| 我的 / 设置 | **低** | 缺身份头部、资料编辑、单位、语言、设置屏整体、训练偏好页 |

**一句话总结**：训练闭环的**数据口径**复刻得相当准（Epley、训练量、完成率、肌肉分布算法逐条一致），但**功能面**只覆盖了安卓的大约一半——差距集中在「设置与偏好体系」「动作素材层」「身体数据的派生指标」三块。

---

## 2. P0 — 口径错误或核心功能缺失

| # | 屏 | 问题 | 安卓 | web | 性质 |
|---|---|---|---|---|---|
| P0-1 | 我的 | **本周概览的统计窗口硬编码周一起始**，不读 `settings.weekStart`；而右上角范围文本按设置生成 → 选「周日」后数字与文案自相矛盾 | `ProfileViewModel.kt:87-90` 两者同传一个 `weekStart` | `ProfileScreen.tsx:40-43` 写死 `mondayOffset`；`AppShell.tsx:196` 用设置生成文本 | **web 自身 bug**，非还原差距 |
| P0-2 | 计划 | **计划组详情页整体缺失**：摘要、节奏 7 格、日页签、动作清单、进度 | `PlanGroupScreen.kt:87` | MISSING | 功能缺失 |
| P0-3 | 计划 | **启用流程不同**：安卓在详情页 CTA 上落盘 + 回读 + toast + 返回；web 点卡片即换指针 | `PlanGroupScreen.kt:231` | `PlansScreen.tsx:55` | 行为差异 |

> P0-1 是本轮唯一的数据正确性问题，且**与安卓无关**——是我上一轮实现时把周窗口写死了。建议优先修。

---

## 3. P1 — 体验明显缺失

### 3.1 训练执行（W2）

| 功能 | 安卓 | web | 性质 |
|---|---|---|---|
| 触觉反馈 | `ActiveScreen.kt:314` 完成一组 30ms 震动，受设置开关控制（`Haptics.kt:23-36`） | MISSING（全项目 `vibrate\|haptic` 零命中） | missing |
| 整体 RPE 采集 | `CompleteScreen.kt:331-410`、`FtCompleteModel.kt:65-140` 采 1–10 写回 `sessionRpe` | MISSING，`workout.ts:363` 恒为 0 | missing |
| 连续记录卡 | `CompleteScreen.kt:117-140` 由真实会话驱动 streak | MISSING | missing |
| 最佳记录口径 | `WorkoutSummaryService.kt:175-192` **跨全部历史**取最佳并带日期 | `SummaryScreen.tsx:36-44` **只取本次会话** | behavior |
| 重量单位 | `ActiveScreen.kt:196-197,1265` 按设置展示 | `ActiveScreen.tsx:198` 硬编码 `kg` | missing |
| 提前结束触发 | `ActiveScreen.kt:377-385` 长按「完成」1200ms | `ActiveScreen.tsx:164` 独立按钮 | behavior |
| 录组庆祝动效 | `ActiveScreen.kt:316,1772,1857` 彩带 + 延迟自动前进 | MISSING | missing |
| 预览分组 | `WorkoutPreviewScreen.kt:182-197` 热身/主训练分组 + 当前动作高亮 | 扁平列表 | behavior |

**web 单向超出**（不算缺陷）：每组一行可回改的输入框（安卓是聚焦当前组的卡片 + 弹窗步进）；每组可标热身（安卓 UI 无入口，模型层 `ActiveWorkoutService.kt:324` 有 `updateSetWarmup` 但无调用者）。

### 3.2 动作库（W4）

| 功能 | 安卓 | web | 性质 |
|---|---|---|---|
| **动作演示 GIF** | `PhotoGifCatalog.kt:15-18` 101 个实拍素材，卡片 4:3 / 弹层 16:9 播放 | 完全不渲染媒体，列表一枚哑铃线稿占位 | missing |
| 二级肌群筛选 | `LibraryScreen.kt:255-270` 选部位后展开肌群子筛选 | 只有一层全量 chips | missing |
| 只看收藏 | `LibraryScreen.kt:130,196-198` 顶栏开关 | MISSING | missing |
| 详情媒体区 + 「演示」角标 | `LibraryScreen.kt:864-990` | MISSING | missing |
| 详情「加入今日计划」CTA | `LibraryScreen.kt:1040-1062` + toast | MISSING | missing |

### 3.3 身体数据（W4）

| 功能 | 安卓 | web | 性质 |
|---|---|---|---|
| 身体成分 4 格（BMI/骨骼肌/基础代谢/水分） | `BodyScreen.kt:505-580`、`FtBodyModel.kt:382-450` | MISSING | missing |
| 体脂健康区间条 + 标记点 | `BodyScreen.kt:582-628` | 仅文本「体脂 X%」 | missing |
| 增肌目标进度 | `BodyScreen.kt:452`（GOAL_KG 74.0） | MISSING | missing |
| 围度记录（胸腰臀臂腿） | `BodyScreen.kt:837-890,1415-1480` | MISSING | missing |
| 身体档案（身高/性别/出生年） | `BodyScreen.kt:1503-1570` | MISSING | missing |
| 趋势图周期切换（周/月/年） | `BodyScreen.kt:682-742` | 恒为全部记录 | behavior |
| 体重单位换算 | `FtBodyModel.kt:200-260` | 硬编码 kg | missing |

### 3.4 我的 / 设置（W5）

| 功能 | 安卓 | web | 性质 |
|---|---|---|---|
| 身份头部（头像/昵称/目标副标题/经验徽标） | `ProfileScreen.kt:235-334` | 只有「本机用户」 | missing |
| 资料编辑页 | `ProfileEditScreen.kt:255-355` | MISSING | missing |
| 单位切换 kg↔lbs | `SettingsScreen.kt:178-186` | MISSING | missing |
| 语言切换 简中/English | `SettingsScreen.kt:193-201` | MISSING | missing |
| 设置屏整体（三段 12 行） | `FtSettingsModel.kt:161-283` | 只有「周开始日」 | missing |
| 训练偏好页（目标/经验/天数/时长/器械/限制肌群） | `TrainingPreferencesScreen.kt:74-172` | MISSING | missing |
| 成就口径 | `FtProfileModel.kt:198-241` 连续天数 + 重量突破 | 每动作 1RM 前 3 | behavior |

### 3.5 首页 / 计划（W1）

| 功能 | 安卓 | web | 性质 |
|---|---|---|---|
| 今日指标项 | `HomeScreen.kt:539` 动作 / 时长(分) / 肌群 | 动作 / 计划组 / 肌群 | behavior |
| 开始训练去向 | `HomeScreen.kt:169` 有草稿直达 active | 一律先进预览 | behavior |
| 推荐胶囊 + 次按钮 | `HomeScreen.kt:326` | 无 chip，次按钮为「换个计划」 | missing |
| 计划列表形态 | `PlansScreen.kt:81` 带返回栏的组列表（含示例行） | 平面预置卡 + 训练日行 | behavior |

### 3.6 回顾（W3，我补齐部分）

| 功能 | 安卓 | web | 性质 |
|---|---|---|---|
| 体重与目标卡 | `ReviewScreen.kt:787`（曲线 + 目标虚线 + 设置弹窗） | 只有一行「最近体重」 | missing |
| 努力程度卡 | `ReviewScreen.kt:940`（RPE 指标 + 柱） | MISSING | missing |
| 估算 1RM 卡 | `ReviewScreen.kt:1047`（按动作列 1RM） | MISSING | missing |
| 肌群点选明细 | `ReviewScreen.kt:543`（点部位看明细、前 3 → 全 18 抽屉） | 只有 top8 排行 | behavior |

---

## 4. P2 — 文案与形态细节（抽样）

- 问候语分档：安卓 3 档，web 4 档（多「夜深了」）— `HomeViewModel.kt:104` vs `HomeScreen.tsx:32`
- 空态文案：安卓按「只看收藏 / 有搜索词 / 部位无动作」分三套，web 一句固定文案 — `FtLibraryModel.kt:277-290`
- 列表形态：安卓三列卡片网格按器械分组，web 单列行
- 详情形态：安卓贴底弹层（84% 高 + 共享元素转场），web 整屏替换
- 详情信息量：安卓单条 tip + 三行键值，web 平铺 steps/cues/mistakes/safety 四卡（**web 超出**）
- 收藏持久化：安卓 `remember` 屏内状态，离开即丢；web 落 localStorage（**web 超出**）
- 身体录入校验：安卓非法值给提示、输入框预填最近体重；web 静默 return
- 身体保存反馈：安卓有「今日已记录 · 刚刚」，web 无

---

## 5. web 单向超出（不是缺陷，记录备查）

| 项 | 说明 |
|---|---|
| 训练量分布柱图 | `ReviewScreen.tsx:182` 周/月柱图，安卓 `ReviewScreen.kt` 无对应组件 |
| 完成率指标行 | `ReviewScreen.tsx:173` 训练量合计 / 完成组数 / 完成率，安卓三张 stat 卡无 |
| 每组行内输入 | 可回改任意一组，安卓只能聚焦当前组 |
| 热身标记 | web 有 UI 入口，安卓 UI 无 |
| 数据持久化 | web 全量落 localStorage，安卓动作库收藏不落盘 |
| 动作详情信息量 | web 四卡全量 vs 安卓单条 tip |
| 102 个动作 | web 用 `content.generated.ts` 全量；安卓首帧加载 `exercise-content.json`（50 条） |

---

## 6. 已知设计取舍（tradeoff，不计入还原缺陷）

| 项 | 取舍理由 |
|---|---|
| 肌群热力用 18 格矩阵而非 `FtBodyMap.kt` 人体图 | 上一轮有意：信息等价（哪些部位练得多一眼可见），不假装自己是人体图。要改属**新需求** |
| 无登录 / 无账号 / 无云同步 | 官网体验是纯本机，数据只进 localStorage |
| 预置计划 43 个动作位中 26 个映射不到动作库 | 与真机同口径（都是按中文名精确匹配），落库用占位 id |

---

## 7. 跨屏共性问题

1. **单位制（kg/lbs）全站缺失**：训练、摘要、回顾、身体、我的五处重量都是 `kg` 字面量。安卓有一条统一链路（`WeightUtils` + `UserProfileService.weightUnit`）。
2. **设置体系只复刻了 1/12**：安卓设置屏三段十二行，web 只有「周开始日」。
3. **`weekStart` 在「我的」屏没接通**（P0-1），是设置项落地不完整的典型表现。

---

## 8. web 自身缺陷（与安卓无关，本轮实测发现）

**「我的」页最佳纪录显示英文 exerciseId**：`ProfileScreen.tsx` 的 `displayName()` 把 `ex_machine_leg_press` 转成 `machine leg press`，实测渲染出 `machine leg press` / `barbell squat` / `preset_upper_lower_exercise_1`。

对比：`SummaryScreen.tsx` 已有正确的解析（`resolveExerciseName` 走内容库 + 计划反查），「我的」页没复用。**建议与 P0-1 一并修**。

---

## 9. 修复建议（按性价比排序，本轮不实施）

| 优先级 | 内容 | 涉及面 | 估计 |
|---|---|---|---|
| **① 立刻** | P0-1 周窗口接通 `settings.weekStart` + 最佳纪录中文名 | 2 个文件 | 小 |
| **② 高** | 单位制（kg/lbs）全站贯通 | 设置结构 + 5 屏显示层 | 中 |
| **③ 高** | 设置屏补全（单位/语言/提醒/常亮）+ 训练偏好页 | 新增 2 屏 | 大 |
| **④ 中** | 身体数据派生指标（成分 4 格 / 体脂区间 / 目标进度 / 围度 / 档案） | 1 屏 + 派生层 | 大 |
| **⑤ 中** | 回顾补三卡（体重目标 / 努力程度 / 1RM） | 1 屏 | 中 |
| **⑥ 中** | 动作库素材层（GIF）+ 二级肌群筛选 + 只看收藏 | 1 屏 + 素材资产 | 大 |
| **⑦ 低** | 计划组详情页 | 新增 1 屏 | 中 |
| **⑧ 低** | 触觉反馈 / 庆祝动效 / RPE 采集 | 训练 + 摘要 | 小 |
| **⑨ 待议** | 肌群人体图（属新需求，非还原缺陷） | 1 屏 + SVG 资产 | 大 |

---

## 10. 附：本轮实测的 web 侧信息结构

| 屏 | h1 | 卡片 |
|---|---|---|
| 首页 | 晚上好，今天练什么？ | 恢复日已练 / 本周节奏 / 最近训练 |
| 计划 | 按分化数成套，启用即用 | 二分化（上下肢）· 训练日 |
| 回顾 | 数字会告诉你哪里没练到 | 本周 可加密 / 训练量分布 / 肌肉分布 / 身体数据 |
| 我的 | （无 h1） | 本机用户 / 本周概览 / 最佳纪录 / 更多 / 设置 / 本机数据 |
| 动作库 | 先看怎么做，再决定练多重 | 筛选结果 |
| 身体数据 | 72.5 kg | 记一条 / 记录 |

> 附注：「我的」屏是九屏中唯一没有 `.ft-h1` 主标题的，视觉层级比其它屏弱一档。
