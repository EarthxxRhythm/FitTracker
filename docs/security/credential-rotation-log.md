# 凭据轮换记录

> 只记**时间 / 凭据名 / 原因 / 消费端是否同步 / 验证方式**。
> **绝不要记录值本身，也不要记录值的前缀或长度。**

| 日期 | 凭据 | 原因 | 消费端已同步 | 验证方式 | 执行人 |
|---|---|---|---|---|---|
| 2026-10-28 | QQ_APP_KEY | 曾在聊天中暴露 | 已**修正填写错误**（首次误填为 AppID）。**未重置**——QQ 互联受应用资质限制，不提供 AppKey 重置入口 | 形态校验通过：含字母、非纯数字、≠ AppID、无空白。⚠ **原值仍然有效，泄露风险未消除**，只能靠"仅服务端持有、绝不下发客户端"控制 | Earth |

## 尚未轮换

| 凭据 | 触发条件 |
|---|---|
| 阿里云 RAM AccessKey | 有空时；支持双活，零停机 |
| `SUPABASE_SERVICE_ROLE_KEY` + `SEND_SMS_HOOK_SECRET` | 真正启用第三方登录 / 短信链路时 |
| 微信 AppSecret | 尚未申请 |

> **AGC Client Secret / api_key 不需要轮换。** 2026-10-28 AGC 链路整体移除
> （`AgcAuthProvider` / `AgcCloudSnapshotStore` 删除，`CloudEnvironment` 收为 Supabase 单实现），
> `apps/harmony/cloud/agc/` 与本地 `agconnect-services.json` 副本均已删除，**没有任何消费端**。
> 轮换一个没人用的 secret 没有意义；真要处理只需确认仓库与磁盘上都不存在该文件。

## 已踩过的坑

| 症状 | 原因 | 处置 |
|---|---|---|
| 替换后 `QQ_APP_KEY` 变成纯数字，且与 `QQ_APP_ID` 同值 | QQ 互联后台 AppID 与 AppKey 并列，复制到了 AppID | 重新复制 AppKey；`tools/rotate-credential.mjs` 已加拒绝规则 |

## 相关文档

- 操作手册：`docs/security/credential-rotation.md`
- 环境变量模板：`server/deploy/.env.template`
- 第三方资质流程：`docs/process/thirdparty-qualification-guide.md`
