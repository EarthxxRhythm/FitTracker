# FitTracker 并行开发执行清单

当前并行执行拆分为 4 条线：`build-gates` / `regression-flow` / `workout-loop` / `content-plan`。

## build-gates
- 分支：`codex/fittracker-build-gates`
- 工作树：`.worktrees/fittracker-build-gates`
- 任务文件：`tasks.phase2.json`
- 范围：构建脚本、任务接力脚本、主路由检查、构建失败提示、并行规范文档

## regression-flow
- 分支：`codex/fittracker-regression-flow`
- 工作树：`.worktrees/fittracker-regression-flow`
- 任务文件：`docs/tasks.regression-flow.json`
- 范围：登录/注册/会话恢复/冷启动分流/认证回归脚本

## workout-loop
- 分支：`codex/fittracker-workout-loop`
- 工作树：`.worktrees/fittracker-workout-loop`
- 任务文件：`docs/tasks.workout-loop.json`
- 范围：训练计划、今日训练、训练记录、统计聚合、训练保存链路

## content-plan
- 分支：`codex/fittracker-content-plan`
- 工作树：`.worktrees/fittracker-content-plan`
- 任务文件：`docs/tasks.content-plan.json`
- 范围：个人资料、动作库、动作详情、UI 通用组件、导航闭环

## 每条线提交前
- `node tools/check-gates.mjs`
- `powershell -ExecutionPolicy Bypass -File tools/task-relay.ps1 -TaskFile <对应任务文件> -RunChecks`

## 交付约定
- 不跨线改共享核心文件，尤其是 `DesignTokens.ets`、`AppRoutes.ets`、`main_pages.json` 和通用组件目录。
- 每条线只更新自己的任务文件 `passes` 状态，不回写其他线的任务文件。
- 主线只负责合并、同步、冲突处理和公共护栏。
