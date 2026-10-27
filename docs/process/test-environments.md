# 测试环境规范

> **层级**：L2 展开
> **最后核对**：2026-10-27
> **上位文档**：`AGENTS.md`（冲突以 L1 为准）
> **状态**：现行（双端设备链路已实测连通：2026-10-27 安卓 MuMu 与鸿蒙 DevEco 均判 PASS；应用内启动与 instrumented 用例仍未验证）
> **路径基准**：命令中 `tools\…` 相对 `apps\harmony\`；`gradlew` 相对 `apps\android\`
> **适用端**：双端

## 为什么需要这份文档

验证环境此前只存在于个人记忆里：

- 鸿蒙模拟器命令只有一行书面记录（`docs\ui\ui-final-acceptance-runbook.md:13`），而那份文档自己标了「工具链已失效」
- **MuMu 模拟器全库零命中**——安卓端怎么连、怎么取图、端口是什么，没有任何记录

结果是每次验证都要重新摸索，或者干脆跳过设备侧只做编译。

## 鸿蒙：DevEco 模拟器

```bash
devecocli emulator start "<name>"    # 模拟器名，如 "Pura 90"
devecocli run                        # 安装并启动当前构建产物
devecocli ui screenshot --path <out> # 取图
```

**证据**：`docs\ui\ui-final-acceptance-runbook.md:13`、`docs\release\gongan-beian-form.md:84`（`devecocli emulator start "Pura 90"`）。

**装 HAP**（已启动模拟器、`hdc` 可连时）：

```bash
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
```

**已知坑**：

- 同时产出 signed / unsigned 两个 HAP。设备上已装 signed 包时再装 unsigned 会以 `code:9568332` 失败——`tools\ohos-test.ps1` 须显式传 `-DefaultHapPath` / `-TestHapPath` 指向 `entry-default-signed.hap` / `entry-ohosTest-signed.hap`
- 跑 ohosTest 前先 `hdc shell aa force-stop <bundle>`。应用进程遗留会导致 `TestAbility onDestroy unexpectedly`（0 用例）——实测对比：`test_run/ohosTest/20261001-011300-p20792`（-2）vs `20261001-011336-p17048`（233/233）
- 不要裸跑 `hvigorw`：历史挂起 17min 无产出，终止后 hvigor daemon 残留 `ESRCH` 坏状态
- **模拟器的存活绑定于「启动它的那个终端会话」（2026-10-27 实测；曾误判为内存 OOM，已推翻）**
  - 现象：由一次性 shell（agent 单次调用、CI step、`run_in_background` job）启动的模拟器，
    在该 shell 结束时随进程树被回收——`hdc` 从 `Connected` 转 `Offline`，进程消失。
  - **误判过程（留档避免重复）**：当时观察到物理内存被压到 ~900MB、`Log\crash_server.log`
    反复记 `memory is low, freeMem: 1561`，据此判为 OOM 并把 `hw.ramSize` 从 4096 改到 2048。
  - **推翻证据**：`pagefile.sys` 已分配 24GB、`Commit Limit 40.5GB`、实际提交仅 14GB，
    虚拟内存余量 26GB；且 `hw.ramSize=4096` 与 `2048` 在同样的持久 shell 内**都连续 90s 稳定**
    （`hdc` 保持 `127.0.0.1:5555 Connected`、procs=2），证明 ramSize 不是变量。
    `hw.ramSize` 已还原为 4096（备份 `hardware-qemu.ini.bak-ram4096-*` 仅用于对照，可删）。
  - **正确做法（两条都实测可行，2026-10-27）**：
    1. **起 + 用放同一次 shell 调用内**（agent / CI 首选）：`devecocli emulator start "Pura 90"`
       前台执行约 54–65s 后返回 `Emulator "Pura 90" started successfully.`（exit 0），
       同一次调用内接着跑 `device-smoke` / `hdc install` / 截图**全部成功**；
       **调用一结束即转 `Offline`**（三次实测一致）。
    2. 人工长驻：在**持久终端**里执行并保持该终端不关。
  - **推论陷阱（留档避免重复）**：由上面这条**不能**推出「必须由人手动启动」。
    曾有判断据此把启动责任推给用户；实测证明 agent 在同一次调用内起 + 用完全可行——
    真正的边界是「**跨调用复用设备**」，不是「agent 能否启动」。
  - 另一条独立坑：`devecocli emulator start` 若在自身超时内没在 `hdc list targets` 看到目标，
    会打印 `... did not appear in hdc list targets within the timeout` 后退出，模拟器随之被带走。
    boot 需约 50–60s（`Log\Emulator.log` 的 `Guest OS Boot Completed!!`），慢机器上容易撞上这个超时。
- **首次启动要等 boot 完成**：`Guest OS Boot Completed!!`（`Log\Emulator.log`）之后 `hdc` 才稳定；
  在此之前会看到 `TCP Offline` / 短暂的 `Connected→Offline` 抖动，单次采样会误判为"没起来"。

## 安卓：MuMu 模拟器

> **2026-10-27 实测（本机，MuMu 15.0）**：
>
> - 安装根目录 `D:\Program Files\Netease\MuMu`（**不在 C 盘**；另有 C/E 盘候选，脚本三盘都探）
> - 实例目录 `vms\MuMuPlayer-15.0-0`，CLI 视角 index `0`，名称「MuMu安卓设备」，Android 15.0
> - **adb 端口写在实例配置里**：`vms\MuMuPlayer-15.0-0\configs\vm_config.json` 的
>   `vm.nat.port_forward.adb.host_port` = `16384`。**这是端口的事实源，不必去设置页抄**
> - 官方 CLI：`nx_main\mumu-cli.exe`，支持 `info` / `control launch|shutdown` / `control app install|launch|close|info` / `setting`
> - ⚠️ **参数顺序坑（2026-10-27 二次实测纠正了首轮的误判）**：`control launch --vmindex 0`
>   是**错的**——`--vmindex` 属于 `control` 而不属于 `launch`，写在后面对 `launch` 无效，
>   命令仍返回 `{"errcode": 0}`，但什么都没启动。**正确写法：`control --vmindex 0 launch`**。
>   改对后实例正常开机：`is_process_started: true`、16384 端口监听、
>   `adb connect 127.0.0.1:16384` 后 `adb devices` 出现 `device`，
>   `node tools/android-device.mjs check` 报 `Android 15 / ABI x86_64 / 判定为模拟器 ✅`。
>   仍然成立的是：**launch 的返回码不是就绪信号**，就绪判据只能是端口监听 + `adb devices` 出现 `device`。
> - **2026-10-27 实测已连通**：`mumu-cli control --vmindex 0 launch` 返回 `errcode 0` 后
>   `16384` 进入 `LISTENING`（`MuMuNxDevice.exe`，约 1.5GB 常驻），
>   `adb connect 127.0.0.1:16384` → `adb devices` 出现 `device`；
>   `node tools/device-smoke.mjs` 判 **PASS**（Android 15 / ABI x86_64 / model 22041211A）。
>   与鸿蒙不同：**MuMu 实例独立存活，跨 shell 不受影响**，起一次可反复复用。
> - 附带实测：`mumu-cli info` 单独调用报 `errcode -21 Missing param <vmindex>`，需写 `info --vmindex 0`。

**连接步骤**（端口以实例配置为准，不要照抄任何默认值）：

1. 启动实例：`"<MuMuHome>\nx_main\mumu-cli.exe" control --vmindex 0 launch`（参数顺序见上），或经多开器界面启动；确认实例进入桌面（launch 返回码不是就绪信号）
2. 脚本会自动从 `vm_config.json` 读端口；也可手动 `adb connect 127.0.0.1:<端口>`
3. `adb devices` 应出现一行 `<ip>:<port>\tdevice`（不是 `offline`）

**脚本化入口**（`apps\android` 下，本仓库新增）：

```bash
node tools/android-device.mjs check     # 发现 + 就绪断言 + 打印 Android 版本/ABI/是否模拟器
node tools/android-device.mjs install   # 构建 debug APK 并安装（需先有可用设备）
node tools/android-device.mjs shoot --out test_run/x.png
node tools/android-device.mjs test --class <FQCN>   # connectedDebugAndroidTest
```

失败时统一以退出码 1 + 指名原因的 `❌ <CODE>: <消息>` 收尾（`NO_TARGETS` /
`MUMU_NOT_REACHABLE` / `INSTALL_FAILED` 等），不抛泛化错误。

**构建与安装**（`apps\android` 下）：

```bash
./gradlew :app:assembleDebug          # 产物 app/build/outputs/apk/debug/app-debug.apk
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

**取图**：

```bash
adb exec-out screencap -p > <out>.png
```

**已知**：`apps\android\app\build.gradle.kts` 里 `testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"`，注释提到「Compose 语义动作在 app 进程内派发，不依赖系统触摸注入（ColorOS 会静默丢弃 `adb input tap`）」——设备侧交互走 Compose 语义断言，不要依赖 `adb input tap`。

| 实例名（目录） | CLI index | adb 端口 | 端口来源 | 连通性 |
|---|---|---|---|---|
| `MuMuPlayer-15.0-0` | `0` | `16384` | `configs\vm_config.json` → `vm.nat.port_forward.adb.host_port`（2026-10-27 读得） | ✅ **已连通**（2026-10-27 实测）：`adb connect 127.0.0.1:16384` → `device`；device-smoke 判 **PASS**，截图 `apps\android\test_run\device-smoke-1793100496980.png`（1,406,502 字节） |

> 端口一栏是**配置值**（读 `vm_config.json`），连通性一栏是**实测值**（以 `adb devices` 出现 `device` 为准）。换机或换实例后两栏都要重测——不要照抄本行。

## 构建命令

| 端 | debug 构建 | 产物路径 | cwd |
|---|---|---|---|
| 鸿蒙 | `devecocli build --product default` | `apps\harmony\entry\build\default\outputs\default\entry-default-signed.hap` | `apps\harmony` |
| 安卓 | `.\gradlew :app:assembleDebug` | `apps\android\app\build\outputs\apk\debug\` | `apps\android` |

**鸿蒙测试包**：`devecocli build --modules entry@ohosTest --product default`（约 1min），产物 `entry\build\default\outputs\ohosTest\entry-ohosTest-unsigned.hap`。

## 一条命令跑双端

```bash
node tools/device-smoke.mjs
```

两端依次检查，产出 `test_run\device-smoke-summary.md`。每端三态：**PASS / FAIL / SKIP**。

**SKIP 不等于 PASS**：设备没启动时该端标 SKIP 并在摘要里写明原因与下一步；退出码不因此变 1（未启动是环境状态不是代码缺陷），但摘要显式写「不计为通过」，避免"没验"被读成"验过了"。

可选参数：`--android-install`（安卓额外构建并安装 debug APK）、`--harmony-test`（鸿蒙额外跑 `ohos-test.ps1`）。

> `--harmony-test` 会以脚本默认的 **unsigned** 包路径调用 `ohos-test.ps1`；设备上已装 signed 包时会撞 `code:9568332`，此时应绕开该开关、直接调 `ohos-test.ps1` 并显式传 `-DefaultHapPath` / `-TestHapPath` 指向 signed 包。
>
> 鸿蒙端跑这条命令前，模拟器必须在**同一次 shell 调用内**先启动（见上文「模拟器的存活绑定」）；跨调用复用一定得到 `SKIP`。

## 什么时候必须上设备

**必须**：

- 启动分流（未登录 → 登录页 / 已登录 → 主壳）
- 登录注册全流程
- 训练主链路（预览 → 执行 → 完成摘要）
- 云同步上下行
- 视觉还原核对（像素级）

**不需要**：

- 纯文档、纯脚本、纯注释改动
- 仅类型/接口重命名且已有单测覆盖

## 双端验证的最低要求

改动涉及用户可见行为时，**两端都要在模拟器上跑一遍**。只做一端的必须在交付报告写「仅 \<端\> 验证：原因」，不得静默略过。

## 本文的验证边界

- **鸿蒙段（2026-10-27 实测）**：模拟器清单 `devecocli emulator list` 本机 8 台（含 `Pura 90`）。`devecocli emulator start "Pura 90"` 前台 54–65s 返回 `started successfully`，`hdc list targets -v` 得 `127.0.0.1:5555` / `5557` `TCP Connected`；signed HAP 安装成功（`install bundle successfully`），截图 `apps\harmony\test_run\harmony-smoke\smoke.png`（1,300,321 字节）。
  ⚠️ 该截图是**锁屏界面**——只证明模拟器在跑，**未证明应用已启动**。
- **安卓段（2026-10-27 实测）**：发现链路脚本化并单测覆盖（`apps\android\tools\android-device.test.mjs` 16 例，实测 **16/16 pass**）；设备连通性**已通过**——MuMu 实例开机、`adb connect 127.0.0.1:16384` 后 `adb devices` 出现 `device`，`device-smoke` 判 PASS 并落截图。
- **跨端**：`node tools\device-smoke.mjs` 2026-10-27 跑出双端 **PASS**，摘要 `test_run\device-smoke-summary.md`。
- **仍未验证（不得称为已验）**：应用内启动（鸿蒙截图停在锁屏）、`ohos-test.ps1`（ohosTest 用例）、`android-device.mjs install` 与 `test`（connectedDebugAndroidTest）。
- 本文档只覆盖模拟器路径，真机路径见各端的 release runbook
