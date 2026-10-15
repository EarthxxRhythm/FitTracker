# APP 开放平台「移动应用创建」表单填写材料

> 用途：开放平台（华为 AGC / 应用宝 / 各渠道）创建移动应用时，`资料填写` 步骤所需的三平台信息。
> 编制：2026-10-14。**所有值均从当前工作树与落盘材料核实**，非记忆。
> 对应截图字段：`Android开发信息` / `HarmonyOS开发信息`（iOS 本项目无，不勾选）

---

## 0. 先看结论：可直接复制区

### Android 开发信息

| 表单字段 | 填写值 |
| --- | --- |
| 安装包名称（包名） | `com.earthrhythm.fittracker` |
| 安装包签名 | 见 §2（**需按指纹粘贴，不是填文件**） |

### HarmonyOS 开发信息

| 表单字段 | 填写值 |
| --- | --- |
| AppLinking | **留空**（本项目未启用 AppLinking，见 §3 的说明） |
| BundleName | `com.earthrhythm.fittracker` |
| 安装包签名 | 见 §2 的鸿蒙指纹区 |

### 应用图标

上传 `design/07_app_icon/market/icon-1024.png`（1024×1024，104 KB）
或 `icon-216.png`（216×216，17.6 KB）——**表单要求 ≥100×100，两者都满足**。

---

## 1. 包名 / BundleName

| 项 | 值 | 证据 |
| --- | --- | --- |
| Android applicationId | `com.earthrhythm.fittracker` | `apps/android/app/build.gradle.kts`（`defaultConfig.applicationId`） |
| Android namespace | `com.fittracker.app` | 同上（**有意分离**：namespace 只决定代码 R 类包名，与上架身份无关） |
| HarmonyOS bundleName | `com.earthrhythm.fittracker` | `apps/harmony/AppScope/app.json5` |

**三个平台建议填同一个包名**（本项目已对齐），便于统一管理与备案。

> ⚠ 若历史上已用别的包名在其它市场注册过，需保持与首次注册一致——包名是应用身份，不可随意变更。

---

## 2. 安装包签名（本节是重点）

### 2.1 Android 侧

**签名材料位置（实测）**：`D:\文档\FitTracker-Android\fittracker-release.jks`

> ⚠ **与文档记录不符，需注意**：`docs/release/android-signing-and-store.md` §1 记载的路径是
> `C:\Users\19308\fittracker-release.jks`，但该路径下**文件不存在**（已实测）。
> 实际文件在 `D:\文档\FitTracker-Android\` 下。**填写前请先确认这是同一份 keystore**。

**keystore 元信息**（来自 `docs/release/android-signing-and-store.md` §1 的生成记录）：

| 项 | 值 |
| --- | --- |
| alias | `fittracker` |
| 类型 | PKCS12 |
| 主体 | `CN=FitTracker, O=EarthRhythm, C=CN` |
| 算法 | RSA 2048 |
| 有效期至 | 2054-02-25 |

**证书指纹**（表单「安装包签名」栏通常填 SHA-256 或 MD5）：

```
SHA-256：B5:1D:C8:15:59:26:B5:A9:32:8F:CC:C3:C8:89:45:09:76:B9:26:1F:64:11:0F:EE:67:D1:DD:1E:0E:18:15:34
SHA-1  ：59:10:66:20:CC:68:32:4F:26:4C:88:FB:4B:D0:4A:04:BF:A3:24:5A
MD5    ：1A:DF:C7:30:DF:59:B9:0B:82:1E:44:FF:91:7F:20:A7
```

> **填写前强烈建议自行复核**（因为 §2.1 的路径不一致已暴露出文档与事实的漂移）：
> ```
> keytool -list -v -keystore "D:/文档/FitTracker-Android/fittracker-release.jks" -alias fittracker
> ```
> 用输出的 SHA-256 / MD5 与上表比对，一致再填。**上架后不能更换签名**，填错代价极高。

### 2.2 HarmonyOS 侧

**证书材料位置**：`C:\Users\19308\.ohos\release-keys\fittracker_release.cer`（证书链 3 张）

**备案 / 表单填写的指纹**（取自 **Leaf 证书**，`docs/release/beian-materials.md` §1）：

| 项 | 值 |
| --- | --- |
| 证书主体 | `C=CN, O=李凡, OU=1794157958125343233, CN=李凡(1794157958125343233)\Release` |
| 证书有效期 | 2026-10-09 → **2029-10-09** |
| MD5 指纹 | `AB:4C:9F:9B:DD:DB:4A:87:07:75:D9:A7:14:7F:41:B5` |
| SHA-1 指纹 | `3D:0B:DA:19:19:DE:13:89:6E:16:74:4B:AC:21:57:44:85:56:E3:04` |
| SHA-256 指纹 | `13:04:C8:51:87:8A:07:24:D2:D0:C8:82:EF:28:D5:7E:75:93:92:D2:AA:13:8E:4F:98:6F:DB:E5:A3:AD:D6:67` |

**公钥（PEM，部分平台要求）**：

```text
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEd2YsCJEbpDcNaIciyUGg0Ucvlrgp
ewsd22gLJmPZsZO/9ysTy3e2DpGh+eE3hPZBPdBeTyr/jkBOz6flqsxplQ==
-----END PUBLIC KEY-----
```

> ⚠ **务必取 Leaf**（证书链最后一张）。取到 Root 或中间 CA 的指纹不通用——项目此前在调试证书上踩过这个坑（见 `beian-materials.md` §3）。

> ⚠ **两个平台的指纹完全不同**（鸿蒙基于 ECC 证书、安卓基于 RSA keystore），各自独立提交，不可混用。

---

## 3. AppLinking 字段（HarmonyOS）

**本项目当前未启用 AppLinking，此栏建议留空。**

依据（实测）：
- `apps/harmony/entry/src/main/module.json5` 中**无** `appLinking` 相关声明；
- 现有 `skills` 声明只有两类：`entity.system.home`（桌面入口）与 `qqopenapi`（QQ 授权回调，见 §4）；
- 项目全仓无 AppLinking 域名配置与 `.well-known/assetlinks` 服务端文件。

> 若表单**强制必填**，可先填应用官网域名 `https://api.earthrhythm.cloud`（现有自托管后端域名）。
> 但注意：AppLinking 生效需要服务端配置 `assetlinks.json`，**仅填域名不会真正启用**——
> 若未来需要「点击链接直达 App 内页面」，需另行立项（服务端 + 端侧配置）。

---

## 4. module.json5 中已有的 scheme 声明（填表时的参考，非表单字段）

第三方登录已占用以下 scheme（不影响上架，但备案/审核若问「应用使用了哪些 scheme」可据此回答）：

| scheme | 用途 | 出处 |
| --- | --- | --- |
| `weixin` | 判断微信是否安装 | `module.json5` querySchemes |
| `wxopensdk` | 跳转微信授权 | 同上 |
| `https` | QQ SDK 内部跳转 | 同上 |
| `qqopenapi` | 接收 QQ 授权回调 | `module.json5` skills（`host` 待填 QQ AppID） |

---

## 5. 应用图标素材

| 文件 | 尺寸 | 大小 | 适用 |
| --- | --- | --- | --- |
| `design/07_app_icon/market/icon-1024.png` | 1024×1024 | 104 KB | 优先（清晰度最佳） |
| `design/07_app_icon/market/icon-1024.webp` | 1024×1024 | 11.8 KB | WEBP 限制 ≤100KB，满足 |
| `design/07_app_icon/market/icon-216.png` | 216×216 | 17.6 KB | 备选 |
| `design/07_app_icon/market/icon-216.webp` | 216×216 | 2.4 KB | 备选 |

**图标设计说明**（供填写「图标说明」或审核问询时使用）：
进度环 PURE——270° 翡翠色弧（`#50ECA7`）+ 缺口中央里程碑点，墨黑微光晕底；寓意训练进度与目标达成。

**生成管线可复现**：`design/07_app_icon/make_market_icon.py`，母版 SVG 源为 `master_bg.html` / `master_fg.html`。
（注：`master_bg.html` / `master_fg.html` 当前有未提交改动，属你的资产，未触碰。）

---

## 6. 三个平台的口径差异（避免填错）

| 项 | Android | HarmonyOS |
| --- | --- | --- |
| 包名/标识 | 安装包名称 = applicationId | BundleName = bundleName |
| 签名 | RSA keystore 的证书指纹 | ECC 证书（Leaf）的指纹 + 公钥 |
| 额外字段 | 无 | AppLinking（本项目留空） |
| 应用市场 | 华为应用市场（Android 区）**独立条目** | 与前者是两个应用条目，分别提审 |

---

## 7. 未核实项（诚实清单）

| # | 事项 | 状态 |
| --- | --- | --- |
| 1 | `D:\文档\FitTracker-Android\fittracker-release.jks` 是否就是文档所指的那份（指纹是否与 §2.1 表格一致） | **未验证**——尝试用常见密码读取失败（`BadPaddingException`），需你用真实密码跑一次 `keytool -list -v` 确认 |
| 2 | `local.properties` 是否已配置 release 签名 | **未接入**——实测只有 `supabase.url` / `supabase.publishableKey` 两项，无 `release.*` 四项。若要以 release 签名打包，需先补齐（见 `android-signing-and-store.md` §2） |
| 3 | 华为 AGC 创建应用表单是否要求额外字段（如 AppLinking 必填、权限说明） | 未验证——各平台表单随版本变化，以你实际打开的表单为准 |
| 4 | iOS 开发信息 | 本项目无 iOS 端，**不勾选** |
