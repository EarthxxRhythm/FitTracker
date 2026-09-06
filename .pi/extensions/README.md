# auto-goal 扩展（项目级）

让主模型在还原队列未完成时**自动续跑**，无需每轮输入“继续”。

- 队列：`cluster/inbox/*.json`（任务包）；完成结果写 `cluster/outbox/<同名>.json`。
- 口径/进度：`design/06_prototype_redraw/STATUS.md`。
- 长跑使命：`design/goal.md`（跨宿主统一目标）。

## 命令

| 命令 | 作用 |
|---|---|
| `/goal status` | 开关/剩余任务/已用轮次 |
| `/goal on [maxTurns]` | 开启自动续跑（默认 60 轮上限） |
| `/goal once` | 只执行下一项后停（干跑） |
| `/goal off` | 关闭 |

## 停止条件（防空转）

1. inbox 无“缺 outbox”任务 → 汇总后自动 off；
2. 达到轮次/时间窗上限（默认 60 轮 / 8h）→ 暂停；
3. 主模型回复含 `AUTO-GOAL-STOP` → 暂停等人工；
4. 同一任务连续注入 3 次仍无 outbox → 暂停（防卡死）。

## 说明

- 状态存 `cluster/.auto-goal.json`（cluster/ 为 gitignore 瞬态目录，不入库）。
- 扩展代码随仓库走（`.pi/extensions/`），改动后 `/reload` 生效；开启前先代码走查
  （自动注入类扩展只发消息，不会绕过确认执行破坏性命令）。
