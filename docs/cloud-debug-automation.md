# 云调试（AGC 云真机）手动操作手册

> 用途：在**无物理设备**条件下，人工通过华为 AGC「云调试」远程真机完成上传 HAP、安装启动、操作、截图与日志采集。
> 状态：v0.1（2026-10-09）。云调试网页流程来自外部来源（官方文档 + 实操帖），标【外部来源】；**§5 演示数据一节为本机实测结论**，标【本机实测】。
> 配套：`.rivet/plans/agent-全自动云调试通道-agc-云真机自动化.md`（全自动路线，APPROVED）、`docs/store-listing-screenshot-checklist.md`（截图内容清单）、`docs/release-build-runbook.md` §12（上架材料待办）。

## 0. 证据等级约定

| 标注 | 含义 |
| --- | --- |
| 【本机实测】 | 2026-10-09 在本机 + Pura 90 模拟器实际执行，有命令输出与落盘记录 |
| 【外部来源】 | 官方文档或第三方实操帖，**未在本机复现** |
| ⚠ | 以 AGC 控制台 / 云真机实际界面为准 |

**诚实边界**：截至 v0.1，云调试**网页侧**的任何一步（入口、上传、控制面板、释放）都**没有在本机执行过**——本机从未建立过云真机会话。凡未标【本机实测】的步骤，第一次执行时都应当作待验证步骤，并把实际界面文案回填本手册。

---

## 1. 前置条件

| 项 | 本项目状态 |
| --- | --- |
| 华为开发者账号并已登录 AGC | 已有（见 `docs/cloud-setup.md` §0） |
| AGC 项目 + HarmonyOS 应用（包名 `com.earthrhythm.fittracker`） | 已创建 |
| 已签名 HAP（**release**） | 见 §2 |
| 配额 | 【外部来源】每天 360 分钟免费云真机时长（HarmonyOS 5.0+）；**同一账号同时最多占用 2 台设备**（官方单机调试流程文档） |

> 云调试是**纯网页 GUI** 服务，无面向开发者的公开 CLI/API——这是本项目的既有调研结论（见计划文档 §2.1 F2）。因此「手动」就是当前的唯一正规路径。

---

## 2. 上传件准备

### 2.1 构建 release 签名包

```bash
devecocli build --product default --build-mode release
```

产物：`entry/build/default/outputs/default/entry-default-signed.hap`

⚠ **debug 与 release 输出同名同目录，互相覆盖**。构建完立刻归档到证据目录，否则无法分辨手上这个包是哪种模式：

```bash
cp entry/build/default/outputs/default/entry-default-signed.hap \
   test_run/cloud-debug/manual-run/upload/FitTracker-<版本>-release-signed.hap
```

本次已归档件：`test_run/cloud-debug/manual-run/upload/FitTracker-1.1.0-release-signed.hap`（26.7 MB，2026-10-09 构建，版本 1.1.0 / 1001000）。

### 2.2 怎么确认手上的 HAP 是 release 还是 debug

【本机实测】用符号表判定，无需装机：

```bash
python -c "
import zipfile,sys
d=zipfile.ZipFile(sys.argv[1]).read('ets/modules.abc')
for n in [b'DeviceSeedService',b'LaunchRequestStore',b'EntryLaunchParameters']:
    print(n.decode(),'->',d.count(n))
" <hap路径>
```

| 判据 | debug 包 | release 包 |
| --- | --- | --- |
| `DeviceSeedService` 等类名出现次数 | > 0（如 5） | **0**（被 property/toplevel 混淆改名） |
| `ets/modules.abc` 体积 | 较大 | 明显更小 |

本次实测对照：debug 归档件 abc = 1,961,820 字节、类名出现 5 次；release 包 abc = 1,163,616 字节、类名出现 0 次。字符串字面量（如 `today_flow`）两种模式都会保留，不能用作判据。

> ⚠ **上架截图必须用 release 包**（`docs/store-listing-screenshot-checklist.md` §二 前置条件 1）。debug 包带调试属性，不能用于市场素材。

---

## 3. 进入云调试

【外部来源】两个入口，功能一致：

1. **AGC 控制台（推荐，发布前测试用）**：登录 AGC →「我的项目」→ 选择 FitTracker 项目 → 左侧导航「**质量**」→「**云调试**」
2. 华为开发者联盟门户 → DevEco 产品 → 云调试（适合临时快速调试）

⚠ 「**云测试**」就在「云调试」隔壁，功能完全不同——云测试是上传后平台自动跑兼容性/稳定性回归，**不能交互调试**，截不了素材、做不了登录态验证。别点错。

---

## 4. 手动黄金路径

每一步的「成功判据」都要当场确认再进下一步。

| # | 步骤 | 成功判据 | 失败恢复 |
| --- | --- | --- | --- |
| 1 | 在单机调试页选择机型/系统版本 → 申请设备 | 页面出现投屏画面 + 控制面板 | 排队等待；同账号最多 2 台，先释放不用的 |
| 2 | 上传 HAP：页面上传入口 → 选 §2.1 的 release 包 | 上传完成并**自动安装**；页面提示安装成功 | 见 §8 |
| 3 | 启动应用：投屏点图标，或控制面板 shell 面板执行 `aa start -a EntryAbility -b com.earthrhythm.fittracker` | 应用画面出现 | 用 shell 面板 `bm dump -n com.earthrhythm.fittracker` 确认是否装上 |
| 4 | 交互操作：投屏点击/滑动；控制面板支持上传图片到设备、打开网页、复制文本、获取文本【外部来源】 | 设备画面按预期变化 | 投屏坐标漂移时**优先改用 shell 面板命令**直达目标页，别硬点 |
| 5 | 取证据：页面截图功能；日志用 shell 面板 `hilog`（可 `hilog \| grep FitTracker` 过滤） | PNG 落盘 + 日志可读 | — |
| 6 | **释放设备** | 页面显示已释放 | 挂着不用也扣配额，用完即还 |

> 「控制面板支持 hdc/adb 命令输入」【外部来源】：官方《使用控制面板调试》文档原文为「Shell 脚本操作：您可以通过输入 adb/hdc 命令来执行」。命令前缀究竟要不要写 `hdc shell`，以面板 placeholder 提示为准——**未本机复现**。

---

## 5. 演示数据：release 包怎么造出「非空态」

### 5.1 结论（【本机实测】，2026-10-09）

**release 包无法通过启动参数注入演示数据**。四组对照实验（模拟器 Pura 90 / HarmonyOS 6.1.1(24)，每组均为 `force-stop` 后 `aa start`，10–12 秒后读 `devecocli ui layout`）：

| # | 包 | 启动参数 | 落地页 | 判定 |
| --- | --- | --- | --- | --- |
| A | release | `--ps devSeed demo_data` | 登录页 | 未注入 |
| B | debug | `--ps devSeed demo_data` | 登录页 | 未注入 |
| C2 | debug | `--ps testMode sandbox --ps devSeed demo_data` | **首页（有数据）** | 注入成功 |
| D | release | `--ps testMode sandbox --ps devSeed demo_data` | 登录页 | 未注入 |

### 5.2 机制（代码依据）

- `entry/src/main/ets/features/pencil/pages/PencilSplashPage.ets:122`——`testMode === 'sandbox'` 生效的前置条件是 `isDebuggablePackage()`（`appInfo.debug`）。
- 同文件 `:125-128`——`devSeed` 的消费**没有** debug 门禁，但它依赖 seed 内的 `AuthService.seedSandboxSession(...)` 建立登录态（`DeviceSeedService.ets:applyDemoDataSeed`）。
- `AppScope/resources/rawfile/agconnect-services.json` 在位 → `CloudEnvironment` 走 AGC 真实链路 → **不切沙盒时 `seedSandboxSession` 不构成有效登录态**（实验 A/B 都停在登录页即为证据）。
- 合起来：devSeed 要生效必须先切沙盒，而切沙盒只对 debug 包开放 ⇒ release 包拿不到 seed 数据。

> **修正既有记录**：`docs/release-build-runbook.md` §10 曾把该现象记为「`devSeed` 在 debug 包生效、在 release 包失效」。按本次实测，**真正变量不是构建模式而是 `testMode=sandbox`**（B 组证明 debug 包不传 testMode 同样失效）；该文档写于 2026-09-13，早于 AGC 真实接线（`0b2742f`，2026-10-01）与 testMode 门禁（`6a1b3cd`，2026-10-01），当时 devSeed 生效是因为尚无 AGC 链路。

### 5.3 因此 release 包的数据来源

**路径 A（确定可行，零依赖）**：在云真机内正常使用应用创建数据——注册/登录（邮箱方式可用）→ 建立训练计划 → 记录训练 → 填身体数据。截图清单要求「非空态」，这条路能同时产出真实的操作画面。

**路径 B（候选，未在云真机验证）**：应用具备手动备份能力（`entry/src/main/ets/shared/services/UserDataBackupService.ets`）——`exportPackage(context)` 产出 JSON，`importPackage(context, json)` 收的是 **JSON 文本字符串**（其空态提示原文为「请先粘贴备份 JSON。」）。理论上可先在本机用 debug 包 + `testMode=sandbox` + `devSeed=demo_data` 造好数据、导出备份 JSON，再在云真机上通过控制面板的「复制文本」能力把 JSON 送进输入框导入。
> ⚠ 该路径的**应用内 UI 入口位置未定位**、**云真机剪贴板通道未验证**、**release 包导入备份后的登录态前提未验证**（备份范围明确不含登录态：`BACKUP_SCOPE_SUMMARY_TEXT = '仅备份目标、计划和训练记录；不包含训练草稿、内容库和媒体缓存。'`）。首次尝试时应按探针对待。

**不要用**：在云真机的 release 包上指望 `devSeed`——已证实无效（§5.1 实验 A/D）。

---

## 6. 命令参考（控制面板 shell 面板用）

| 目的 | 命令 |
| --- | --- |
| 启动应用 | `aa start -a EntryAbility -b com.earthrhythm.fittracker` |
| 强制停止 | `aa force-stop com.earthrhythm.fittracker` |
| 确认已安装 | `bm dump -n com.earthrhythm.fittracker` |
| 读日志（全量） | `hilog` |
| 读日志（过滤） | `hilog \| grep FitTracker` |
| 错误日志 | `hilog -L E` |

本项目实参（已核实）：包名 `com.earthrhythm.fittracker`（`AppScope/app.json5:3`）、Ability `EntryAbility`（`entry/src/main/module.json5:6,20`）。

---

## 7. 证据落盘

```text
test_run/cloud-debug/manual-run/
├── upload/                       # 上传件归档（release 包放这里）
├── prev-<日期>-entry-default-signed.hap   # 历史包（模式已判定）
├── devseed-*.jpeg                # 注入实验截图
└── <任务名>/                     # 每次云真机会话按任务建子目录
```

截图成品的命名与归档另见 `docs/store-listing-screenshot-checklist.md` §五（建议 `docs/release-assets/screenshots-<versionName>/`，不入主分支源码目录）。

---

## 8. 故障速查

| 现象 | 处置 |
| --- | --- |
| 上传后安装失败：包名冲突 | 云真机上已有同包名旧版本 → 先卸载再上传 |
| 安装被拒：签名受限 | 换 release 签名包；若仍被拒 → 属**未验证项**（计划文档 H5），记录现象转官方工单 |
| 上传报格式错误 | 确认 HAP 完整（对比大小与 §2.1 归档件一致） |
| 启动后落在登录页 | 正常——release 包不会自动登录（§5） |
| 投屏点击不生效/漂移 | 改用 shell 面板 `aa start` 直达目标页（§4 步骤 4） |
| 页面元素找不到 | 页面可能改版：用 `observe`/`extract` 重探文本锚点并回填本手册 |
| 配额告急 | 同一会话内集中做完探针；用完立即释放 |

---

## 9. 未复现项（诚实边界）

| # | 项 | 状态 |
| --- | --- | --- |
| U1 | 云调试入口路径「质量 → 云调试」 | 【外部来源】，未本机打开 |
| U2 | 页面上传 HAP 后自动安装 | 【外部来源】，未本机执行 |
| U3 | 控制面板的 hdc/adb 命令输入（前缀格式） | 【外部来源】，未本机执行 |
| U4 | 控制面板「复制文本/上传图片到设备」 | 【外部来源】，未本机执行 |
| U5 | 云真机可安装 release 签名包 | 未验证（计划文档 H5）；本机模拟器安装 release 包**已通过**，但不等于云真机 |
| U6 | 备份导入（§5.3 路径 B）走云真机 | 未验证，UI 入口未定位 |
| U7 | 云调试的设备释放/配额查询界面 | 【外部来源】 |

---

## 10. 证据锚点

- 本机实测记录：`test_run/cloud-debug/manual-run/`（上传件归档、注入实验截图）
- 页面/代码核实：`AppScope/app.json5:3`、`entry/src/main/module.json5:6,20`、`entry/src/main/ets/features/pencil/pages/PencilSplashPage.ets:34,122,125`、`entry/src/main/ets/shared/services/DeviceSeedService.ets`、`entry/src/main/ets/shared/services/UserDataBackupService.ets:15,95,103`、`AppScope/resources/rawfile/agconnect-services.json`
- 构建与签名：`devecocli build --product default --build-mode release`（本次 BUILD SUCCESSFUL in 1 min 8 s）
- 外部来源：官方《使用控制面板调试》（控制面板能力）、官方单机调试流程文档（申请设备 / 同账号 2 台上限）、51cto《鸿蒙云调试——远程真机，不用买也能测》（入口与流程）、CSDN《华为 云调试：应用上传、调试》（上传失败三因）、官方云调试产品页（配额）
