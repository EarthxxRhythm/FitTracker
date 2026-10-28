# 菲特 规范注册表

> **层级**：L1 权威
> **最后核对**：2026-10-27
> **上位文档**：无，本文是索引
> **状态**：现行
> **路径基准**：表中路径均相对仓库根
> **适用端**：双端

## 怎么用这份表

- **要遵守什么** → 按「层级」看：L1 冲突时以此为准，L2 是 L1 的展开，L3 只作参考不作实现依据
- **改哪一端要看哪份** → 按「适用端」过滤（`双端` / `仅鸿蒙` / `仅安卓`）
- **哪些内容可能已失真** → 「会漂移」标 `是` 的，引用前必须回代码复核
- **谁在自动拦** → 「自动检查」列写明由哪个脚本负责

## 表格解析约定

`check-specs.mjs` 按固定列顺序解析本表，**列名与顺序不得改动**：

`| 层级 | 路径 | 管辖 | 适用端 | 状态 | 会漂移 | 自动检查 |`

「自动检查」列的取值决定校验强度：

- `check-specs（头部）` → 校验文件存在 **且** H1 后有 6 行统一头部
- `check-specs（仅存在）` → 只校验文件存在（参考类文档不强制头部）
- `check-code-rules` / `check-parity` → 由对应脚本承担，本表只登记

## 注册表

| 层级 | 路径 | 管辖 | 适用端 | 状态 | 会漂移 | 自动检查 |
|---|---|---|---|---|---|---|
| L1 | `AGENTS.md` | 工程约束总纲：代码边界、服务归属、ArkTS 约定、清理规则、构建命令、并行原则 | 双端 | 现行 | 是 | `check-specs`（头部） |
| L1 | `docs\process\vibe-coding-workflow.md` | 开发流程唯一权威：任务源、标准循环、验证分层、交接格式 | 双端 | 现行 | 是 | `check-specs`（头部） |
| L2 | `apps\harmony\entry\src\main\ets\common\services\AGENTS.md` | 应用级服务归属 + singleton / flush / Context 约定 | 仅鸿蒙 | 现行 | 否 | `check-specs`（头部） |
| L2 | `apps\harmony\entry\src\main\ets\shared\AGENTS.md` | 跨功能领域逻辑归属 + ANTI-PATTERNS | 仅鸿蒙 | 现行 | 否 | `check-specs`（头部） |
| L2 | `apps\harmony\entry\src\main\ets\components\AGENTS.md` | 通用组件约定 + AppButton 厚底规则 + 触控尺寸 | 仅鸿蒙 | 现行 | 否 | `check-specs`（头部） |
| L2 | `apps\harmony\entry\src\main\ets\features\workout\pages\AGENTS.md` | 训练页仅保留 2 页，禁建第二套主线 | 仅鸿蒙 | 现行 | 否 | `check-specs`（头部） |
| L2 | `apps\harmony\entry\src\main\ets\features\workout\services\AGENTS.md` | 训练编排归属 + ANTI-PATTERNS | 仅鸿蒙 | 现行 | 否 | `check-specs`（头部） |
| L2 | `docs\process\engineering-standards.md` | 鸿蒙代码细则：RT / SV / AR / DS 七条 rule id + 正反例 | 仅鸿蒙 | 现行 | 否 | `check-specs`（头部）+ `check-code-rules` |
| L2 | `docs\process\dual-platform-parity.md` | 双端对等清单、身份与字段对齐、改动时的同步要求 | 双端 | 现行 | 是 | `check-specs`（头部）+ `check-parity` |
| L2 | `docs\process\test-environments.md` | 鸿蒙 DevEco 模拟器 + 安卓 MuMu 模拟器的连法与取图 | 双端 | 现行 | 是 | `check-specs`（头部） |
| L2 | `docs\process\auth-verification.md` | 登录验证优先级：自部署栈 → 沙盒降级 → 显式跳过 | 双端 | 现行 | 是 | `check-specs`（头部） |
| L2 | `docs\process\agent-team-fittracker-overlay.md` | 多 agent 协作适配层 | 双端 | 现行 | 否 | `check-specs`（头部） |
| L2 | `docs\glossary.md` | 口径单一真源：事实口径表、术语标准词、口径分层规则、语言与文案口径 + GL 闸门 | 双端 | 现行 | 是 | `check-specs`（头部）+ `check-glossary` |
| L2 | `docs\cloud\supabase-sync-setup.md` | 自托管 Supabase 配置：快照表迁移、端侧字段映射、验证步骤 | 双端 | 现行 | 是 | `check-specs`（头部） |
| L2 | `apps\android\AGENTS.md` | 安卓端工程约束：端结构、Supabase 注入链路、与双端对等的关系 | 仅安卓 | 现行 | 否 | `check-specs`（头部） |
| L3 | `docs\process\harmonyos-default.md` | 官方 ArkTS 语法约束摘录 | 仅鸿蒙 | 现行 | 否 | `check-specs`（头部） |
| L3 | `docs\cloud\cloud-setup.md` | 历史 AGC 云服务配置手册（2026-10-28 后端改定为自托管 Supabase 后作废，仅作排错参考） | 仅鸿蒙 | 已被取代 | 是 | `check-specs`（仅存在） |
| L3 | `docs\release\release-build-runbook.md` | 发布工程面事实：构建/签名/证书、AGC 平台侧操作、bundleName 变更影响 | 双端 | 现行 | 是 | `check-specs`（仅存在） |
| L3 | `docs\process\pi-agent-parallel-restore.md` | pi 宿主多 agent 并行还原的安装与派工说明 | 双端 | 现行 | 是 | `check-specs`（仅存在） |
| L3 | `docs\process\qq-appid-landing-checklist.md` | QQ AppID / AppKey 落位清单（待人工提供凭据） | 双端 | 部分失效 | 是 | `check-specs`（仅存在） |
| L3 | `docs\process\regression-flow-status.md` | 认证链路回归覆盖现状（状态记录，非规范） | 仅鸿蒙 | 现行 | 是 | `check-specs`（仅存在） |
| L3 | `docs\process\thirdparty-qualification-guide.md` | 第三方登录资质申请操作手册（待人工执行） | 双端 | 部分失效 | 是 | `check-specs`（仅存在） |
| L3 | `docs\ui\ui-acceptance-checklist.md` | UI 验收口径 A/B/C/D 四维 | 双端 | 现行 | 否 | `check-specs`（仅存在） |
| L3 | `docs\ui\模拟器视觉回归说明.md` | 模拟器视觉回归的操作说明 | 双端 | 现行 | 是 | `check-specs`（仅存在） |
| L3 | `docs\ui\ui-acceptance-record-template.md` | 验收记录模板 | 双端 | 现行 | 否 | `check-specs`（仅存在） |
| L3 | `docs\ui\ui-design-review-packet.md` | 设计评审包模板 | 双端 | 现行 | 否 | `check-specs`（仅存在） |
| L3 | `docs\ui\ui-sample-spot-check.md` | 抽样检查说明 | 双端 | 现行 | 否 | `check-specs`（仅存在） |
| L3 | `docs\ui\midscene-regression-report-template.md` | Midscene 回归报告模板 | 双端 | 现行 | 否 | `check-specs`（仅存在） |

## 已删除的规范

| 路径 | 删除日期 | 去因 | 内容去向 |
|---|---|---|---|
| `docs\ui\设计系统代码规范文档.md` | 2026-10-27 | 2026-05-23 的 MVP 收口版，`features/onboarding/`、`GOAL_SETUP` 路由、`pages/HomePage` 三处锚点在当前代码中已不存在，却被 `docs\README.md` 与 `docs\prototype\ui-analysis-and-beautify-prompt.md` 当作现行规范引用 | 有效章节（ArkTS 严格模式、服务层、DesignTokens、文案、动作内容）并入 `docs\process\engineering-standards.md`；失效内容不迁移 |

## 不属于规范的索引文档

以下两份是导航而非规范，不参与层级裁定：

| 路径 | 作用 |
|---|---|
| `README.md` | 项目总览：功能、技术栈、质量门禁表、目录结构、文档导航 |
| `docs\README.md` | 文档入口：目录结构、当前实现依据、发布与合规索引 |
