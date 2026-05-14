# PRD优化：FitTracker 健身工具产品需求文档重写

## TL;DR
> **Summary**: 基于现有 HarmonyOS ArkUI 代码库，按照互联网产品 PRD 惯例（用户故事 + Given-When-Then + MoSCoW + 数据字典）重写 FitTracker PRD，删除原 PRD 中与代码不符的云端/社交/AI 功能描述。
> **Deliverables**: 一份优化后的 `FitTracker健身工具PRD.md`（项目根目录），包含用户故事、验收标准、数据字典、交互流程。
> **Effort**: Medium
> **Parallel**: YES — 3 waves (Foundation → Content Sections → Review)
> **Critical Path**: Task 1 → Task 2 → Tasks 3-8 (parallel) → Task 9 → Final Verification

## Context
### Original Request
用户提供了一份 8 章中文 PRD 草稿和原型图 PDF/JPG（无法读取），要求"根据业内标准对PRD和产品原型图进行优化"。

### Interview Summary
- **标准**: 互联网产品 PRD 惯例（用户故事 + Given-When-Then 验收标准 + MoSCoW 优先级 + 交互说明）
- **范围**: 全面改造（结构 + 内容 + 代码对齐 + 缺失补全）
- **策略**: 以代码为准重写 PRD（因原 PRD 与代码严重不符）
- **交付**: Markdown 文件放入项目根目录
- **原型图**: 模型无法读取，以代码 + DesignTokens 为 UI 描述依据

### Metis Review (gaps addressed)
- ✅ 锁定本地优先 MVP 范围，云端/AI 标记为 Future Iteration
- ✅ 每项功能映射到具体代码模块（页面对应页面文件，服务对应业务逻辑）
- ✅ 添加 PRD→代码映射表保证可追溯性
- ✅ 所有验收标准必须可执行（脚本/命令验证，非人工判断）
- ✅ 独立"未来迭代"章节存放超出 MVP 的功能
- ✅ 包含 ArkTS strict mode 约束和 DesignTokens 引用规范

## Work Objectives
### Core Objective
产出一份与 FitTracker HarmonyOS 代码库完全对齐的产品需求文档，供开发、测试、设计团队作为基准。

### Deliverables
1. `FitTracker健身工具PRD.md` — 优化后的完整 PRD（项目根目录）
2. 内部包含：执行摘要、产品范围、用户画像、用户故事（MoSCoW）、功能需求、数据字典、交互流程、非功能需求、验收标准、路线图

### Definition of Done
- [ ] `FitTracker健身工具PRD.md` 存在于项目根目录
- [ ] 文档中所有功能描述均有对应代码模块（页面/服务/组件）可追溯
- [ ] 至少 6 条用户故事，每条含 Given-When-Then 验收标准
- [ ] 数据字典包含 Exercise、Plan、WorkoutSession、UserProfile 等核心类型
- [ ] 无云端同步、OAuth、AI 推荐等未实现功能的描述出现在核心章节
- [ ] 所有 UI 描述引用 DesignTokens.ets 中的 token 名称

### Must Have
- 以代码为准，删除所有与实现不符的功能描述
- 用户故事格式 + Given-When-Then 验收标准
- MoSCoW 优先级标注（Must/Should/Could/Won't）
- 数据字典对齐代码接口类型
- 中文 UI，面向 HarmonyOS ArkUI
- 交互流程步骤化描述

### Must NOT Have
- 云端同步/Firebase/后端 API 描述（除 Future Iteration 章节）
- OAuth 2.0 / JWT / 社交登录（当前仅 Mock 认证）
- 3D 动画/视频演示（当前无媒体资源）
- AI 算法推荐（当前仅规则匹配）
- 社交功能/社区/分享（当前未实现）
- 成就徽章系统（当前未实现）
- 饮食记录/体脂追踪（当前未实现）
- 硬编码色值/字号（必须引用 DesignTokens）
- 任何功能增删（PRD 描述现有功能，不新增需求）

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.
- Test decision: tests-after — 验证 PRD 文档完整性、代码对齐性
- QA policy: 每项任务有可脚本化验证步骤
- Evidence: `.sisyphus/evidence/task-{N}-{slug}.md`

## Execution Strategy
### Parallel Execution Waves
> Target: 3-4 tasks per wave.

Wave 1: Foundation — 结构模板 + 数据字典提取
Wave 2: Content Sections — 并行编写各章节
Wave 3: Integration — 组装 + 一致性审查 + 格式审查

### Dependency Matrix
```
Task 1 (结构模板) ──→ Task 3-8 (并行写各章节) ──→ Task 9 (组装+审查)
Task 2 (数据字典) ──→ Task 3-8 (需要数据模型引用)
                                    ──→ F1-F4 (最终验证)
```

### Agent Dispatch Summary
| Wave | Task Count | Categories |
|------|-----------|------------|
| 1 | 2 | deep, quick |
| 2 | 6 | writing ×5, deep |
| 3 | 1 + 4 (verification) | writing, oracle, unspecified-high ×2, deep |

## TODOs
> Implementation + Test = ONE task. Never separate.
> EVERY task MUST have: Agent Profile + Parallelization + QA Scenarios.

- [x] 1. 创建 PRD 骨架模板 + 章节结构

  **What to do**: 
  1. 在项目根目录创建 `FitTracker健身工具PRD.md`
  2. 写入完整的章节骨架（按下方结构），每个章节填入占位标记 `<!-- TODO: Section X -->`
  3. 章节结构（15 部分）：
     - 一、文档概述（目的、适用范围、术语定义）
     - 二、产品概述（执行摘要、产品定位、MVP 范围、Future Iteration）
     - 三、用户画像（3 个 Persona，对齐代码中实际支持的使用场景）
     - 四、用户故事与优先级（MoSCoW 表格 + 6-9 条用户故事）
     - 五、功能需求详述（训练计划、动作库、训练记录、统计、认证/个人）
     - 六、数据字典（Exercise、Plan、WorkoutSession、UserProfile 等类型定义）
     - 七、交互流程（4 条核心流程：选计划→训练→记录→查看统计）
     - 八、UI/UX 设计约束（DesignTokens 引用规范、组件库映射、ArkUI 约束）
     - 九、非功能需求（性能、本地存储、兼容性、可用性）
     - 十、验收标准（每条用户故事的 Given-When-Then）
     - 十一、PRD→代码映射表
     - 十二、路线图与里程碑（MVP → 近期 → 远期）
     - 十三、风险与缓解
     - 十四、附录（术语表、参考文档）
  4. 确保文件编码为 UTF-8，开头包含元信息注释

  **Must NOT do**: 
  - 不要填入任何具体内容（除章节标题和占位符）
  - 不要使用 emoji（除设计系统已定义的图标字符如 ←）

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: 纯结构创建，无业务逻辑
  - Skills: [`writing-plans`] — Reason: 需要遵循 PRD 文档规范
  - Omitted: [`test-driven-development`] — 无代码变更

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: Tasks 3-8 | Blocked By: None

  **References**:
  - Pattern: `AGENTS.md` — PRD 应引用的代码结构总览
  - Template: Metis 推荐的 15 节 PRD 大纲（已在本任务描述中）
  - Constraint: `entry/src/main/ets/common/styles/DesignTokens.ets` — 所有 UI 描述的权威来源

  **Acceptance Criteria** (agent-executable only):
  - [ ] `ls FitTracker健身工具PRD.md` 返回文件存在
  - [ ] `grep -c "^## " FitTracker健身工具PRD.md` 输出 ≥ 14（至少 14 个二级标题）
  - [ ] `grep "TODO: Section" FitTracker健身工具PRD.md | wc -l` 输出 ≥ 8（至少 8 个待填充标记）

  **QA Scenarios**:
  ```
  Scenario: 骨架文件结构完整
    Tool: Bash
    Steps: 
      1. wc -l FitTracker健身工具PRD.md
      2. grep -c "^## " FitTracker健身工具PRD.md
    Expected: 文件行数 > 50，至少 14 个二级标题
    Evidence: .sisyphus/evidence/task-1-skeleton.md

  Scenario: 占位标记完整
    Tool: Bash
    Steps: grep "TODO: Section" FitTracker健身工具PRD.md
    Expected: 输出 8+ 行，每行对应一个待填充章节
    Evidence: .sisyphus/evidence/task-1-skeleton.md
  ```

  **Commit**: YES | Message: `docs: add PRD skeleton template for FitTracker` | Files: [`FitTracker健身工具PRD.md`]

- [x] 2. 提取数据字典（代码接口 → PRD 数据模型）

  **What to do**: 
  1. 阅读以下文件中的 interface/type 定义，提取所有数据模型：
     - `common/services/TrainingPlanService.ets` — ExerciseRef, TrainingDay, PresetPlan, UserPlan
     - `common/services/WorkoutSessionService.ets` — SavedSet, SavedExercise, WorkoutSession, WeeklyStats, ExerciseRecord
     - `common/services/ExerciseService.ets` — Exercise
     - `common/services/AuthService.ets` — AuthResult
     - `common/services/UserProfileService.ets` — UserProfile
  2. 为每个类型生成 Markdown 表格：字段名、类型、必填、说明、来源文件
  3. 写入 `.sisyphus/drafts/data-dictionary.md`（供 Task 3-8 引用）
  4. 标注哪些字段来自代码（标记 `[code]`）、哪些来自 PRD 描述推导（标记 `[derived]`）

  **Must NOT do**: 
  - 不要编造代码中不存在的字段
  - 不要修改任何 .ets 文件

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: 需要精确理解 ArkTS 类型系统和 5 个服务文件的接口定义
  - Skills: [] — 不需要特殊 skill
  - Omitted: [`test-driven-development`] — 无测试编写

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: Tasks 3-8 | Blocked By: None

  **References**:
  - Type sources: `common/services/TrainingPlanService.ets:10-34` (ExerciseRef, TrainingDay, PresetPlan, UserPlan)
  - Type sources: `common/services/WorkoutSessionService.ets:12-51` (SavedSet, SavedExercise, WorkoutSession, WeeklyStats, ExerciseRecord)
  - Type sources: `common/services/ExerciseService.ets:6-15` (Exercise)
  - Type sources: `common/services/AuthService.ets` (AuthResult)
  - Pattern: `AGENTS.md` — Services conventions

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep -c "| .* | .* |" .sisyphus/drafts/data-dictionary.md` 输出 ≥ 10（至少 10 个字段行）
  - [ ] 每个数据模型表格至少包含：字段名、类型、说明三列
  - [ ] `grep "\[code\]" .sisyphus/drafts/data-dictionary.md | wc -l` ≥ 所有字段的 80%

  **QA Scenarios**:
  ```
  Scenario: 所有核心类型均有记录
    Tool: Bash
    Steps: grep "^## " .sisyphus/drafts/data-dictionary.md
    Expected: 输出包含 Exercise, Plan, WorkoutSession, UserProfile, ExerciseRecord, WeeklyStats
    Evidence: .sisyphus/evidence/task-2-datadict.md

  Scenario: 与代码源文件一致
    Tool: Bash
    Steps:
      1. grep "interface Exercise " entry/src/main/ets/common/services/ExerciseService.ets
      2. grep "Exercise" .sisyphus/drafts/data-dictionary.md
    Expected: 数据字典中 Exercise 的字段与代码中 interface Exercise 的字段完全匹配
    Evidence: .sisyphus/evidence/task-2-datadict.md
  ```

  **Commit**: NO (写入 `.sisyphus/drafts/` 临时文件)

- [x] 3. 编写「执行摘要 + 产品范围」章节

  **What to do**: 
  1. 填充 PRD 第二章节（产品概述）
  2. 执行摘要：1-2 段，描述 FitTracker 是什么（HarmonyOS 本地健身记录工具）、解决什么问题
  3. MVP 范围（In-Scope）：列出 9 页面、6 服务、5 计划、45 动作，本地存储，中文 UI
  4. 明确 Out-of-Scope：云端同步、社交、AI、3D 动画、iOS/Android
  5. Future Iteration 章节：列出云端同步、社交功能、AI 推荐等作为远期目标，标注依赖和风险
  6. 引用 Task 2 的数据字典和 `AGENTS.md` 的技术栈描述

  **Must NOT do**: 
  - 不要声称支持 iOS/Android/Web 平台
  - 不要提及云端服务器、Firebase 或任何后端技术
  - 不要描述 200+ 动作（实际 45 个）

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: 纯文档编写，需清晰表达产品定位
  - Skills: [] — 基础写作任务
  - Omitted: None

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: Task 9 | Blocked By: Tasks 1, 2

  **References**:
  - Codebase reality: `AGENTS.md` — OVERVIEW + STRUCTURE
  - Platform: HarmonyOS Stage Mode, ArkTS/ArkUI
  - Storage: `@ohos.data.preferences` (fit_tracker_* stores)
  - Design: `common/styles/DesignTokens.ets`

  **Acceptance Criteria** (agent-executable only):
  - [ ] 文档中包含 "## 二、产品概述" 章节
  - [ ] "In-Scope" 小节列出 9 个页面名称（与 `main_pages.json` 一致）
  - [ ] "Out-of-Scope" 小节包含：云端同步、社交、AI、3D 动画、跨平台
  - [ ] 包含 "Future Iteration" 小节

  **QA Scenarios**:
  ```
  Scenario: 范围描述与代码一致
    Tool: Bash
    Steps:
      1. grep -A 20 "In-Scope" FitTracker健身工具PRD.md
      2. diff <(grep -oP 'pages/\w+' main_pages.json | sort) <(grep -oP 'pages/\w+' FitTracker健身工具PRD.md | sort)
    Expected: PRD 中列出的页面与 main_pages.json 注册的页面完全匹配
    Evidence: .sisyphus/evidence/task-3-scope.md
  ```

  **Commit**: NO (批量提交在 Task 9)

- [x] 4. 编写「用户画像」章节

  **What to do**: 
  1. 填充 PRD 第三章节（用户分析）
  2. 保留原 PRD 的 3 个 Persona 框架，但修改细节以对齐当前 MVP 能力：
     - Persona 1: 健身新手张明 — 使用预置计划、跟随训练
     - Persona 2: 有经验者李婷 — 查看动作详情、追踪记录
     - Persona 3: 减脂目标王浩 — 日历热力图、统计面板
  3. 每个 Persona 包含：基本信息、健身目标、使用场景（映射到具体页面）、期望功能（仅限已实现功能）
  4. 删除原 PRD 中关于 AI 推荐、社区交流、饮食记录等未实现功能的描述

  **Must NOT do**: 
  - 不要描述 Persona 使用未实现的功能（如"通过社区分享训练成果"）
  - 不要超过 3 个 Persona（保持原 PRD 结构）

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: 用户画像写作
  - Skills: [] — 基础写作任务
  - Omitted: None

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: Task 9 | Blocked By: Tasks 1, 2

  **References**:
  - Original PRD sections 三(一) and 三(二) — 原始用户画像素材
  - Page mapping: `AGENTS.md` — WHERE TO LOOK table
  - Feature scope: Task 3 输出的 In-Scope 列表

  **Acceptance Criteria** (agent-executable only):
  - [ ] 包含 3 个 Persona，每个有独立小节
  - [ ] 每个 Persona 的"期望功能"仅描述已实现的功能
  - [ ] 无任何 Persona 提及云端/AI/社交

  **QA Scenarios**:
  ```
  Scenario: Persona 功能引用均为已实现
    Tool: Bash
    Steps: grep -i "社交\|社区\|AI\|云端\|分享\|推荐算法\|OAuth\|Firebase" FitTracker健身工具PRD.md | grep -A 2 "Persona\|用户画像"
    Expected: 在用户画像章节中无上述关键词匹配
    Evidence: .sisyphus/evidence/task-4-personas.md
  ```

  **Commit**: NO (批量提交在 Task 9)

- [x] 5. 编写「用户故事与 MoSCoW 优先级」章节

  **What to do**: 
  1. 填充 PRD 第四章节
  2. 创建 MoSCoW 优先级总表（Must/Should/Could/Won't）
  3. 编写 6-9 条用户故事，格式：`作为<角色>，我希望<功能>，以便<价值>`
  4. 每条用户故事附带 Given-When-Then 验收标准（3-5 条）
  5. Must Have 故事（建议 4 条）：
     - 选择并启用预置训练计划
     - 执行训练并记录组数据
     - 查看周统计和日历热力图
     - 浏览动作库并查看动作详情
  6. Should Have 故事（建议 2-3 条）：
     - 查看个人最佳纪录（1RM）
     - 自定义训练计划
     - 用户注册/登录
  7. Could Have 故事（建议 1 条）：训练备注和笔记
  8. Won't Have（标注为 Future Iteration）：云端同步、社交分享、AI 推荐、成就系统

  **Must NOT do**: 
  - 不要把 Won't Have 功能写成用户故事（仅在表格中标注）
  - 验收标准不要使用模糊措辞（如"正常显示"、"功能正常"）

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: 用户故事和验收标准的精准写作
  - Skills: [] — 基础写作任务
  - Omitted: None

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: Task 9 | Blocked By: Tasks 1, 2

  **References**:
  - Page features: `pages/AGENTS.md` — WHERE TO LOOK table (each page's key features)
  - Service capabilities: `common/services/AGENTS.md` — WHERE TO LOOK table
  - Data types: Task 2 输出的 `.sisyphus/drafts/data-dictionary.md`
  - Navigation: Index.ets 底部 Tab 栏（训练/动作库/统计/我的）

  **Acceptance Criteria** (agent-executable only):
  - [ ] MoSCoW 表格包含 ≥ 10 行功能项
  - [ ] Must Have 用户故事 ≥ 4 条
  - [ ] 每条用户故事格式：`作为<角色>，我希望<功能>，以便<价值>`
  - [ ] 每条 Must/Should 故事有 ≥ 3 条 Given-When-Then
  - [ ] Won't Have 行不展开为用户故事

  **QA Scenarios**:
  ```
  Scenario: 用户故事格式正确
    Tool: Bash
    Steps: grep "作为.*，我希望.*，以便.*" FitTracker健身工具PRD.md | wc -l
    Expected: 输出 ≥ 6（至少 6 条用户故事）
    Evidence: .sisyphus/evidence/task-5-stories.md

  Scenario: Must Have 故事可追溯到代码
    Tool: Bash
    Steps: 
      for story in "启用预置训练计划" "执行训练并记录" "查看周统计" "浏览动作库"; do
        grep -q "$story" FitTracker健身工具PRD.md && echo "FOUND: $story" || echo "MISSING: $story"
      done
    Expected: 所有 4 条 Must Have 主题均找到
    Evidence: .sisyphus/evidence/task-5-stories.md
  ```

  **Commit**: NO (批量提交在 Task 9)

- [x] 6. 编写「功能需求详述」章节（训练计划 + 动作库）

  **What to do**: 
  1. 填充 PRD 第五章节前半部分
  2. 训练计划子章节：
     - 功能点：5 套预置计划、启用/切换计划、今日训练视图、休息日视图
     - 交互流程：预置计划页 → 计划详情 → 启用 → 首页今日训练
     - 页面映射：Index.ets（列表+今日训练）、PlanDetailPage.ets（计划详情）
     - 数据模型引用：PresetPlan, UserPlan, TrainingDay, ExerciseRef
     - 设计约束：引用 ColorTokens.SUCCESS（当前计划高亮）、Chip 组件（肌群标签）
  3. 动作库子章节：
     - 功能点：45 个动作、按肌群筛选、按器械筛选、搜索、动作详情、个人纪录
     - 交互流程：动作库 Tab → 筛选 → 点击动作 → 详情页（动作要领/参与肌群 Tab）
     - 页面映射：ExerciseLibraryPage.ets、ExerciseDetailPage.ets
     - 数据模型引用：Exercise、ExerciseRecord（1RM）
     - 设计约束：引用 MuscleColorMap（肌群标签色）、SegmentedControl 组件

  **Must NOT do**: 
  - 不要声称超过 45 个动作
  - 不要描述 3D 动画或视频播放器
  - 不要描述"收藏动作"功能（当前未实现）

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: 功能需求文档写作
  - Skills: [] — 基础写作任务
  - Omitted: None

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: Task 9 | Blocked By: Tasks 1, 2

  **References**:
  - TrainingPlanService: `common/services/TrainingPlanService.ets:79-369` (5 preset plans)
  - ExerciseService: `common/services/ExerciseService.ets:39-91` (45 exercises)
  - Index.ets: `:20-27` (segments, plan data), `:228-230` (SegmentedControl)
  - PlanDetailPage.ets: plan preview + timeline
  - ExerciseLibraryPage.ets: filter/search UI
  - ExerciseDetailPage.ets: `:22-24` (tabs), `:73-80` (hero placeholder)

  **Acceptance Criteria** (agent-executable only):
  - [ ] 训练计划章节提及 5 套预置计划名称（与 PRESET_PLANS 数组一致）
  - [ ] 动作库章节提及 45 个动作总量
  - [ ] 每个功能点标注对应的页面文件名
  - [ ] 无视频/3D/动画相关描述

  **QA Scenarios**:
  ```
  Scenario: 计划名称与代码一致
    Tool: Bash
    Steps:
      1. grep "name:" entry/src/main/ets/common/services/TrainingPlanService.ets | head -5
      2. grep "五分化\|全身训练\|推拉腿\|上肢\|下肢" FitTracker健身工具PRD.md
    Expected: PRD 中列出的计划名称与 PRESET_PLANS 中的 name 字段匹配
    Evidence: .sisyphus/evidence/task-6-features.md
  ```

  **Commit**: NO (批量提交在 Task 9)

- [x] 7. 编写「功能需求详述」章节（训练记录 + 统计 + 认证/个人）

  **What to do**: 
  1. 填充 PRD 第五章节后半部分
  2. 训练记录子章节：
     - 功能点：计时器（正计时）、动作组数录入（手风琴折叠）、重量/次数输入、1RM 实时估算（Epley 公式）、结束训练摘要
     - 页面映射：WorkoutRecorderPage.ets
     - 交互流程：首页"开始训练"→ 计时器启动 → 展开动作 → 录入组数据 → 结束训练 → 摘要弹窗
     - 数据模型：SavedSet, SavedExercise, WorkoutSession
     - 约束：1RM = weight × (1 + reps / 30)、本地 preferences 存储
  3. 统计子章节：
     - 功能点：日历热力图（月视图 5 档绿色深浅）、周统计概览（次数/时长/组数/总量 4 指标）、月份切换
     - 页面映射：StatsPage.ets
     - 数据模型：WeeklyStats、trainingDates
     - 设计约束：热力图色阶引用（5 档绿色值见 StatsPage.ets:73-74）
  4. 认证/个人子章节：
     - 功能点：手机号+密码注册/登录（Mock 认证）、个人资料（名称、头像占位）
     - 页面映射：RegisterPage.ets、LoginPage.ets、ProfilePage.ets
     - 数据模型：AuthResult、UserProfile

  **Must NOT do**: 
  - 不要描述 OAuth 2.0 / JWT / 社交登录（当前仅 Mock 内存认证）
  - 不要描述云端数据同步
  - 不要描述成就徽章系统
  - 不要描述语音录入（当前未实现）
  - 不要描述分享功能

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: 功能需求文档写作
  - Skills: [] — 基础写作任务
  - Omitted: None

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: Task 9 | Blocked By: Tasks 1, 2

  **References**:
  - WorkoutRecorderPage.ets: full file (timer, sets, 1RM, summary)
  - StatsPage.ets: `:10-27` (state vars, heatmap colors)
  - WorkoutSessionService.ets: `:62-70` (saveSession), `:82-100` (getWeeklyStats)
  - AuthService.ets: mock auth flow
  - SessionManager.ets: token management
  - UserProfileService.ets: profile persistence

  **Acceptance Criteria** (agent-executable only):
  - [ ] 训练记录章节包含 1RM 公式 `weight × (1 + reps / 30)`
  - [ ] 统计章节描述 4 项周统计指标（次数/时长/组数/总量）
  - [ ] 认证章节标注"Mock 认证（内存存储）"
  - [ ] 无 OAuth/JWT/云端/社交/成就 相关描述

  **QA Scenarios**:
  ```
  Scenario: 1RM 公式正确
    Tool: Bash
    Steps: grep "weight.*1.*reps.*30\|Epley" FitTracker健身工具PRD.md
    Expected: 输出包含 Epley 公式或其算术等价形式
    Evidence: .sisyphus/evidence/task-7-features.md
  ```

  **Commit**: NO (批量提交在 Task 9)

- [x] 8. 编写「数据字典 + 交互流程 + UI 约束 + 非功能需求」章节

  **What to do**: 
  1. 数据字典（第六章）：将 Task 2 的 `.sisyphus/drafts/data-dictionary.md` 内容整合进 PRD，格式化表格
  2. 交互流程（第七章）：描述 4 条核心流程：
     - 流程 A: 选择计划 → 查看详情 → 启用 → 首页今日训练 → 开始训练
     - 流程 B: 训练执行 → 计时 → 录入组数据 → 1RM 更新 → 结束 → 摘要
     - 流程 C: 统计 Tab → 查看周统计 → 切换月份 → 点击日期查看详情
     - 流程 D: 动作库 Tab → 筛选肌群 → 点击动作 → 查看详情（动作要领 + 参与肌群 + 个人纪录）
  3. UI/UX 约束（第八章）：
     - DesignTokens 引用规范：所有色值必须引用 ColorTokens.*，所有字号引用 FontTokens.*
     - 组件库映射表：AppButton → 主/次/幽灵按钮、AppCard → 描边/填充卡片等
     - ArkTS strict mode 约束摘要（无 any、无 as const、工厂函数模式）
  4. 非功能需求（第九章）：对齐当前实现：
     - 性能：本地存储查询 < 300ms（无网络依赖）
     - 本地存储：fit_tracker_* stores、JSON 序列化
     - 兼容性：HarmonyOS 5.0+、ArkUI
     - 可用性：中文 UI、DesignTokens 统一风格

  **Must NOT do**: 
  - 不要编造性能指标（必须从 AGENTS.md 或代码注释中获取已有指标）
  - 不要添加 TLS/HTTPS 安全需求（纯本地应用）
  - 不要添加 GDPR/CCPA 合规需求（无用户数据上传）

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: 技术写作，需整合多方面信息
  - Skills: [] — 基础写作任务
  - Omitted: None

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: Task 9 | Blocked By: Tasks 1, 2

  **References**:
  - Data types: Task 2 输出的 `.sisyphus/drafts/data-dictionary.md`
  - Design tokens: `common/styles/DesignTokens.ets` (full file)
  - Components: `components/` directory (AppButton, AppCard, AppInput, ChartCalendar, SegmentedControl, Chip, EmptyState)
  - ArkTS rules: `AGENTS.md` — ARKTS STRICT MODE RULES section
  - Page conventions: `pages/AGENTS.md` — CONVENTIONS section
  - Service conventions: `common/services/AGENTS.md` — CONVENTIONS section

  **Acceptance Criteria** (agent-executable only):
  - [ ] 数据字典包含 ≥ 5 个类型定义表格
  - [ ] 交互流程包含 ≥ 4 条步骤化流程
  - [ ] UI 约束章节引用 DesignTokens.ets
  - [ ] 非功能需求无 HTTPS/TLS/GDPR/云端 相关描述

  **QA Scenarios**:
  ```
  Scenario: 数据字典字段可追溯
    Tool: Bash
    Steps: 
      for type in "ExerciseRef" "TrainingDay" "PresetPlan" "WorkoutSession" "WeeklyStats"; do
        echo "Checking $type..."
        grep -q "interface $type " entry/src/main/ets/common/services/*.ets && echo "  CODE: FOUND"
        grep -q "$type" FitTracker健身工具PRD.md && echo "  PRD: FOUND"
      done
    Expected: 每个类型在代码和 PRD 中均存在
    Evidence: .sisyphus/evidence/task-8-reference.md
  ```

  **Commit**: NO (批量提交在 Task 9)

- [x] 9. 整合、一致性审查、格式审查

  **What to do**: 
  1. 将 Tasks 3-8 的所有章节内容整合到 PRD 骨架中，移除所有 `<!-- TODO -->` 占位符
  2. 执行一致性检查：
     - 交叉引用检查（如用户故事引用的页面名是否在功能需求中出现）
     - 数据字典中的类型是否在功能需求中被引用
     - MoSCoW 表格中的功能是否在功能需求中有对应描述
  3. 格式规范化：
     - 统一标题层级（## 章节、### 子章节）
     - 统一表格格式
     - 确保所有代码术语使用反引号（如 `Index.ets`、`ColorTokens.PRIMARY`）
  4. 添加 PRD→代码映射表（第十一章）：表格列出 PRD 章节 → 对应代码文件
  5. 添加版本信息：`> 版本: 2.0 | 日期: YYYY-MM-DD | 基于代码库对齐重写`
  6. 在文档头部添加元信息注释（描述文档用途、适用范围、基准代码 commit）

  **Must NOT do**: 
  - 不要新增原计划外的大段内容
  - 不要删除 Tasks 3-8 产出的内容（仅做格式修正）
  - 不要修改 `.sisyphus/drafts/` 以外的文件路径引用

  **Recommended Agent Profile**:
  - Category: `deep` — Reason: 需要全局一致性审查和精确的交叉引用检查
  - Skills: [`writing-plans`] — Reason: 需要严格的文档质量标准
  - Omitted: [`test-driven-development`] — 无测试编写

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: Final Verification | Blocked By: Tasks 3-8

  **References**:
  - All previous task outputs (embedded in PRD file)
  - `AGENTS.md` — code map for cross-reference
  - `pages/AGENTS.md` — page features
  - `common/services/AGENTS.md` — service capabilities

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep "TODO: Section" FitTracker健身工具PRD.md` 输出为空（所有占位符已移除）
  - [ ] 文档包含版本信息行（`版本: 2.0`）
  - [ ] 文档包含完整的 PRD→代码映射表
  - [ ] `wc -l FitTracker健身工具PRD.md` 输出 ≥ 400（足够详细）

  **QA Scenarios**:
  ```
  Scenario: 无残留占位符
    Tool: Bash
    Steps: grep -c "TODO" FitTracker健身工具PRD.md
    Expected: 输出 0
    Evidence: .sisyphus/evidence/task-9-integration.md

  Scenario: 关键章节均存在
    Tool: Bash
    Steps: 
      for section in "文档概述" "产品概述" "用户画像" "用户故事" "功能需求" "数据字典" "交互流程" "非功能需求" "映射表"; do
        grep -q "$section" FitTracker健身工具PRD.md && echo "✓ $section" || echo "✗ MISSING: $section"
      done
    Expected: 全部 ✓
    Evidence: .sisyphus/evidence/task-9-integration.md
  ```

  **Commit**: YES | Message: `docs: rewrite FitTracker PRD v2.0 aligned with HarmonyOS codebase` | Files: [`FitTracker健身工具PRD.md`]

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.** Rejection or user feedback -> fix -> re-run -> present again -> wait for okay.

- [x] F1. Plan Compliance Audit — oracle
  - Verify: All tasks completed per spec; no scope creep; all Must Have deliverables present
- [x] F2. Code Quality Review — unspecified-high
  - Verify: PRD content accurately reflects codebase (spot-check 5 features against source files)
- [x] F3. Real Manual QA — unspecified-high
  - Verify: Document is self-consistent (cross-references valid, no broken links, all tables well-formed)
- [x] F4. Scope Fidelity Check — deep
  - Verify: No cloud/AI/social features in core chapters; all out-of-scope items in Future Iteration only

## Commit Strategy
- Tasks 1, 9: Individual commits
- Tasks 2: No commit (temp file)
- Tasks 3-8: No individual commits (batched in Task 9)
- Final: Single commit with the complete PRD

## Success Criteria
- [ ] Optimized PRD file exists and is ≥ 400 lines
- [ ] All functional descriptions match corresponding .ets files
- [ ] Zero references to unimplemented cloud/AI/social features in core chapters
- [ ] ≥ 6 user stories with Given-When-Then acceptance criteria
- [ ] Complete data dictionary with ≥ 5 type definitions
- [ ] PRD→code mapping table is complete
- [ ] DesignTokens references used for all UI values
- [ ] All Final Verification agents return APPROVE
