# 第三方组件与许可声明

> **层级**：L2 法律合规
> **最后核对**：2026-10-28
> **上位文档**：LICENSE（Apache-2.0）
> **适用端**：双端 + 服务端

本仓库 **自身的源代码** 以 Apache-2.0 授权（见 [LICENSE](LICENSE)）。
下表列出本仓库**包含或依赖**的第三方组件及其许可。

## 一、随仓库分发的二进制 / 资源

| 组件 | 文件位置 | 许可 | 说明 |
|---|---|---|---|
| Geist Mono | `apps/harmony/entry/src/main/resources/rawfile/fonts/GeistMono-Variable.ttf` | SIL OFL-1.1 | Copyright 2024 The Geist Project Authors (https://github.com/vercel/geist-font.git) |
| Inter | `apps/harmony/entry/src/main/resources/rawfile/fonts/Inter-Variable.ttf` | SIL OFL-1.1 | Copyright 2016 The Inter Project Authors (https://github.com/rsms/inter) |
| Noto Sans SC | `apps/harmony/entry/src/main/resources/rawfile/fonts/NotoSansSC-Variable.ttf` | SIL OFL-1.1 | © 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source' |
| 腾讯 QQ 互联 Android SDK | `apps/android/app/libs/open_sdk_3.5.19_r9483ffc7_lite.jar` | 腾讯专有许可 | 由 QQ 互联开放平台官方分发，**不适用本仓库的 Apache-2.0**。仅为让 Android 端开箱可编译而保留。详见第六节 |
| Lucide 图标 | `apps/harmony/entry/src/main/resources/rawfile/pencil-lucide-*.svg` | ISC | Copyright (c) Lucide Contributors |
| 动作演示素材（101 条 GIF） | `rawfile/exercise-gifs-photo/`、`apps/android/app/src/main/assets/exercise-gifs-photo/` | Unlicense（公共领域） | 来源 [free-exercise-db](https://github.com/yuhonas/free-exercise-db)，由 `build-exercise-gifs-photo.mjs` 合成三段乒乓 GIF。Unlicense 不强制署名，此处为来源登记 |
| Gradle Wrapper | `apps/android/gradle/wrapper/gradle-wrapper.jar` | Apache-2.0 | Gradle 官方分发的包装器 |

三个字体文件的 OFL 全文见 `apps/harmony/entry/src/main/resources/rawfile/fonts/OFL.txt`。

## 二、HarmonyOS 端依赖（构建期从 ohpm 获取，不随仓库分发）

| 组件 | 版本 | 许可 |
|---|---|---|
| `@tencent/wechat_open_sdk` | ^1.0.23 | 腾讯微信 OpenSDK 许可 |
| `@tencent/qq-open-sdk` | ^1.0.4 | 腾讯 QQ 互联 SDK 许可 |
| `@ohos/hypium`（测试） | 1.0.25 | Apache-2.0 |
| `@ohos/hamock`（测试） | 1.0.0 | Apache-2.0 |

HarmonyOS SDK 本身（`@kit.*`、ArkUI、ArkTS 编译器）由 DevEco Studio 提供，受华为 HarmonyOS SDK 许可约束，**不随本仓库分发**。

## 三、Android 端依赖（构建期从 Maven 获取，不随仓库分发）

| 组件 | 版本 | 许可 |
|---|---|---|
| Android Gradle Plugin | 9.4.1 | Apache-2.0 |
| Kotlin | 2.4.20 | Apache-2.0 |
| AndroidX Core / Lifecycle / Activity / Navigation / DataStore / AppCompat / Work | 见 `apps/android/gradle/libs.versions.toml` | Apache-2.0 |
| Jetpack Compose BOM + Material3 | 2026.09.00 | Apache-2.0 |
| kotlinx-serialization-json | 1.11.0 | Apache-2.0 |
| Coil（含 coil-gif） | 2.7.0 | Apache-2.0 |
| 微信 Android OpenSDK | 6.8.40 | 腾讯微信 OpenSDK 许可 |
| JUnit 4 | 4.13.2 | EPL-1.0 |
| Robolectric | 4.16 | Apache-2.0 |

## 四、服务端（可选组件，位于 `server/`）

| 组件 | 许可 |
|---|---|
| Supabase（自托管部署、CLI、Edge Functions Runtime） | Apache-2.0 |
| 阿里云短信服务 SDK 调用代码（本仓库自行编写） | Apache-2.0 |
| Caddy（反向代理配置示例） | Apache-2.0 |

## 五、商标

| 商标 | 归属 | 本仓库中的使用 |
|---|---|---|
| 微信 / WeChat | 腾讯控股有限公司 | `pencil-social-wechat.svg` 仅用于登录入口的指示性标识 |
| QQ | 腾讯控股有限公司 | `pencil-social-qq.svg` 同上 |
| 华为 / HUAWEI / HarmonyOS | 华为技术有限公司 | `pencil-social-huawei.svg` 同上；项目名称中提及 HarmonyOS 仅为说明运行平台 |

上述商标归各自权利人所有。本仓库不主张任何商标权，也不表示权利人对本项目的认可或背书。
Apache-2.0 第 6 条**不授予**商标使用许可；如需在衍生作品中使用上述商标，请自行取得授权。

## 六、关于腾讯 QQ SDK 二进制的特别说明

`apps/android/app/libs/open_sdk_3.5.19_r9483ffc7_lite.jar` 是腾讯通过 [QQ 互联开放平台](https://connect.qq.com/) 面向第三方开发者分发的官方 SDK 二进制，其使用与再分发受腾讯自身许可条款约束，**不受本仓库 Apache-2.0 许可覆盖**。

保留该文件的原因：`apps/android/app/src/main/java/com/fittracker/app/ui/screens/auth/LoginScreen.kt` 在编译期引用了 `com.tencent.tauth.Tencent` / `IUiListener` / `UiError`，缺失该 JAR 时 Android 端无法编译。

如果你要分发本项目的衍生二进制、或将本仓库用于商业场景，建议：

1. 自行从 QQ 互联开放平台下载该 SDK，并核对当时的许可条款；
2. 或删除该 JAR、移除 Android 端的 QQ 登录代码后自行构建（HarmonyOS 端的 `@tencent/qq-open-sdk` 通过 ohpm 获取，不受此限制）。

若权利人提出异议，本项目将把该文件移出仓库，改为文档指引下载。

---

如发现遗漏或有许可疑问，请开 issue 或直接联系维护者。
