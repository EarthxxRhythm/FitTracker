# HomePage V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 FitTracker 中创建一个新的 `HomePageV2`，用 ArkUI 复刻 `screen-home.html` 的首页结构，并用本地 mock view model 驱动页面，暂不接入真实业务数据。

**Architecture:** 新首页使用独立页面文件 `HomePageV2.ets`，不直接重写现有 `pages/HomePage.ets`。页面数据来自 `HomeMockViewModel.ets`，先固定结构与字段边界，再逐步搭建 hero 区、preview 区、入口网格区，最后再替换为真实服务数据。

**Tech Stack:** HarmonyOS Stage Mode、ArkTS、ArkUI、现有 `DesignTokens.ets`、现有 `AppRoutes.ets`、现有 `main_pages.json`

## Global Constraints

- 必须使用 ArkUI / ArkTS，不能直接复用 HTML/CSS。
- 必须遵守本仓库 ArkTS strict mode 约束，不能使用 `any`、`@ts-ignore`、对象字面量无显式类型等写法。
- 所有用户可见文案使用中文，参考稿中的英文小标签如果保留，需要明确这是视觉文案而不是最终产品 copy。
- 不要直接改写老首页 `entry/src/main/ets/pages/HomePage.ets`，本轮以独立新页面落地。
- 当前阶段不接入 `TrainingPlanService`、`WorkoutSessionService` 等真实数据源。
- 用户希望自己写代码，所以当前计划以任务分解、字段约束、完成标准为主，不直接提供现成实现代码。

---

## 文件结构

- 创建 `entry/src/main/ets/features/home/pages/HomePageV2.ets`
  - 负责首页 V2 页面本体、页面状态、页面级跳转、页面布局骨架。
- 创建 `entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`
  - 负责首页 mock 数据类型定义和整页 mock 数据组装。
- 修改 `entry/src/main/resources/base/profile/main_pages.json`
  - 注册新页面路径。
- 修改 `entry/src/main/ets/app/AppRoutes.ets`
  - 让 `AppRoutes.HOME` 指向新页面。
- 可选修改 `docs/homepage-v2-codex-relay-2026-07-21.md`
  - 用于记录当前执行状态和已完成任务，方便其他会话接力。

## 分阶段待办

### 阶段 1：创建落点

#### 任务 1：创建首页目录

**目的：** 给新首页建立独立的功能目录，避免直接把新页面塞回旧 `pages/` 目录。

**Files:**
- Create: `entry/src/main/ets/features/home/pages/`
- Create: `entry/src/main/ets/features/home/viewmodels/`

- [ ] 创建 `features/home/pages` 目录
- [ ] 创建 `features/home/viewmodels` 目录
- [ ] 确认两个目录都存在

**完成标准：**
- `pages` 和 `viewmodels` 目录都已创建
- 目录位置在 `entry/src/main/ets/features/home/` 下

#### 任务 2：创建首页空文件

**目的：** 先建立文件壳，后面每次只填一个责任清晰的文件。

**Files:**
- Create: `entry/src/main/ets/features/home/pages/HomePageV2.ets`
- Create: `entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`

- [ ] 创建 `HomePageV2.ets`
- [ ] 创建 `HomeMockViewModel.ets`
- [ ] 确认两个文件路径正确

**完成标准：**
- 两个文件都存在
- 文件名与计划完全一致

### 阶段 2：打通页面入口

#### 任务 3：注册 `main_pages.json`

**目的：** 让 HarmonyOS 路由系统识别 `HomePageV2`，否则页面文件存在也无法跳转进入。

**Files:**
- Modify: `entry/src/main/resources/base/profile/main_pages.json`

- [ ] 打开 `main_pages.json`
- [ ] 找到 `src` 数组
- [ ] 新增 `features/home/pages/HomePageV2`
- [ ] 检查 JSON 语法是否正确

**完成标准：**
- `src` 数组里存在 `features/home/pages/HomePageV2`
- 文件仍是合法 JSON

#### 任务 4：切换首页路由常量

**目的：** 让应用里所有基于 `AppRoutes.HOME` 的入口都先指向新首页，减少临时调试成本。

**Files:**
- Modify: `entry/src/main/ets/app/AppRoutes.ets`

- [ ] 打开 `AppRoutes.ets`
- [ ] 找到 `static readonly HOME`
- [ ] 把它的值从 `pages/HomePage` 改为 `features/home/pages/HomePageV2`
- [ ] 保存后检查路径字符串是否与 `main_pages.json` 一致

**完成标准：**
- `AppRoutes.HOME` 指向 `features/home/pages/HomePageV2`
- 路径字符串与页面注册路径一致

### 阶段 3：定义数据边界

#### 任务 5：为 `HomeMockViewModel.ets` 写文件头注释

**目的：** 先给文件一个明确责任，后续会话一打开就知道这是“首页 mock 数据与类型定义”。

**Files:**
- Modify: `entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`

- [ ] 写符合项目习惯的 JSDoc 头注释
- [ ] 在注释里说明这是首页 V2 的 mock view model 文件

**完成标准：**
- 文件顶部有项目风格的注释
- 注释能说明文件职责

#### 任务 6：定义 `HomeMetaPill`

**目的：** 把首页顶部胶囊标签建模成结构化数据，方便统一渲染和后续切换真实数据源。

**Files:**
- Modify: `entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`

- [ ] 新增类型 `HomeMetaPill`
- [ ] 给它添加最小字段 `text`
- [ ] 检查字段名是否能直接表达“胶囊显示文字”

**建议字段：**
- `text`

**完成标准：**
- 存在 `HomeMetaPill`
- 该类型能表示“一个胶囊标签”

#### 任务 7：定义 `HomePreviewCard`

**目的：** 给摘要预览卡片建立固定结构，确保页面展示层级和数据层级一一对应。

**Files:**
- Modify: `entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`

- [ ] 新增类型 `HomePreviewCard`
- [ ] 添加 `eyebrow`
- [ ] 添加 `title`
- [ ] 添加 `note`
- [ ] 检查这 3 个字段是否足够支撑第一版摘要卡片

**完成标准：**
- 存在 `HomePreviewCard`
- 它能描述“一张摘要预览卡片”

#### 任务 8：定义 `HomeEntryCard`

**目的：** 把功能入口卡片的文案和目标路由绑定在一条数据里，方便卡片渲染和点击跳转复用同一份数据。

**Files:**
- Modify: `entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`

- [ ] 新增类型 `HomeEntryCard`
- [ ] 添加 `title`
- [ ] 添加 `description`
- [ ] 添加 `route`
- [ ] 检查字段名是否能直接支撑入口卡片渲染和点击行为

**完成标准：**
- 存在 `HomeEntryCard`
- 它能描述“一张可点击入口卡片”

#### 任务 9：定义 `HomeViewModel`

**目的：** 用一个整页总类型把首页所需数据收拢起来，让页面只依赖单一 view model 边界。

**Files:**
- Modify: `entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`

- [ ] 新增类型 `HomeViewModel`
- [ ] 添加 `title`
- [ ] 添加 `subtitle`
- [ ] 添加 `metaPills`
- [ ] 添加 `previewCards`
- [ ] 添加 `entryCards`
- [ ] 检查 `metaPills`、`previewCards`、`entryCards` 是否分别引用前面定义的子类型数组

**完成标准：**
- 存在 `HomeViewModel`
- 它能表示整页首页数据

### 阶段 4：填第一版 mock 数据

#### 任务 10：准备首页主信息 mock

**目的：** 先给 hero 区提供最基础的页面文案，确保页面可以用真实结构显示出第一屏内容。

**Files:**
- Modify: `entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`

- [ ] 准备 `title`
- [ ] 准备 `subtitle`
- [ ] 确认文案适合首页主视觉，不是技术描述

**建议内容：**
- `title`: `今天训练，继续推进`
- `subtitle`: `上次训练已经完成，本周进度稳定，建议按计划进入今天的主训练`

**完成标准：**
- 主标题和副标题都有值
- 文字能支撑 hero 区展示

#### 任务 11：准备胶囊 mock

**目的：** 让 hero 区顶部的状态标签先能完整显示。

**Files:**
- Modify: `entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`

- [ ] 准备第 1 个胶囊：`今日主线`
- [ ] 准备第 2 个胶囊：`45 分钟`
- [ ] 准备第 3 个胶囊：`恢复良好`
- [ ] 确认它们最终以 `HomeMetaPill[]` 的形式组织

**完成标准：**
- 有 3 个胶囊项
- 数据类型与 `HomeMetaPill[]` 一致

#### 任务 12：准备 preview 卡片 mock

**目的：** 让页面第二块摘要卡片区有内容可渲染。

**Files:**
- Modify: `entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`

- [ ] 准备第 1 张卡片：`Today / 上肢推训练 / 卧推、上斜哑铃推举、肩推`
- [ ] 准备第 2 张卡片：`Recovery / 睡眠 7.8 小时 / 状态稳定，建议正常推进重量`
- [ ] 准备第 3 张卡片：`Goal / 增肌阶段 第 3 周 / 本周目标 4 次训练，已完成 2 次`
- [ ] 确认它们最终以 `HomePreviewCard[]` 的形式组织

**完成标准：**
- 有 3 张 preview 卡片
- 每张卡片都具备 `eyebrow`、`title`、`note`

#### 任务 13：准备入口卡片 mock

**目的：** 让底部入口区不仅能显示文案，还能带上后续跳转需要的路由信息。

**Files:**
- Modify: `entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`

- [ ] 准备第 1 张入口卡：开始训练
- [ ] 准备第 2 张入口卡：我的计划
- [ ] 准备第 3 张入口卡：训练复盘
- [ ] 准备第 4 张入口卡：动作库
- [ ] 为每张卡填好标题、说明、目标路由
- [ ] 确认它们最终以 `HomeEntryCard[]` 的形式组织

**完成标准：**
- 有 4 张入口卡片
- 每张卡片都能对应一个后续页面入口

#### 任务 14：导出整页 mock view model

**目的：** 让页面只需一次取数，就能拿到首页第一版全部内容。

**Files:**
- Modify: `entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`

- [ ] 写一个返回 `HomeViewModel` 的导出入口
- [ ] 确认这个入口把主信息、胶囊、preview 卡片、入口卡片都组装进去
- [ ] 检查返回类型与 `HomeViewModel` 一致

**完成标准：**
- 页面后续可以通过一个导出入口拿到整页数据

### 阶段 5：创建页面壳

#### 任务 15：为 `HomePageV2.ets` 写文件头注释和 import

**目的：** 先搭页面文件的结构边界，避免页面逻辑和依赖导入混乱生长。

**Files:**
- Modify: `entry/src/main/ets/features/home/pages/HomePageV2.ets`

- [ ] 写文件头注释
- [ ] 导入设计 token
- [ ] 导入 `AppButton`
- [ ] 导入 `AppRoutes`
- [ ] 导入 `HomeMockViewModel` 中的类型和整页数据入口

**完成标准：**
- 文件头职责清楚
- import 足够支撑首页第一版页面

#### 任务 16：声明页面结构和状态

**目的：** 让页面状态字段和 view model 字段一一对应，避免后续数据接入时出现“字段散落在页面里”的问题。

**Files:**
- Modify: `entry/src/main/ets/features/home/pages/HomePageV2.ets`

- [ ] 声明 `@Entry @Component struct HomePageV2`
- [ ] 声明主标题状态
- [ ] 声明副标题状态
- [ ] 声明胶囊数组状态
- [ ] 声明 preview 卡片数组状态
- [ ] 声明入口卡片数组状态

**完成标准：**
- 页面结构存在
- 关键状态字段与 `HomeViewModel` 能对应起来

#### 任务 17：接入 mock 数据到页面状态

**目的：** 打通“页面出现时读取整页 mock 数据”的最小闭环。

**Files:**
- Modify: `entry/src/main/ets/features/home/pages/HomePageV2.ets`

- [ ] 写 `aboutToAppear()`
- [ ] 在页面出现时读取整页 mock view model
- [ ] 把标题、副标题、胶囊、preview 卡片、入口卡片分别写入页面状态

**完成标准：**
- 页面状态不再是空壳
- 页面后续 `build()` 可以直接使用这些状态

### 阶段 6：搭页面骨架

#### 任务 18：先搭整页容器

**目的：** 先解决页面站得住的问题，再逐步往里填内容。

**Files:**
- Modify: `entry/src/main/ets/features/home/pages/HomePageV2.ets`

- [ ] 创建最外层背景容器
- [ ] 创建滚动容器
- [ ] 创建主内容容器
- [ ] 确认页面在深色背景下能完整显示

**完成标准：**
- 页面有最外层背景
- 页面内容可滚动

#### 任务 19：搭 hero 区骨架

**目的：** 先把最重要的第一屏结构立起来。

**Files:**
- Modify: `entry/src/main/ets/features/home/pages/HomePageV2.ets`

- [ ] 添加品牌小字位置
- [ ] 添加大标题位置
- [ ] 添加副标题位置
- [ ] 添加胶囊区位置
- [ ] 添加主按钮位置
- [ ] 添加次按钮位置

**完成标准：**
- hero 区完整存在
- 主要信息顺序与参考稿一致

#### 任务 20：搭 preview 区骨架

**目的：** 给摘要卡片预留独立区块，方便后续集中调卡片样式。

**Files:**
- Modify: `entry/src/main/ets/features/home/pages/HomePageV2.ets`

- [ ] 创建 preview 区容器
- [ ] 渲染第 1 张摘要卡片
- [ ] 渲染第 2 张摘要卡片
- [ ] 渲染第 3 张摘要卡片

**完成标准：**
- preview 区有 3 张卡片
- 每张卡片都能显示 3 层信息

#### 任务 21：搭入口网格骨架

**目的：** 把首页底部的主要导航入口搭出来，先保证结构完整。

**Files:**
- Modify: `entry/src/main/ets/features/home/pages/HomePageV2.ets`

- [ ] 创建入口区容器
- [ ] 渲染第 1 张入口卡片
- [ ] 渲染第 2 张入口卡片
- [ ] 渲染第 3 张入口卡片
- [ ] 渲染第 4 张入口卡片

**完成标准：**
- 入口区有 4 张卡片
- 每张卡片都能展示标题和说明

### 阶段 7：接入交互占位

#### 任务 22：添加统一跳转方法

**目的：** 把页面上的点击跳转收口到一个地方，避免按钮和卡片各自写一套跳转逻辑。

**Files:**
- Modify: `entry/src/main/ets/features/home/pages/HomePageV2.ets`

- [ ] 新增页面级跳转方法
- [ ] 确认该方法接收目标路由
- [ ] 处理跳转失败时不崩溃

**完成标准：**
- 页面上有统一的跳转入口

#### 任务 23：给 hero 区按钮绑定跳转

**目的：** 让首页第一屏的主次操作先可点击，形成基本导航闭环。

**Files:**
- Modify: `entry/src/main/ets/features/home/pages/HomePageV2.ets`

- [ ] 给主按钮绑定目标页面
- [ ] 给次按钮绑定目标页面
- [ ] 确认点击后至少能进入已注册页面

**完成标准：**
- 两个按钮都有占位跳转行为

#### 任务 24：给入口卡片绑定跳转

**目的：** 让底部入口区从“纯展示卡片”变成“可导航卡片”。

**Files:**
- Modify: `entry/src/main/ets/features/home/pages/HomePageV2.ets`

- [ ] 让每张入口卡点击时读取自己的 `route`
- [ ] 通过统一跳转方法执行导航
- [ ] 确认 4 张入口卡都能触发跳转

**完成标准：**
- 4 张入口卡都有点击行为

### 阶段 8：视觉复刻和验证

#### 任务 25：做第一轮视觉微调

**目的：** 先把布局比例、留白、层级调到接近参考稿，再考虑更细节的 1:1 质感。

**Files:**
- Modify: `entry/src/main/ets/features/home/pages/HomePageV2.ets`
- Reference: `C:\Users\Administrator\Downloads\screen-home.html`

- [ ] 调整 hero 区留白
- [ ] 调整标题字号层级
- [ ] 调整胶囊间距
- [ ] 调整摘要卡片间距
- [ ] 调整入口卡片网格间距

**完成标准：**
- 页面结构节奏接近参考稿

#### 任务 26：做第二轮卡片样式微调

**目的：** 让页面卡片质感更接近参考稿中的面板、预览卡、入口卡层级。

**Files:**
- Modify: `entry/src/main/ets/features/home/pages/HomePageV2.ets`
- Reference: `entry/src/main/ets/common/styles/DesignTokens.ets`

- [ ] 调整 hero 大卡片圆角
- [ ] 调整 hero 大卡片边框与背景
- [ ] 调整 preview 卡片圆角、边框、阴影
- [ ] 调整 entry 卡片圆角、边框、阴影
- [ ] 检查是否仍然遵守项目 token 体系

**完成标准：**
- 主要卡片区块有明显主次质感

#### 任务 27：编译验证

**目的：** 确认新首页不仅“看起来存在”，而且能在 ArkTS strict mode 下真正通过编译。

**Files:**
- Verify: `entry/src/main/ets/features/home/pages/HomePageV2.ets`
- Verify: `entry/src/main/ets/features/home/viewmodels/HomeMockViewModel.ets`

- [ ] 运行 `hvigorw assembleHap --mode module -p product=default`
- [ ] 记录编译错误
- [ ] 优先修复类型错误、路由注册错误、ArkTS strict mode 错误
- [ ] 再次运行构建直到通过

**完成标准：**
- 构建通过
- 没有残留的 ArkTS 语法级错误

#### 任务 28：运行验证

**目的：** 检查新首页在真实启动流里能被打开，并且能完成基础导航。

**Files:**
- Verify: `entry/src/main/ets/app/StartupPage.ets`
- Verify: `entry/src/main/ets/app/AppRoutes.ets`

- [ ] 启动应用
- [ ] 确认登录后或冷启动后进入的是 `HomePageV2`
- [ ] 确认 hero 按钮可点击
- [ ] 确认入口卡片可点击
- [ ] 记录与参考稿差异

**完成标准：**
- 新首页能从应用正常进入
- 基本交互可用

## 当前建议执行顺序

如果只做一小段，优先按下面顺序推进：

1. 任务 1 到任务 4
2. 任务 5 到任务 9
3. 任务 10 到任务 14
4. 任务 15 到任务 17
5. 任务 18 到任务 24
6. 任务 25 到任务 28

## 自检

- 本计划已覆盖：文件创建、路由注册、数据类型定义、mock 数据准备、页面骨架、交互占位、视觉微调、编译验证、运行验证。
- 本计划未包含真实服务接入，符合当前范围。
- 本计划未直接给出实现代码，符合用户希望自己开发的要求。
