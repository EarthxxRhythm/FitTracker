# 安全策略

## 报告漏洞

**不要用公开 issue 报告安全问题。**

请走 GitHub 的私密渠道：[Security Advisories → Report a vulnerability](https://github.com/EarthxxRhythm/FitTracker/security/advisories/new)

报告里请包含：

- 受影响的端（HarmonyOS / Android / 服务端）与版本或提交号
- 复现步骤或 PoC（可以是文字描述，不需要可执行代码）
- 影响判断：能读到什么、能改到什么、需不需要用户交互
- 如果涉及数据，说明涉及哪类数据（训练记录 / 账号标识 / 备份包）

## 响应约定

| 阶段 | 目标时间 |
|---|---|
| 确认收到 | 3 个工作日内 |
| 初步评估（是否成立、严重度） | 7 个工作日内 |
| 修复或缓解方案 | 视严重度，通常 30 天内 |

这是个人维护的项目，时间承诺尽力而为。修复发布后会在 Release notes 与 Advisory 中致谢（除非你要求匿名）。

## 特别需要关注的范围

- **备份包解析**：`contracts/` 定义的 `UserDataBackupPackage` 是两端共用的外部输入，导入路径要能抵御畸形 JSON。
- **云端凭据边界**：`service_role` key 只允许存在于服务端；任何把它下发到客户端的改动都算严重问题。
- **第三方登录回调**：`wxapi.WXEntryActivity` 与鸿蒙侧的登录回调参数校验。
- **本地数据隔离**：跨 `bundleName` / `applicationId` 的数据可见性。

## 已知不可轮换的凭据

`QQ_APP_KEY`（QQ 互联 AppKey）**无法在开放平台后台重置**——受应用资质限制，重置入口不可用。

这意味着它的保护策略不能是"泄露后再轮换"，只能是"确保永不泄露 + 泄露即止损"：

| 措施 | 状态 |
|---|---|
| 只存放于服务端 `server/deploy/thirdparty.env`（`chmod 600`，`.gitignore` 覆盖） | ✅ |
| 绝不注入客户端（Android / HarmonyOS 均不引用） | ✅ |
| 只经 Supabase Edge Function 使用 | ✅ |
| 按内容扫描 git 全历史（`git log -S`），确认从未入库 | ✅ 2026-10-28 |
| 泄露时的唯一止损手段：下架 QQ 登录入口 | — |

同理，`SUPABASE_SERVICE_ROLE_KEY` 一旦泄露可轮换，但两个平台（自托管 Supabase 栈、Edge Function）都要同步改，属于"能换但麻烦"的一类。

**报告这类问题请直接走私密渠道**，不要开公开 issue。

## 不支持的报告

- 依赖版本号过旧但无可利用路径的自动化扫描结果
- 需要物理接触已解锁设备才能触发的场景
- 社交工程、钓鱼邮件类（本项目没有相关面）
