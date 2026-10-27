# 贡献与协作

> **层级**：L2 展开
> **最后核对**：2026-10-27
> **上位文档**：`AGENTS.md`（仓库根，L1）——冲突以 L1 为准
> **状态**：现行
> **路径基准**：文中 `tools\…` 除注明外相对 `apps\harmony\`；`docs\…`、`apps\…` 相对仓库根
> **适用端**：双端

## 提交信息格式

```
<type>(<scope>): <中文摘要，说清做了什么 / 为什么>
```

**type**：`feat` | `fix` | `refactor` | `docs` | `test` | `chore` | `perf`

**scope**：`harmony` | `android` | `docs` | `tools`。新增 scope 需先在本文登记，避免同一区域出现多种写法。

摘要用中文描述结果，不写「update」「fix bug」这类无信息量内容。

**实测样例**（取自本仓库历史，全部符合）：

- `fix(harmony): 训练页按计划动作与总组数推进，不再做完一个动作就结束`
- `feat(harmony): 动作演示媒体统一渲染壳（加载占位 + 淡入 + 失败回退）`
- `chore(harmony): 清理 27 个死图标资产`

## 提交前门槛

按顺序，任一红即停：

1. 在 `apps\harmony` 下运行 `apps\harmony\tools\check-gates.mjs`——7 步：内容构建 / 页面注册 / 空白检查 / 文档死链 / **规范注册表** / **双端对等** / **代码规则**，最后接真实 ArkTS 编译
2. 改了 `.ets` 至少有构建通过；改了页面必须过 `check-main-pages`
3. 改了导出符号或服务签名，grep 全部消费方确认同步

新增的三道闸各自管什么：

| 闸 | 脚本 | 拦什么 |
|---|---|---|
| 规范注册表 | `check-specs.mjs` | 文件被删/路径被改/头部字段漏填/注册表与文件状态不一致/日期写未来 |
| 双端对等 | `check-parity.mjs` | 鸿蒙注册页漏登记、安卓屏目录漏登记、`applicationId` ≠ `bundleName`、豁免缺理由或复核方式 |
| 代码规则 | `check-code-rules.mjs` | RT-01/02 路由、SV-01 单例、AR-01/02/03 分层、DS-01 内联色值 |

## 双端同步

**任何用户可见行为改动，两端都要落。** 只做一端的，提交信息必须写「仅 \<端\>」并说明原因。

细则见 `docs\process\dual-platform-parity.md`，其中三条硬要求：

- 新增字段：追四条链（写入 → 持久化 → 备份包 → 同步白名单 hash 视图），另一端同步
- 新增屏：两端同时建，或在对应清单里登记为「单端独有」并给理由
- 合规文档：字段进同步链路后，隐私政策两份副本（`docs\legal\privacy-policy.md` + `rawfile\legal\privacy-policy.txt`）都要改

## 测试环境

| 端 | 环境 | 详见 |
|---|---|---|
| 鸿蒙 | DevEco 模拟器（`devecocli emulator start "<name>"` → `run` → `ui screenshot`） | `docs\process\test-environments.md` |
| 安卓 | MuMu 模拟器（端口以实例设置页为准，不照抄默认值） | 同上 |

改动涉及启动分流、登录注册、训练主链路、云同步、视觉还原时**必须上设备**；纯文档/脚本/注释改动不需要。

## 登录验证

优先级：**自部署栈真实链路** → 沙盒降级 → 临时跳过。

跳过时交付报告必须写：

```markdown
登录验证：已跳过
- 路径：未执行
- 原因：<服务器不可达 / 切流未完成 / 短信通道故障 / ...>
```

**不得用「注册页能打开」冒充「登录可用」。** 细则见 `docs\process\auth-verification.md`。

## 分支与合并

本仓库当前为单人 + agent 协作模式，无 PR 流程。约定：

- 一个逻辑单元一个提交，不把不相关改动混在一起
- 不 force push `main` / `master`
- 分支命名 `feature/<主题>` 或 `fix/<主题>`

## 评审

- 涉及兼容层（`WorkoutSessionPersistenceBridgeService` / `PersistenceFallbackService`）的改动，必须在提交信息里说明数据迁移影响
- 高风险改动（认证、云同步、数据持久化）走交叉审查

## 发布节奏

见 `docs\release\release-build-runbook.md`（构建、签名、产物、bundleName 迁移）。
