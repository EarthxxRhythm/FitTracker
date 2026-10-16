# 公安联网备案「新增 APP」表单填写材料

> 生成：2026-10-16。平台：全国互联网安全管理服务平台（`beian.mps.gov.cn`）→ 业务办理 → APP 业务 → 新增 APP。
> 对应截图字段逐字校准（2026-10-16 实拍表单）；所有值取自当前工作树实测，非记忆。
> 配套：`docs/release/beian-materials.md`（工信部 ICP 备案取证）、`docs/release/app-platform-form-materials.md`（开放平台表单）。

## 0. 两条必须先纠正的默认值

| 字段 | 表单默认 | **应改为** | 依据 |
| --- | --- | --- | --- |
| 相关前置许可 | 默认选中「**是**」 | **「否」** | 菲特属普通工具类，无专项许可要求（同 ICP 备案口径，见 `beian-materials.md` §6.1③：官方 FAQ `faqs-appgallery-95`「仅提供普通工具…无需前置许可」） |
| 应用类型 | 未选 | **计算机应用类 G** | G 类说明「手机软件、应用工具」；本应用为健身训练记录工具，非生活服务类 C（C 类为出行/配送/教育等连接用户与服务的平台型） |

> 选「是」会展开「前置许可种类」并要求上传许可材料，与事实不符。选「否」后前置许可种类无需填写。

## 1. 逐字段填写值

| # | 表单字段 | 是否必填 | 填写值 |
| --- | --- | --- | --- |
| 1 | 运行平台 | * | **已填**：Android、鸿蒙（正确。本项目无 iOS 端） |
| 2 | 应用 logo | * | 上传 `design\07_app_icon\market\icon-1024.png`（1024×1024 PNG，102.0 KB，符合「≤2MB、仅 1 个」） |
| 3 | 应用类型 | * | **计算机应用类 G** |
| 4 | 应用包名 | * | `com.earthrhythm.fittracker` |
| 5 | 市值 | 否 | 留空 |
| 6 | 月活用户量 | 否 | `0` |
| 7 | 注册用户总量 | 否 | `0` |
| 8 | 相关前置许可 | * | **否** |
| 9 | 前置许可种类 | — | 不填（第 8 项选「否」后无需填） |
| 10 | 运行截图 | * | 见 §2（最多 6 个，单个 ≤5MB，png/jpeg/jpg） |
| 11 | 功能描述 | * | 见 §3 |

### 包名说明

应用包名输入框提示「多个请以逗号分隔，如 com.app.abc1.com.app.abc2」——**本项目只需填一个**：

- 鸿蒙 `bundleName` = `com.earthrhythm.fittracker`（`apps\harmony\AppScope\app.json5:3`）
- 安卓 `applicationId` = `com.earthrhythm.fittracker`（`apps\android\app\build.gradle.kts:52`）

两端包名一致，已对齐（见 `app-platform-form-materials.md` §1），无需逗号分隔。

> 注：安卓 `namespace = com.fittracker.app`（同文件 `:43`）只决定代码 R 类包名，与上架/备案身份无关，**不要填**。

## 2. 运行截图（3–6 张）

### 规格

- 格式 png/jpeg/jpg，单个文件不超过 5MB，最多 6 个文件。
- 现有 `test_run\` 下真机截图均为竖屏 1320×2856、0.13–0.25MB，**格式与体积全部满足**。

### ✅ 两端运行截图已实拍（2026-10-16）

两平台运行截图已在本机实拍完成，落在 `test_run\beian-screenshots\`（gitignore 目录，素材不入库）。

| 平台 | 设备 | 系统 | 分辨率 | 目录 |
| --- | --- | --- | --- | --- |
| **鸿蒙** | Pura 90（模拟器） | HarmonyOS 6.1.1(24) | 1320×2856 | `test_run\beian-screenshots\harmony\` |
| **安卓** | PKB110（真机 USB） | Android 16 | 1256×2760 | `test_run\beian-screenshots\android\` |

**鸿蒙端清单**（6 张，均含真实数据）：

| 文件 | 页面 | 内容（UI 树实测） |
| --- | --- | --- |
| `01-home.jpeg` | 首页 | 下肢B / 5 动作 / 45 分钟 / 本周 2/4 天 |
| `02-plan.jpeg` | 计划页 | 二分化（上下肢）/ 上肢A / 动作清单 5 项（4×8-12 等） |
| `03-review.jpeg` | 回顾页 | 本周 2 次 / 75 分钟 / 体重 -0.8kg / 训练节奏柱图 / 肌肉地图 |
| `04-profile.jpeg` | 我的页 | 谱尼 / 本周 75 分钟 / 4 次 / 消耗 1240 千卡 / 连续 6 天 |
| `05-exercise.jpeg` | 动作库 | 杠铃/哑铃/器械分组，动作图示完整 |
| `00-launch.jpeg` | 登录页 | 手机验证码 / 邮箱密码 + 华为/微信/QQ 三入口（**当前真实界面**） |

**安卓端清单**（4 张，均含真实数据）：

| 文件 | 页面 | 内容 |
| --- | --- | --- |
| `01-home.png` | 首页 | 下肢 / 33% 进度 / 3 动作 / 本周 1/3 次 |
| `02-plan.png` | 计划页 | 增肌基础计划 / 胸部日 / 动作清单 |
| `03-review.png` | 回顾页 | 本周 +18% / 1 次 / 体重 -0.8kg / 训练节奏 / 肌肉地图 |
| `04-profile.png` | 我的页 | 林默 / 训练 4 次 / 1240 千卡 / 成就两条 |

### 复现方式（可重跑）

```bash
# 鸿蒙（模拟器；release 包注入不了 seed，须用 debug 包）
cd apps/harmony
devecocli emulator start "Pura 90"
# 切 debug 签名后构建（release 包下 isDebuggablePackage()=false，seed 被门禁挡）
cp ~/.ohos/release-keys/build-profile.debug-backup.json5 build-profile.json5
devecocli build --product default --build-mode debug
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b com.earthrhythm.fittracker --ps devSeed review_metrics --ps testMode sandbox
hdc shell uitest dumpLayout -p /data/local/tmp/l.json && hdc file recv /data/local/tmp/l.json .   # 取真实坐标
hdc shell uinput -T -c <x> <y>                                                                  # 点击导航
hdc shell snapshot_display -f /data/local/tmp/s.jpeg && hdc file recv /data/local/tmp/s.jpeg out.jpeg
# 拍完务必恢复 release 配置
cp ~/.ohos/release-keys/build-profile.release-local.json5 build-profile.json5

# 安卓（真机）
adb shell monkey -p com.earthrhythm.fittracker -c android.intent.category.LAUNCHER 1
adb exec-out screencap -p > out.png
```

### 两个关键实测事实（复现时必知）

1. **鸿蒙 release 包注入不了演示数据**：`PencilSplashPage.ets:122` 的判据是 `testMode === 'sandbox' && this.isDebuggablePackage()`，而 `isDebuggablePackage()` 读 `bundleInfo.appInfo.debug`（`:35-42`）——release 包恒为 false。**必须构建 debug 包**才能让 `devSeed` 生效。
2. **`devSeed` 取值决定数据形态**：`DeviceSeedService.ets:40/44/48` 三个分支——
   - `review_metrics`：带训练记录与复盘指标（**推荐**，回顾页/我的页才有数据）
   - `today_flow`：只有今日训练卡（首页有数据，**回顾页仍为空态**）
   - `demo_data`：内容目录演示数据

> ⚠️ 注：本次为了拍鸿蒙功能页，临时把 `build-profile.json5` 切成 debug 签名并构建，完成后**已恢复 release 配置并复跑 release 构建验证通过**（`BUILD SUCCESSFUL`）。该文件处于 `git update-index --skip-worktree` 状态，git 视角无差异。

### 存量 9 月截图（已确认不可用，勿混用）

`test_run\` 根目录下的真机截图拍摄于 **2026-09-07 ~ 09-14**，其后代码有多次影响界面的改动（`1f61e0c` 移除同步设置、`882b18f` 换第三方登录入口、`e2022b0`/`f0a85cf` 改错误呈现）——`login.jpeg` 显示「微信 / Apple」（当前为华为/微信/QQ）、`settings.jpeg` 含已移除的「训练数据同步」开关。**本文件 §2 上方的新拍截图已取代它们。**

## 3. 功能描述（可直接复制）

```
菲特是一款运行于 HarmonyOS / Android 的健身训练记录工具，围绕"记录—复盘—调整"的训练闭环设计。主要功能：一、训练记录：训练预览 → 逐组录入次数与重量 → 完成摘要的完整链路，记录结构化保存。二、训练计划：内置二分化（上下肢）、三分化、四分化、五分化共 4 套预置计划，可浏览计划组详情、预览训练日的动作与组次安排并一键启用。三、训练复盘：历史训练列表与单次训练详情、周训练趋势、动作个人纪录（PR）下钻、肌肉分布统计。四、动作库：内置动作列表与详情，支持按部位/肌群两级筛选、按器械筛选与收藏；动作演示素材随安装包内置，运行时不联网下载。五、身体数据：记录体重、体脂等数据并形成随时间的变化记录。六、账号与云同步（可选）：支持手机验证码、邮箱密码、华为账号三种登录方式，登录后数据以整包快照形式同步至华为端云一体化服务（AGC）云数据库，云端数据按用户 ID 隔离；未配置云端凭据时自动进入本地演示模式，不发起网络请求。七、数据备份与恢复：支持导出 JSON 备份包与导入恢复。八、设置：体重单位、语言、周开始日、训练提醒、声音与震动、训练中屏幕常亮等，并含隐私说明与退出登录。数据默认保存在设备本机，不强制注册账号，未登录时全部本地功能可离线使用；应用仅申请网络访问与振动两项权限，不申请位置、通讯录、相机、麦克风等敏感权限。
```

> 口径来源：`docs\release\software-copyright-form.md` §11（软著申请表「软件的主要功能」，已按 `main_pages.json`、`TrainingPlanService.ets`、`module.json5` 实测校准）。与 ICP 备案填的「服务内容：健身训练记录工具」一致。

## 4. 与本项目其他备案/表单材料的区别

| 材料 | 平台 | 用途 | 本文件关系 |
| --- | --- | --- | --- |
| ICP 备案（工信部） | 华为云/腾讯云 | 拿备案号 | 前置；通过后才有本表（公安备案） |
| **公安联网备案** | 全国互联网安全管理服务平台 | 本文件 | 依据《计算机信息网络国际联网安全保护管理办法》，ICP 备案成功后**开通之日起 30 日内**办理 |
| 开放平台注册表单 | QQ 互联等 | 应用注册 | 独立；`app-platform-form-materials.md` |
| 软著申请 | 中国版权保护中心 | 著作权登记 | 独立；`software-copyright-form.md` |
