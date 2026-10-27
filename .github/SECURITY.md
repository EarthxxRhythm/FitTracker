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

## 不支持的报告

- 依赖版本号过旧但无可利用路径的自动化扫描结果
- 需要物理接触已解锁设备才能触发的场景
- 社交工程、钓鱼邮件类（本项目没有相关面）
