# FitTracker HarmonyOS 技术实现方案

## TL;DR
> **Summary**: 基于 HarmonyOS ArkTS/ArkUI 框架，分 3 阶段实现 FitTracker 健身工具的完整技术方案。覆盖技术架构设计、15 个模块的顺序实现、单元测试编写。
> **Effort**: XL (15 模块 × 3 阶段) | **Parallel**: Wave-based | **Critical Path**: DesignTokens → Services → Pages

## Context
### Requirements
- 平台：HarmonyOS API 10+，ArkTS 语言，ArkUI 声明式 UI
- 功能：5 套预置训练计划、45 个动作库、训练记录（1RM Epley）、周统计 + 日历热力图、Mock 认证
- 约束：本地优先（@ohos.data.preferences），无后端，无云同步，中文 UI
- 规范：rules.md（目录结构、命名约定、性能规则）、鸿蒙智能体默认规则（73 条 ArkTS 编译器约束）

### Technical Stack
- **语言**：ArkTS（TypeScript 超集，严格模式）
- **UI 框架**：ArkUI 声明式（@Component, @State, @Prop, @Link）
- **存储**：@ohos.data.preferences（fit_tracker_* 系列 store）
- **路由**：@ohos.router（pushUrl / replaceUrl / getParams）
- **构建**：hvigor + ohpm
- **测试**：@ohos/hypium（hamock 模拟）

## Architecture Design

### Layer Architecture
```
┌─────────────────────────────────────┐
│  Pages (9 @Entry structs)           │  ← UI Layer
│  Index | PlanDetail | ExerciseLib   │
│  ExerciseDetail | WorkoutRecorder   │
│  Stats | Register | Login | Profile │
├─────────────────────────────────────┤
│  Components (10 @Component structs) │  ← Reusable Widgets
│  AppButton | AppCard | AppInput     │
│  Chip | SegmentedControl | SearchBar│
│  StatBadge | EmptyState | PageHeader│
│  MainTabBar                         │
├─────────────────────────────────────┤
│  Services (6 singleton classes)     │  ← Business Logic
│  AuthService | TrainingPlanService  │
│  ExerciseService | WorkoutSessionSvc│
│  UserProfileService | SessionManager│
├─────────────────────────────────────┤
│  Styles                             │  ← Design System
│  DesignTokens.ets                   │
├─────────────────────────────────────┤
│  Utils                              │  ← Helpers
│  ValidationUtils.ets                │
├─────────────────────────────────────┤
│  @ohos.data.preferences             │  ← Persistence
│  fit_tracker_plans                  │
│  fit_tracker_sessions               │
│  fit_tracker_profile                │
└─────────────────────────────────────┘
```

### Data Flow
```
User Action → Page (@State) → Service (singleton) → Preferences (JSON)
                  ↑                                      |
                  └──────────── async return ────────────┘
```

### State Management Strategy
| Decorator | Use Case | Example |
|-----------|----------|---------|
| @State | Page-local state | `@State todayTraining: TrainingDay` |
| @Prop | Parent→Child one-way | `@Prop label: string` in AppButton |
| @Link | Parent↔Child two-way | `@Link isActive: boolean` |
| @Provide/@Consume | Cross-level | TabBar state |

### Router Graph
```
Index (Tab: 训练/动作库/统计/我的)
├── PlanDetailPage (计划详情 → 启用 → 返回 Index)
├── ExerciseLibraryPage (筛选肌群/器械 → 动作卡片)
│   └── ExerciseDetailPage (动作要领/参与肌群 Tab)
├── WorkoutRecorderPage (开始训练 → 计时 → 录入 → 保存)
├── StatsPage (周统计 + 日历热力图)
├── RegisterPage (注册 → 首页)
├── LoginPage (登录 → 首页)
└── ProfilePage (个人信息 → 退出登录)
```

## Implementation Sequence

### Phase 1: Foundation (基础设施)

#### M1. DesignTokens & Styles
**Files**: `entry/src/main/ets/common/styles/DesignTokens.ets`
**What**: 导出 ColorTokens/FontTokens/SpacingTokens/RadiusTokens/ShadowTokens
**QA**: 验证所有 token 值通过 `$r` 引用，支持暗黑/白色双主题
**ArkTS Rules**: 禁止硬编码色值/字号

#### M2. Utilities
**Files**: `entry/src/main/ets/common/utils/ValidationUtils.ets`
**What**: 手机号（11 位数字）、密码（≥6 位）验证函数
**QA**: 边界测试（空字符串、特殊字符、超长输入）

#### M3. Base Components (3)
**Files**:
- `entry/src/main/ets/components/AppButton.ets` — primary/secondary/ghost variants + loading
- `entry/src/main/ets/components/AppCard.ets` — 描边/填充卡片
- `entry/src/main/ets/components/AppInput.ets` — 表单输入框

**Pattern**: `@Component struct`, `@Prop` props, `DesignTokens` references
**QA**: 各 variant 渲染正确，loading 状态不阻塞 UI

### Phase 2: Business Logic (业务层)

#### M4. AuthService + SessionManager
**Files**:
- `entry/src/main/ets/common/services/AuthService.ets` — register/login, in-memory Map
- `entry/src/main/ets/common/services/SessionManager.ets` — token generate/validate

**Exports**: `interface AuthResult { success, message, token }`
**QA**: 注册→登录→token 验证流程；重复注册/错误密码边界

#### M5. ExerciseService
**File**: `entry/src/main/ets/common/services/ExerciseService.ets`
**Exports**: `interface Exercise`, `EXERCISES[]` (45 items), `getAll()`, `getById()`, `filterByMuscle()`, `filterByEquipment()`, `search()`, `getPage()`
**QA**: 45 个动作完整性验证；筛选/搜索/分页正确性

#### M6. TrainingPlanService
**File**: `entry/src/main/ets/common/services/TrainingPlanService.ets`
**Exports**: `interface ExerciseRef`, `TrainingDay`, `PresetPlan`, `UserPlan`, `mkExercise()`, `mkDay()`, `mkPlan()`, `PRESET_PLANS[]` (5), `getTodayTraining()`
**QA**: 5 套计划完整性；今日训练计算逻辑；休息日视图

#### M7. WorkoutSessionService
**File**: `entry/src/main/ets/common/services/WorkoutSessionService.ets`
**Exports**: `interface SavedSet`, `SavedExercise`, `WorkoutSession`, `WeeklyStats`, `ExerciseRecord`, `saveSession()`, `getWeeklyStats()`, `getAllExerciseRecords()`, `getTrainingDates()`
**QA**: 保存/加载会话；周统计 4 指标计算；个人纪录（1RM）更新

#### M8. UserProfileService
**File**: `entry/src/main/ets/common/services/UserProfileService.ets`
**Exports**: `interface UserProfile`, `saveProfile()`, `getProfile()`
**QA**: 个人资料持久化；头像占位

### Phase 3: Advanced Components (高级组件)

#### M9. Chip & SegmentedControl
**Files**: `components/Chip.ets`, `components/SegmentedControl.ets`
**Usage**: 肌群标签、Tab 切换
**QA**: 选中/未选中状态切换；多选支持

#### M10. SearchBar & StatBadge & EmptyState & PageHeader
**Files**: `components/SearchBar.ets`, `components/StatBadge.ets`, `components/EmptyState.ets`, `components/PageHeader.ets`
**QA**: 搜索防抖；统计卡片数字格式化；空状态渲染

### Phase 4: Pages (页面层 — 按依赖顺序)

#### M11. Auth Pages (3)
**Files**: `pages/RegisterPage.ets`, `pages/LoginPage.ets`, `pages/ProfilePage.ets`
**Dependencies**: M4 (AuthService), M8 (UserProfileService), M3 (AppButton/AppInput)
**QA**: 注册→登录→个人资料完整流程；表单验证；错误提示

#### M12. Index (Home)
**File**: `pages/Index.ets`
**Dependencies**: M6 (TrainingPlanService), M3, M9 (SegmentedControl)
**Features**: TabBar 导航、预置/我的计划列表、今日训练视图、休息日视图
**QA**: 计划启用/切换/删除；Tab 切换；今日训练加载

#### M13. Plan Pages
**File**: `pages/PlanDetailPage.ets`
**Dependencies**: M6 (TrainingPlanService)
**QA**: 计划详情时间线渲染；启用计划流程

#### M14. Exercise Pages (2)
**Files**: `pages/ExerciseLibraryPage.ets`, `pages/ExerciseDetailPage.ets`
**Dependencies**: M5 (ExerciseService), M7 (WorkoutSessionService), M9, M10
**QA**: 筛选/搜索/分页；详情 Tab 切换；1RM 个人纪录展示

#### M15. Workout & Stats Pages (2)
**Files**: `pages/WorkoutRecorderPage.ets`, `pages/StatsPage.ets`
**Dependencies**: M7 (WorkoutSessionService), M5 (ExerciseService), M3, M10
**QA**: 计时器精度；手风琴折叠；1RM 实时计算（Epley 公式验证）；训练保存摘要；热力图 5 档色阶；周统计 4 指标；月份切换

### Phase 5: Unit Testing

#### T1. Service Tests
**Framework**: `@ohos/hypium` + `hamock`
**Files**: `entry/src/ohosTest/ets/test/`
**Test Cases**:
- `AuthService.test.ets`: register (success/duplicate), login (success/wrong password/unregistered), token validation
- `ExerciseService.test.ets`: getAll (45 items), getById, filterByMuscle, search, getPage
- `TrainingPlanService.test.ets`: PRESET_PLANS count (5), getTodayTraining, plan enable/clone
- `WorkoutSessionService.test.ets`: saveSession, getWeeklyStats, getTrainingDates, getAllExerciseRecords
- `ValidationUtils.test.ets`: phone validation (valid/invalid/empty), password validation

#### T2. Component Tests
**Files**: `entry/src/ohosTest/ets/test/`
- `AppButton.test.ets`: render variants, loading state
- `AppCard.test.ets`: outlined/filled variants

#### T3. Integration Tests (Manual QA)
**Checklist**: `features.json` (已存在)
**Flows**: 注册→登录→启用计划→开始训练→录入组数→保存→查看统计→查看动作详情→查看1RM

## ArkTS Compiler Constraints Compliance
> 从 `鸿蒙智能体默认规则（官方）.md` 提取，实施阶段必须遵守

| # | 规则 | 影响 |
|---|------|------|
| 1 | 禁止 `any`/`unknown` | 所有类型显式声明 |
| 2 | 禁止 `as const` | 用工厂函数（`mkExercise`/`mkDay`/`mkPlan`）替代 |
| 3 | 禁止索引访问 `obj["field"]` | 用 `obj.field` 点语法 |
| 4 | 禁止解构赋值/声明 | 用临时变量逐字段取值 |
| 5 | 禁止展开运算符（数组除外） | 手动解包 |
| 6 | 禁止 `for..in` | 用 `for..of` 或普通 `for` |
| 7 | 禁止函数表达式 | 用箭头函数 |
| 8 | 禁止 `Function.apply/bind/call` | 遵循传统 OOP 风格 |
| 9 | 禁止交叉类型 | 用继承替代 |
| 10 | 禁止映射类型 | 用常规 class |
| 11 | 禁止索引签名 | 用数组 |
| 12 | `import` 必须在文件最顶部 | 无 import 前语句 |
| 13 | 对象字面量需对应显式接口/class | 用工厂函数返回显式类型 |

## Success Metrics
- [ ] 全部 15 个模块通过 LSP 零错误检测
- [ ] 全部 9 个页面可启动并渲染
- [ ] 5 套预置计划在 Index.ets 正确展示
- [ ] 45 个动作在 ExerciseLibraryPage.ets 可按肌群/器械筛选
- [ ] 1RM Epley 公式计算结果精确（`Math.round(weight × (1 + reps / 30))`）
- [ ] 周统计 4 指标与训练数据一致
- [ ] 热力图 5 档色阶与训练日期匹配
- [ ] 注册→登录→训练→统计→退出完整流程可走通
- [ ] 所有 service 单元测试通过
- [ ] 零 ArkTS 编译器违规
