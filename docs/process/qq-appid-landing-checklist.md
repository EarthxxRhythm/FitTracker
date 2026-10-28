# QQ 互联审核通过后的落位清单

> 背景：QQ 互联应用已审核通过（2026-10-15 用户确认）。
> 用途：把 QQ AppID / AppKey 从平台填入项目三处落位点。
> 状态：**等待用户提供 AppID 与 AppKey**（Agent 无法从代码或网络获取账号私有凭据）。

---

## 1. 你需要提供两个值

从 [QQ 互联管理中心](https://connect.qq.com/manage.html) → 应用管理 → 你的应用 → 详情页，抄取：

| 参数 | 形态 | 用途 |
| --- | --- | --- |
| **AppID** | 纯数字串（如 `123456789`） | 客户端拉起授权 + 服务端换票 + **鸿蒙 scheme host** |
| **AppKey** | 32 位十六进制字符串 | **仅服务端**换票使用（不下发客户端） |

> ⚠ **AppKey 属密钥**：只填服务端 Secrets，**不要**放进客户端配置、不要贴到聊天里。
> AppID 非密钥（会出现在 scheme 声明中），可安全提供。

---

## 2. 三处落位点（提供后我来改，或你自行填）

### ① 鸿蒙：`apps/harmony/entry/src/main/module.json5`（当前是占位符）

```json5
// 现状（L73-78）：
{
  "scheme": "qqopenapi",
  "host": "<QQ_APP_ID>",          // ← 替换为真实 AppID
  "pathRegex": "\\b(auth|share)\\b"
}

// 改为：
"host": "你的QQ_AppID",
```

**为什么必须改**：QQ 官方明确警告——host 填错会导致 QQ 无法回调（授权后回不到应用）。
该值同时用于 scheme 匹配，必须与 QQ 平台登记的 AppID 完全一致。

> ⚠ 这是**唯一需要改代码的地方**，且该文件**入库**。AppID 非密钥，可入库。

### ② 鸿蒙：`apps/harmony/AppScope/resources/rawfile/` 下的 `thirdparty.json`（需本地新建；仓库中不再存在该文件）

该文件**不入库**（`.gitignore:62` 已有 `**/thirdparty.json` 规则，实测生效）。

复制模板 `thirdparty.example.json` 并填真值：

```json
{
  "wechatAppId": "wx_your_wechat_app_id",
  "qqAppId": "你的QQ_AppID",
  "huaweiClientId": "your_huawei_client_id"
}
```

> 微信 / 华为的 AppID 若还没拿到，可先留模板占位值——`ThirdPartyConfig` 对空/占位值
> 会返回空串，对应通道自动降级为「暂未开通」，不影响 QQ 通道使用。

### ③ 安卓：`apps/android/local.properties`（需追加一行）

该文件**不入库**。当前只有 supabase 两项，追加：

```properties
qq.appId=你的QQ_AppID
```

> 安卓侧不需要 AppKey——它在服务端换票时使用。
> 微信同理：`wechat.appId=wx...`（拿到后补）。

---

## 3. 服务端（部署时填，不在本次）

`server/deploy/.env.template` 的 C 段已有占位：

```properties
QQ_APP_ID=<QQ互联 AppID 数字串>
QQ_APP_KEY=<QQ互联 AppKey>
```

部署换票函数时通过 `npx supabase secrets set` 注入。**AppKey 只在这里出现**。

---

## 4. 改完后如何验证

| 层 | 验证方式 | 现在能否跑 |
| --- | --- | --- |
| 鸿蒙编译 | `cd apps/harmony && devecocli build --product default` | ✅ 能（改完即可跑） |
| 安卓编译 | `cd apps/android && ./gradlew compileDebugKotlin` | ✅ 能 |
| scheme 声明正确性 | 检查 module.json5 的 host 与 QQ 平台 AppID 逐字一致 | ✅ 能（人工比对） |
| **QQ 授权真实回调** | 真机点「QQ 登录」→ 切 QQ → 授权 → 回应用 | ⛔ **需真机 + 已配置的 AppID** |
| **服务端换票** | 端侧拿 authCode → 服务端换 openid | ⛔ 需部署换票函数 |

---

## 5. 顺带：微信那条线还没通

QQ 审核通过了，但**微信开放平台仍未申请**（`docs/process/thirdparty-qualification-guide.md` §4）：

- 微信需要**开发者资质认证 300 元/年**（微信登录属需认证的高级能力）
- 移动应用创建需填 Bundle ID + identifier，审核 1–7 工作日
- 还有 debug/release **双 appIdentifier** 的坑（见该手册 §1）

华为账号那条线**已就绪**（AGC 配置已在库），只需确认 Account Kit 已启用并取 Client ID/Secret。
