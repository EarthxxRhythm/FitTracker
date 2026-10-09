# FitTracker 文档入口

## 目录结构

文档按主题分簇（2026-10 重组，此前 45 个文件平铺于 `docs/` 根）：

| 目录 | 内容 |
| --- | --- |
| `docs/release/` | 构建与发布：release runbook、上架截图清单、云调试自动化 |
| `docs/cloud/` | 云与数据：AGC 配置手册、内容库 schema/同步、内容导入说明、动作视频库方案 |
| `docs/ui/` | UI 与视觉验收：验收清单与记录模板、评审包、视觉回归说明、设计系统规范 |
| `docs/prototype/` | 原型还原：1:1 还原规则、动效与发散还原工作流、ArkUI 迁移提示词 |
| `docs/process/` | 工程流程与协作：多代理信箱协议、任务队列、开发循环、平台规则 |
| `docs/closeout/` | 阶段收尾与治理：MVP/备份收尾、收尾审计、路线图、旧页面治理清单 |
| `docs/legal/` | 隐私政策与用户协议 |
| `docs/archive/` | 历史归档（只读，不作为实现依据） |

根级保留 4 份：本文件、`CHANGELOG.md`、`blockers.md`（活跃卡点登记）、`产品需求文档（PRD）.md`。

## 当前实现依据

- 当前页面注册唯一来源：`entry/src/main/resources/base/profile/main_pages.json`
- 当前代码路由唯一来源：`entry/src/main/ets/app/AppRoutes.ets`
- 当前工程约束：根目录 `AGENTS.md`
- 当前 UI 主线：`features/pencil/`、`features/welcome/`、`features/account/`、`features/exercise/`、`features/workout/`

当前启动主线为（登录后直达主壳；原「训练目标」引导页已移除）：

`PencilSplashPage -> PencilLoginPage/PencilRegisterPage -> PencilAppShell`（未登录路径）；`PencilSplashPage -> PencilAppShell`（已登录路径）

应用壳内的主要内容由 `PencilHomePage`、`PencilPlanPage`、`PencilActivePage`、`WorkoutCompletePage`、`PencilReviewPage` 和 `PencilProfilePage` 承载；训练预览由 `PencilPreviewContent` 以壳内全模态呈现；账号与同步为 `AccountSyncPage`。

## 历史归档

`docs/archive/` 下的归档目录（当前为 `legacy-cleanup-2026-09/`）保存早期工作台账、开发日志与已完成的实现计划等历史材料。归档文件只用于审计和历史追溯，不作为新的代码、路由或目录实现依据。

验收证据、构建记录和设备回归材料继续保留在原位置，除非明确要求，不移动或删除。

## 迁移提示词

把 Open Design HTML 原型迁移为 ArkUI 页面（完整 UI/UX 还原）时使用的提示词，拆为两份配合使用：

- `docs\prototype\prototype-to-arkui-prompt-template.md` —— 通用方法论模板，跨项目复用，方括号处按项目替换
- `docs\prototype\prototype-to-arkui-prompt-fittracker.md` —— FitTracker 专属附录：八项规格源落点、15 屏清单与 ArkUI 落点、可执行命令、已踩过的坑、验收口径

用法：先读附录第 1 节确认规格源，再把模板正文的方括号填成附录里的实际路径。

## 发布与合规

- `docs/release/release-build-runbook.md` —— 构建/发布工程面的真实状态、命令、缺口与接入点；第 9 节记录 bundleName 变更对本地数据沙箱的影响与迁移路径
- `docs/CHANGELOG.md` —— 版本说明与更新日志
- `docs/cloud/cloud-setup.md` —— AGC 云服务配置手册（认证服务 / 云数据库 / 证书指纹；配置记录 + 排错速查）
- `docs/legal/privacy-policy.md` —— 隐私政策（本地优先；登录后可选的云同步数据范围、退出与清除）
- `docs/legal/user-agreement.md` —— 用户协议
- `docs/release/store-listing-screenshot-checklist.md` —— 应用市场上架截图清单（release 包实拍）
