---
name: fittracker-dual-review
description: "审查 FitTracker 双端（HarmonyOS ArkTS + Android Kotlin/Compose）的功能、数据、视觉与错误处理是否对等，找出「一端做了另一端没做」的具体缺陷。当用户要求审查/体检/优化这个 app、做发布前审计、排查双端行为不一致、或新增字段/校验/提示后需要确认另一端是否同步时使用。触发词：双端一致性、两端对齐、审查这个 app、体检、发布前审计、为什么鸿蒙有安卓没有、字段漏同步、fittracker review。不用于：单端新功能实现、纯设计稿评审、与 FitTracker 无关的项目。"
---

> **发布状态：未安装。** 这是待审草案，宿主的 skill draft 写入能力不可用（`Draft saving is unavailable in this host`），
> 因此它**不会被任何会话加载**。要启用，需通过桌面 App → Settings → Extensions 导入本文件，
> 或把 `rivet` 加入 PATH 后执行：
> ```
> rivet skills add <本文件所在目录> --scope project --project D:\.CodeSpace\.MyProjects\FitTracker
> ```
> 安装只影响**新会话**，当前会话不会刷新。

# FitTracker 双端一致性审查

在这个仓库里做「分析并优化」时，真正的高发缺陷不是单端写得烂，而是**一端做了、另一端没做**。本项目历史上被证实的不对称包括：`bodyRecords` 进了同步白名单但隐私政策未更新、Android 缺整体 RPE 采集入口、Android 计划组 days 硬编码、鸿蒙身高/出生年无区间校验而 Android 有、Android 注册页无沙盒降级横幅。本 skill 把这类审查固化下来。

## 何时使用

**用**：
- 用户要求「审查/体检/优化这个 app」「发布前审计」「深度 bug hunting」
- 排查「为什么鸿蒙有、安卓没有」这类不对称
- 新增了数据字段、校验、提示、降级路径后，需要确认另一端同步
- 改动跨 `apps/harmony` 与 `apps/android`

**不用**：
- 只在单端实现新功能
- 纯设计稿/原型评审
- 与 FitTracker 无关的仓库

## 第 0 步：先读事实源，不要靠记忆

审查前必须读这些，任何一条都可能是别的会话刚改过的：

| 目的 | 路径 |
|---|---|
| 项目约束（单例规则、服务归属、ArkTS 约定、清理规则） | `AGENTS.md` |
| 状态账（**会漂移**，只作线索） | `.rivet/COMMAND.md` |
| 鸿蒙页面注册唯一事实源 | `apps/harmony/entry/src/main/resources/base/profile/main_pages.json` |
| 鸿蒙路由常量源 | `apps/harmony/entry/src/main/ets/app/AppRoutes.ets` |
| Android 屏清单 | `apps/android/app/src/main/java/com/fittracker/app/ui/screens/` |
| 视觉验收权威基线 | `FitTracker-design/design/06_prototype_redraw/RECHECK-2026-09-13.md` |
| 工作区未提交改动归属 | `.rivet/COMMAND.md` §四 |

`COMMAND.md` 的 `Status:` 行不可信——本项目实证过它标 APPROVED 但已执行完、标「剩余 3 项缺口」但三项全已修。判定真实状态必须回代码与 `git log`。

## 第 1 步：建立验证基线

改动前后都要跑，记录 exit code 与通过数：

```bash
# Android 单测（基线量级：608 tests / 0 failures / 60 suites）
cd apps/android && ./gradlew :app:testDebugUnitTest --console=plain

# Node 单测（基线：15 tests / 15 pass）
node tools/run-tests.mjs

# 鸿蒙静态检查三件套（都应 exit 0）
cd apps/harmony
node tools/check-main-pages.mjs    # 18 个注册页
node tools/check-gates.mjs
node tools/check-dead-refs.mjs     # 应输出「无死引用」

# ArkTS 编译（本项目 typecheck 门禁，约 1min）
devecocli build --product default
```

不要裸跑 `hvigorw`——历史上有挂起 17min 并留下 daemon 坏状态的记录。

## 第 2 步：按四类不对称逐个对照

### 2.1 数据域：字段是否双端都在链路上

对每个新增字段，追四条链：
1. 写入（谁产生它）
2. 持久化（Preferences / DataStore / JSON）
3. 备份包（`UserDataBackupService.exportPackage` 对应实现）
4. 同步白名单（`normalizePayloadForHash` 或等价 hash 视图——**不在视图里则变更检测对该域失明**）

再回到**隐私政策**（`docs/legal/privacy-policy.md` + `rawfile/legal/privacy-policy.txt` 两份副本）核对称谓是否仍准确。本项目踩过：字段进了同步链路但政策仍写「不参与云同步」。

### 2.2 校验口径：同一输入双端范围是否一致

找数值输入点（体重、身高、出生年、围度、RPE、sets/reps），双端并排比：
- 是否有有限性校验（`Number.isFinite` / `isFinite()`）
- 是否有上下界（本项目已确立：体重 `0 < x ≤ 500`）
- 是否有除零保护（Epley 1RM 分母、BMI 除法）

已知不对称范例：鸿蒙 `BodyDataContent.ets` 只判 `Number.isFinite`，Android `BodyScreen.kt` 有 `invalidHeight`/`invalidYear` 两道界校验。

### 2.3 提示与降级：用户是否被告知

- 沙盒/演示模式横幅：双端覆盖是否对等（本项目现状：鸿蒙登录+注册有，Android 仅登录有）
- 空态、错误态、加载失败态是否双端都有
- 静默降级检查：`PersistenceFallbackService.recordFallback` 这类「记录降级状态」的方法**是否有调用方**——零调用意味着降级从不被记录，用户无感知

### 2.4 实现路径：同一功能两端是否同构

- 路由页 vs 覆盖层（本项目：训练预览在鸿蒙是 `bindContentCover`，Android 是独立路由）
- 状态所有者：Android ViewModel vs 鸿蒙 `@Observed` state 类；检查是否存在**同一状态被 new 两次**（主壳一次、薄壳页一次）
- 页面清单对齐：`main_pages.json` 的 N 项 vs Android `screens/` 的 N 个目录，逐项映射

## 第 3 步：每条 finding 必须过五道门

缺任何一道就不要报：

1. **精确位置**：`file:line`，不是文件名
2. **可达触发路径**：什么操作/什么输入能走到
3. **错误行为**：实际会出什么错，或违反了哪条项目/平台契约
4. **具体影响**：用户、数据、安全、兼容性或运维层面的后果
5. **反证已做**：读完整函数与调用方，确认现有 guard/cleanup/补偿校验**没有**挡住

搜索命中只是线索，不是 finding。风格偏好、任意尺寸限制、「可能会」的风险一律不报。

严重度按影响而非修复难度：Critical（可利用安全/不可逆数据丢失/核心路径发布阻断）> High（可能崩溃/数据损坏/核心功能失效）> Medium（条件更窄的真实缺陷）> Low（有限影响的具体小缺陷）。

## 第 4 步：视觉审查用项目的口径，不要自创

- 判定口径：`--crop 100,740` + a11y 文本掩码，**非文本内容区偏差 ≤ 8%**
- **不存在单一通用 align**：welcome/plan/library 的 best-fit 是 0 或负值，其余屏是 35。必须逐屏并列记录 best-fit 与物理 35 两组数字，任何「统一按某值重测」都会得出错误结论
- library 的历史 28.42% 是口径错误产物（掩媒体后 3.75%），不要引用
- 截至 `RECHECK-2026-09-13.md`：达标 6 屏，未达标 5 屏（profile / login / plan / register / review），complete / planGroup / planDetail 三屏**从未采集**
- `STATUS.md` 与 `ACCEPTANCE-PLAN.md` 里的旧表格已被该文件明确核销作废

## 第 5 步：明确标注验证边界

无鸿蒙设备时（`hdc list targets` → `[Empty]`），下列事项**做不到**，必须标「未在真实环境验证」，不得用静态推理冒充：

- 云同步真机端到端（AGC CloudDB 读写）
- ohosTest 全量运行
- 设备截图与像素级视觉验收
- 双账号行级隔离实测

能做的：编译、单测、三项静态检查、源码级调用链取证。

## 验收标准

一次合格的审查交付必须同时满足：

- [ ] 每条 finding 带 `file:line` + 触发路径 + 影响 + 反证结论
- [ ] 双端对照项两侧都给位置，不只给缺的那一侧
- [ ] 明确区分「我实测过的」与「文档/他人声称的」——后者要独立复核
- [ ] 跑过第 1 步的基线命令，报告里给出的通过数来自本轮真实输出
- [ ] 设备侧未验证项被显式列出，不静默略过
- [ ] 未修改任何代码（除非用户明确要求修）

## 示例：一次真实的不对称审查

**背景**：`docs/legal/privacy-policy.md:30` 写「身体数据：否（当前版本不参与云同步）」。

**追踪**：
1. `CloudSyncService.buildLocalPayload:249` → `UserDataBackupService.exportPackage` → 含 `bodyRecords:107` / `bodyMeasurements:108`
2. `normalizePayloadForHash:311-322` 解析的正是上传载荷 `envelope.backupJson`，其中显式列出这两个键
3. 该处注释原文：「不入此视图则其变化不改变 hash，同步变更检测对该域『失明』」→ 反证失败：身体数据确实在同步链路上
4. 引入时点 `4cb147f`（新增身体测量数据域），隐私政策最后修改于 `9f2fbfc` 且未同步声明 → 漂移在 HEAD 成立

**结论**：合规缺陷，上架前必须改政策措辞（后来由 `94157d3` 修复）。这类「代码已改、合规文档没跟」是双端项目的典型坠点，且只有沿完整链路追才能证明。

## 依赖与限制

- 需要：`node`、`gradle`（`apps/android/gradlew`）、`devecocli`（鸿蒙构建）、`git`
- `devecocli` 不可用时 ArkTS 编译无法验证，只能降级到静态检查
- 本 skill 的检查清单来自 2026-10 的实测，项目演进后需重新校准路径与基线数字
- 本 skill 未在真实设备上验证过任何一条设备侧流程
