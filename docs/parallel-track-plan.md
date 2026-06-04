# FitTracker 并行开发执行清单

当前并行开发分为 4 条线：`build-gates` / `regression-flow` / `workout-loop` / `content-plan`。

## build-gates

- 分支：`codex/fittracker-build-gates`
- 工作树：`.worktrees/fittracker-build-gates`
- 任务源：无独立任务文件时，默认跟随当前主线 `docs/tasks.workout-loop.json`
- 范围：构建脚本、任务接力脚本、检查护栏、验证入口、工具文档

说明：这条线以工具化和护栏为主，必要时可以在人类指令中明确子任务，不再回退到 `tasks.phase2.json`。

## regression-flow

- 分支：`codex/fittracker-regression-flow`
- 工作树：`.worktrees/fittracker-regression-flow`
- 任务文件：`docs/tasks.regression-flow.json`
- 范围：登录、注册、会话恢复、冷启动分流、认证回归脚本

## workout-loop

- 分支：`codex/fittracker-workout-loop`
- 工作树：`.worktrees/fittracker-workout-loop`
- 任务文件：`docs/tasks.workout-loop.json`
- 范围：训练计划、今日训练、训练记录、统计聚合、训练保存链路

## content-plan

- 分支：`codex/fittracker-content-plan`
- 工作树：`.worktrees/fittracker-content-plan`
- 任务文件：`docs/tasks.content-plan.json`
- 范围：个人资料、动作库、动作详情、通用 UI 组件、导航补齐

## 每条线开始前

- `node tools/check-gates.mjs`
- `powershell -ExecutionPolicy Bypass -File tools/task-relay.ps1 -TaskFile <对应任务文件> -WritePrompt`

主线 `workout-loop` 可以省略 `-TaskFile`，因为当前默认入口已经指向它。

## 验证建议

- 日常轻量验证优先 `powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1`
- 当前 focused smoke 推荐入口：`backup-card`、`media-card`
- 只有在路由、持久化或训练主链路准备合并前，再补 `powershell -ExecutionPolicy Bypass -File tools/premerge-regression.ps1`

## 交付约定

- 不跨线回退他人的共享核心改动
- 每条线只更新自己对应任务文件中的 `passes`
- 工具化收口可以更新文档和脚本，但不要顺手改写其他任务线的业务状态
- 主线负责最终合并、同步、冲突处理和公共护栏
