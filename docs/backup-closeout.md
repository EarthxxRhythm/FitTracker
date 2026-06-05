# FitTracker Backup Closeout

## 1. 覆盖的数据范围

本轮把 FitTracker 的本地备份能力收成正式交付形态，手动入口与系统入口共用同一份 JSON 协议。

覆盖范围固定为：

- `goal`
- `my_plans`
- `current_plan_id`
- `sessions`
- `contentMeta.contentVersion`

明确不纳入本轮备份范围：

- `WorkoutDraftService` 训练草稿
- `fittracker_content.db` 及其内容种子重建数据
- 媒体缓存、封面缓存、视频缓存

## 2. 恢复语义与冲突规则

- `goal`：以导入包为准，导入包为 `null` 时清空本地目标。
- `plans/current_plan_id`：以导入包为准；若指针失效，回退到首个可用计划，并返回固定 warning 文案。
- `sessions`：按 `sessionId` 去重合并；导入包中同 `sessionId` 的记录覆盖本地旧记录。
- 历史训练记录视为事实数据，不因内容库版本变化而丢弃。
- 系统备份桥接固定文件名：`fittracker-user-data-backup.json`。
- `EntryBackupAbility.onProcess()` 的 idle 态与正常过程态统一返回同一 JSON 结构：`stage/statusId/success/backupFilePath/detailText`。

## 3. 验收命令与测试项

| 检查项 | 命令 / 来源 | 结果 | 产物 |
| --- | --- | --- | --- |
| Build gates | `node tools/check-gates.mjs` | Passed | 2026-06-06 终端执行通过 |
| Default HAP | `hvigorw assembleHap --mode module -p module=entry@default -p product=default --no-parallel` | Passed | `entry/build/default/outputs/default/entry-default-unsigned.hap` |
| ohosTest HAP | `hvigorw assembleHap --mode module -p module=entry@ohosTest -p product=default --no-parallel` | Passed | `entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap` |
| 备份 focused smoke | `powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev-smoke.ps1 -Target backup-card -DeviceId 127.0.0.1:5555` | Passed | `midscene_run/focused/backup_card-20260606-020200-p8772/midscene-entrypoints-smoke-summary.md` |
| 备份 smoke HTML | summary latest html | Passed | `midscene_run/focused/backup_card-20260606-020200-p8772/report/midscene-harmony-127.0.0.1_5555-2026-06-06_02-02-05-0lk7mdcv.html` |
| 备份 Hypium 覆盖 | `entry/src/ohosTest/ets/test/UserDataBackupService.test.ets`、`entry/src/ohosTest/ets/test/SystemBackupBridgeService.test.ets` | Included | 已编入 `entry@ohosTest` 构建产物 |

说明：

- 当前仓库本轮仍沿用“`entry@ohosTest` 编译通过 + focused smoke 通过”的本地验收方式，尚未补一条独立 CLI Hypium 执行入口。
- 手动入口验收关注回顾页备份卡；系统入口验收关注 `EntryBackupAbility -> SystemBackupBridgeService -> UserDataBackupService` 的共享协议与往返恢复。

## 4. 已知非目标与延期项

- release 签名配置与正式分发包
- 远端同步 / 云账户体系
- `WorkoutDraftService` 跨版本备份与恢复迁移
- 内容数据库整库备份与媒体缓存备份
- 超出 `EntryBackupAbility` roundtrip 的更大系统设置联调交付
