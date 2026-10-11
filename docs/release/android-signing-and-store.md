# 安卓上架准备（签名 · 备案材料 · 渠道）

> 建立：2026-10-10。对应配置：`app/build.gradle.kts` 的 `signingConfigs` / `buildTypes.release`，以及 `local.properties` 的 `release.*` 四项。
> 配套：鸿蒙侧 `docs/release/release-build-runbook.md` §12（上架材料待办）与 `docs/release/beian-materials.md`（备案取证）。

## 0. 当前状态

| 项 | 值 | 证据落点 |
| --- | --- | --- |
| applicationId | `com.earthrhythm.fittracker`（与鸿蒙 bundleName 对齐） | `app/build.gradle.kts` |
| namespace | `com.fittracker.app`（代码资源命名空间，**有意与上架身份分离**） | 同上 |
| 应用名 | 「菲特」 | `app/src/main/res/values/strings.xml` |
| versionName / versionCode | `0.1.0` / `1` | `app/build.gradle.kts` |
| minSdk / targetSdk | 24 / 37 | 同上 |
| 云后端 | Supabase（迁移自托管见 `.rivet/plans/fittracker-后端自建服务器部署-自托管-supabase-数据迁移.md`） | `supabase/`、`deploy/` |
| **签名** | 已生成并接入：`C:\Users\19308\fittracker-release.jks`，alias `fittracker`，有效至 2054-02-25 | 见 §1、§2 |
| release 包 | 已产出首个**签名**包 `app-release.apk`（13.0 MB，2026-10-10），`apksigner verify` 通过 | 见 §3 |
| 法务文本 | 已就绪（品牌名「菲特（FitTracker）」） | `app/src/main/assets/legal/` |

## 1. 生成 release keystore（一次性，永久生效）

> ⚠️ **上架后不能更换签名** —— 换签名等于换了应用身份，老用户无法覆盖升级，只能下架重发。生成前先想清楚，生成后立刻离线备份。

```bash
keytool -genkeypair -v \
  -keystore ~/fittracker-release.jks \
  -alias fittracker \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=<姓名或主体名>, OU=, O=EarthRhythm, L=<城市>, ST=<省>, C=CN"
```

要点：

- 有效期给足（`-validity 10000` ≈ 27 年）。Google Play 对新增应用的密钥有效期有下限要求，短了会被拒。
- **keystore 文件与两个密码必须离线备份**（丢了无法再更新已上架应用）。
- keystore **不得入库**；本仓库已有的 `local.properties` 本就用于存放不入库的本机配置。

> **本机生成记录（2026-10-10）**：keystore 已生成于 `C:\Users\19308\fittracker-release.jks`（PKCS12，2656 B），alias `fittracker`，主体 `CN=FitTracker, O=EarthRhythm, C=CN`，RSA 2048，有效期至 2054-02-25。证书指纹（与最终 APK 签名一致）：
> - SHA-256：`B5:1D:C8:15:59:26:B5:A9:32:8F:CC:C3:C8:89:45:09:76:B9:26:1F:64:11:0F:EE:67:D1:DD:1E:0E:18:15:34`
> - SHA-1：`59:10:66:20:CC:68:32:4F:26:4C:88:FB:4B:D0:4A:04:BF:A3:24:5A`
> - MD5：`1A:DF:C7:30:DF:59:B9:0B:82:1E:44:FF:91:7F:20:A7`

## 2. 接入配置（写进 `local.properties`，不进版本库）

```properties
release.storeFile=C:/Users/<你>/fittracker-release.jks
release.storePassword=<keystore 密码>
release.keyAlias=fittracker
release.keyPassword=<key 密码>
```

`app/build.gradle.kts` 读取这四项：

- 四项齐全 → release 构建自动使用该签名；
- 任一缺失 → **不签名**，构建照常通过（避免"配置缺失即构建失败"）。

路径请写**绝对路径**（模块内的相对路径会以 `app/` 为基准解析）。

## 3. 构建与验签

```bash
./gradlew :app:assembleRelease
ls app/build/outputs/apk/release/            # 签名成功时为 app-release.apk（不再带 -unsigned）
apksigner verify --print-certs app/build/outputs/apk/release/app-release.apk
```

`apksigner` 位于 `$ANDROID_HOME/build-tools/<版本>/apksigner.bat`（Git Bash 下需带 `.bat` 后缀）。

> **实测记录（2026-10-10）**：本配置骨架的两条分支都已验证 ——
> 未配置时产出 `app-release-unsigned.apk`；注入临时 keystore 后产出 `app-release.apk`，且 `apksigner --print-certs` 正常读出证书 DN 与 SHA-256/SHA-1/MD5 指纹。验证用的临时 keystore 已删除，未留在仓库或本机。

## 4. 备案材料（安卓侧，与鸿蒙侧是两套）

APP 备案要求提交「应用公钥 + MD5 指纹」。安卓侧取自 **release 签名证书**：

```bash
# 从 keystore 读（与最终 APK 一致）——DN / SHA-256 / SHA-1
keytool -list -v -keystore ~/fittracker-release.jks -alias fittracker | grep -E "SHA256|SHA1|Owner"

# MD5：JDK 17 的 keytool -list -v 已不再输出 MD5 行，须用 openssl 从证书补算
keytool -exportcert -rfc -keystore ~/fittracker-release.jks -alias fittracker -storepass <密码> \
  | openssl x509 -noout -fingerprint -md5

# 或从已签名 APK 读（DN + SHA-256/SHA-1/MD5 一次给全，最省事）
apksigner verify --print-certs app/build/outputs/apk/release/app-release.apk
```

注意：

- 取**签名证书自身**的指纹，不要取证书链中其他证书（鸿蒙侧在调试证书上踩过这个坑）。
- 鸿蒙侧材料基于 `.cer`（`docs/release/beian-materials.md`），与安卓的 keystore **指纹完全不同** —— 两个平台各自提交一套。
- 备案主体、接入商、服务器/域名与鸿蒙侧共用；**趁备案那次一并登记两个平台**，避免后续走变更。

## 5. 渠道提审要点

| 渠道 | 关键差异 |
| --- | --- |
| 华为应用市场（Android 区） | 与鸿蒙版是**两个独立的应用条目**，分别提审 |
| 应用宝 / 小米 / OPPO / vivo | 各自开发者账号与资质审核，材料口径相近 |
| Google Play | AAB 格式、targetSdk 门槛、Data Safety 表单；新个人账号有测试者数量与时长要求 |

共同材料：APP 备案号、软件著作权（国内多数市场要求，**以各市场实际要求为准**）、隐私政策与用户协议链接、图标与截图（须用 release 包实拍）。

## 6. 缺口与后续

- [x] 生成 release keystore 并写入 `local.properties`（§1、§2）
- [x] 产出首个签名 release 包并验签（§3）
- [x] 提取备案用的公钥与 MD5 指纹（§4）—— 见 §1 生成记录
- [ ] 备份 keystore 与密码到离线介质
- [ ] 决定是否开启 R8（当前 `isMinifyEnabled = false`；部分渠道要求加固）
- [ ] 各渠道开发者账号与软著
- [ ] 用 release 包实拍市场截图
