# 工作流文档收敛归档（2026-10）

这批文档原位于 `docs/process/`，各自定义「每轮怎么推进开发」。2026-10 收敛为单一权威流程 ——
`docs/process/vibe-coding-workflow.md`，本目录保存原文供历史追溯。

## 为什么收敛

- 多份文档重复描述同一套「最短验证链」「提交边界规则」，权威被稀释 —— 规则分散在太多文档里
  会互相淹没（Anthropic Claude Code 实践：CLAUDE.md 过长时规则会被 agent 忽略）。
- 部分文档描述的机制已不存在：
  - `parallel-track-plan.md` 的四条 worktree 线（`.worktrees/` 已删除）
  - `handoffkit-fittracker-multi-agent-system.md` 引用 monorepo 重组前的目录结构
    （`features/review/`、无 `apps/harmony/` 前缀的 `entry/src/...`）

## 归档清单

| 文件 | 归档原因 |
| --- | --- |
| `continuous-dev-loop.md` | 与 `vibe-coding-workflow.md` 重叠（任务队列循环）；其 `tasks/project-queue.json` 现位于 `apps/harmony/tasks/` |
| `parallel-track-plan.md` | 描述的四条 worktree 线已不存在（`.worktrees/` 已删） |
| `handoffkit-fittracker-multi-agent-system.md` | 未落地的设计（Phase 1/2/3）；引用重组前的目录结构 |
| `task-relay.md` | 工具 `tools/task-relay.ps1` 仍在，但用法已被 `vibe-coding-workflow.md` §4 Step 1 覆盖 |

## 保留在 `docs/process/` 的活跃文档

- `vibe-coding-workflow.md` —— 唯一权威开发流程（路径基准：`tools/…` 等相对 `apps/harmony/`）
- `agent-team-fittracker-overlay.md` —— 团队角色路由（与流程互补，不重复）
- `tasks.*.json` —— 任务源数据
- `regression-flow-status.md`、`harmonyos-default.md`、`pi-agent-parallel-restore.md` —— 领域参考

归档文件只用于历史追溯，不作为实现依据。
