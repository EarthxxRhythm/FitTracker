# 登录验证规范

> **层级**：L2 展开
> **最后核对**：2026-10-28
> **上位文档**：`AGENTS.md`（冲突以 L1 为准）
> **状态**：现行
> **路径基准**：文中 `server\…`、`docs\…` 相对仓库根；`AppScope\…`、`local.properties` 相对各端工程根
> **适用端**：双端

## 为什么需要这份文档

登录是本项目**唯一**会触发真实外部网络（短信）的链路。它容易在验证时被跳过，也容易用「注册页能打开」冒充「登录可用」——后者是假绿，比不验更糟。

本文件规定验证的优先顺序、自部署栈的事实状态、以及跳过时的标注义务。

## 验证优先级

| 优先级 | 路径 | 能验证到什么 | 使用条件 |
|---|---|---|---|
| 1 | **自部署栈真实链路** | 全链路：客户端 → Caddy → GoTrue → sms-hook → 阿里云短信 | 服务器可达且 app 已完成切流 |
| 2 | 沙盒降级 | 仅 UI 与本地状态流转，**验不到云链路** | 无 Supabase 配置（鸿蒙缺 `supabase.json`、安卓 `SUPABASE_URL` 为空串 → 沙盒降级、UI 明示演示模式） |
| 3 | 临时跳过 | 什么都没验证 | 前两条都不可用 |

**选 2 或 3 时，交付报告必须显式标注**，格式见文末。

## 自部署栈（事实源：`server\deploy\README.md`）

| 项 | 值 | 证据 |
|---|---|---|
| 地址 | `https://api.earthrhythm.cloud`（**仅 443**；`:8443` 临时入口已于 2026-10-28 退役） | `server\deploy\README.md` 状态行 |
| 服务器 | 腾讯云 Lighthouse `106.55.37.80`（Ubuntu 24.04 / 4C4G） | 同上 |
| 外网验证 | 匿名 401 / 带 key 200 / 证书 Let's Encrypt 有效至 2027-01-08（**2026-10-28 复验**） | 同上实测记录 ⑫、⑬ |
| 短信链路 | GoTrue → `GOTRUE_HOOK_SEND_SMS_URI=/sms-hook` → sms-hook 服务 → 阿里云短信 | 同文件「架构一览」 |
| OTP 有效期 | `GOTRUE_SMS_OTP_EXP = 300`（秒） | 同文件实测记录 ⑧：默认 60s 下 62 秒即 `otp_expired`/403 |
| 数据与切流 | **均已完成**：数据迁移 10-11（快照级），双端切流 10-25 前完成 | 同上状态行 |

**关键**：自部署栈与双端配置都已就绪，可直接验证真实链路，**无需再做切流**。

## 取 OTP 明文（免真机收短信）

```bash
sudo nsenter -t $(docker inspect -f '{{.State.Pid}}' fittracker-sms-hook) \
  -n tcpdump -i any -s 0 'tcp port 8787' -w /tmp/otp.pcap
```

**三个必须**（来自 `server\deploy\README.md` 实测记录 ⑨）：

1. 必须用 `nsenter` 进 sms-hook 容器的网络命名空间——宿主 `lo` 抓不到（Docker 端口映射不经该接口）
2. 抓包与触发 OTP **必须在同一个 ssh 会话内**——`nohup` / `setsid` / `systemd-run` 三种后台方式都活不过会话结束
3. 必须 `-w` 写盘——stdout 走管道会全缓冲，读不到内容

## 免短信登录：预置 E2E 账号

自部署栈里有两组 `@earthrhythm.test` 账号（`.test` 是 RFC 2606 保留 TLD，永不可能是真实邮箱），**刻意保留供测试用，不要清理**（2026-10-28 用户确认）：

| 账号 | 用途 | 2026-10-28 状态 |
|---|---|---|
| `e2e-harmony@earthrhythm.test` | 主流程（登录 / 同步上下行 / 重启持久化） | 邮箱已确认、有密码、未封禁；持一条 12.5 KB 快照 |
| `e2e-harmony-b@earthrhythm.test` | 双账号越权（RLS）对照 | 邮箱已确认、有密码、未封禁；无快照 |

**价值**：绕过短信 OTP，直接邮箱密码登录验证云链路——不消耗阿里云短信配额、不需要真机、不受 OTP 300 秒窗口限制。

**密码不入本文**（避免明文入库）。当前记录在 `apps\harmony\test_run\cloud-debug\manual-test-guide.md`；⚠ 该路径位于 `test_run\`（易失目录，且被凭据盘点排除），清理后需在 Dashboard 重置密码。

**统计口径**：`auth.users` 计数包含这两条（当前 4 个账号中 2 个为测试账号）。对外报数或数据核对须排除，条件为 `email is null or email not like '%@earthrhythm.test'`。

## 双端配置入口

| 端 | 配置文件 | 字段 | 入不入库 |
|---|---|---|---|
| 鸿蒙（当前生效） | `AppScope\resources\rawfile\supabase.json` | `url` / `publishableKey` | ❌ `.gitignore` 排除 |
| 鸿蒙（历史残留，不再启用） | `AppScope\resources\rawfile\agconnect-services.json.disabled`（2026-10-28 复验：源码树内已不存在，仅旧构建产物缓存可能残留） | AGC 身份 / 云数据库配置，随 AGC 云后端一并作废 | ❌ 同上 |
| 安卓 | `local.properties` | `supabase.url` / `supabase.publishableKey` | ❌ 同上 |

缺配置时的行为：鸿蒙 `CloudEnvironment` 探测不到 → 沙盒降级、UI 明示演示模式；安卓 `SUPABASE_URL` 为空串 → 云端功能优雅禁用。

`server\deploy\.env.template` 是环境变量清单模板（不含真值），真值存服务器 `/opt/fittracker/*.env`（权限 600）。

## 禁止

- **不得用「注册页能打开」「登录页渲染正常」冒充「登录可用」**——这两个只证明路由通，不证明认证链路通
- **不得把 OTP 明文、服务密钥写进提交信息、文档或测试代码**
- **跳过验证时不得省略报告中的标注**——静默略过视为违规

## 交付报告的标注格式

```markdown
登录验证：<已执行 / 已跳过>
- 路径：<自部署栈 / 沙盒降级 / 未执行>
- 结果：<成功 / 失败 / N/A>
- 原因（跳过或失败时必填）：<服务器不可达 / 切流未完成 / 短信通道故障 / ...>
```

## 本文的验证边界

- 自部署栈状态已于 **2026-10-28** 从外部复验：443 上 health 200 / snapshots 200 / sms-hook 401，证书有效至 2027-01-08；`:8443` 临时入口同日退役
- app 切流已完成，可直接走「优先自部署栈」路径
- 沙盒降级路径验不到 Supabase 的真实鉴权与 RLS 行为
