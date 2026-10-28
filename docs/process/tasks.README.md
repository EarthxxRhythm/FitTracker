# 任务源说明（tasks.*.json）

> **层级**：L2 说明
> **最后核对**：2026-10-28
> **上位文档**：`docs/process/vibe-coding-workflow.md`（L1 流程权威）
> **状态**：现行

本目录下的 `tasks.*.json` 是 AI Coding 接力的任务源。每个条目形如 `{ id, category, description, passes }`。

## 一、`passes` 的语义（先看这条，避免误判）

`passes` **不是**「功能是否实现」的状态位，而是**接力收口的翻牌标志**：由接力流程在某一轮验收完成后置 `true`。

裁定依据：`.rivet/COOPT.md` §passes 语义裁决（2026-10-17）——反证是 `tasks.workout-loop.json` 的 id 27-36 全标 `false`，但对应功能代码早已存在（计时器 `ActiveContent.ets`、Epley 1RM `WorkoutSessionService.ets`、周统计 `StatsDashboardService.ets`）。

**因此**：

- 判断功能是否实现，看代码与测试，**不看** `passes`。
- `passes` 只由 `apps/harmony/tools/task-relay.ps1` 读取（挑 `passes: false` 中 id 最小的一项作为下一任务），脚本本身从不写回。
- 想让某项不再被派发，才置 `true`；不要用它表达「验收通过」。

## 二、四个文件的分工

| 文件 | 定位 | 是否可被自动接力选中 | 状态 |
|---|---|---|---|
| `tasks.workout-loop.json` | 默认主线：计划 → 训练 → 记录 → 统计 | ✅ | 现行，2026-10-28 已校准 |
| `tasks.content-plan.json` | 并行内容线：个人资料、动作库、UI 组件、导航 | ✅ | 现行，2026-10-28 已校准 |
| `tasks.regression-flow.json` | 并行回归线：认证与同步回归口径 | ✅ | 现行，2026-10-28 按 Supabase 现状重写 |
| `tasks.legacy.json` | 1.0.0 时代历史快照（手机号+密码本地优先） | ❌（不在 task-relay 候选列表） | **冻结归档，不再维护** |

`tasks.phase2.json`、`tasks.next.json`、`tasks.json` 为更早期阶段记录，已不在仓库中；如遇旧文档引用，按不存在处理。

## 三、2026-10-28 校准记录

后端由华为 AGC 改为自托管 Supabase、账号与同步页下线、同步改为登录后恒定自动，导致任务源出现两类漂移：

1. **认证模型**（`tasks.regression-flow.json`，全 9 条）
   - 原：手机号 + 密码注册 / 登录、未注册手机号拦截、"账号未注册"提示。
   - 现：手机验证码（未注册自动创建）、邮箱密码、微信 / QQ / 华为账号；登录为强制前置；无「账号与同步」页。
   - 处置：**按现实现重写 1-9 条描述**，`passes` 保持 `true`（回归口径已验）。
2. **内容与页面口径**（`tasks.content-plan.json` / `tasks.workout-loop.json`）
   - 头像由「占位」改为真实头像（`AvatarImageService`，未设置时按昵称派生色块）。
   - 动作库由原型样例改为本地生成真实目录（约 102 条，`free-exercise-db` 素材）。
   - 「统计页」在现行导航中名为「回顾页」。
   - 训练记录补充：按计划动作与总组数推进、组记录按动作分组。
   - 组件规范补充：`DesignTokens` + `MotionIntent` + `DuTokens` 三层。

`tasks.legacy.json` **未改动**：它是历史快照，保留原样用于追溯；其中「本地优先 / 手机号密码」语义与当前实现不符，不要照它执行。

## 四、使用方式

```powershell
# 在鸿蒙工程根执行
powershell -ExecutionPolicy Bypass -File tools/task-relay.ps1                 # 默认主线
powershell -ExecutionPolicy Bypass -File tools/task-relay.ps1 -TaskFile docs/process/tasks.content-plan.json -WritePrompt
```

`-TaskFile` 路径相对仓库根；脚本内部会 `Set-Location` 到 `apps/harmony`。

## 五、维护约定

- 改描述可以，改 `passes` 需明确这是「接力翻牌」而非「功能验收」。
- 新增条目沿用现有 `id` 序列，不要复用已删除的 id。
- 改动后跑 `node -e "JSON.parse(require('fs').readFileSync('<file>','utf8'))"` 或等同校验，避免破坏 `task-relay.ps1`。
