# FitTracker Monetization Spec v1

更新时间：2026-06-08

## 1. 目标

本规格定义 FitTracker 的第一版商业化方案，目标是：

- 在不伤害核心留存的前提下建立收入结构
- 给后续正式发布、IAP 接入和云能力预留稳定边界
- 明确免费版、买断版、订阅版的功能分层
- 让产品、客户端、QA、发布工程在同一口径下推进

本规格当前只定义产品和工程边界，不直接引入真实支付实现。

## 2. 总体策略

FitTracker 采用三层商业化结构：

- `Free`
- `Pro Lifetime`
- `Plus Subscription`

策略原则固定为：

1. 不把基础训练主流程锁死
2. 先卖更强的本地工具能力
3. 后卖持续服务能力
4. 订阅只绑定持续产生成本的能力
5. 不把已经作为买断承诺的能力再挪进订阅

## 3. 版本定位

### Free

定位：完整可用的基础训练工具。

目标：

- 建立留存
- 建立训练记录习惯
- 让用户感受到本地优先和启动快的价值

### Pro Lifetime

定位：一次性买断的本地高级能力包。

目标：

- 完成第一笔付费转化
- 面向重视数据、效率和本地能力的核心用户

### Plus Subscription

定位：持续服务能力包。

目标：

- 承接云同步、远端内容更新和高级持续服务收入
- 只在相关服务能力成熟后上线

## 4. 功能分层

| 能力 | Free | Pro Lifetime | Plus Subscription |
| --- | --- | --- | --- |
| 目标设置 | Yes | Yes | Yes |
| 当前计划与基础训练流 | Yes | Yes | Yes |
| 训练记录与基础回顾 | Yes | Yes | Yes |
| 动作详情基础信息 | Yes | Yes | Yes |
| 本地备份与恢复 | Yes | Yes | Yes |
| 本地内容同步基础 | Yes | Yes | Yes |
| 历史训练保存上限 | Limited | Unlimited | Unlimited |
| 高级趋势分析 | No | Yes | Yes |
| 高级 PR 视图 | No | Yes | Yes |
| 更深的周/月统计 | No | Yes | Yes |
| 更多自定义计划 | No | Yes | Yes |
| 高级筛选、收藏、替代动作 | No | Yes | Yes |
| 高级目标调整建议 | Basic | Enhanced | Full |
| 云同步 | No | No | Yes |
| 多设备同步 | No | No | Yes |
| 远端内容持续更新 | No | No | Yes |
| 高级计划推荐 | No | No | Yes |
| 更完整媒体内容库 | No | No | Yes |

说明：

- `Limited` 表示可以保留核心体验，但保留数量或深度限制
- Free 必须保持“能完成完整训练循环”
- Pro 只承接本地高级能力
- Plus 只承接持续服务能力

## 5. 不收费的底座能力

以下能力固定保留在 Free：

- 开始训练
- 记录组数、重量、次数
- 基础回顾
- 基础动作详情
- 本地备份与恢复
- 本地内容可用性

原因：

- 这些能力构成 FitTracker 的可信度底座
- 如果过早设为付费墙，会直接伤害留存和口碑

## 6. 商品定义

### SKU A：`fittracker_pro_lifetime`

- 类型：非消耗型
- 层级：Pro Lifetime
- 目标：本地高级能力解锁
- 建议价格：`¥68 - ¥98`
- 首发期可考虑：`¥58 - ¥78`

### SKU B：`fittracker_plus_monthly`

- 类型：自动续费订阅
- 层级：Plus Subscription
- 目标：轻量订阅入口
- 建议价格：`¥15 - ¥22 / 月`

### SKU C：`fittracker_plus_yearly`

- 类型：自动续费订阅
- 层级：Plus Subscription
- 目标：主推订阅款
- 建议价格：`¥128 - ¥168 / 年`

定价规则：

- 年费主推
- 月费只做体验入口
- Pro 早期用户的永久权益不能缩水

## 7. 推荐付费触发点

### 7.1 回顾价值触发

触发时机：

- 第 5 次训练后
- 第 7 次训练后
- 第一次形成明显趋势和 PR 累积时

推荐指向：

- Pro Lifetime

核心卖点：

- 解锁长期趋势
- 解锁高级 PR 细节
- 解锁更完整训练分析

### 7.2 计划深度触发

触发时机：

- 用户开始创建多个自定义计划
- 用户需要同时维护多个目标路径

推荐指向：

- Pro Lifetime

核心卖点：

- 解锁更多计划
- 解锁更强调整能力

### 7.3 数据连续性触发

触发时机：

- 用户表现出明显的换机或多设备需求
- 用户频繁使用备份和恢复

推荐指向：

- Plus Subscription

核心卖点：

- 云同步
- 多设备连续使用

### 7.4 内容升级触发

触发时机：

- 用户高频查看动作详情
- 用户希望获得更完整媒体和持续更新内容

推荐指向：

- Plus Subscription

核心卖点：

- 持续内容更新
- 更丰富媒体内容

## 8. 当前最值得卖的价值

如果只定义第一笔付费商品，优先卖：

1. 无限历史
2. 高级趋势与 PR 分析
3. 更多计划与高级调整能力

原因：

- 不依赖云
- 与当前产品完成度匹配
- 工程接入成本较低
- 对核心训练用户的价值最直观

## 9. 工程落地边界

### 9.1 当前阶段就应预留

- entitlement 模型
- 商品 ID 常量
- 功能 gating 映射
- 设置页中的会员状态展示位
- 关键功能入口的能力判断接口

### 9.2 推荐 entitlement 结构

```ts
interface MonetizationEntitlement {
  tier: 'free' | 'pro' | 'plus'
  source: 'local_default' | 'iap_purchase' | 'restored_purchase'
  productId: string
  expiresAt: number
  updatedAt: number
}
```

### 9.3 推荐能力判断接口

```ts
canUseAdvancedInsights
canUseUnlimitedHistory
canUseAdvancedPlans
canUseCloudSync
canUsePremiumContent
```

### 9.4 当前明确不做

- 不接真实支付 SDK
- 不做购买流程 UI
- 不做购买恢复实现
- 不做服务端收据校验
- 不把云同步强行提前

## 10. 分阶段实施计划

### Phase A：商业化预留

目标：

- 完成功能分层和工程预留

范围：

- entitlement 模型
- gating 表
- 设置页预留位
- 商品 ID 常量

### Phase B：Pro 落地

目标：

- 支持一次性买断商品

范围：

- 非消耗型 IAP
- 本地权益缓存
- 恢复购买
- 基础权益展示

### Phase C：Plus 落地

目标：

- 上线持续服务型订阅

范围：

- 订阅商品
- 订阅状态同步
- 云同步与远端内容绑定

## 11. 风险与约束

主要风险：

- 免费版被削弱过度
- Pro 与 Plus 边界模糊
- 先上订阅，后补服务
- 正式发布链未打通就过早投入支付工程
- 后续挪动 Pro 权益导致用户预期受损

约束：

- 当前仓库仍以内部验收与 unsigned HAP 为主
- 正式 IAP 接入应放在签名发布能力稳定之后
- Plus 的上线必须依赖真实持续服务能力，而不是空订阅

## 12. 验收口径

商业化预留阶段的通过标准：

- 免费、Pro、Plus 的能力边界文档固定
- 商品 ID 与 entitlement 方案固定
- 功能 gating 不破坏当前 MVP 主流程
- 不混入真实支付实现

## 13. 当前结论

FitTracker 的第一版商业化不应采用纯广告模式，也不应一上来就纯订阅。

推荐结论固定为：

- 用 Free 建立留存
- 用 Pro 完成首笔转化
- 用 Plus 承接未来持续服务收入
