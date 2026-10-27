# 凭据轮换记录

> 只记**时间 / 凭据名 / 原因 / 消费端是否同步 / 验证方式**。
> **绝不要记录值本身，也不要记录值的前缀或长度。**

| 日期 | 凭据 | 原因 | 消费端已同步 | 验证方式 | 执行人 |
|---|---|---|---|---|---|
| 2026-10-28 | QQ_APP_KEY | 曾在聊天中暴露 | 已更新 `server/deploy/thirdparty.env`（首次误填 AppID 已重做） | 形态校验通过：含字母、非纯数字、≠ AppID、无空白。端到端换票待函数部署后验证 | Earth |

## 尚未轮换

| 凭据 | 触发条件 |
|---|---|
| AGC Client Secret / api_key | 仓库推上线前（当前 `agconnect-services.json` 为 `.disabled`，云链路停用） |
| 阿里云 RAM AccessKey | 有空时；支持双活，零停机 |
| `SUPABASE_SERVICE_ROLE_KEY` + `SEND_SMS_HOOK_SECRET` | 真正启用第三方登录 / 短信链路时 |
| 微信 AppSecret | 尚未申请 |

## 已踩过的坑

| 症状 | 原因 | 处置 |
|---|---|---|
| 替换后 `QQ_APP_KEY` 变成纯数字，且与 `QQ_APP_ID` 同值 | QQ 互联后台 AppID 与 AppKey 并列，复制到了 AppID | 重新复制 AppKey；`tools/rotate-credential.mjs` 已加拒绝规则 |

## 相关文档

- 操作手册：`docs/security/credential-rotation.md`
- 环境变量模板：`server/deploy/.env.template`
- 第三方资质流程：`docs/process/thirdparty-qualification-guide.md`
