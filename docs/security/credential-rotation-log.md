# 凭据轮换记录

> 只记**时间 / 凭据名 / 原因 / 消费端是否同步 / 验证方式**。
> **绝不要记录值本身，也不要记录值的前缀或长度。**

| 日期 | 凭据 | 原因 | 消费端已同步 | 验证方式 | 执行人 |
|---|---|---|---|---|---|
| 2026-10-28 | QQ_APP_KEY | 曾在聊天中暴露 | **未完成**：首次执行误填 AppID（与 `QQ_APP_ID` 同值、纯数字），已置空，待填入正确 AppKey | 重做后校验「新值 ≠ AppID」且非纯数字 | Earth |

## 轮换周期建议

| 凭据 | 周期 |
|---|---|
| `SUPABASE_SERVICE_ROLE_KEY` | 每 6 个月，或人员变动时 |
| 阿里云 RAM AccessKey | 每 6 个月 |
| QQ / 微信 / AGC 平台密钥 | 每年，或怀疑泄露时立即 |
| `SEND_SMS_HOOK_SECRET` | 随 service_role 一起 |

## 已踩过的坑

| 症状 | 原因 | 处置 |
|---|---|---|
| 替换后 `QQ_APP_KEY` 变成纯数字，且与 `QQ_APP_ID` 同值 | QQ 互联后台 AppID 与 AppKey 并排显示，复制到了 AppID | 重新复制 AppKey；本仓库 `tools/rotate-credential.mjs` 未做格式校验，靠比对两个键发现 |

## 相关文档

- 操作手册：`docs/security/credential-rotation.md`
- 环境变量模板：`server/deploy/.env.template`
- 第三方资质流程：`docs/process/thirdparty-qualification-guide.md`
