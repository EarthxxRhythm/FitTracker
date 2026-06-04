# FitTracker 任务接力器

`tools/task-relay.ps1` 用来把“下一步做什么”整理成标准接力提示。

它会：

1. 读取任务源 JSON
2. 找出 `passes: false` 且 `id` 最小的下一项
3. 采集 `git status --short --branch` 和 `git log --oneline -5`
4. 按需运行固定前置检查
5. 生成一份可直接交给 Coding Agent 的提示文件

## 当前约定

- 默认任务源：`docs/tasks.workout-loop.json`
- 并行线请显式传入：
  - `docs/tasks.content-plan.json`
  - `docs/tasks.regression-flow.json`
- `tasks.phase2.json` 仅保留为历史阶段文件，不再作为默认入口

## 用法

生成下一步提示：

```powershell
powershell -ExecutionPolicy Bypass -File tools/task-relay.ps1 -WritePrompt
```

针对指定任务线生成提示：

```powershell
powershell -ExecutionPolicy Bypass -File tools/task-relay.ps1 -TaskFile docs/tasks.content-plan.json -WritePrompt
```

生成提示并跑前置检查：

```powershell
powershell -ExecutionPolicy Bypass -File tools/task-relay.ps1 -RunChecks -WritePrompt
```

## 产物

- 控制台摘要：当前任务 ID、分类、描述、仓库状态、最近提交
- 提示文件：`midscene_run/task-relay-prompt.md`

## 轻量验证建议

- 日常 focused smoke 优先用 `powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1`
- 当前默认短入口是 `current-plan`，只测 `Home -> Preview -> Active`
- `backup-card` 和 `media-card` 继续保留为补充入口；需要一起跑时用 `-Target both`
- 只有在涉及路由、持久化或训练主链路合并前，再补 `tools/premerge-regression.ps1`

## 适用场景

当你要继续“下一步”或准备把任务交给另一位 Coding Agent 时，先跑这个脚本。它会把任务源、仓库快照和执行顺序整理成一份标准作业单，减少来回重复说明。
