# FitTracker Release / Build Runbook

## 1. 目的

这份 runbook 只覆盖 FitTracker 的构建与发布工程面，用来回答 4 个问题：

- 当前仓库能稳定产出什么交付物
- release / signing 现在真实卡在哪里
- 发布与构建工程师建议用什么命令复跑
- 后续把正式签名接进来时，应改哪些接入点

本文件不覆盖业务功能验收，不替代 `docs/mvp-closeout.md` 的 MVP 功能收官记录。

## 2. 当前真实状态

截至 2026-06-06，仓库的发布口径仍是“内部验收包”，不是正式签名发布包。

已确认的现状：

- DevEco / hvigor / PackageHap 基础链路可用，`PackageHap -> spawn java ENOENT` 已通过 `tools/deveco-env.ps1`、`tools/java.cmd`、`tools/node-java-shim.cjs` 收住。
- 当前可稳定产出 unsigned HAP：
  - `entry/build/default/outputs/default/entry-default-unsigned.hap`
  - `entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap`
- 根配置 `build-profile.json5` 中声明了 `release` build mode，但 `app.signingConfigs` 仍为空数组。
- `default` product 仍绑定 `signingConfig: "default"`，说明 release 配置口子已经留出，但还没有真实可用的 signing material。
- `entry/build-profile.json5` 目前只定义了 release 期的模块级构建选项，尚未承担正式签名职责。
- 应用标识仍处于样板状态：
  - `AppScope/app.json5` 当前 `bundleName` 为 `com.example.fittracker_opencode`
  - `vendor` 为 `example`

结论：**当前仓库具备稳定 unsigned 构建能力，但不具备正式 signed release 交付能力。**

## 3. 当前建议命令

### 3.1 只读 readiness 检查

```powershell
node tools/check-release-readiness.mjs
```

用途：

- 快速确认 release build mode、signing 配置占位、环境脚本、unsigned 产物、样板应用标识是否处于可继续推进状态
- 当 signing 尚未接入时，脚本会以非零退出码明确提示“release not ready”

### 3.2 基础构建环境准备

```powershell
powershell -ExecutionPolicy Bypass -File tools/deveco-env.ps1
```

用途：

- 统一设置 `JAVA_HOME`
- 规范化 `Path` / `PATH`
- 将 DevEco JBR、hvigor、toolchain 与 repo 内 Java shim 补进当前会话

### 3.3 当前可复跑的 unsigned 构建

```powershell
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p module=entry@default -p product=default --no-parallel
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p module=entry@ohosTest -p product=default --no-parallel
```

说明：

- 这是当前仓库唯一已经被验证过的构建交付口径
- 若出现 Java / PackageHap 相关问题，先重跑 `tools/deveco-env.ps1`

## 4. 正式签名发布仍缺的前置条件

以下项目没有补齐前，不应宣称仓库已具备 release 签名交付能力。

### 4.1 应用身份前置项

- 正式 `bundleName`
- 正式 `vendor`
- 对应的 AppGallery Connect 应用条目

当前 `com.example.fittracker_opencode` / `example` 只适合作为开发样板值，不适合作为正式发布身份。

### 4.2 签名材料前置项

- HarmonyOS 发布证书材料
- 与应用身份匹配的 profile / provisioning 材料
- 本机安全存放策略

当前仓库内未发现可直接用于 release signing 的签名材料文件，也不应把这些材料提交进仓库。

### 4.3 构建配置前置项

- 在 `build-profile.json5` 中补齐真实 `signingConfigs`
- 明确 `default` product 在 release 期实际引用的 signing config 名称
- 约定签名材料来源是“本机绝对路径”还是“环境变量注入到本地配置”

### 4.4 验收前置项

- 一次真实 signed HAP 构建记录
- 一次 signed 包安装 / 启动验证
- 一份 release closeout 或发布交付记录

## 5. 建议的后续接入点

本仓库后续接正式签名时，建议只改下列工程接入点：

- `build-profile.json5`
  - 补齐 `app.signingConfigs`
  - 保持 `products` 与 `buildModeSet` 的职责在根配置层
- `entry/build-profile.json5`
  - 继续只承载模块级 release 构建选项，如混淆、资源策略
- `tools/deveco-env.ps1`
  - 继续负责 DevEco / Java / hvigor 运行环境
  - 不建议把证书内容硬编码进脚本
- 新的本机私有配置载体
  - 可以是本机私有文件，也可以是环境变量映射
  - 必须默认不入库

建议原则：

- 证书、profile、密码、别名等敏感信息不提交仓库
- 仓库只保留接入点、校验脚本、命令说明和故障定位文档

## 6. 当前不建议做的事

- 不要在签名材料未齐时，先把 `build-profile.json5` 写成伪完整配置
- 不要把证书或密码以明文文件形式提交到仓库
- 不要把 MVP 的 unsigned closeout 文档直接改写成“已签名发布完成”

## 7. 外部依赖清单

正式签名发布至少依赖以下外部条件：

- 本机安装可用的 DevEco Studio / hvigor / HarmonyOS SDK
- 华为开发者账号
- AppGallery Connect 应用
- 发布证书与 profile 材料
- 用于签名的本机安全存储位置与访问权限

## 8. 与现有文档的关系

- `docs/mvp-closeout.md`：记录 MVP 内部验收包，不记录正式签名发布完成
- 本文档：记录发布与构建工程面的真实状态、命令、缺口与后续接入点

