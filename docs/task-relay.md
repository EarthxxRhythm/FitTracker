# FitTracker 任务接力器

`tools/task-relay.ps1` 用来把“下一步做什么”自动化。

它会：

1. 读取 `tasks.phase2.json`
2. 找出 `passes=false` 且 `id` 最小的任务
3. 读取 `git status --short --branch` 和 `git log --oneline -5`
4. 可选运行固定前置检查
5. 生成一份可直接交给 Coding Agent 的提示文件

## 用法

仅生成下一步提示：

```powershell
powershell -ExecutionPolicy Bypass -File tools/task-relay.ps1 -WritePrompt
```

生成下一步提示，并同时跑前置检查：

```powershell
powershell -ExecutionPolicy Bypass -File tools/task-relay.ps1 -RunChecks -WritePrompt
```

## 产物

- 控制台摘要：当前任务 ID、分类、描述、仓库状态、最近提交
- 提示文件：`midscene_run/task-relay-prompt.md`

## 适用场景

当你又想说“计划下一步”或者“按这个顺序执行”时，先跑这个脚本。它会把下一项任务、仓库快照和执行顺序整理成一份标准作业单，减少来回重复。
