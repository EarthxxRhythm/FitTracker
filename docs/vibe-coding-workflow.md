# FitTracker Vibe Coding 工作流

## 1. 目标

这份工作流用于约束 AI Coding Agent 和人工协作者在 FitTracker 项目中的接力开发方式。重点不是“自由发挥”，而是让每一轮都围绕一个清晰任务源、一个可验证目标和一组可复用的验证动作推进。

当前原则：

- 单任务推进
- 测试优先
- 小步提交
- 明确交接
- 文档与状态同步

## 2. 权威信息源

每次接力前，优先读取：

1. [AGENTS.md](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/AGENTS.md)
2. 当前任务源 JSON
3. [项目开发日志.txt](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/项目开发日志.txt)
4. 当前要修改的源码文件

当前任务源约定：

- 默认主线：[`docs/tasks.workout-loop.json`](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/docs/tasks.workout-loop.json)
- 并行内容线：[`docs/tasks.content-plan.json`](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/docs/tasks.content-plan.json)
- 并行回归线：[`docs/tasks.regression-flow.json`](/C:/.CodeSpace/.DevEcoStudioProjects/FitTracker/docs/tasks.regression-flow.json)
- `tasks.phase2.json`、`tasks.next.json`、`tasks.json` 仅作为历史阶段记录，不再作为默认接力入口
- `docs/tasks.legacy.json` 仅作归档，不作为自动接力任务源

## 3. 核心原则

### 3.1 一次只做一个任务点

- 每次只处理所选任务源中 `passes: false` 且 `id` 最小的那一项
- 不顺手扩展到多个未排期任务
- 工具化收口可以独立成一轮，但不要伪装成功能已完成

### 3.2 先确认环境，再改代码

- 接手后先看 `git status`、`git log`、开发日志
- 确认 DevEco / hvigor / SDK / Node 脚本链路可用
- 如果环境有问题，先修环境并记录

### 3.3 测试和验证跟改动风险匹配

- 新增逻辑优先补失败测试再实现
- 工具脚本优先跑命令级自验证
- UI 入口优先用短链路 smoke，避免每轮都跑整套长回归

### 3.4 离手时留下可接力状态

- 代码处于可读、可运行、可合并状态
- 开发日志同步更新
- 明确说明完成内容、验证结果和剩余风险

## 4. 标准循环

### Step 1. 选定任务源

1. 选一个任务源文件
2. 找到下一项 `passes: false`
3. 读取开发日志
4. 查看 `git log --oneline -5`
5. 查看 `git status --short --branch`

默认可直接用：

```powershell
powershell -ExecutionPolicy Bypass -File tools/task-relay.ps1 -WritePrompt
```

并行线请显式指定：

```powershell
powershell -ExecutionPolicy Bypass -File tools/task-relay.ps1 -TaskFile docs/tasks.content-plan.json -WritePrompt
```

### Step 2. 跑前置检查

- `node tools/check-gates.mjs`
- 需要时再加 `powershell -ExecutionPolicy Bypass -File tools/task-relay.ps1 -RunChecks -WritePrompt`

如果只是做轻量入口验证，优先：

```powershell
powershell -ExecutionPolicy Bypass -File tools/dev-smoke.ps1
```

当前推荐 focused smoke 入口优先覆盖：

- `current-plan`

补充入口仍包括：

- `backup-card`
- `media-card`

### Step 3. 实现最小改动

- 只实现当前任务要求
- 优先复用现有服务、组件和路由
- 遵守 ArkTS 严格模式与项目约束

### Step 4. 回归验证

至少做与改动匹配的验证：

- 新增测试通过
- 相关旧测试未破坏
- 必要时补短链路 smoke
- 只有涉及路由、持久化或训练主链路收口时，再跑 `tools/premerge-regression.ps1`

### Step 5. 记录与交接

1. 更新 `项目开发日志.txt`
2. 只更新当前任务源里对应任务的 `passes`
3. 提交 commit

## 5. FitTracker 的验证分层

### 5.1 逻辑层

适用于：

- Service
- 纯函数
- 统计计算
- 数据映射与聚合

建议使用 Hypium / ohosTest 覆盖核心逻辑。

### 5.2 流程层

适用于：

- 登录/注册/冷启动
- 训练计划启用
- 训练记录保存
- 回顾页/动作详情入口

日常优先短链路验证；只有在合并前或高风险改动后再补长链路回归。

## 6. 特殊约束

- 禁止 `any` / `unknown`
- 禁止随意动态对象索引访问
- UI 使用 `DesignTokens.ets`
- 不要回退他人的未完成改动
- 不要把文档整理和功能完成混写成同一个结论

## 7. 推荐交接格式

交接说明建议包含：

- 完成了哪个任务源里的哪一项
- 改了哪些核心文件
- 跑了哪些验证
- 还有哪些风险或待补动作

## 8. 节奏建议

一轮会话尽量只完成下面三类之一：

- 一个小功能点
- 一个工具/环境修复点
- 一个关键回归收口点

这样可以让并行开发仍然保持清晰边界。
