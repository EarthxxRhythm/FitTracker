# FitTracker 首页 1:1 开发规格书

日期：2026-07-23

参考原型：
- `C:\Users\Administrator\Downloads\screen-home.html`

适用范围：
- FitTracker 首页
- Open Design 首页提示词约束
- HarmonyOS ArkUI 首页实现
- 人工视觉验收

## 1. 目标

本规格书用于解决“代码总是不能 1:1 复刻 UI/UX 设计”的问题。

针对当前首页，目标不是“做一个差不多的训练页”，而是把参考原型中的首页视觉语言、信息层级、状态切换和导航语义拆成可实现、可验收、可复用的规格。

本次首页必须满足：

- 首屏只存在一个绝对主任务：`开始训练` 或 `继续训练`
- 首页是 `Today-first command brief`，不是综合仪表盘
- 顶部、主卡、底部导航都使用首页专属语义，不退化成通用组件堆叠
- 预置计划、动作库、工具入口全部下沉到首屏主卡之后
- 训练 tab 在底部导航中是唯一被强化的主 tab

## 2. 原型结论

从 `screen-home.html` 可提炼出 4 个核心事实：

### 2.1 这不是普通卡片页

首页不是“标题 + 多卡片列表”的标准信息页，而是：

- `today-nav`
- `today-card`
- `secondary modules`
- `bottom-nav`

也就是“顶部上下文 + 今日决策主卡 + 次级补充模块 + 强化底部导航”的单主线结构。

### 2.2 首页使用独立视觉语法

原型里同时存在通用系统样式和 `body[data-screen="home"]` 的首页特化样式。首页真正应该跟随的是后者，而不是全局默认浅色语法。

首页专属特征包括：

- 深色背景与低对比玻璃面板
- 训练主卡的大圆角和多层渐变
- 训练 tab 独占图标和高亮容器
- 极强的主次字号落差
- 明确的状态 pill 和进度视觉

### 2.3 首页不是静态图，而是状态页

原型中存在：

- `data-state="ready"`
- `data-state="loading"`
- `data-state="empty"`
- `data-state="error"`

所以代码实现必须先定义状态模型，再定义视觉模型。否则默认态像，其他态就会崩。

### 2.4 UX 的关键不在“像”，而在“主任务排序正确”

首屏最先回答的必须是：

- 今天练什么
- 能不能继续上次训练
- 现在该点哪个按钮

如果首屏先出现计划说明、数据概览、工具入口、预置计划，就算样式接近，也不算 1:1 复刻 UX。

## 3. 首页骨架规格

首页固定分为 4 层。

### 3.1 顶部上下文层

组件建议名：
- `TodayNav`

职责：
- 显示日期
- 显示问候语
- 显示右上角轻量动作按钮

结构：
- 左侧：日期 + 问候语
- 右侧：圆形轻按钮

约束：
- 不是 hero 区
- 不承载品牌大叙事
- 不允许放多余说明文案
- 右上角按钮只做辅助入口，不能抢主 CTA

### 3.2 今日决策主卡

组件建议名：
- `TodayHeroCard`

职责：
- 承担首页绝对主任务
- 展示今天训练主题
- 展示状态
- 展示进度
- 提供主按钮和次按钮

内部结构固定为：
- `head`
- `body`
- `actions`

推荐字段：
- `kicker`
- `title`
- `statusText`
- `statusTone`
- `supportCopy`
- `progressValue`
- `progressLabel`
- `metrics`
- `primaryAction`
- `secondaryAction`

约束：
- `title` 最多 2 行
- 首屏只允许一个强主按钮
- 次按钮只能作为辅助动作
- 不允许把预置计划入口放进主卡

### 3.3 次级模块层

组件建议名：
- `WeeklyRhythmModule`
- `BoundaryModule`
- `ExplorePlansModule`

职责：
- 补充本周节奏
- 补充计划边界
- 补充探索内容

排序固定为：
1. 本周节奏
2. 计划边界
3. 探索计划

约束：
- 这些模块不能在视觉上压过主卡
- 不能出现并列多个“像主卡一样大”的块
- 探索计划必须放在首屏主任务之后

### 3.4 底部导航层

组件建议名：
- `TodayBottomNav`

导航项：
- 首页
- 计划
- 训练
- 回顾
- 我的

当前项目按已实现路线可临时保持：
- 动作库
- 训练
- 回顾

但从原型语义看，最终推荐还是 5 项结构。

约束：
- 除 `训练` 外，其余 tab 只保留文字
- `训练` tab 保留图标
- `训练` 是唯一浮起或强化的 tab
- 整个底部导航是稳定导航，不是卡片

## 4. 首页状态规格

首页必须至少支持 4 种状态。

### 4.1 Ready

含义：
- 今日训练已确定
- 可以直接开始训练或继续训练

表现：
- 绿色或偏成功态的状态 pill
- 主按钮可点击
- 指标完整展示

### 4.2 Loading

含义：
- 正在读取计划、草稿、恢复状态

表现：
- 主按钮禁用
- 主卡骨架不跳位
- 文案改为“正在准备”

### 4.3 Empty

含义：
- 用户还没有完成目标设置

表现：
- 主卡骨架保留
- 标题改为引导配置
- 主按钮变成“设置训练目标”
- 本周节奏和边界区块可收起或弱化

### 4.4 Error

含义：
- 数据读取失败或关键状态异常

表现：
- 保持同骨架
- 状态 pill 改为警告态
- 主按钮改为安全回退动作
- 不允许布局塌陷

## 5. 视觉 Token 规格

本页不建议直接照搬原型中的全部 CSS 变量，而应只提炼首页专属 token。

### 5.1 颜色层级

建议保留这 5 层：

- `home.bg`
- `home.surface.hero`
- `home.surface.subtle`
- `home.border.glass`
- `home.accent.train`

视觉原则：
- 背景深于卡面
- hero 卡与普通卡必须能一眼分层
- 强调色只服务主任务和训练导航

### 5.2 字体层级

首页至少要有 6 级文字：

- 顶部日期
- 顶部问候
- 主卡 kicker
- 主卡 title
- 状态/指标标签
- 辅助说明

关键原则：
- `title` 和普通正文要有明显断层
- 指标数字不能和正文一个级别
- 状态 pill 文本必须明显更小、更紧

### 5.3 圆角体系

首页至少区分：

- `control`
- `card-sm`
- `card-hero`
- `pill`

原则：
- 主卡圆角大于普通卡
- 底部导航激活容器圆角大于普通文本 tab

### 5.4 阴影与边框

首页不适合单纯用一个普通阴影变量。

推荐表达：
- 外阴影：极轻，负责浮起
- 内描边：负责玻璃质感
- 渐变背景：负责层级过渡

原则：
- hero 卡 = 渐变 + 内描边 + 轻外阴影
- 次级卡 = 更弱的背景和更轻的边界
- 不要所有卡都一样重

## 6. 组件拆分规格

首页不应整页直接写死，建议至少拆成以下组件。

### 6.1 `TodayNav`

字段：
- `dateText`
- `greetingText`
- `actionLabel`

### 6.2 `TodayStatusPill`

字段：
- `text`
- `tone`

枚举建议：
- `success`
- `warning`
- `info`
- `neutral`

### 6.3 `TodayMetricRing`

字段：
- `value`
- `label`

职责：
- 展示本周进度

### 6.4 `TodayMetricGrid`

字段：
- `items`

单项字段建议：
- `label`
- `value`
- `note`
- `emphasize`

### 6.5 `TodayHeroCard`

字段：
- `kicker`
- `title`
- `subtitle`
- `status`
- `progress`
- `metrics`
- `primaryAction`
- `secondaryAction`

### 6.6 `WeeklyRhythmStrip`

字段：
- `items`

单项字段建议：
- `title`
- `subtitle`
- `current`
- `completed`

### 6.7 `BoundaryList`

字段：
- `items`

单项字段建议：
- `marker`
- `label`
- `value`

### 6.8 `TodayBottomNav`

字段：
- `currentKey`
- `items`

单项字段建议：
- `key`
- `label`
- `route`
- `highlight`

## 7. 布局约束

这部分是最容易在代码里跑偏的。

### 7.1 首屏约束

- 首屏必须完整看到顶部上下文和今日主卡
- 首屏内不允许出现多个同权重大卡
- 主 CTA 在 3 秒内必须可见

### 7.2 单行约束

以下内容默认尽量单行：

- 顶部日期
- 顶部问候
- 底部导航文案
- 状态 pill
- 指标标签

### 7.3 换行约束

以下内容允许两行，但不能继续扩张：

- 主卡标题
- 主卡辅助说明
- 计划卡受众说明

### 7.4 底部导航约束

- 训练 tab 允许图标 + 文字
- 其他 tab 保持纯文字
- tab 宽度按视觉平衡，不按平均机械切分

### 7.5 卡片密度约束

- hero 卡内部间距大于次级卡
- 次级卡之间的垂直间距必须统一
- 不允许某个模块单独变成“超厚卡”

## 8. 当前项目映射建议

结合 FitTracker 当前代码结构，建议这样映射。

### 8.1 页面入口

- 保持注册主入口为 [HomePage.ets](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/entry/src/main/ets/pages/HomePage.ets)
- 首页真实实现放在 [HomePageV2.ets](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/entry/src/main/ets/features/home/pages/HomePageV2.ets)

### 8.2 状态映射层

- 首页展示态数据放在 [HomeDashboardService.ets](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/entry/src/main/ets/features/home/services/HomeDashboardService.ets)

### 8.3 组件层

推荐组件边界：

- [TopContextBar.ets](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/entry/src/main/ets/components/TopContextBar.ets)
- [HeroWorkoutCard.ets](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/entry/src/main/ets/components/HeroWorkoutCard.ets)
- [StatusPill.ets](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/entry/src/main/ets/components/StatusPill.ets)
- [WeeklyRhythmStrip.ets](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/entry/src/main/ets/components/WeeklyRhythmStrip.ets)
- [SummaryRow.ets](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/entry/src/main/ets/components/SummaryRow.ets)
- [BottomTabBar.ets](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/entry/src/main/ets/components/BottomTabBar.ets)

### 8.4 Token 层

首页专属 token 统一收敛进：

- [DesignTokens.ets](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/entry/src/main/ets/common/styles/DesignTokens.ets)

不要在首页页面里继续硬编码：

- 颜色
- 圆角
- 大多数间距
- 阴影
- 导航高度

## 9. 最容易失真的 10 个点

1. 把首页做成普通 `PageHeader + Card List`
2. 主卡和次级卡视觉权重一样
3. 主按钮不够强，次按钮太抢戏
4. 底部导航所有 tab 一样重
5. 训练 tab 没有独占高亮语义
6. 指标数字和普通文案字号差太小
7. 状态 pill 做成普通标签
8. 主卡各区块没有 `head / body / actions` 分层
9. 空态和错误态直接换布局
10. 为了自适应把本来该一行的内容全拆成两行

## 10. 开发验收清单

### 10.1 视觉验收

- 首屏第一眼只能看到一个绝对主任务
- 顶部上下文比主卡明显更轻
- 主卡比后续模块更重
- 底部导航中训练 tab 最突出
- 文案层级清楚，不像统一列表

### 10.2 布局验收

- 没有异常换行
- 没有文字截断到不可读
- 没有多余空白块
- 卡片间距节奏统一
- 底部导航不挤压正文内容

### 10.3 状态验收

- `ready` 不跳位
- `loading` 不塌布局
- `empty` 仍保持首页骨架
- `error` 仍保留安全回退动作

### 10.4 UX 验收

- 用户 3 秒内知道今天练什么
- 用户 3 秒内知道现在该点哪个按钮
- 用户能理解自己是在“继续训练”还是“开始新训练”
- 用户不会先被计划探索区吸走注意力

## 11. Open Design 提示词约束模板

后续如果继续让 Open Design 出首页稿，建议直接附带下面这类约束：

> 为 FitTracker 设计一个 today-first command brief 风格的首页。  
> 它是冷静、专业、深色的今日训练简报页，而不是综合仪表盘。  
> 首屏只允许一个绝对主卡“今日训练”，必须优先回答今天练什么、是否继续上次训练、现在该点哪个按钮。  
> 页面骨架固定为：顶部上下文、今日决策主卡、次级模块、底部导航。  
> 顶部只放日期、问候语、一个轻量辅助按钮，不做大英雄区。  
> 主卡必须拆成 head、body、actions 三层，包含状态 pill、进度视觉、3 个指标、1 个主按钮、1 个次按钮。  
> 本周节奏和计划边界只能作为次级模块，放在主卡之后。  
> 预置计划和动作库必须继续下沉，不能压过今日主任务。  
> 底部导航放下方，借鉴市面头部训练类 app：除“训练”外其余 tab 只保留文字，“训练”tab 保留图标并做唯一强化。  
> 整页只靠排版、层级、渐变、边框和卡片语义建立气质，不使用人物插画。  
> 所有文案尽量保持单行，尤其是顶部信息、状态 pill、底部 tab 和指标标签，避免模型把本应一行的信息拆成多行。  

## 12. 下一步建议

建议按这个顺序继续：

1. 先把首页专属 token 从原型里抽成一张字段清单
2. 再把 `TodayHeroCard` 做成独立视觉基准组件
3. 然后做 `TodayBottomNav`
4. 最后再拼装首页整页

如果只能选一个下一步，优先做：

- `TodayHeroCard` 的 1:1 复刻

因为首页像不像，70% 取决于这一个组件。
