# 菲特 文档入口

## 目录结构

文档按主题分簇（2026-10 重组，此前 45 个文件平铺于 `docs/` 根）：

| 目录 | 内容 |
| --- | --- |
| `docs/release/` | 构建与发布：release runbook、上架截图清单、云调试自动化 |
| `docs/cloud/` | 云与数据：Supabase 后端配置（现行，`supabase-sync-setup.md`）、内容库 schema/同步、内容导入说明、动作视频库方案；另含历史 AGC 手册（已被取代，仅作排错参考） |
| `docs/ui/` | UI 与视觉验收：验收清单与记录模板、评审包、视觉回归说明 |
| `docs/prototype/` | 原型还原：1:1 还原规则、动效与发散还原工作流 |
| `docs/process/` | 工程流程与协作：工程约束总纲（`engineering-constraints.md`）、代码细则、双端对等、测试环境、登录验证 |
| `docs/closeout/` | 阶段收尾与治理：MVP/备份收尾、收尾审计、路线图、旧页面治理清单 |
| `docs/legal/` | 隐私政策与用户协议 |
| `docs/architecture/` | 系统图集：流程图 / 用例图 / 类图 / 序列图 |
| `docs/archive/` | 历史归档（只读，不作为实现依据） |

根级保留 4 份：本文件、`CHANGELOG.md`、`blockers.md`（活跃卡点登记）、`产品需求文档（PRD）.md`。

## 当前实现依据

- 当前页面注册唯一来源：`entry/src/main/resources/base/profile/main_pages.json`
- 当前代码路由唯一来源：`entry/src/main/ets/app/AppRoutes.ets`
- 当前工程约束：根目录 `AGENTS.md`
- 当前 UI 主线：`features/pencil/`、`features/welcome/`、`features/exercise/`、`features/workout/`

当前启动主线为（登录后直达主壳；原「训练目标」引导页已移除）：

`PencilSplashPage -> PencilLoginPage/PencilRegisterPage -> PencilAppShell`（未登录路径）；`PencilSplashPage -> PencilAppShell`（已登录路径）

应用壳内的主要内容由 `PencilHomePage`、`PencilPlanPage`、`PencilActivePage`、`WorkoutCompletePage`、`PencilReviewPage` 和 `PencilProfilePage` 承载；训练预览由 `PencilPreviewContent` 以壳内全模态呈现。云同步为恒定自动（无同步设置页）；退出登录入口位于设置页底部。

## 历史归档

`docs/archive/` 下的归档目录保存历史材料，只用于审计和历史追溯，不作为新的代码、路由或目录实现依据：

- `legacy-cleanup-2026-09/` —— 早期工作台账、开发日志与已完成的实现计划
- `workflow-consolidation-2026-10/` —— 收敛归档的重复流程文档（见该目录 README）

验收证据、构建记录和设备回归材料继续保留在原位置，除非明确要求，不移动或删除。

## 发布与合规

- `docs/release/release-build-runbook.md` —— 构建/发布工程面的真实状态、命令、缺口与接入点；第 9 节记录 bundleName 变更对本地数据沙箱的影响与迁移路径
- `docs/CHANGELOG.md` —— 版本说明与更新日志
- `docs/cloud/cloud-setup.md` —— **已被取代（历史）**：2026-10-28 后端改定为自托管 Supabase 后作废的 AGC 云服务配置手册（认证服务 / 云数据库 / 证书指纹；配置记录 + 排错速查），仅作排错参考
- `docs/legal/privacy-policy.md` —— 隐私政策（数据默认留在本机；登录后自动同步的数据范围、退出与清除）
- `docs/legal/user-agreement.md` —— 用户协议
- `docs/release/store-listing-screenshot-checklist.md` —— 应用市场上架截图清单（release 包实拍）
