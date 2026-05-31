# FitTracker — Project Knowledge Base

**Generated:** 2026-04-29 | **Commit:** b702f45 | **Branch:** master

## OVERVIEW

HarmonyOS ArkUI fitness training tracker. Records workouts (sets/reps/weight), computes 1RM (Epley formula), persists sessions to local preferences, shows weekly stats + calendar heatmap + personal records. Local-only, no backend. Chinese (zh-CN) UI.

**Stack:** HarmonyOS Stage Mode · ArkTS/ArkUI · @ohos.data.preferences · @kit.ArkData

## STRUCTURE

```
entry/src/main/ets/
├── common/
│   ├── services/     # Singleton services: Auth, TrainingPlan, WorkoutSession, Exercise, etc.
│   ├── styles/       # DesignTokens.ets (colors, fonts, spacing, radii, shadows)
│   └── utils/        # ValidationUtils.ets (phone/password validators)
├── components/       # Reusable @Component widgets: AppButton, AppCard, AppInput, etc.
├── pages/            # Auth entry pages, HomePage, and legacy shells kept out of the main route
├── app/              # Startup routing and app-level route helpers
├── features/         # Current product pages for onboarding, workout, review, exercise
├── entryability/     # EntryAbility.ets — app lifecycle entry
└── entrybackupability/ # EntryBackupAbility.ets — backup extension
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add a main-line page | `app/` or `features/` + `main_pages.json` | Register in `resources/base/profile/main_pages.json` |
| Add a legacy page shell | `pages/` | Keep out of the main route unless explicitly required |
| Add a service | `common/services/` | Follow singleton + preferences pattern |
| Add a reusable UI component | `components/` | @Component, @Prop-based props |
| Change colors/spacing | `common/styles/DesignTokens.ets` | All visual properties defined here; NEVER hardcode |
| Add a training plan | `common/services/TrainingPlanService.ets` | PRESET_PLANS array |
| Session persistence | `common/services/WorkoutSessionService.ets` | Store: `fit_tracker_sessions`, key: `sessions` |
| Router navigation | `main_pages.json` | 9 registered pages; use `router.pushUrl({ url: 'pages/X' })` |

## CODE MAP

| Symbol | Type | Location | Refs | Role |
|--------|------|----------|------|------|
| `StartupPage` | @Entry struct | `app/StartupPage.ets` | — | Cold-start route gate: login vs home |
| `LoginPage` | @Entry struct | `pages/LoginPage.ets` | — | Local login entry |
| `RegisterPage` | @Entry struct | `pages/RegisterPage.ets` | — | Local registration entry |
| `HomePage` | @Entry struct | `pages/HomePage.ets` | — | Today's training entry + plan summary |
| `GoalSetupPage` | @Entry struct | `features/onboarding/pages/GoalSetupPage.ets` | — | Save goal and generate plan |
| `WorkoutPreviewPage` | @Entry struct | `features/workout/pages/WorkoutPreviewPage.ets` | — | Preview plan before training |
| `ActiveWorkoutPage` | @Entry struct | `features/workout/pages/ActiveWorkoutPage.ets` | — | Live training execution and 1RM input |
| `WorkoutSummaryPage` | @Entry struct | `features/workout/pages/WorkoutSummaryPage.ets` | — | Workout recap and transition to review |
| `ReviewHomePage` | @Entry struct | `features/review/pages/ReviewHomePage.ets` | — | History, trends, and goal adjustment |
| `ExerciseDetailPage` | @Entry struct | `features/exercise/pages/ExerciseDetailPage.ets` | — | Exercise info + personal records |
| `TrainingPlanService` | singleton class | `common/services/TrainingPlanService.ets` | all pages | 5 preset plans, plan CRUD |
| `WorkoutSessionService` | singleton class | `common/services/WorkoutSessionService.ets` | 3 pages | Session save/load, weekly stats, records |
| `AuthService` | singleton class | `common/services/AuthService.ets` | 2 pages | Mock auth (in-memory) |
| `ColorTokens` | static class | `common/styles/DesignTokens.ets` | all UI files | Design tokens: PRIMARY=#00C853, etc. |
| `AppButton` | @Component | `components/AppButton.ets` | all pages | Primary/secondary/ghost button with loading |

## LEGACY PAGES

The following page shells stay in `pages/` only as historical material and must not be reintroduced into `main_pages.json`:

- `Index.ets`
- `PlanDetailPage.ets`
- `ExerciseLibraryPage.ets`
- `ProfilePage.ets`
- `StatsPage.ets`
- `WorkoutRecorderPage.ets`
- `RudderStyleTab.ets`

## CONVENTIONS

- **Singleton services**: `export default new ClassName()` — instantiated at module level. NEVER use `new` at call site.
- **Preferences**: `preferences.getPreferences(context, STORE_NAME)` from `@kit.ArkData`, then `.put()` + `.flush()`. Store names use `fit_tracker_` prefix.
- **Context**: Passed via `getContext(this)` in @Component structs. Async methods take `context: Context`.
- **Router params**: `router.getParams() as Record<string, T>`. Always wrapped in try-catch.
- **Design tokens**: ALL visual values from `DesignTokens.ets`. NO hardcoded colors, fonts, spacing, or radii in components.
- **Page structure**: `@Entry @Component struct XxxPage { @State ...; async aboutToAppear() { ... }; build() { Column() { ... } } }`
- **Chinese UI**: All user-facing strings in Chinese. Placeholders, labels, button text.
- **JSDoc header**: Each file starts with `/** Name —— description */` + feature number references (e.g., `功能 #26`).

## ANTI-PATTERNS (THIS PROJECT)

- **DO NOT** use `new` to instantiate services — use the default-exported singleton instance.
- **DO NOT** hardcode colors/fonts/spacing — always use `ColorTokens.*`, `FontTokens.*`, `SpacingTokens.*`.
- **DO NOT** modify `AppButton` primary background color or add shadows to ghost variants.
- **DO NOT** use `@ts-ignore` or `as any`.
- **DO NOT** create `node_modules` inside `entry/src/main/ets/`.

## COMMANDS

```bash
# Build (requires DevEco Studio)
hvigorw assembleHap --mode module -p product=default

# OpenSpec workflow
openspec list                    # List active changes
openspec status --change <name>  # Check change status
openspec instructions apply --change <name>  # Get implementation tasks
```

## NOTES

- **Mock auth**: `AuthService` stores users in memory (`Map<string, string>`). No real backend.
- **No tests**: `ohosTest` module exists (hamock + hypium) but no test files written.
- **Preferences keys**: `fit_tracker_plans` (my_plans, current_plan_id), `fit_tracker_sessions` (sessions).
- **1RM formula**: Epley: `weight * (1 + reps / 30)` — consistent across app.
- **Calendar heatmap**: 5-level green scale based on `trainingDates` set in StatsPage.

## ARKTS STRICT MODE RULES (HarmonyOS Compiler Constraints)

以下 ArkTS 语法约束违反将直接导致**编译失败**。编写或修改任何 `.ets` 文件时必须遵守。

### 类型系统

| 规则 | 说明 | 本项目常见场景 |
|------|------|---------------|
| `arkts-no-as-const` | 禁止 `as const` 断言 | 用显式类型标注 + 接口替代 |
| `arkts-no-any-unknown` | 禁止 `any` / `unknown` 类型 | 始终显式声明类型 |
| `arkts-no-untyped-obj-literals` | 对象字面量必须对应显式 class/interface | 用**工厂函数**返回显式类型，或先声明类型变量 |
| `arkts-no-noninferrable-arr-literals` | 数组元素必须可推断类型 | 给数组加类型标注 `: Type[]`，或使用工厂函数 |
| `arkts-identifiers-as-prop-names` | 属性名必须是合法标识符 | **禁止中文/连字符作为 key** → 改用函数映射 |
| `arkts-no-props-by-index` | 禁止 `obj["field"]` 索引访问 | 改用 `obj.field` 点语法；动态字段用 if/else |
| 结构化类型 | 不支持比较两种类型的公共 API | 用继承、接口或类型别名 |

### 语法特性

| 规则 | 说明 | 替代方案 |
|------|------|---------|
| 逗号运算符 | 仅 `for` 循环内允许 | 拆分为独立语句 |
| `for..in` | 禁止遍历对象属性 | 用 `for..of` / 常规 `for` 循环 |
| 解构赋值/声明 | 不支持 | 用临时变量逐字段取值 |
| 展开运算符 `...` | 仅支持数组展开到 rest 参数 | 手动解包 |
| 函数表达式 | 不支持 | 改用箭头函数 |
| 嵌套函数 | 不支持 | 改用箭头函数/lambda |
| `in` 运算符 | 不支持 | 用 `instanceof` |
| `typeof` 类型标注 | 不支持 | 用显式类型声明 |
| `Function.apply/bind/call` | 不支持 | 遵循传统 OOP 风格，不操作 `this` |

### 模块与导入

| 规则 | 说明 |
|------|------|
| 所有 `import` 必须在文件最顶部 | import 之前不能有其他语句 |
| 不支持 `require` / `export =` | 用标准 `import` / `export` |
| 不支持全局作用域 / `globalThis` | 用显式模块导入导出 |
| 不支持命名空间用作对象 | 用 class 或 module |

### 类与接口

| 规则 | 说明 |
|------|------|
| 构造函数中不声明字段 | 在类声明内部声明 |
| 不支持类用作对象 | 类声明引入的是类型，不是值 |
| 不支持声明合并 | 每个 class/interface/enum 定义必须紧凑 |
| 不支持交叉类型 | 用继承替代 |
| 不支持映射类型 | 用常规 class 实现 |
| `Partial/Required/Readonly/Record` 可用 | 其他 TypeScript 工具类型不支持 |
| 不支持索引签名 | 改用数组 |

### HarmonyOS API 使用规范

- **优先使用官方 API/UI 组件/动画**，不自行构造 API
- API 调用前确认：入参/返回值、API Level、设备支持情况
- 确认是否需要 `import` 语句和对应权限（`module.json5`）
- `@Component` / `@ComponentV2` 区分兼容性，与已有工程保持一致
- UI 常量使用 resources 资源值 + `$r` 引用，避免字面值
- 国际化资源在每种语言下添加值，避免遗漏
- 颜色资源需支持暗黑/白色双主题

### ArkUI 动画规范

- 优先使用 `animateTo`、`transform`、声明式 `@State` 驱动
- 复杂子组件设置 `renderGroup(true)` 减少渲染批次
- 动画过程中**禁止频繁改 `width/height/padding/margin`**，严重影响性能

### 本项目已修复的错误模式（参考）

修复方式 → 工厂函数（`mkExercise`/`mkDay`/`mkPlan`）、函数映射（`getMuscleColor`）、显式类型变量
