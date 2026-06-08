# FitTracker Monetization Technical Design v1

更新时间：2026-06-08

## 1. 目标

这份文档承接 [monetization-spec-v1.md](./monetization-spec-v1.md)，把商业化方案推进到可开发的技术设计层。

本轮目标只包括：

- 定义 entitlement 数据模型
- 定义 gating 服务边界
- 定义商品目录、状态来源、持久化方案
- 明确首批接入点和测试预留口径

本轮明确不包括：

- 真实 IAP SDK 接入
- 购买流程 UI
- 恢复购买实现
- 服务端收据校验
- 订阅状态同步
- 云同步与订阅绑定实现

## 2. 设计原则

1. 免费主流程不被破坏
2. 本地默认可运行
3. 权益判断优先本地可读
4. 页面只读判权，不直接管理商业规则
5. gating 逻辑集中管理，不散落到页面条件分支里
6. 真实支付能力未来可平滑接入

## 3. 当前分层目标

当前技术设计围绕三层会员态：

- `free`
- `pro`
- `plus`

语义固定为：

- `free`：默认本地态
- `pro`：一次性买断权益
- `plus`：订阅权益

## 4. 推荐文件边界

建议后续实现全部落在 shared 层，不直接放到页面里。

### 4.1 模型层

- `entry/src/main/ets/shared/models/TrainingModels.ets`
  - 可扩展商业化相关 interface / factory

如果希望边界更清楚，也可以新增：

- `entry/src/main/ets/shared/models/MonetizationModels.ets`

### 4.2 服务层

建议新增：

- `entry/src/main/ets/shared/services/MonetizationCatalogService.ets`
- `entry/src/main/ets/shared/services/MonetizationEntitlementService.ets`
- `entry/src/main/ets/shared/services/MonetizationGateService.ets`

职责建议：

- `MonetizationCatalogService`
  - 管理逻辑 SKU、store product ID、tier 映射
- `MonetizationEntitlementService`
  - 读写本地 entitlement
  - 对齐当前登录用户
  - 归一过期或无效权益
- `MonetizationGateService`
  - 把 entitlement 解析成能力判断
  - 面向页面与业务服务暴露 typed gate API

## 5. 数据模型

### 5.1 核心 entitlement 快照

推荐主模型：

```ts
export interface MonetizationEntitlement {
  userId: string
  tier: 'free' | 'pro' | 'plus'
  source: 'local_default' | 'iap_purchase' | 'restored_purchase' | 'debug_override'
  status: 'active' | 'expired'
  skuKey: string
  productId: string
  grantedAt: number
  expiresAt: number
  updatedAt: number
  lastValidatedAt: number
  schemaVersion: number
}
```

字段语义：

- `userId`
  - 当前本地登录用户
  - 建议来源于 `SessionManager` 解析 token 后得到的 `userId`
- `tier`
  - 当前权益层级
- `source`
  - 权益来源
  - `local_default` 用于未购买默认态
  - `debug_override` 仅用于开发或测试注入
- `status`
  - 当前权益快照状态
- `skuKey`
  - 仓库内部稳定逻辑 SKU
- `productId`
  - 对应 store product ID
  - `free` 态可以为空字符串
- `grantedAt`
  - 首次赋权时间
- `expiresAt`
  - 非订阅权益可为 `0`
  - 订阅权益使用未来时间戳
- `updatedAt`
  - 最近一次本地状态刷新时间
- `lastValidatedAt`
  - 最近一次真实校验或恢复时间
- `schemaVersion`
  - entitlement 本地结构版本号

### 5.2 已解析访问态

不建议页面直接比较 `tier` 或自己拼装 capability，建议服务层输出已解析访问态。

```ts
export interface ResolvedAccessState {
  tier: 'free' | 'pro' | 'plus'
  canUseAdvancedInsights: boolean
  canUseUnlimitedHistory: boolean
  canUseAdvancedPlans: boolean
  canUseCloudSync: boolean
  canUsePremiumContent: boolean
  canUseEnhancedGoalAdjustment: boolean
  blockedReason: string
  evaluatedAt: number
}
```

说明：

- 不建议使用动态 `Record<string, boolean>` map
- 当前 ArkTS 约束下，更适合显式布尔字段和 typed `canUseXxx()` 接口

### 5.3 capability key

如果页面需要按能力请求 gate，建议保留固定 capability 列表：

```ts
export type MonetizationCapability =
  | 'advanced_insights'
  | 'unlimited_history'
  | 'advanced_plans'
  | 'cloud_sync'
  | 'premium_content'
  | 'enhanced_goal_adjustment'
```

### 5.4 gate 结果

```ts
export interface MonetizationGateResult {
  capability: MonetizationCapability
  allowed: boolean
  requiredTier: 'pro' | 'plus'
  activeTier: 'free' | 'pro' | 'plus'
  upgradeProductId: string
  reason: string
}
```

说明：

- `reason` 供页面决定提示文案
- `upgradeProductId` 用于未来接支付页时跳转

## 6. 商品目录设计

建议把商品目录独立出来，而不是散在 UI 文案里。

```ts
export interface MonetizationProduct {
  skuKey: string
  productId: string
  tier: 'pro' | 'plus'
  billingType: 'non_consumable' | 'subscription'
  isPrimaryOffer: boolean
}
```

首批固定逻辑 SKU：

- `pro_lifetime`
- `plus_monthly`
- `plus_yearly`

首批固定商品 ID：

- `fittracker_pro_lifetime`
- `fittracker_plus_monthly`
- `fittracker_plus_yearly`

建议把商品信息分三层处理：

1. `skuKey`
   - 仓库内部稳定逻辑键
2. `productId`
   - 未来接 AppGallery Connect 时使用的 store product ID
3. `billingEnvironment`
   - 当前环境标识

建议由 `MonetizationCatalogService` 暴露：

- `getProducts()`
- `getProduct(productId: string): MonetizationProduct | undefined`
- `getProductBySkuKey(skuKey: string): MonetizationProduct | undefined`
- `getPrimaryUpgradeForTier(tier)`
- `getDefaultUpgradeForCapability(capability)`

## 7. 持久化方案

### 7.1 store 建议

建议在 `FitTrackerStores` 增加：

- `MONETIZATION = 'fit_tracker_monetization'`

### 7.2 持久化格式

与现有 `SyncService`、`WorkoutSessionService`、`UserProfileService` 风格保持一致，使用 preferences + JSON。

推荐：

- store：`fit_tracker_entitlement`
- key：`user_entitlements`
- value：`MonetizationEntitlement[]`

查找方式：

1. 通过 `SessionManager` 解析当前 `userId`
2. 在本地 entitlement 数组中线性匹配当前用户

理由：

- 与当前项目“单例服务 + 独立 preferences store + 页面拉状态”的风格一致
- 不需要动态拼接复杂 key
- 易于 ohosTest 注入和持久化模拟
- 未来接 IAP 只需刷新 entitlement，不必改页面层逻辑

### 7.3 默认态

首次无本地记录时返回：

```ts
{
  userId: '',
  tier: 'free',
  source: 'local_default',
  status: 'active',
  skuKey: '',
  productId: '',
  grantedAt: 0,
  expiresAt: 0,
  updatedAt: 0,
  lastValidatedAt: 0,
  schemaVersion: 1
}
```

## 8. 服务接口建议

### 8.1 MonetizationEntitlementService

```ts
readEntitlement(context): Promise<MonetizationEntitlement>
writeEntitlement(context, entitlement): Promise<void>
resolveCurrentUserEntitlement(context): Promise<MonetizationEntitlement>
getActiveTier(context): Promise<'free' | 'pro' | 'plus'>
isSubscriptionActive(context): Promise<boolean>
clearEntitlementForTesting(context): Promise<void>
setEntitlementForTesting(entitlement): void
```

关键行为：

- 默认态自动回落为 `free + local_default`
- 过期订阅在读取时归一为 `free`
- 页面永远不直接碰 preferences

### 8.2 MonetizationGateService

```ts
getGateResult(context, capability): Promise<MonetizationGateResult>
canUse(context, capability): Promise<boolean>
resolveAccessState(context): Promise<ResolvedAccessState>
```

实现原则：

- 所有 tier 到 capability 的映射集中放在 service 内部
- 页面不持有业务规则表

### 8.3 MonetizationCatalogService

```ts
getProducts(): MonetizationProduct[]
getProduct(productId: string): MonetizationProduct | undefined
getProductBySkuKey(skuKey: string): MonetizationProduct | undefined
getUpgradeProductForCapability(capability): string
getBillingEnvironment(): 'disabled' | 'mock' | 'sandbox' | 'production'
```

## 9. 首批接入点

当前不做全应用铺开，只建议在最有付费意义的点先预留 gate。

### 9.1 ReviewHomePage

文件：

- `entry/src/main/ets/features/review/pages/ReviewHomePage.ets`
- `entry/src/main/ets/shared/services/ReviewInsightsService.ets`

建议先对这些能力预留 gate：

- 高级趋势分析
- 深度 PR 详情
- 更长历史范围

原因：

- 这里最接近“用户已经看到价值并愿意升级”的时刻

### 9.2 GoalAdjustmentPreviewService

文件：

- `entry/src/main/ets/shared/services/GoalAdjustmentPreviewService.ets`

建议预留：

- `enhanced_goal_adjustment`

原因：

- 适合作为 Pro 的高级智能建议能力入口

### 9.3 训练计划相关能力

文件：

- `entry/src/main/ets/common/services/TrainingPlanService.ets`
- `entry/src/main/ets/features/workout/pages/TrainingPlanDetailPage.ets`

建议预留：

- 更多自定义计划
- 高级计划能力

### 9.4 动作详情与内容能力

文件：

- `entry/src/main/ets/features/exercise/pages/ExerciseDetailPage.ets`
- `entry/src/main/ets/shared/services/ContentRepository.ets`
- `entry/src/main/ets/shared/services/SyncService.ets`

建议预留：

- premium content
- 更完整媒体内容

### 9.5 未来设置 / 会员状态入口

当前主仓库只有旧 `ProfilePage.ets` 历史壳，不适合作为正式承载页。

因此建议：

- 本轮只定义未来“会员状态入口页”需要的数据契约
- 暂不把展示逻辑接回旧 `ProfilePage`

### 9.6 免费底座保护名单

以下入口与能力在 future gating 落地后也必须保持 free 可用：

- `Startup`
- `Login`
- `Register`
- `GoalSetup`
- `Home`
- `WorkoutPreview`
- `ActiveWorkout`
- `WorkoutSummary`
- 基础 `Review`
- 基础 `ExerciseDetail`
- 本地备份恢复
- 本地内容可用性

### 9.7 不建议本轮接入的地方

- `ActiveWorkoutPage`
- `WorkoutPreviewPage`
- 启动路由
- 备份恢复链路

原因：

- 容易伤害主流程
- 与商业化价值不直接对应

## 10. 页面使用方式建议

页面不要直接：

- 比较 `tier === 'pro'`
- 手写商品 ID
- 在 UI 中硬编码 upgrade 逻辑

页面只应消费：

- `canUseXxx`
- `MonetizationGateResult`
- `ResolvedAccessState`

推荐模式：

1. 页面请求 gate result 或 access state
2. 若 `allowed=true`，显示完整能力
3. 若 `allowed=false`，显示轻量升级卡或降级态

## 11. 测试设计

### 11.1 单元 / ohosTest 预留

优先为以下两类服务补测试：

- `MonetizationEntitlementService`
- `MonetizationGateService`

建议覆盖：

1. 无 entitlement 返回 `free + local_default`
2. `pro` 对高级回顾能力开放
3. `plus` 对云能力开放
4. 过期订阅回退 `free`
5. 无效 productId 不提升权限
6. debug/testing override 只在测试注入下生效
7. 免费底座能力在 `free` 下永远可用

### 11.2 页面层未来最小覆盖

建议首批页面验证：

- `ReviewHomePage`
  - 免费态显示受限入口
  - Pro 态显示完整洞察
- 未来会员状态页
  - entitlement 状态正确展示

还应预留集成测试基线：

- 启动分流不因 entitlement 预留而改变
- `Home -> Preview -> Active -> Summary -> Review` 的免费主链不断裂
- Review 页高级模块只能降级或提示，不能导致空白页
- 动作详情基础信息始终可见，媒体内容可按层级降级

### 11.3 focused smoke 未来入口

等页面真正接入后，再考虑 focused smoke：

- `review-premium-gate`
- `membership-status`
- 继续保留 `current-plan` 作为免费主链控制组
- 继续保留 `media-card` 作为 premium content 入口烟测
- 继续保留 `backup-card` 作为免费底座控制组

当前文档阶段不需要新增 smoke。

## 12. 与发布工程的关系

当前仓库仍以 unsigned HAP 和 readiness 为主。

因此商业化预留层要满足：

- 现在就能定义逻辑 SKU、商品目录和本地 entitlement 结构
- 但不能假装 IAP 已可用

与发布工程的关系如下：

- `monetization spec / technical design`：现在就可以落文档
- `catalog constants / entitlement model / mock gating`：现在可以预留
- `真实 IAP 接入`：必须等签名发布链路稳定后再做

当前 billing 环境建议只定义两种可运行态：

- `disabled`
- `mock`

`sandbox` / `production` 只留接口名和文档位置，不进入本轮实现。

未来会受影响的文档与脚本：

- `docs/release-build-runbook.md`
- `tools/check-release-readiness.mjs`
- 未来如新增 IAP sandbox 验收，再追加专门脚本

## 13. 实施顺序

推荐顺序固定为：

### Phase A：技术预留

- 文档落地
- entitlement 模型
- catalog 常量
- gate service

### Phase B：只读接入

- Review 页和未来会员状态入口开始消费 gate result
- 不接真实支付

### Phase C：IAP 接入

- 非消耗型 Pro
- 恢复购买
- 本地 entitlement 刷新

### Phase D：订阅接入

- Plus 月费 / 年费
- 订阅状态同步
- 云能力绑定

## 14. 本轮通过标准

本轮属于文档设计阶段，通过标准为：

- entitlement 数据模型固定
- gate 服务边界固定
- 逻辑 SKU 与 capability 映射方向固定
- 首批接入点固定
- 免费底座保护名单固定
- 没有混入真实支付实现

## 15. 当前结论

FitTracker 的商业化工程起手不应该从“支付流程”开始，而应该从“权益模型和能力门控”开始。

一句话总结：

**先把 entitlement 和 gating 做成稳定底座，再接 Pro，再接 Plus。**
