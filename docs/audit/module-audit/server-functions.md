# 模块审计 · server/supabase/functions（短信 Hook + 第三方换票）

> 范围：`server\supabase\functions\{send-sms,thirdparty-exchange}` 全部 7 个文件（含测试）
> 生成方式：机械 `wc`/`grep` 穷举 + 定点通读 + `deno test` 实跑 + `deno eval` 行为探针，**未修改任何源码**
> 判定基线：`docs\process\engineering-constraints.md`（L1）、`server\deploy\README.md`（部署现状事实源）
> 状态：客观发现，不含「应改成什么」的设计结论。**本台账不含任何密钥值**——只写字段名与行号，见 §7 F-3。

## §0 口径与方法（先声明，避免下游误读）

- **前缀**：路径全部相对仓库根，文档内用 Windows 反斜杠；抽验命令（§8）里一律用正斜杠。
- **计数单位**：`N 行` = `wc -l` 实测行数；`N 例` = `Deno.test` 定义数（另附实跑 passed 数）。两者不混写。
- **暂缓项决议 #1（采纳）——禁动区的 file:line 依据**：`server\deploy\` 与 `server\supabase\migrations\` **不在本域审计范围**，但为让「禁动标签」有 file:line 背书，本台账对二者做了**只读走查**并给出冻结依据锚点（§7 F-1～F-5）。走查只读，未执行、未建议改动。
- **暂缓项决议 #6（采纳）——file:line 可复核 gate**：§8 给出可执行抽验脚本（锚点正则 + 行号断言），行号漂移即红，台账须重生成。
- **问题分型**：只写实际捕获的事实。本域实测分布为「重复实现 / 契约漂移 / 魔法值散落 / 边界 / 测试覆盖」五类；**「越界依赖」实测为 0**（见 §2 D 备注），不凑条目。
- 优先级：`P0` 影响线上正确性或安全面 / `P1` 已发生漂移或必然漂移 / `P2` 仅记录事实。

## §1 规模基线（`wc -l` 实测）

| 文件 | 行数 | | 对照文件（禁动区，只读） | 行数 |
|---|---|---|---|---|
| `server\supabase\functions\send-sms\index.ts` | 205 | | `server\deploy\sms-hook\index.ts` | 203 |
| `server\supabase\functions\send-sms\aliyun.ts` | 147 | | `server\deploy\sms-hook\aliyun.ts` | 157 |
| `server\supabase\functions\send-sms\aliyun.test.ts` | 111 | | `server\deploy\sms-hook\aliyun.test.ts` | 114 |
| `server\supabase\functions\thirdparty-exchange\index.ts` | 438 | | `server\deploy\sms-hook\deno.json` | 9 |
| `server\supabase\functions\thirdparty-exchange\providers.ts` | 453 | | `server\deploy\sms-hook\Dockerfile` | 19 |
| `server\supabase\functions\thirdparty-exchange\index.test.ts` | 273 | | | |
| `server\supabase\functions\thirdparty-exchange\providers.test.ts` | 319 | | | |
| **合计** | **1946 行 / 7 文件** | | **对照合计** | **502 行 / 5 文件** |

测试实跑（`deno 2.9.6`，本轮）：

| 目录 | 命令 | 结果 |
|---|---|---|
| `functions\thirdparty-exchange` | `deno test --allow-env` | **41 passed / 0 failed** |
| `functions\send-sms` | `deno test` | **7 passed / 0 failed** |
| `deploy\sms-hook`（对照） | `deno test` | **7 passed / 0 failed** |

`Deno.test` 定义数：`send-sms\aliyun.test.ts` 7、`thirdparty-exchange\index.test.ts` 16、`providers.test.ts` 25、`deploy\sms-hook\aliyun.test.ts` 7。41 = 25 + 16，与 `docs\cloud\supabase-sync-setup.md:140` 的声称一致（见 C-4）。

## §2 边界（B-）

| ID | 位置 | 实测 | 判定 | 优先级 |
|---|---|---|---|---|
| B-1 | `functions\send-sms\index.ts:42`、`:191-192` | `declare const EdgeRuntime` 声明平台全局，`typeof EdgeRuntime !== "undefined"` 守卫；对照版 `deploy\sms-hook\index.ts:193` 改为 `void sendTask` fire-and-forget。同一「立即应答 + 后台发送」语义靠两套机制实现，一致性只由注释 `:9` / `:188` 维持 | 平台耦合点集中，可接受；但语义一致无测试守护 | P2 |
| B-2 | `functions\send-sms\index.ts:158` vs `deploy\sms-hook\index.ts:159` | 前者 `Deno.serve(handler)` 不绑端口（平台托管）；后者 `Deno.serve({ port: Number(Deno.env.get("PORT") \|\| "8787") }, …)` | 入口形态不同，属部署载体差异（有意） | P2 |
| B-3 | `server\supabase\functions\`（目录级） | `ls` 实测：该目录下**无** `deno.json` / `import_map.json` / `tsconfig.json`（仅 `send-sms/`、`thirdparty-exchange/` 两个子目录）；对照 `deploy\sms-hook\deno.json:1-9` 定义了 `tasks.test` / `tasks.check` 与 `fmt.lineWidth=100` | functions 侧无 `deno check` 门禁入口、无格式化基线 → 两副本风格基线不同（本域两份源码缩进/引号风格已不一致） | P1 |
| B-4 | `thirdparty-exchange\index.ts:26-28`（注释）、`:360` `handleExchange` | 部署要求 `--no-verify-jwt`；函数体内**无调用方鉴权**（不校验 JWT、不校验 Origin，仅校验 `method` / `SUPPORTED_PROVIDERS` / `authCode` 非空） | 公网可达的会话签发端点，唯一门槛是第三方 `authCode` 一次性 | P1 |
| B-5 | `functions\send-sms\index.ts:96`（对照 `deploy\sms-hook\index.ts:94`） | 签名比对 `candidate === expected`（普通字符串相等），未用恒定时间比较 | HMAC 比对存在时序侧信道（自用规模下风险低，如实记录） | P2 |
| B-6 | `functions\send-sms\index.ts:87-88`、`:166-175` | `webhook-timestamp` 只参与 `signedContent`，**无新鲜度窗口校验**（standardwebhooks 建议 ±5 分钟） | 验签通过即接受旧请求 → 重放面；body 内容为 `{phone, otp}`，重放后果为重复发短信用量 | P1 |
| B-7 | `functions\send-sms\index.ts:154` vs `deploy\sms-hook\index.ts:152-155` | 失败均 `console.error`；对照版多一条成功留痕 `console.log("aliyun send ok")` | 仅容器版可核实「短信是否已发出」，两侧可观测性不对等（`deploy\README.md` 实测记录 ⑨ 的运维姿势依赖该日志） | P1 |
| B-8 | `functions\send-sms\index.ts:160`、`deploy\sms-hook\index.ts:161` | `await req.text()` 前无长度上限，先全量读 body 再验签 | 验签前消耗带宽/内存（Hook 场景 body 极小，风险低） | P2 |
| B-9 | `thirdparty-exchange\index.ts:38-41`（注释）、`:51` `readEnv()` | 环境变量**每次请求读取**而非模块级快照，注释给出实测原因（`deno test` 在 import 后 `Deno.env.set` 不生效） | 有意设计，且与测试隔离方式绑定——改回快照会让 16 个端点用例退化为误判 | P2 |

> 越界依赖（本域特有口径：函数内互相 import 或向 `apps\` 反向依赖）实测 **0 命中**：`send-sms\aliyun.ts:6-12` 与 `thirdparty-exchange\index.ts:31-37` 的 import 全部指向同目录 `./aliyun.ts` / `./providers.ts`，无跨函数、无向上层依赖。**不列条目**（避免制造无依据条目）。

## §3 重复实现（D-）

| ID | 位置 | 实测 | 判定 | 优先级 |
|---|---|---|---|---|
| D-1 | `functions\send-sms\aliyun.ts`（147 行）↔ `deploy\sms-hook\aliyun.ts`（157 行） | `diff -u` 实测：8 个导出中 7 个逐字相同（`percentEncode` / `aliyunTimestamp` / `aliyunSign` / `buildAliyunParams` / `DYPNS_API_HOST` / `DYSMS_API_HOST` / `buildSendSmsVerifyCodeParams` + 私有 `bytesToBase64`）；差异集中在文件头注释与 `toMainlandPhone` 一处逻辑。`deploy\README.md:36` 明确「两份独立维护，改动需同步」 | **整文件复制**，同步责任落在人身上 | P0 |
| D-2 | `functions\send-sms\aliyun.ts:62-64` ↔ `deploy\sms-hook\aliyun.ts:69-74` | **漂移已发生**：前者 `replace(/^\+86/,"")` 再削空白；后者按长度剥离 `86`(13 位) / `0086`(15 位)。`deno eval` 实测同一输入：`"8613177992005"` → functions 版原样 `8613177992005`（13 位），对照版 `13177992005`；`"008613177992005"` → functions 版原样，对照版 `13177992005`。对照版注释 `:65-68` 记录该形态会触发阿里云 `ILLEGAL_MOBILE`（2026-10-10 实测复现） | functions 版仍带旧缺陷；**若按文件头部署说明重新部署即复现**（见 C-5） | **P0** |
| D-3 | `functions\send-sms\index.ts`（205 行）↔ `deploy\sms-hook\index.ts`（203 行） | `diff -u` 实测差异 3 处：① 文件头注释（`:7-15` 关系说明）② 成功留痕分支（`deploy:152-155`）③ 后台任务调用方式（`EdgeRuntime.waitUntil` → `void sendTask`，`functions:191-192` / `deploy:193`） | 整文件复制，漂移面 3 处 | P0 |
| D-4 | `functions\send-sms\index.ts:57`、`functions\send-sms\aliyun.ts:11`、`deploy\sms-hook\index.ts:55`、`deploy\sms-hook\aliyun.ts:11` | `bytesToBase64(ArrayBuffer)` **4 份逐字相同副本** | 同目录内也重复（index 与 aliyun 各一份） | P1 |
| D-5 | `functions\send-sms\index.ts:47`、`deploy\sms-hook\index.ts:45` | `base64ToBytes(base64)` 2 份逐字相同副本 | 同上 | P1 |
| D-6 | 三函数两份：`verifyHookSignature`（`functions:71` / `deploy:69`）、`parseTemplateExtra`（`108` / `106`）、`sendViaAliyun`（`126` / `124`） | 逐字相同，含 20s 超时与 `console.error` 文案 | 重复面覆盖全部业务逻辑，仅平台适配层不同 | P1 |
| D-7 | `thirdparty-exchange\index.ts:48`、`providers.ts:19`/`:155`/`:324`/`:450`、`apps\harmony\...\auth\AuthTypes.ets:12` | provider 标识三套表示**分置四处、无单一事实源**：白名单 `["wechat","qq","huawei"]`（index:48）、伪邮箱前缀 `'wx'`/`'qq'`/`'hw'`（providers 内三处）、客户端联合类型 `'huawei' \| 'wechat' \| 'qq'`（Harmony `:12`）。新增 provider 需同步 3 处服务端 + 2 端客户端 | 键空间与展示空间耦合在同一字符串上，却无映射表 | P1 |
| D-8 | `thirdparty-exchange\index.ts:92`（`errorResponse(code, messageZh, status)`）与客户端 `apps\harmony\...\SupabaseAuthProvider.ets:288-297`、`apps\android\...\SupabaseAuthProvider.kt:216-231` | 同一批中文文案在两处独立定义：服务端写 9 条（`:368/372/380/385/388/395/401/411/418`），客户端按 HTTP status 重写 4 档。客户端**不解析**服务端 `message_zh` | 同一文案面两套定义且不等价（见 C-1/C-3） | P1 |

## §4 魔法值散落（M-）

| ID | 位置 | 实测 | 优先级 |
|---|---|---|---|
| M-1 | `functions\send-sms\aliyun.ts:84-92` 与 `:137-145`（对照版 `:94-102` / `:147-155`） | 阿里云 RPC 固定值在 `buildAliyunParams` 与 `buildSendSmsVerifyCodeParams` 各写一遍：`cn-hangzhou`、`HMAC-SHA1`、`SignatureVersion "1.0"`、`Version "2017-05-25"`。**共 4 组重复（两函数 × 两副本）** | P1 |
| M-2 | `functions\send-sms\index.ts:142`、`deploy\sms-hook\index.ts:140` | 超时 `20000`(ms) 硬编码两处，无常量 | P1 |
| M-3 | `deploy\sms-hook\index.ts:159`、`server\deploy\.env.template:69`、`server\deploy\Caddyfile:37` | 端口 `8787` 三处（代码默认值 / 环境变量模板 / Caddy 反代目标）——改一处不同步即 502 | P1 |
| M-4 | `thirdparty-exchange\index.ts:255`、`:423`、`apps\harmony\...\SupabaseAuthProvider.ets:273`、`apps\android\...\SupabaseAuthProvider.kt:207` | `'magiclink'` 字面量 4 处：服务端 `generate_link` 请求体（`:255`）与成功响应 `type`（`:423`）；双端兜底 `ifEmpty` / `len > 0 ?` 默认值（HM `:273`、Android `:207`） | P2 |
| M-5 | `thirdparty-exchange\providers.ts:23`、`apps\harmony\...\SupabaseAuthProvider.ets:38-39` | 伪邮箱域两套且值不同：函数侧 `'thirdparty.fittracker.app'`（`providers.ts:23`）、客户端 `'phone.fittracker.app'`（`.ets:39`，注释 `:38` 称「对齐 Android INTERNAL_EMAIL_DOMAIN」）。`providers.ts:26-30` 注释用「与客户端同构」表述——同构指结构而非同值，易被读成同值 | P2 |
| M-6 | `functions\send-sms\index.ts:129`、`:109-110`（对照版 `:127` / `:107-108`） | 环境变量缺省值散落：`templateParamKey \|\| "code"`、`parseTemplateExtra` 回落 `{ min: "5" }`（该 `"5"` 与阿里云模板文案「5分钟内有效」及 compose 侧 `GOTRUE_SMS_OTP_EXP=300` 是三处独立维护的口径，见 §7 F-1） | P1 |

## §5 契约漂移（C-）

| ID | 位置 | 实测 | 判定 | 优先级 |
|---|---|---|---|---|
| C-1 | `thirdparty-exchange\index.ts:368-418`（9 个错误码）vs 双端客户端 | 服务端返回 `{ error, message_zh }` 且码值有测试守护（`index.test.ts:91/100/109/117/125/138/242`）。客户端**完全不读** `error` / `message_zh`：Harmony `:288-297`、Android `:216-231` 只按 `status` 映射。→ 9 个码中 6 个（`method_not_allowed` / `server_misconfigured` / `invalid_payload` / `unsupported_provider` / `missing_auth_code` / `identity_incomplete`）无任何消费方 | **死契约**：服务端契约面大于实际使用面，测试守护的是无人读的字段 | P1 |
| C-2 | `thirdparty-exchange\index.ts:72-77`、`:421-426` | 成功响应含 `user_id` 与 `is_new_user`；双端只读 `token_hash` / `type`（HM `:272-273`、Android `:200-201`）。`is_new_user` 语义（首登引导）**无消费方** | 冗余字段 + 未落地语义 | P2 |
| C-3 | `thirdparty-exchange\index.ts:380/385/388/401` vs HM `:292-293` / Android `:230` | 服务端 4 个错误以 **400** 返回（`invalid_payload` / `unsupported_provider` / `missing_auth_code` / `identity_incomplete`），客户端把 400 一律显示「授权已失效，请重新登录」→ 参数错误被描述为授权失效，且无法重试引导 | 状态码承载了两种语义（客户端问题 / 凭据问题） | P1 |
| C-4 | `docs\cloud\supabase-sync-setup.md:140` | 文档声称「41 passed（25 providers + 16 端点）」；本轮 `deno test` 实测 **41 passed / 0 failed**（§1） | ✅ 文案与代码一致（确认项，非缺陷） | P2 |
| C-5 | `thirdparty-exchange\index.ts:26-28`、`functions\send-sms\index.ts:23-26`、`docs\cloud\supabase-sync-setup.md:118-127` vs `server\deploy\README.md`（实测记录 ⑩）、`server\deploy\Caddyfile:28-37` | 两函数头部与文档都写 `npx supabase functions deploy --project-ref <ref>`；但：① 旧托管项目 `ixzozsqaprtquwxzhdsm` 已删除（README 实测记录 ⑩，`db.*` 与 API 域名两侧 `Non-existent domain`）；② `server\deploy\` 内 `grep -r functions` 仅 2 处命中，**均为注释/文档文字，无 compose 服务或路由定义**；③ `Caddyfile` 只反代 `/sms-hook*` → `127.0.0.1:8787` 与默认 → `127.0.0.1:8000`，无 `/functions/v1` 规则 | 函数源码的部署说明指向已失效载体；**自托管栈内无该函数的部署配置证据**（是否由 Envoy 网关转发 `/functions/v1` 属官方 compose 运行态，仓库内不可证——显式记为未收敛项，不作断言） | P1 |
| C-6 | `server\deploy\thirdparty.env:1-5`（21 行，**UNTRACKED**） | 该文件是第三方 secrets 的**本机真值**载体：`:1` 自述「本机真值（*.env 规则排除，不入库）」，`:2` 指向旧托管命令 `npx supabase secrets set --env-file …`，`:5` 记录「AppKey 曾在聊天中暴露，正式发布前建议轮换」。`git ls-files` 实测 UNTRACKED，`.gitignore:133` `*.env` 覆盖 → **未入库，红线未被突破**。但 `server\deploy\README.md:32-45` 的「文件说明」表**未收录该文件**（表中只有 `.env.template`，`:41`） | 目录实际内容与文件清单不一致；凭据轮换的历史欠账只存在于该文件注释里 | P1 |

## §6 测试覆盖（T-）

| ID | 位置 | 实测 | 判定 | 优先级 |
|---|---|---|---|---|
| T-1 | `functions\send-sms\`（目录） | 只有 `aliyun.test.ts`（111 行，测纯函数）；**无 `index.test.ts`** → `verifyHookSignature`（`:71`）、`parseTemplateExtra`（`:108`）、`sendViaAliyun`（`:126`）、路由分支（`:158-205`）零覆盖。安全不变量「验签」不在测试网内 | 最关键的鉴权函数无测试；对照 `thirdparty-exchange` 有 16 个端点用例，口径不一致 | **P0** |
| T-2 | `functions\send-sms\aliyun.test.ts:36-38` vs `deploy\sms-hook\aliyun.test.ts:36-41` | 测试副本同样分叉：前者 3 例（`+86` / 裸号 / 空），后者 5 例（增 `8613900000001` 与 `0086…`）。**两份 `deno test` 均 7 passed**——绿不区分实现正确性，`functions` 侧的绿正对应 D-2 的缺陷 | 「测试全绿」不能证明两副本等价 | **P0** |
| T-3 | `tools\run-tests.mjs` | 实测 `grep -i deno tools/*.mjs apps/harmony/tools/*.mjs` **0 命中** → 根级 `node tools/run-tests.mjs` 不执行本域任何测试。本域测试只能手工 `cd` + `deno test`（依赖本机 deno；本轮 deno 2.9.6 可用） | 本域无门禁保护，漂移只能靠人发现 | P1 |
| T-4 | `deploy\sms-hook\deno.json:3-4` vs `server\supabase\functions\`（无配置） | `deno check index.ts` 入口只存在于对照侧；functions 侧无 check 入口 | 类型错误在 functions 侧只能靠 `deno test` 的 `Check` 阶段间接触发（`deno test` 默认会 check 被 import 的模块，实测输出含 `Check aliyun.test.ts`） | P2 |

## §7 禁动区（只读走查，冻结依据锚点）

> 本节仅为「禁动标签」提供 file:line 背书，**未执行、未改动、不建议改动**。任何改动前须回到 `docs\process\engineering-constraints.md` 与对应计划。

| ID | 冻结对象 | 规模 | 冻结依据锚点（file:line） | 说明 |
|---|---|---|---|---|
| F-1 | `server\deploy\sms-hook\*`（5 文件 502 行） | `index.ts` 203 / `aliyun.ts` 157 / `aliyun.test.ts` 114 / `deno.json` 9 / `Dockerfile` 19 | `server\deploy\README.md:12-16`（2026-10-28 实测运行态：13 容器 + sms-hook 稳定运行）、`README.md:36`（两份独立维护声明）、`Caddyfile:31-32`（唯一入口反代 8787） | 这是**当前线上在用**的短信 Hook 实现；`functions\send-sms\` 是旧托管栈副本。二者关系见 D-1/D-3 |
| F-2 | `server\deploy\Caddyfile`（59 行） | — | `:31-32`（`route /sms-hook*` → `reverse_proxy 127.0.0.1:8787`）、`:36`（默认 → `127.0.0.1:8000`）、`:23`（8443 已于 2026-10-28 退役）、`:25`（单文件 bind mount inode 陷阱） | 运行时反代唯一事实源；改配置须 `docker restart` 才生效（README 实测记录 ⑬） |
| F-3 | `server\deploy\thirdparty.env`（21 行，**含真值**）、`server\deploy\.env.template`（99 行，不含真值） | — | `thirdparty.env:1`（自述真值）、`:2`（旧托管命令）、`:5`（AppKey 暴露欠账）、`.env.template:41`（不含真值声明）、`:60-69`（B 段 sms-hook 变量名）、`:72-98`（C 段第三方变量名） | **本台账不复制任何值**。真值形态仅用于证伪「模板无真值」：见 C-6。轮换流程归 `docs\security\credential-rotation.md` |
| F-4 | `server\supabase\migrations\*.sql`（4 文件 568 行） | `20261004000000_snapshots.sql` 27 / `20261101000000_content_library.sql` 91 / `20261101000001_snapshot_mirror.sql` 412 / `20261101000002_exercise_media.sql` 38 | `20261004000000_snapshots.sql:10`（建表）、`:17`（RLS）、`:20-30`（三条 own 策略）；`20261101000000_content_library.sql:31/55/63`（3 宽表）、`:75-89`（RLS + 仅 select 策略）；`20261101000001_snapshot_mirror.sql:34-139`（7 表 + RLS）、`:142`（首条 own 策略）；`README.md` Wave 7（执行顺序不可颠倒、幂等） | 已上线的库结构事实源；改 schema 必须走新迁移文件，不得改历史文件 |
| F-5 | `server\deploy\migrate\*`（3 文件 114 行） | `dump.sh` 40 / `restore.sh` 44 / `verify.sql` 30 | `server\deploy\README.md:44-46`（用途）、Wave 5 已标注失效（README `:160-166` 区段：旧库不可达，仅历史存档） | 迁移脚本含连接串形态说明，只读 |

## §8 file:line 可复核 gate（暂缓项决议 #6 的落点）

台账锚点抽验：断言「该行仍包含该正则」，任一红即说明源码已改动、台账对应条目须重生成。shell 内路径用正斜杠。

```bash
cd "$(git rev-parse --show-toplevel)" || exit 1
fail=0
chk() { # chk <file> <line> <ere>
  local got; got=$(sed -n "${2}p" "$1")
  if printf '%s' "$got" | grep -Eq "$3"; then
    printf 'OK   %s:%s\n' "$1" "$2"
  else
    printf 'FAIL %s:%s 期望 /%s/ 实得: %s\n' "$1" "$2" "$3" "$got"; fail=1
  fi
}
# 边界 / 重复实现 / 魔法值 / 契约 关键锚点
chk server/supabase/functions/send-sms/index.ts 42 'declare const EdgeRuntime'
chk server/supabase/functions/send-sms/index.ts 191 'typeof EdgeRuntime'
chk server/supabase/functions/send-sms/index.ts 96 'candidate === expected'
chk server/supabase/functions/send-sms/aliyun.ts 62 'export function toMainlandPhone'
chk server/supabase/functions/send-sms/aliyun.ts 63 'phone\.replace'
chk server/deploy/sms-hook/aliyun.ts 71 'digits.length === 13'
chk server/supabase/functions/send-sms/aliyun.ts 11 'function bytesToBase64'
chk server/supabase/functions/send-sms/index.ts 57 'function bytesToBase64'
chk server/supabase/functions/send-sms/index.ts 142 '20000'
chk server/supabase/functions/thirdparty-exchange/index.ts 48 'SUPPORTED_PROVIDERS'
chk server/supabase/functions/thirdparty-exchange/index.ts 395 'exchange_failed'
chk server/supabase/functions/thirdparty-exchange/providers.ts 23 'thirdparty\.fittracker\.app'
chk server/deploy/sms-hook/index.ts 155 'aliyun send ok'
chk server/deploy/Caddyfile 32 '127\.0\.0\.1:8787'
chk server/supabase/migrations/20261004000000_snapshots.sql 10 'create table if not exists public.snapshots'
chk server/supabase/migrations/20261101000000_content_library.sql 77 'create policy "exercises_public_read"'
echo "---"; [ "$fail" -eq 0 ] && echo "ALL ANCHORS OK" || { echo "DRIFT DETECTED"; exit 1; }
```

行为面探针（复现 D-2，无需网络）：

```bash
cd server/supabase/functions/send-sms && deno eval \
  "const m=await import('./aliyun.ts'); console.log(m.toMainlandPhone('8613177992005'))"
# 期望（现状）= 8613177992005（13 位，未归一化）；对照 deploy/sms-hook/aliyun.ts 为 13177992005
```

## §9 未收敛项 / 未验证

1. **自托管栈是否暴露 `/functions/v1/*`（C-5）**：仓库内无证据。需在服务器上实测（`curl -s -o /dev/null -w '%{http_code}' https://api.<域名>/functions/v1/thirdparty-exchange -X POST -d '{}'`），本台账不作断言。
2. **第三方账号（微信/QQ/华为）端到端未实测**：`docs\cloud\supabase-sync-setup.md:133-145` 已列 5 项「部署后必验」，其中伪邮箱域 `thirdparty.fittracker.app` 是否被 GoTrue 接受、`generate_link` 返回字段名均未验证。本域测试全部为离线 mock（41 passed 不含任何真实网络）。
3. **`functions\send-sms` 是否仍有部署目标**：C-5 已记录「旧项目删除 + 自托管侧无配置证据」，但未核实服务器上是否残留 `edge-runtime` 容器。属运行态事实，超出只读仓库审计。
4. 本任务工单的其余暂缓项（`audit-contracts` §0-§7 章节错配、`audit-tools-remotion` 技术栈异构、三域台账 git 基线、contracts 五型分布）**不属于本域**，此处不裁决，交回计划层。

## §10 缺陷清单速览（按优先级）

- **P0**：D-2（`toMainlandPhone` 漂移，functions 版仍带 `ILLEGAL_MOBILE` 缺陷）、T-1（验签零覆盖）、T-2（测试副本分叉，绿不代表等价）、D-1/D-3/D-6（整文件重复实现，同步靠人）
- **P1**：B-3/B-4/B-6/B-7、D-4/D-5/D-7/D-8、M-1/M-2/M-3/M-6、C-1/C-3/C-5/C-6、T-3
- **P2**：B-1/B-2/B-5/B-8/B-9、C-2/C-4、M-4/M-5、T-4
