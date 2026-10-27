# 本地第三方 SDK 目录

## open_sdk_3.5.19_r9483ffc7_lite.jar（腾讯 QQ 互联 Android SDK）

**用途**：`app/build.gradle.kts` 中以 `implementation(files("libs/open_sdk_3.5.19_r9483ffc7_lite.jar"))` 引入，供 `LoginScreen.kt` 的 QQ 登录使用。

**许可**：腾讯专有许可，**不属于**本项目的 Apache-2.0。见仓库根 `THIRD-PARTY-NOTICES.md` 第六节。

**替换 / 获取方式**：

1. 打开 [QQ 互联开放平台](https://connect.qq.com/)，用开发者账号登录；
2. 创建或进入应用 → 下载 Android SDK；
3. 取其中的 `open_sdk_<版本>_<哈希>_lite.jar`，覆盖本目录同名文件或新建后同步修改 `app/build.gradle.kts` 第 163 行的文件名；
4. 清理并重建：`./gradlew :app:clean :app:assembleDebug`。

**如果你不需要 QQ 登录**：

删除该 JAR 并移除 `com.fittracker.app.ui.screens.auth.LoginScreen.kt` 中引用 `com.tencent.tauth.*` 的代码段（约 492-515 行）即可编译。微信登录不受影响——它通过 Maven 依赖 `com.tencent.mm.opensdk:wechat-sdk-android` 获取。

**版本兼容**：升级 SDK 后请同时核对 `app/build.gradle.kts` 与 `AndroidManifest.xml` 中与 QQ 相关的 `<queries>` / activity 声明。
