# pi 多 Agent 并行还原：安装与派工说明

> 状态：2026-09-07 已安装并写好项目 agents。用于在 **pi 宿主**里并行还原
> Open Design → ArkUI 的 15 屏。

## 1. 一次性安装（已完成）

- subagent 扩展：把 pi 官方示例
  `node_modules/@earendil-works/pi-coding-agent/examples/extensions/subagent/{index.ts,agents.ts}`
  复制到 `~/.pi/agent/extensions/subagent/`（Windows 用复制，不用 symlink）。
- 示例角色：`agents/{scout,planner,reviewer,worker}.md` → `~/.pi/agent/agents/`
- 工作流 prompt：`prompts/*.md` → `~/.pi/agent/prompts/`
- 会话内 `/reload`（或重启 pi）后，模型工具列表出现 `subagent`
  （single / parallel ≤8 任务 4 并发 / chain）。

## 2. 项目角色（已入库 `.pi/agents/`，agentScope:"both" 时生效）

| agent | 用途 | 工具 |
|---|---|---|
| `spec-scout` | 只读差距侦察，输出 文件:行 证据 | read/grep/find/ls |
| `app-engineer` | 按冻结规格还原布局+动效，只改 owner_files，禁 build/install | read/bash/edit/write 等 |
| `qa-device` | 模拟器像素/动效验收，产出数值报告 | read/bash/write 等 |

角色 prompt 与纪律见各 `.pi/agents/*.md`；主会话（Delivery Lead）负责集成、统一构建、
设备验收、小步提交。

## 3. 任务包格式（写 `cluster/inbox/<task>.json`，模板见
`cluster/TEMPLATES/README.md` 与 `screen-task.home.example.json`）

字段：`task / title / brief(自包含) / owner_files / do_not_touch / acceptance / created_at`。

## 4. 派工协议（pi 宿主）

1. 主会话串行完成黄金组件基线后，把每屏任务写入 `cluster/inbox/<task>.json`。
2. 用 `subagent` parallel 派工（`agentScope:"both"`），任务正文 = “读并执行
   cluster/inbox/<task>.json，完成后写 cluster/outbox/<task>.json”。
3. 以 outbox 出现为完成信号；主会话统一 assembleHap（单写者）→ qa-device 验收 →
   未达标回派该屏二轮。
4. 达标逐屏小步提交；终期 15 屏「还原率报告」归档 `test_run/`。

## 5. 约束

- 并发 ≤4；子代理只在 owner_files 写；共享文件（DesignTokens/AppShell/规格库）只读。
- 脏工作区为用户资产：agent 不回退/覆盖未列文件。
- 每屏先 spec-scout 或自带 文件:行 差距清单，避免“凭旧页面近似”。
