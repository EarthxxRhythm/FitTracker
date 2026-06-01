# FitTracker 并行开发执行清单（build-gates）

当前并行执行已拆分为 4 条线：build-gates / regression-flow / workout-loop / content-plan。

## build-gates
- 分支: `codex/fittracker-build-gates`
- 工作树: `.worktrees/fittracker-build-gates`
- 范围:
  - `tasks.phase2.json`（仅更新未通过项的 `passes`
  - `tools/check-main-pages.mjs`
  - `tools/content/build-content.mjs`
  - `tools/check-gates.mjs`
  - `tools/task-relay.ps1`
  - `docs/*`（构建校验与接力失败说明）

## 每次提交前
- `node tools/check-gates.mjs`
- `powershell -ExecutionPolicy Bypass -File tools/task-relay.ps1 -RunChecks`

## 交付约定
- 不改公共组件、`DesignTokens.ets`、`app/` 路由主线文件。
- 仅在确认与本线无冲突时改任务文件与脚本。
- 完成目标项后，更新 `tasks.phase2.json` 中对应 `passes`，并在项目日志记录要点。

## 任务目标
- `tasks.phase2.json` 的 `id:6`（构建校验）需变为 `passes: true`。
- 当 JSONL 脏数据、覆盖缺口、主路由异常出现时，脚本输出应带明确失败点与修复方向。
