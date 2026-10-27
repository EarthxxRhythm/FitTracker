# 登录验证规范

> **层级**：L2 展开
> **最后核对**：2026-10-27
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
| 2 | 沙盒降级 | 仅 UI 与本地状态流转，**验不到云链路** | 无 AGC 配置 / 无 Supabase 配置 |
| 3 | 临时跳过 | 什么都没验证 | 前两条都不可用 |

**选 2 或 3 时，交付报告必须显式标注**，格式见文末。

## 自部署栈（事实源：`server\deploy\README.md`）

| 项 | 值 | 证据 |
|---|---|---|
| 地址 | `https://api.earthrhythm.cloud` | `server\deploy\README.md:5-7` |
| 服务器 | 腾讯云 Lighthouse `106.55.37.80`（Ubuntu 24.04 / 4C4G） | 同上 |
| 外网验证 | 匿名 401 / 带 key 200 / Let's Encrypt 证书通过（2026-10-10 实测） | 同上 |
| 短信链路 | GoTrue → `GOTRUE_HOOK_SEND_SMS_URI=/sms-hook` → sms-hook 服务 → 阿里云短信 | 同文件「架构一览」 |
| OTP 有效期 | `GOTRUE_SMS_OTP_EXP = 300`（秒） | 同文件实测记录 ⑧：默认 60s 下 62 秒即 `otp_expired`/403 |
| **当前缺口** | **「数据迁移与本机 app 切流待执行」** | `server\deploy\README.md:5-7` |

**关键**：自部署栈已上线，但 app 侧还没切过去。要验证真实链路，先按 `server\deploy\README.md` 的「Wave 6 · app 切流」把两端配置指向新栈。

## 取 OTP 明文（免真机收短信）

```bash
sudo nsenter -t $(docker inspect -f '{{.State.Pid}}' fittracker-sms-hook) \
  -n tcpdump -i any -s 0 'tcp port 8787' -w /tmp/otp.pcap
```

**三个必须**（来自 `server\deploy\README.md` 实测记录 ⑨）：

1. 必须用 `nsenter` 进 sms-hook 容器的网络命名空间——宿主 `lo` 抓不到（Docker 端口映射不经该接口）
2. 抓包与触发 OTP **必须在同一个 ssh 会话内**——`nohup` / `setsid` / `systemd-run` 三种后台方式都活不过会话结束
3. 必须 `-w` 写盘——stdout 走管道会全缓冲，读不到内容

## 双端配置入口

| 端 | 配置文件 | 字段 | 入不入库 |
|---|---|---|---|
| 鸿蒙 | `AppScope\resources\rawfile\agconnect-services.json` | AGC 全套 | ❌ `.gitignore` 明确排除 |
| 安卓 | `local.properties` | `supabase.url` / `supabase.publishableKey` | ❌ `.gitignore` 明确排除 |

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

- 自部署栈的「已上线」结论引用自 `server\deploy\README.md` 的 2026-10-10 实测记录，**本会话未重新验证服务器可达性**
- app 切流未完成，所以「优先走自部署栈」目前需要先做切流，不能直接跑
- 沙盒降级路径验不到 AGC / Supabase 的真实鉴权与 RLS 行为
