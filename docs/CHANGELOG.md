# 更新日志

本文件记录 FitTracker 各版本的版本说明与变更。版本号与 `versionCode` 以 `AppScope/app.json5` 为准。

## [1.0.0] — 2026-09-13

首个正式版本。定位为**本地优先的健身训练记录工具**：所有训练与身体数据默认只保存在设备本机，应用不申请任何权限、不发起任何网络请求。

### 版本信息

| 字段 | 值 | 来源 |
| --- | --- | --- |
| versionName | `1.0.0` | `AppScope/app.json5` |
| versionCode | `1000000` | `AppScope/app.json5` |
| bundleName | `com.earthrhythm.fittracker` | `AppScope/app.json5` |
| vendor | `EarthRhythm` | `AppScope/app.json5` |

### 新增

- **目标设置与启动分流**：冷启动按登录态分流到欢迎/登录或主壳；首启引导设置训练目标。
- **个性化训练计划**：依据目标生成当前计划，首页直接呈现"今日训练"。
- **训练流**：训练预览 → 训练执行（组次计时与记录）→ 训练完成摘要。
- **训练复盘**：历史训练、周趋势、动作 PR 下钻、肌肉分布等统计视图。
- **动作库**：动作列表、筛选、收藏与动作详情（含要点与媒体状态卡，素材内置于安装包）。
- **身体数据**：体重、体脂等记录。
- **本地账号与会话**：本地注册/登录与会话恢复。
- **数据备份与恢复**：手动导出/导入本地 JSON 备份包；承接系统备份回调（`allowToBackupRestore`）。
- **设置**：单位、语言、周开始日与各类开关的状态记录。
- **视觉主线**：按原型 1:1 重建的深色翠绿（Cool Emerald）界面，`entry/src/main/resources/base/profile/main_pages.json` 注册的 20 个页面构成完整主路由。
- **本地化资源**：补齐 `zh_CN` 与 `en_US` 应用级字符串资源目录，与默认资源键集一致。

### 已知限制

- **界面仅提供简体中文**：设置页的"English"选项当前只记录选择状态，尚未驱动界面语言切换；`zh_CN` / `en_US` 资源目录已就绪，但界面文案仍为代码内中文。
- **数据能力为本地实现**：设置页的"训练数据同步""匿名使用数据""健康数据授权"当前均为界面状态记录，未接入账号服务器、统计服务或健康数据权限（详见 `docs/legal/privacy-policy.md` 第六节）。
- **应用身份变更会改变本地数据沙箱**：`bundleName` 已由样板值 `com.example.fittracker_opencode` 替换为正式身份 `com.earthrhythm.fittracker`（`vendor` 同步由 `example` 改为 `EarthRhythm`）。**bundleName 决定应用私有沙箱路径，变更后旧身份包留下的本地数据在新包下不可见**，迁移路径详见 `docs/release-build-runbook.md` 第 9 节。
- **签名链未接入**：当前仅能产出 unsigned HAP，尚不具备正式签名发布能力。

### 升级提示

- 本版本为首个版本，无历史数据迁移问题。
- 从其他 `bundleName` 的构建升级（例如替换身份后）属于"新应用安装"，原沙箱数据不会自动迁移，升级前请先导出备份包。

---

## 版本号约定

- 版本号遵循语义化版本（`MAJOR.MINOR.PATCH`）；
- 每次发布需同步更新：`AppScope/app.json5` 的 `versionCode` / `versionName`、设置页"关于"中展示的版本号，以及本文件。
