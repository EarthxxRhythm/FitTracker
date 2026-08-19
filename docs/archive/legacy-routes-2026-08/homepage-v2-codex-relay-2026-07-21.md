# HomePage V2 Codex Relay

日期：2026-07-21

## 当前目标

在 FitTracker 中新建一个 `HomePageV2`，用 HarmonyOS ArkUI 复刻 `C:\Users\Administrator\Downloads\screen-home.html` 的首页视觉结构。

## 最新计划入口

- 完整待办与执行顺序见：`docs/superpowers/plans/2026-07-21-homepage-v2-implementation-plan.md`
- 本文件继续保留为“接力说明”，计划内容以后以正式计划文件为准

本轮目标不是接入真实数据，而是先完成：

- 可被路由打开的新首页页面
- 本地 mock view model
- 可演进到真实接口的数据结构
- 接近参考稿的页面布局骨架

## 当前约束

- 不能直接复用 HTML/CSS，必须改写成 ArkUI / ArkTS
- 必须遵守项目的 ArkTS strict mode 约束
- 用户希望自己开发，所以当前文档只记录待办和目的，不提供现成实现代码
- 页面未来需要能接真实服务，但当前阶段不接 `TrainingPlanService` 和 `WorkoutSessionService`
- 页面风格目标是尽量 1:1 贴近 `screen-home.html`

## 建议文件位置

- 页面文件：`entry/src/main/ets/features/home/pages/HomePageV2.ets`
- 数据文件：`entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`

## 推荐开发顺序

1. 创建目录和空文件
2. 注册 `main_pages.json`
3. 调整 `AppRoutes.HOME`
4. 定义 `HomeMockViewModel.ets` 中的基础类型
5. 再写页面 `@State`
6. 再接 mock 数据
7. 最后逐区块搭页面

## 最小任务清单

### 任务 A：创建首页目录和文件

目的：
让新首页有独立落点，不直接扰动现有 `pages/HomePage.ets`。

要做的事：

- 创建目录 `entry/src/main/ets/features/home/pages`
- 创建目录 `entry/src/main/ets/features/home/viewmodels`
- 创建文件 `HomePageV2.ets`
- 创建文件 `HomeMockViewModel.ets`

完成标准：

- 目录存在
- 文件存在
- 暂时允许为空文件

### 任务 B：注册新页面

目的：
让 HarmonyOS 路由系统认识这个新页面，否则即使文件存在也不能通过路由打开。

要做的事：

- 打开 `entry/src/main/resources/base/profile/main_pages.json`
- 在 `src` 数组中加入 `features/home/pages/HomePageV2`

完成标准：

- `main_pages.json` 中存在新页面路径
- 页面路径格式与其他页面一致

### 任务 C：切换首页入口到新页面

目的：
让应用中所有“回首页”或“进入首页”的现有路由先统一指向新页面，便于反复预览和调试。

要做的事：

- 打开 `entry/src/main/ets/app/AppRoutes.ets`
- 找到 `HOME`
- 把 `HOME` 指向 `features/home/pages/HomePageV2`

完成标准：

- `AppRoutes.HOME` 不再指向 `pages/HomePage`
- 应用启动后首页入口会落到新页面

### 任务 D：定义 `HomeMetaPill` 类型

目的：
把首页顶部那组“小胶囊标签”从普通文本升级为结构化数据，方便页面统一循环渲染，也方便以后替换成真实接口返回值。

要做的事：

- 在 `HomeMockViewModel.ets` 中新增一个类型，名字叫 `HomeMetaPill`
- 这个类型只描述“一个胶囊项”
- 第一版只保留最小字段，不要过度设计

建议字段：

- `text`

字段含义：

- `text`：胶囊里展示的文字，比如“今日主线”“45 分钟”“恢复良好”

为什么先只放这个字段：

- 当前阶段只是首页 mock
- 页面需要的是一组样式统一、内容不同的标签
- 还不需要图标、状态色、选中态这些复杂信息

完成标准：

- 类型名正确，为 `HomeMetaPill`
- 至少有 `text` 字段
- 后面可以用 `HomeMetaPill[]` 表示整组标签

### 任务 E：定义 `HomePreviewCard` 类型

目的：
明确首页“摘要预览卡片”的数据结构，让页面按固定的信息层级来渲染卡片，而不是把文案零散写在页面里。

要做的事：

- 在 `HomeMockViewModel.ets` 中新增一个类型，名字叫 `HomePreviewCard`
- 这个类型只描述“一张摘要预览卡片”
- 第一版只定义最核心的 3 层信息

建议字段：

- `eyebrow`
- `title`
- `note`

字段含义：

- `eyebrow`：卡片顶部的小标签，比如 `Today`、`Recovery`、`Goal`
- `title`：卡片最重要的一行信息，比如“上肢推训练”“睡眠 7.8 小时”
- `note`：卡片的补充描述，比如“卧推、上斜哑铃推举、肩推”

为什么这样拆：

- 参考稿里的摘要卡片有明显的信息主次
- 这 3 个字段足够支持第一版卡片层级
- 先定义清楚数据层级，后面调字号、颜色、留白会更顺

完成标准：

- 类型名正确，为 `HomePreviewCard`
- 至少包含 `eyebrow`、`title`、`note`
- 后面可以用 `HomePreviewCard[]` 渲染多张卡片

### 任务 F：定义 `HomeEntryCard` 类型

目的：
把底部功能入口卡片的数据和跳转目标绑定在一起，避免页面里另外维护一份分散的点击逻辑映射。

要做的事：

- 在 `HomeMockViewModel.ets` 中新增一个类型，名字叫 `HomeEntryCard`
- 这个类型只描述“一张功能入口卡片”
- 它既要有展示文案，也要有路由信息

建议字段：

- `title`
- `description`
- `route`

字段含义：

- `title`：入口卡片主标题，比如“开始训练”“我的计划”
- `description`：入口卡片说明文字
- `route`：点击卡片后要去的页面路径或路由常量对应值

为什么需要 `route`：

- 入口卡片不是纯展示卡片
- 它本质上是导航入口
- 把目标路由和文案放到同一条数据里，后续接点击事件更简单

完成标准：

- 类型名正确，为 `HomeEntryCard`
- 至少包含 `title`、`description`、`route`
- 后面可以用 `HomeEntryCard[]` 渲染入口并绑定点击行为

### 任务 G：定义 `HomeViewModel` 类型

目的：
用一个总类型把首页第一版需要的所有数据收拢起来，让页面后续只依赖一份完整的 view model，而不是东拿一点、西拿一点。

要做的事：

- 在 `HomeMockViewModel.ets` 中新增一个类型，名字叫 `HomeViewModel`
- 这个类型表示“整页首页数据”
- 它需要组合前面定义的 3 个子类型

建议字段：

- `title`
- `subtitle`
- `metaPills`
- `previewCards`
- `entryCards`

字段含义：

- `title`：首页主标题
- `subtitle`：首页副标题
- `metaPills`：顶部胶囊标签数组
- `previewCards`：摘要预览卡片数组
- `entryCards`：功能入口卡片数组

为什么最后才定义它：

- 它依赖前面 3 个零件类型
- 前面的类型先稳定，总类型才容易一次拼对
- 这是未来从 mock 切换到真实接口的关键边界

完成标准：

- 类型名正确，为 `HomeViewModel`
- 它内部引用 `HomeMetaPill`、`HomePreviewCard`、`HomeEntryCard`
- 页面后续可以通过一份 `HomeViewModel` 取到整页所需内容

## 第一版建议 mock 内容

### 首页主信息

- `title`：今天训练，继续推进
- `subtitle`：上次训练已经完成，本周进度稳定，建议按计划进入今天的主训练

### 状态胶囊

- `今日主线`
- `45 分钟`
- `恢复良好`

### 预览卡片

1. `Today` / `上肢推训练` / `卧推、上斜哑铃推举、肩推`
2. `Recovery` / `睡眠 7.8 小时` / `状态稳定，建议正常推进重量`
3. `Goal` / `增肌阶段 第 3 周` / `本周目标 4 次训练，已完成 2 次`

### 功能入口卡片

1. `开始训练` / `进入今天的训练预览与执行流程`
2. `我的计划` / `查看当前训练计划与周期安排`
3. `训练复盘` / `查看历史记录、趋势与个人最佳`
4. `动作库` / `查看动作说明、记录与推荐动作`

## 给后续 Codex 会话的说明

- 用户希望自己写代码，所以优先提供任务分解、字段建议、检查清单
- 除非用户主动要代码，否则不要直接输出整段实现
- 当前最适合继续的下一步，是指导用户完成 `HomeMockViewModel.ets` 的 4 个基础类型定义
