# FitTracker 后端自托管部署手册

> 本目录是「app 后端从 supabase.com 搬到自己服务器」的可复现资产。
> 完整实施计划见 `.rivet/plans/fittracker-后端自建服务器部署-自托管-supabase-数据迁移.md`。
>
> **当前部署状态（2026-10-28 实测）**：服务器 `106.55.37.80`（腾讯云 Lighthouse，Ubuntu 24.04 / 4C4G）
> 13 个容器 + sms-hook + Caddy 稳定运行；`https://api.earthrhythm.cloud` **仅 443 单入口**外网验证通过
> （匿名 401 / 带 key 200 / Let's Encrypt 证书 2027-01-08 到期），临时入口 `:8443` 已于同日退役。
> 数据迁移已于 10-11 完成（快照级），双端切流完成，线上主账号在用（`auth.users` 4 / `public.snapshots` 2）。

## 架构一览

```
Android App ──HTTPS──> Caddy(自动 TLS, --network host) ──┬── /auth/v1 /rest/v1 ──> Envoy 网关(127.0.0.1:8000) ──> GoTrue / PostgREST ──> Postgres
                                                          └── /sms-hook ──────────> sms-hook 服务(127.0.0.1:8787) ──> 阿里云短信
```

服务器布局：

| 路径 | 内容 |
|------|------|
| `/opt/supabase` | 官方栈 git 工作区（`docker/` 下为 compose 与 `.env`） |
| `/opt/supabase/docker/docker-compose.fittracker.yml` | 端口收口 override（api-gw + supavisor） |
| `/opt/fittracker/sms-hook/` | 短信 hook 服务源码（构建镜像用） |
| `/opt/fittracker/sms-hook.env` | 短信服务环境变量（含密钥，`chmod 600`） |
| `/opt/fittracker/caddy/Caddyfile` | HTTPS 反代配置（域名已替换） |
| `/opt/fittracker/backup/` | 每日 pg_dump 备份 + `daily.sh`（cron 03:30） |
| `/opt/fittracker/migrate/` | 迁移脚本与（未来的）dump 文件 |
| `/opt/fittracker/studio-password.txt` | Supabase Studio 管理密码（600） |
| `/opt/fittracker/deploy-src/` | 本目录（部署资产/模板）在服务器上的副本；其中 `Caddyfile` 保留 `api.example.com` 占位符，**不是**运行时配置——运行时在 `/opt/fittracker/caddy/Caddyfile`（域名已替换、无注释） |

## 文件说明

| 文件 | 用途 |
|------|------|
| `sms-hook/{index.ts,aliyun.ts}` | 短信 hook 服务源码（`supabase/functions/send-sms/` 的容器平移版；两份独立维护，改动需同步） |
| `sms-hook/aliyun.test.ts` | 纯函数单测（`deno test`；含 node:crypto 独立对账） |
| `sms-hook/Dockerfile` | 服务镜像（⚠ 基础镜像固定 `denoland/deno:2.9.6`——官方无 `:2` 滚动 tag，见实测记录） |
| `Caddyfile` | HTTPS 反代（替换 `api.example.com` 为实际域名；Caddy 必须 `--network host` 运行） |
| `supabase-override/docker-compose.fittracker.yml` | 端口收口：api-gw(8000) + supavisor(5432/6543) 全部限制为 127.0.0.1 |
| `.env.template` | 环境变量清单（A 段→栈 `.env`；B 段→`sms-hook.env`；不含真值） |
| `migrate/dump.sh` | 旧库导出（roles / schema / data 三段） |
| `migrate/restore.sh` | 新库还原 + 对账（连接串须带 pooler 租户后缀，见文件头注） |
| `migrate/verify.sql` | 对账 SQL（新旧库各跑一次对照） |

## 部署步骤（对应计划的 Wave 1–6）

> **⚠ 先做：Windows → Linux 行尾标准化**。本目录文件在 Windows 上生成（CRLF 行尾）——上传到服务器后先统一转换：
>
> ```bash
> cd /opt/fittracker && find . -type f \( -name '*.sh' -o -name '*.sql' -o -name 'Dockerfile' -o -name 'Caddyfile' -o -name '*.env*' -o -name '*.ts' -o -name '*.yml' \) -exec sed -i 's/\r$//' {} +
> ```

### Wave 1 · 服务器基础

```bash
# Docker（官方 apt 源；国内用腾讯云镜像源更快）
curl -fsSL https://get.docker.com | sh
# 目录
mkdir -p /opt/fittracker/{caddy,sms-hook,backup,migrate/out}
# Docker 权限（免 sudo 操作）：sudo usermod -aG docker ubuntu（重开 ssh 生效；当次会话可用 sg docker -c '…'）
# 防火墙（服务器内 ufw；云侧还有一道——见实测记录 ④）
ufw allow 22,80,443/tcp && ufw enable
# swap：腾讯云 Ubuntu 镜像预置约 2G，实测够用（整套栈稳态内存 ~1.8G/3.6G，swap 几乎不用）
```

### Wave 2 · Supabase 栈

```bash
git clone --depth 1 https://github.com/supabase/supabase /opt/supabase
cd /opt/supabase/docker
cp .env.example .env
sh utils/generate-keys.sh --update-env                 # 官方仓库自带脚本（生成基础密钥）
sg docker -c 'sh utils/add-new-auth-keys.sh --update-env'   # 需 docker 权限（新版 key：sb_publishable_…）

# ① 端口收口：拷贝 override 并启用
cp <本目录>/supabase-override/docker-compose.fittracker.yml ./
#   在 .env 设置：COMPOSE_FILE=docker-compose.yml:docker-compose.fittracker.yml

# ② 短信 hook：编辑 docker-compose.yml（hook 三行为【被注释的字面量】，仅写 .env 无效！）
#   约 241-243 行，取消注释并改为：
#     GOTRUE_HOOK_SEND_SMS_ENABLED: "true"
#     GOTRUE_HOOK_SEND_SMS_URI: "https://api.<域名>/sms-hook"
#     GOTRUE_HOOK_SEND_SMS_SECRETS: "v1,whsec_<与 sms-hook.env 同值>"

# ③ 编辑 .env：SUPABASE_PUBLIC_URL / SITE_URL / DASHBOARD_PASSWORD
sg docker -c 'docker compose config --quiet'   # 校验（含 !override）
sg docker -c 'docker compose up -d'
```

验证：`docker compose ps` 全 healthy；`ss -ltnp | grep -E ':8000|:5432|:6543'` 三行均应为 **127.0.0.1** 前缀。

### Wave 3 · 域名 + HTTPS

DNS：`api.<域名>` A 记录 → 服务器公网 IP。云控制台防火墙放行 **80 与 443**（两个都要！）。然后：

```bash
cp <本目录>/Caddyfile /opt/fittracker/caddy/Caddyfile && vi /opt/fittracker/caddy/Caddyfile  # 替换域名
sg docker -c 'docker run -d --name fittracker-caddy --restart unless-stopped \
  --network host \
  -v /opt/fittracker/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
  -v fittracker_caddy_data:/data -v fittracker_caddy_config:/config \
  caddy:2-alpine'
```

> `--network host` 必须：容器内 127.0.0.1 是容器自身回环；bridge 网络下反代宿主 8000/8787 会全部 502。

验证：外网 `curl https://api.<域名>/auth/v1/health` 匿名 401、带 key 200。
**本地测 TLS 的正确姿势**（直接 `curl https://127.0.0.1` 会因 SNI 不匹配报 `internal error`，那是测试问题不是故障）：
`curl -sk --resolve api.<域名>:443:127.0.0.1 https://api.<域名>/auth/v1/health`

### Wave 4 · 表 / Auth 配置 / 短信服务

```bash
# ① snapshots 表 + RLS（复用仓库迁移文件；经容器内直连执行最稳）
sg docker -c "docker exec -i supabase-db psql -U postgres -d postgres" < <仓库>/supabase/migrations/20261004000000_snapshots.sql

# ② sms-hook 服务（env 只放 B 段内容）
cp -r <本目录>/sms-hook /opt/fittracker/sms-hook
vi /opt/fittracker/sms-hook.env     # SEND_SMS_HOOK_SECRET + 阿里云四项（见 .env.template B 段）
chmod 600 /opt/fittracker/sms-hook.env
cd /opt/fittracker/sms-hook && sg docker -c 'docker build -t fittracker-sms-hook:local .'
sg docker -c 'docker run -d --name fittracker-sms-hook --restart unless-stopped \
  --env-file /opt/fittracker/sms-hook.env -p 127.0.0.1:8787:8787 fittracker-sms-hook:local'

# ③ 重启 auth 使 hook 配置生效
sg docker -c 'cd /opt/supabase/docker && docker compose up -d auth'
```

验证：外网 `POST https://api.<域名>/sms-hook`（无签名）应 401；触发 `/auth/v1/otp` 后手机收到阿里云短信，
`docker logs fittracker-sms-hook` 无 401/阿里云错误。

> ⚠ 短信服务单测：`cd /opt/fittracker/sms-hook && docker run --rm -v "$PWD:/app" -w /app denoland/deno:2.9.6 deno test`

### Wave 5 · 数据迁移

> **⚠ 本 Wave 已失效（2026-10-28 核实）**：旧项目 `ixzozsqaprtquwxzhdsm.supabase.co` 已被删除，
> `db.ixzozsqaprtquwxzhdsm.supabase.co` 与 `ixzozsqaprtquwxzhdsm.supabase.co` 在本机与服务器两侧
> 均返回 `Non-existent domain`，源端已不可达。本流程仅作历史存档。
>
> 实际执行的是**快照级手工迁移**（10-11）：当时旧库仅 1 条快照（1 计划 / 2 次训练 / `preset_ppl`），
> 已并入线上主账号 `5f54f358-197b-4ab0-957f-43f6c9d05271`，其现存快照 7 条 session 的前两条
> 即旧数据（`session_1791545625627`、`session_1791545860849`，10-08 训练）。现存副本归档于
> `/opt/fittracker/migrate/archive/`（权限 600）。

```bash
# 导出（在能连旧库的机器上，需 Node/npx）
cd <本目录>/migrate
OLD_DB_URL="postgres://postgres:<旧密码>@db.<ref>.supabase.co:5432/postgres" ./dump.sh
# 上传 out/ 到 /opt/fittracker/migrate/out/ 后（服务器上）：
NEW_DB_URL="postgres://postgres.your-tenant-id:<新密码>@127.0.0.1:5432/postgres" \
DUMP_DIR=/opt/fittracker/migrate/out ./restore.sh
```

验证：对账三项数字与旧库一致；抽样用户字段一致；旧账号密码可换到 token。
对账不过 → 停下排查（旧库未被动过，可重来）。

### Wave 6 · app 切流

`local.properties`（本机，不进版本库）改为新栈 URL + key → 重新构建 → 真机回归：
手机 OTP（真短信）/ 密码登录 / 注册 / 云同步上下行 / 账号页状态 / 旧快照拉取。
回滚：改回旧项目 URL/key 重建。

## 运维

### 备份（每日 03:30，已装 cron）

`/opt/fittracker/backup/daily.sh`：`docker exec supabase-db pg_dump -Fc` → 原子落盘 → 保留 14 天。
验证备份可读：`docker exec -i supabase-db pg_restore --list < <dump 文件> | head`
（异地拷贝建议：定期把 dump 拉回本机或对象存储。）

### 升级（官方栈）

```bash
cd /opt/supabase && git pull
cd docker && git diff HEAD@{1} -- .env.example docker-compose.yml   # 核对官方变更
sg docker -c 'docker compose pull && docker compose up -d'
```

升级前先手动跑一次备份。注意：`docker-compose.yml` 内有本地改动（hook 三行）——`git pull` 冲突时需人工合并
（若官方已把 hook 改为变量插值，可回归 `.env` 管理）；override 文件与 `.env` 不受 git 管理，无冲突。

### 故障排查

| 症状 | 排查 |
|------|------|
| OTP 收不到短信 | `docker logs fittracker-sms-hook`（验签 401 / 阿里云错误码）；`docker logs supabase-auth` 看有无 hook 调用（没有 → compose hook 三行没生效） |
| 外部 443 超时 | 云控制台防火墙是否放行了 **443**（80 与 443 是两条独立规则）；服务器内部 `ss -ltnp \| grep :443` 应有 caddy |
| TLS `internal error` | 多半是 SNI 不匹配的测试姿势问题——用 `curl --resolve 域名:443:127.0.0.1 https://域名/…` 复验 |
| app 请求 401/403 | `apikey`/`Bearer` 与栈生成 key 是否一致（网关侧）；RLS 拒绝（数据侧） |
| 内存吃紧 | `docker stats`；停用非必需服务（Studio/Analytics/Vector，compose override），或升配 |

### 安全清单

- `.env` / `sms-hook.env` 权限 600，永不进版本库；Studio 密码在 `/opt/fittracker/studio-password.txt`（600）。
- 端口收口：8000（网关）/ 5432 / 6543（pooler）/ 8787（sms-hook）全部仅绑 127.0.0.1；
  ufw 只放行 22/80/443。⚠ Docker 发布端口绕过 ufw——收口靠 override 的绑定层（不可只依赖防火墙）。
- 密钥轮换：`utils/generate-keys.sh --update-env` / `utils/add-new-auth-keys.sh --update-env` → `docker compose up -d`；
  hook secret 两端（docker-compose.yml ↔ sms-hook.env）同步换。
- 阿里云 AK 轮换：RAM 控制台「创建 AccessKey」→ 更新 `sms-hook.env` → `docker restart fittracker-sms-hook`。
- 迁移 dump 文件含全部用户数据，验证后删除或加密留存。现存副本已归档至 `/opt/fittracker/migrate/archive/`（权限 600）；`old_db_url.txt`（含已失效库的明文密码）已于 2026-10-28 删除。

## 实测记录（执行期发现，与初版计划的偏差）

| # | 发现 | 处置 |
|---|------|------|
| ① | `denoland/deno:2` 镜像不存在（官方无 `:2` 滚动 tag） | Dockerfile 固定 `2.9.6` |
| ② | `supavisor`（连接池）默认绑 0.0.0.0:5432/6543（compose ps 实测发现） | override 追加收口段 |
| ③ | 宿主 psql 经 pooler 连接须带租户后缀（否则 `ENOIDENTIFIER`）；`POOLER_TENANT_ID` 默认值即 `your-tenant-id` | 迁移脚本与文档统一为 `postgres.your-tenant-id` |
| ④ | 云防火墙 80/443 是**两条独立规则**（只放 80 时外部 443 超时） | Wave 3 步骤明确两条都要放行 |
| ⑤ | GOTRUE_HOOK_SEND_SMS_* 在 compose 中为被注释字面量（写 `.env` 无效） | 文档改为「编辑 docker-compose.yml」 |
| ⑥ | Caddy 容器 bridge 网络下反代宿主服务全 502 | 统一 `--network host` |
| ⑦ | swap：平台预置 ~2G 已足够（未按计划再加 4G） | 保留平台配置，稳态观测内存充裕 |
| ⑧ | GoTrue 短信 OTP 默认有效期仅 **60 秒**，与阿里云模板文案「5分钟内有效」不符（真人/自动化都极易超时） | compose 第 197 行改字面量 `GOTRUE_SMS_OTP_EXP: "300"` 并 `docker compose up -d auth`；实测 OTP 生成后 **120 秒**提交仍返回 200（旧值下 62 秒即 `otp_expired`/403） |
| ⑨ | 取 OTP 明文做免真机验证：宿主 `lo` 抓不到 sms-hook 流量（Docker 端口映射不经该接口）；`nohup`/`setsid`/`systemd-run` 三种方式的后台 tcpdump 都活不过 ssh 会话结束 | 用 `sudo nsenter -t $(docker inspect -f '{{.State.Pid}}' fittracker-sms-hook) -n tcpdump -i any -s 0 'tcp port 8787' -w /tmp/otp.pcap`，且**抓包与触发必须在同一 ssh 会话内**；必须 `-w` 写盘（stdout 走管道会全缓冲，读不到内容） |
| ⑩ | 旧 supabase.com 项目 `ixzozsqaprtquwxzhdsm` 在快照级迁移完成后被删除，`db.*` 与 API 域名两侧均 `Non-existent domain` | 迁移判为已完成；`old_db_url.txt` 已删（凭据失效且属敏感信息），快照副本移入 `archive/`（600）；Wave 5 与状态行已同步标注 |
| ⑪ | `supabase.json` 与 `supabase.json.disabled` 内容完全一致（MD5 `68bfa1a2…`，同一分钟生成），系启停操作残留 | 删除 `.disabled`；`CloudEnvironment.getBackend()` 只判 `supabase.json` 存在性，冗余副本会在后端切换时造成误判 |
| ⑫ | `:8443` 曾是 443 就绪前的临时入口（Caddy 同站点双监听 `api.earthrhythm.cloud, https://api.earthrhythm.cloud:8443`），双端凭据均写死该端口 | **2026-10-28 已退役**：双端改 443 并重新打包（HAP 37 MB / apk 30 MB，产物内 URL 已核对）；Caddyfile 去除 8443；`ufw delete allow 8443/tcp`。443 复验 health 200 / snapshots 200 / sms-hook 401，8443 外部超时。⚠ 腾讯云控制台防火墙的 8443 规则需在控制台另行删除 |
| ⑬ | 单文件 bind mount 下 `sed -i` 修改 `/opt/fittracker/caddy/Caddyfile`，容器内 `/etc/caddy/Caddyfile` 仍是旧 inode（MD5 不同）；`caddy reload` 报成功、`caddy validate` 报 Valid，但 8443 继续监听 | 改配置后必须 `docker restart fittracker-caddy` 才对容器生效；`caddy validate` 校验的是容器内旧文件，**不可**作为生效判据。判据应为「宿主与容器 MD5 一致」+「`ss -ltn` 无 8443」 |
