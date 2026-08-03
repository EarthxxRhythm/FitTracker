# FitTracker `TodayHeroCard` 开发清单

日期：2026-07-23

适用对象：
- 首页主卡视觉复刻
- ArkUI 组件实现
- Open Design 到代码的中间规格

关联文档：
- [homepage-1to1-spec-2026-07-23.md](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/docs/homepage-1to1-spec-2026-07-23.md)
- 参考原型：`C:\Users\Administrator\Downloads\screen-home.html`
- 当前实现：[HeroWorkoutCard.ets](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/entry/src/main/ets/components/HeroWorkoutCard.ets)

## 1. 目标

`TodayHeroCard` 是首页 1:1 还原的核心组件。

如果这一块不像，整页基本不会像。  
所以它不能只做成“一个大卡片”，而必须承担：

- 今日训练主题
- 当前状态判断
- 本周进度表达
- 主决策动作
- 次级辅助动作

## 2. 组件职责

这个组件只做 3 件事：

1. 用最强视觉层级表达“今天练什么”
2. 用最少信息表达“现在该做什么”
3. 用最轻补充信息表达“为什么这么做”

它不负责：

- 预置计划探索
- 动作库入口
- 多层工具导航
- 设置和资料入口

这些都必须留在主卡外。

## 3. 固定结构

`TodayHeroCard` 必须固定为 3 段结构：

### 3.1 Head

包含：
- `kicker`
- `title`
- `subtitle`
- `progress ring`

布局规则：
- 左文右环
- 标题永远优先于进度环
- 环形进度不能压缩标题区域

### 3.2 Body

包含：
- `status pill`
- `metrics row`

布局规则：
- 先状态，后指标
- 指标最多 3 项
- 指标之间等权，但第一项允许语义强调

### 3.3 Actions

包含：
- `primary action`
- `secondary action`

布局规则：
- 主按钮在上
- 次按钮在下
- 两个按钮宽度都占满

## 4. 字段清单

推荐保持下面这组字段，不要边写边加。

### 4.1 文案字段

- `eyebrow`
- `title`
- `subtitle`
- `statusText`
- `progressText`
- `progressLabel`
- `primaryActionText`
- `secondaryActionText`

### 4.2 状态字段

- `statusTone`
- `primaryDisabled`

### 4.3 数据字段

- `metrics`

单个 metric 建议字段：
- `label`
- `value`
- `note`
- `emphasize`

### 4.4 行为字段

- `onPrimaryClick`
- `onSecondaryClick`

## 5. 信息层级规则

这是最关键的部分。

### 5.1 第一层

用户第一眼必须看到：
- `title`

它回答：
- 今天练什么
- 现在是恢复还是训练

### 5.2 第二层

第二眼看到：
- `status pill`
- `primary action`

它回答：
- 当前是否适合继续训练
- 现在该点哪个按钮

### 5.3 第三层

第三眼看到：
- `subtitle`
- `progress ring`
- `metrics`

它回答：
- 为什么今天这样安排
- 本周推进到哪了
- 这次训练的规模和来源

## 6. 状态分支清单

主卡至少要覆盖 4 种状态。

### 6.1 Ready

含义：
- 今日训练明确，可直接开始

字段建议：
- `eyebrow = 今日训练`
- `statusTone = success`
- `primaryActionText = 开始训练`
- `secondaryActionText = 查看预览`

标题语义：
- 直接显示训练主题

### 6.2 Resume

含义：
- 有中断训练可恢复

字段建议：
- `eyebrow = 恢复训练`
- `statusTone = warning`
- `primaryActionText = 继续训练`
- `secondaryActionText = 查看预览`

标题语义：
- 不是展示训练名称，而是展示“从上次中断处继续”

### 6.3 Empty

含义：
- 尚未完成目标设置

字段建议：
- `eyebrow = 开始配置`
- `statusTone = warning`
- `primaryActionText = 设置训练目标`
- `secondaryActionText = 查看动作库`

标题语义：
- 不是训练主题，而是配置引导

### 6.4 Loading

含义：
- 正在同步计划和状态

字段建议：
- `eyebrow = 正在准备`
- `statusTone = info`
- `primaryActionText = 正在准备`
- `primaryDisabled = true`

标题语义：
- 不做空白，不跳骨架

## 7. 布局约束

### 7.1 标题约束

- `title` 最多 2 行
- 不允许压成 3 行
- 标题优先级高于进度环

### 7.2 副文案约束

- `subtitle` 最多 2 行
- 超长时截断，不扩高到破坏首屏

### 7.3 指标约束

- 指标固定 3 项
- 单项宽度等分
- 不允许因为 note 太长把整行撑坏

### 7.4 按钮约束

- 主按钮必须是唯一强视觉按钮
- 次按钮只能弱一级
- 两个按钮不能并排

### 7.5 进度环约束

- 环形区是辅助表达，不是主视觉中心
- 它必须小于标题权重
- 它不能挤压文字列到过窄

## 8. 视觉约束

### 8.1 卡片气质

应有：
- 深色底
- 轻渐变
- 内描边
- 轻外阴影

不应有：
- 纯平黑块
- 普通白描边卡片感
- 和次级卡一致的视觉重量

### 8.2 状态 pill

应有：
- 小尺寸
- 低高度
- 强语义色

不应有：
- 做成普通按钮
- 太粗太高
- 颜色比主按钮更抢

### 8.3 主按钮

应有：
- 明显亮于背景
- 比次按钮更厚、更亮
- 看起来是唯一立即操作点

不应有：
- 与次按钮同权
- 过多装饰
- 抢过标题

## 9. 当前代码与目标差距

结合当前 [HeroWorkoutCard.ets](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/entry/src/main/ets/components/HeroWorkoutCard.ets)，目前已经有基础骨架，但要更接近原型，还需要关注下面几点。

### 9.1 已有基础

- 已有 `eyebrow / title / subtitle`
- 已有 `statusText / statusTone`
- 已有 `metrics`
- 已有 `primary / secondary` 按钮
- 已有右侧进度区

### 9.2 还原风险点

- 当前 `progress stack` 还是偏通用组件，不够接近原型中的首页专属环形语义
- 当前 `metrics` 的 note 容易因为文本长度破坏视觉整齐
- 当前 `subtitle` 和 `status` 之间层级还可以再拉开
- 当前主卡更像“设计系统 hero 卡”，还不够像“首页专属 today card”

## 10. 开发顺序

建议严格按这个顺序做，不要乱跳。

### Step 1

先固定字段，不改样式。

完成标准：
- 所有状态都能喂给组件

### Step 2

再固定结构：
- `head`
- `body`
- `actions`

完成标准：
- 无论任何状态，骨架都不跳

### Step 3

再调标题、状态 pill、进度环层级。

完成标准：
- 第一眼只看见训练主题和主动作

### Step 4

再调 metrics 和按钮细节。

完成标准：
- metrics 是辅助，不抢主任务

### Step 5

最后做空态、加载态、恢复态的视觉收口。

完成标准：
- 所有状态仍保留同一主卡骨架

## 11. 验收清单

### 11.1 视觉验收

- 第一眼是否只看到一个绝对主任务
- 标题是否比指标和副文案强很多
- 主按钮是否明显强于次按钮
- 进度环是否是辅助而不是主角

### 11.2 布局验收

- 标题是否被压得太窄
- 副文案是否超过 2 行
- metrics 是否对齐整齐
- 按钮是否撑满并有稳定节奏

### 11.3 状态验收

- `ready` 像训练日
- `resume` 像恢复继续
- `empty` 像引导配置
- `loading` 像准备中而不是坏掉

## 12. 给 Open Design 的单组件提示词

如果你只想先让 Open Design 重做这一张主卡，可以直接用：

> 为 FitTracker 设计一个首页主卡 `TodayHeroCard`。  
> 它是深色、冷静、专业的训练产品主卡，不是营销 Banner。  
> 卡片必须固定为三层结构：head、body、actions。  
> head 左侧放 kicker、主标题、辅助说明，右侧放一个小型环形进度表达。  
> body 先放一个状态 pill，再放 3 个等权指标。  
> actions 只放两个纵向按钮：上方唯一主按钮，下方克制的次按钮。  
> 主标题最多 2 行，副文案最多 2 行。  
> 指标是辅助信息，不能压过主标题和主按钮。  
> 整张卡片要有深色渐变、内描边、轻微外阴影和高圆角，但不能像普通仪表盘。  
> 视觉重点依次是：标题、主按钮、状态、进度、指标。  

## 13. 下一步建议

下一步最合适的是二选一：

1. 直接开始改 [HeroWorkoutCard.ets](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/entry/src/main/ets/components/HeroWorkoutCard.ets)，按这份清单收敛成首页专属主卡
2. 先补一份 `TodayBottomNav` 的同级开发清单，先把另外一个最容易失真的模块也固定下来

如果只选一个，优先选第 1 个。
