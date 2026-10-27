# 凭据轮换手册

> **层级**：L2 运维
> **最后核对**：2026-10-28
> **上位文档**：`AGENTS.md`（L1）
> **适用端**：服务端 / 双端构建

轮换凭据最常出的错不是「换错了值」，而是**顺序错了导致服务中断**，或者**换完旧值还躺在某个文件里**。本文按可执行顺序写。

## 0. 先判断：这次到底要不要换

标准只有一条：**这个值有没有离开过你的机器？**

| 情形 | 结论 |
|---|---|
| 出现在 git 历史 / 公开仓库 | 必须换 |
| 出现在聊天、截图、工单、日志 | 必须换 |
| 只在本机被 gitignore 的文件里 | 不急，按周期换 |
| 从未填过值（空占位） | 不用换 |

### 2026-10-28 实测的当前分布

对工作区 3216 个文件做过全量值比对（已排除 .git / build / node_modules / test_run）：

| 凭据 | 工作区内出现位置 | 状态 |
|---|---|---|
| `QQ_APP_KEY` | 仅 `server/deploy/thirdparty.env`（untracked） | 该文件自述「曾在聊天中暴露」→ **需轮换** |
| `AGC_CLIENT_SECRET` / `AGC_API_KEY` | 仅 `rawfile/agconnect-services.json.disabled`（untracked） | 随 APK / 截图外流过则需轮换 |
| `QQ_APP_ID` | 4 处（local.properties、thirdparty.json、module.json5、thirdparty.env） | **非密钥**，可公开，不用换 |
| `SUPABASE_URL` | 7 处 | URL 非密钥，不用换 |
| `WECHAT_APP_SECRET` | 未配置 | 不用换 |
| `ALIYUN_ACCESS_KEY_*` | 仅服务器 | 视暴露情况 |

**服务器上的副本不在上表内**（本机无法扫描）。轮换后必须在服务器上再 grep 一次旧值。

## 1. 两种轮换模式（决定顺序）

### A 类：平台支持新旧并存 → 先建后删，零停机

适用：阿里云 RAM AccessKey、Supabase `service_role`、`SEND_SMS_HOOK_SECRET`

1. 平台新建一个
2. 写进配置
3. 重启 / 重新部署
4. 验证通过
5. 禁用旧的，观察 1-2 天再删除

### B 类：重置即失效 → 必须在同一窗口内连续做完

适用：QQ AppKey、AGC Client Secret

1. 先把配置文件、部署命令、验证方式全部准备好（不要边点边找）
2. 平台重置
3. 立刻写入配置
4. 立刻推送 / 重新部署
5. 立刻验证

中间任何一步停太久，对应登录就是坏的。

## 2. 逐项操作

### 2.1 QQ_APP_KEY（B 类）

**平台入口**：<https://connect.qq.com/manage.html> → 应用管理 → 我的应用 → 应用信息 → 基础信息 → AppKey 右侧「重置」

**消费方**：`server/supabase/functions/thirdparty-exchange/index.ts:58`，仅服务端。

**客户端不受影响**：客户端只持 `QQ_APP_ID`（`entry/src/main/module.json5` 的 skills host、Android 的 `BuildConfig.QQ_APP_ID`）。所以轮换对本机已装的 App 没有影响。

**执行**：

```powershell
# 1) 把新 AppKey 存到一个临时文件（不要粘进终端，避免进入命令历史）
notepad .rotate.tmp          # 只写一行：新 AppKey 的值，保存

# 2) 脚本替换进 thirdparty.env、扫描残留、写轮换记录，然后自动删除临时文件
node tools/rotate-credential.mjs QQ_APP_KEY

# 3) 推送到 Edge Function Secrets（自托管或云端按你的部署目标选一个）
npx supabase secrets set --env-file server/deploy/thirdparty.env --project-ref <ref>

# 4) 重新部署函数并验证
npx supabase functions deploy thirdparty-exchange --project-ref <ref>
```

验证方式见 `4。

### 2.2 AGC Client Secret / api_key（B 类）

**平台入口**：<https://developer.huawei.com/consumer/cn/service/josp/agc/index.html> → 我的项目 → 项目设置 → 常规 → Client Secret →「重置」

**两个消费端必须同时改**：

| 消费端 | 位置 |
|---|---|
| 服务端换票 | `thirdparty.env` 的 `HUAWEI_CLIENT_SECRET` → 推 Supabase secrets |
| 客户端 SDK | 重新下载 `agconnect-services.json`，替换 `apps/harmony/AppScope/resources/rawfile/` 下那份（当前文件名带 `.disabled` 后缀，说明云链路是停用状态） |

⚠ 客户端那份里的 `client_secret` 形如 `[!00B4...]`，那是 AGC 的加密封装，**原样保留方括号与感叹号**，不要手改。

**执行**：

```powershell
notepad .rotate.tmp                       # 新 Client Secret
node tools/rotate-credential.mjs HUAWEI_CLIENT_SECRET
npx supabase secrets set --env-file server/deploy/thirdparty.env --project-ref <ref>
# 再把 AGC 控制台重新下载的 agconnect-services.json 放回 rawfile/
```

### 2.3 SUPABASE_SERVICE_ROLE_KEY（A 类）

**入口**：自托管栈，服务器上

```bash
cd /opt/supabase/docker
sh utils/add-new-auth-keys.sh --update-env     # 生成新 key，新旧并存
```

⚠ **不要用 `generate-keys.sh`**：它会连 `JWT_SECRET` 一起重生成，所有现存会话与 anon key 立即失效。区分见 `server/deploy/.env.template` 的 A 段说明。

拿到新值后：写入 `thirdparty.env` → 推 secrets → 验证换票 → 再删旧的。

### 2.4 阿里云 RAM AccessKey（A 类，唯一标准双活）

**入口**：<https://ram.console.aliyun.com/manage/ak> → 用户 → 目标子账号 → 创建 AccessKey（每用户最多 2 个，够轮换）

```bash
# 服务器
vim /opt/fittracker/sms-hook.env        # 换成新的 AK/SK
docker compose -f /opt/supabase/docker/docker-compose.yml up -d --no-deps sms-hook
# 触发一次验证码登录确认短信可达
# 回 RAM 控制台：先「禁用」旧 AccessKey，观察 1-2 天，再「删除」
```

顺手核对该子账号权限只到 `AliyunDypnsFullAccess`，不要给 AdministratorAccess。

### 2.5 SEND_SMS_HOOK_SECRET（A 类）

自己生成，不来自任何平台：

```bash
openssl rand -base64 32      # 结果前加 v1,whsec_
```

两处必须一致：

- `/opt/supabase/docker/docker-compose.yml` 的 `GOTRUE_HOOK_SEND_SMS_SECRETS`
- `/opt/fittracker/sms-hook.env` 的 `SEND_SMS_HOOK_SECRET`

Gotrue 的 hook secrets 支持逗号分隔多值，可短暂写 `v1,whsec_旧,v1,whsec_新` 过渡，验证通过再删旧的。

## 3. 轮换后必做

### 3.1 搜旧值残留

`rotate-credential.mjs` 会自动扫描工作区。服务器需单独扫：

```bash
ssh root@<server> "grep -rn '<旧值前8位>' /opt/fittracker /opt/supabase 2>/dev/null"
```

常见漏点：`test_run/`、`*.bak`、`*.log`、截图、`.env.*.local`、编辑器备份（`*~`、`*.swp`）。

### 3.2 记一条记录

追加到 `docs/security/credential-rotation-log.md`，**只记时间与凭据名，绝不要记值**。脚本会自动追加。

### 3.3 确认旧值真的死了

| 凭据 | 怎么确认 |
|---|---|
| QQ_APP_KEY | 用旧 key 调换票接口应返回失败；或平台侧确认已重置 |
| AGC Client Secret | AGC 控制台只显示新值（Secret 不可回看） |
| 阿里云 AK | RAM 控制台显示「已禁用 / 已删除」 |
| service_role | 旧 key 调用 Admin API 返回 401 |

## 4. 验证命令

```powershell
# Edge Function 是否在线（404 = 未部署，500 server_misconfigured = 配置缺失，401 = 正常需鉴权）
try { Invoke-WebRequest -Uri 'https://api.earthrhythm.cloud/functions/v1/thirdparty-exchange' -Method POST -Body '{"provider":"qq","authCode":"x"}' -ContentType 'application/json' -TimeoutSec 8 -UseBasicParsing } catch { $_.Exception.Response.StatusCode.value__ }
```

函数返回 `server_misconfigured` 说明 secrets 没生效；能走到 provider 校验说明配置已就位。

## 5. 不要做的事

- 不要把新值贴进任何聊天窗口、issue、截图 —— 这次泄露就是这么发生的
- 不要在没有维护窗口的情况下重置 B 类凭据
- 不要用 `generate-keys.sh` 换单个 key
- 不要为了让 CI 通过而把密钥写进 workflow（走 repository secrets）
- 不要在轮换后删除 `server/deploy/.env.template` 里的占位说明 —— 它是给别人看的
