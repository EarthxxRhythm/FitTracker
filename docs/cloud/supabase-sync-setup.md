# Supabase 云同步配置手册（自托管后端）

> **层级**：L2 展开
> **最后核对**：2026-10-28
> **上位文档**：`AGENTS.md`（L1，冲突以 L1 为准）
> **状态**：现行
> **路径基准**：文中 `server\…`、`apps\…`、`docs\…` 相对仓库根
> **适用端**：双端

> 用途：记录鸿蒙端「云同步」接入自托管 Supabase（PostgREST）的配置与验证流程。本文是**现行**后端手册；AGC 手册（`docs/cloud/cloud-setup.md`，已被取代）仅作历史参考。`CloudEnvironment.getBackend()` 现为 supabase / sandbox 二态仲裁，无 agc 分支。
> 端侧实现：`apps/harmony/entry/src/main/ets/shared/services/SupabaseCloudSnapshotStore.ets`（快照存储）；认证侧 `apps/harmony/entry/src/main/ets/common/services/auth/SupabaseAuthProvider.ets`（含 access token 自动刷新）。
> 状态：2026-10-13 首次落地——编译门禁与契约测试（`apps/harmony/entry/src/ohosTest/ets/test/SupabaseCloudSnapshotStore.test.ets`）已就位；设备端到端按 §4 执行。

## 1. 服务端：执行快照表迁移

迁移文件：`server/supabase/migrations/20261004000000_snapshots.sql`（`public.snapshots` 表 + 行级安全策略）。

执行方式（任选其一）：

1. Supabase Dashboard → SQL Editor → 粘贴本文件全文 → Run（推荐，零依赖）；
2. `supabase link --project-ref <项目ref>` + `supabase db push`（已装 CLI 时）。

表契约（端侧字段映射）：

| 列 | 类型 | 端侧字段 |
| --- | --- | --- |
| `user_id` | uuid（主键，引用 auth.users） | CloudSnapshot.userId |
| `payload` | jsonb | CloudSnapshot.payloadJson（JSON 内联值） |
| `updated_at` | timestamptz | CloudSnapshot.updatedAt（epoch 毫秒 ↔ ISO8601 UTC 转换） |

RLS：仅本人可 select / insert / update（策略条件 `auth.uid() = user_id`）；**无 delete 策略**——客户端不可删除快照（清空请用 Dashboard）。

## 2. 端侧：放置运行时凭据

把真实 `supabase.json` 放入 `AppScope/resources/rawfile/`（与 `thirdparty.json` 同级）。字段形状见模板 `AppScope/resources/rawfile/supabase.example.json`：

```json
{
  "url": "https://<项目ref>.supabase.co",
  "publishableKey": "sb_publishable_..."
}
```

- 该文件含运行时凭据、**不入库**（根 `.gitignore` 已排除 `**/supabase.json`）；缺失或解析失败时端侧回落沙盒（不触云）。
- 探测逻辑：`apps/harmony/entry/src/main/ets/common/services/SupabaseConfig.ets`（rawfile 探测，失败一律视为未配置）。

## 3. 后端选择优先级

`apps/harmony/entry/src/main/ets/common/services/CloudEnvironment.ets` 的 `getBackend()` 是单一真源：

> 测试强制 sandbox > **Supabase 显式配置**（supabase.json 探测通过）> 沙盒兜底

AGC 分支已从代码删除（2026-10-28），不存在「Supabase 与 AGC 同时配置」的情形；配置缺失即落沙盒。同步链路由 `apps/harmony/entry/src/main/ets/shared/services/CloudSyncService.ets` 的 `resolveStore()` 按该优先级选择快照存储。

## 4. 验证步骤

1. **构建**：`cd apps/harmony && devecocli build --product default`
2. **契约测试**（设备/模拟器在线时，全量执行）：
   `powershell -NoProfile -ExecutionPolicy Bypass -File apps/harmony/tools/ohos-test.ps1 -Preset full -DeviceId <target>`
   覆盖：ISO8601 codec（互逆 / 微秒截断 / 偏移归一 / 畸形拒绝）、pull/push 请求构造与响应分支、token 透传。
   > ⚠ 不要用 `-ClassNames SupabaseCloudSnapshotStore,CloudSyncService`：Hypium 的 `-s class` 按 describe **全名精确匹配**，
   > 这两个套件的 describe 名带后缀（`SupabaseCloudSnapshotStore codec` / `CloudSyncService decision matrix` 等），
   > 传短名会匹配到 0 个用例且 **result code 仍为 0**（假绿）。2026-10-15 实测：短名 0 用例，全量 287/287。
3. **端到端**（真机/模拟器）：
   - 登录（Supabase 认证）→ 账号与同步页「立即同步」→ UI 显示「已同步」；
   - 服务端核对：Dashboard → Table Editor → `snapshots` 出现本人一行；
   - 双账号 A/B：B 登录后读不到 A 的行（RLS 行级隔离）；
   - 登出换号后首同步为 push 认领（云端无该账号快照时）。

## 5. 排错速查

| 现象 | 处置 |
| --- | --- |
| 提示「云服务未就绪」 | `supabase.json` 缺失或字段为空 → 按 §2 放置；核对 url / publishableKey 非空 |
| 同步失败且日志 401 / 403 | access token 失效或 RLS 拒绝 → 核对 §1 迁移是否已执行、策略条件是否为 `auth.uid() = user_id` |
| push 报 409 | PostgREST upsert 未生效 → 核对主键 `user_id` 与请求 `Prefer` 头；确认迁移表存在 |
| 请求超时 / 网络不可达 | 端侧超时连接 15s / 读 20s → 检查设备网络与 Supabase 域名可达性 |
| 表不存在（404） | 未执行 §1 迁移 → 执行后重试 |
| token 过期后同步失败 | 端侧自动刷新（`ensureFreshAccessToken`）；若刷新被 4xx 拒绝会清会话 → 重新登录 |

> 相关：契约测试 `apps/harmony/entry/src/ohosTest/ets/test/SupabaseCloudSnapshotStore.test.ets`；全门禁 `apps/harmony/tools/check-gates.mjs`；历史 AGC 手册 `docs/cloud/cloud-setup.md`（已被取代）。

---

## 6. 第三方登录配置（微信 / QQ / 华为账号）

> 端侧实现：鸿蒙 `apps/harmony/entry/src/main/ets/common/services/auth/thirdparty/`（三桥）、
> 安卓 `apps/android/app/src/main/java/com/fittracker/app/`（WXEntryActivity / QqAuthStore / startQqAuth）。
> 服务端：`server/supabase/functions/thirdparty-exchange/`（换票端点 + 纯函数 + 测试）。
> 状态：代码已落地并通过编译与单测；**端到端需真机 + 已审核资质**（见第 7 节未验项）。

### 6.1 身份映射约定

第三方身份落到 GoTrue 用户，用**伪邮箱**承载（与手机号的 `phone.fittracker.app` 同构）：

| provider | 稳定标识 | 伪邮箱 |
| --- | --- | --- |
| 微信 | unionid（缺失回落 openid） | `wx_{id}@thirdparty.fittracker.app` |
| QQ | openid（缺失回落 unionid） | `qq_{id}@thirdparty.fittracker.app` |
| 华为 | UnionID（缺失回落 OpenID） | `hw_{id}@thirdparty.fittracker.app` |

### 6.2 端侧配置

**鸿蒙**：把 `thirdparty.json` 落盘到 `AppScope/resources/rawfile/`（不入库，模板见 `AppScope/resources/rawfile/thirdparty.example.json`）：

```json
{
  "wechatAppId": "wx<你的AppID>",
  "qqAppId": "<QQ互联 AppID>",
  "huaweiClientId": "<AGC Client ID>"
}
```

**鸿蒙 QQ 附加要求**：把 `qqAppId` 同时填入 `entry/src/main/module.json5` 的
`abilities[EntryAbility].skills[]` 中 `uris[].host`（当前为 `<QQ_APP_ID>` 占位符）。
⚠ 填错会导致 QQ 无法回调（腾讯官方明确警告）。

**安卓**：在 `apps/android/local.properties` 追加（不入库）：

```properties
wechat.appId=wx<你的AppID>
qq.appId=<QQ互联 AppID>
```

### 6.3 服务端部署

1. **Secrets**：按 `server/deploy/.env.template` 的 C 段填齐 8 项，然后
   `npx supabase secrets set --env-file <C段文件> --project-ref <ref>`。
   ⚠ 其中 `SUPABASE_SERVICE_ROLE_KEY` 是 **service_role** key（能绕过 RLS），**绝不可下发客户端**。
2. **部署函数**：
   ```
   npx supabase functions deploy thirdparty-exchange --project-ref <ref> --no-verify-jwt
   ```
   `--no-verify-jwt` 必需：端侧在未登录状态下调用本函数，不带 Supabase JWT；
   函数自身以 service_role 访问 Admin API。
   若走自托管 Supabase 栈容器路径，参照 `server/deploy/README.md` 的 sms-hook 模式（Dockerfile + Caddy 反代）。

### 6.4 验证步骤

**离线（已通过）**：`cd server/supabase/functions/thirdparty-exchange && deno test --allow-env`
→ 41 passed（25 个 providers 用例 + 16 个端点用例，覆盖正常/errcode 非零/网络异常/响应畸形四类分支，
以及密钥不外泄、错误响应不含第三方原始报文、幂等建号）。

**部署后必验（当前未实测，见第 7 节）**：
1. `POST https://api.<域名>/functions/v1/thirdparty-exchange` 带合法 authCode → 200 且 `token_hash` 非空。
2. **伪邮箱策略**：GoTrue 是否接受 `thirdparty.fittracker.app` 域（手机号伪邮箱已在用，但域名不同需独立验证）。
   若被拒，改用 Admin API 的 `phone` 字段承载，或调整域名。
3. **字段名核对**：`/admin/generate_link` 响应是否为 `properties.hashed_token`。
   若本栈版本不同，只改 `normalizeTokenHash` 一处（该函数已容错 4 种位置）。
4. 端侧用返回的 `token_hash` 调 `/auth/v1/verify {type:'magiclink', token_hash}` → 拿到 access_token 与 refresh_token。
5. 真机：微信 / QQ / 华为账号各走一遍完整授权 → 主壳，账号页 provider 显示正确。

