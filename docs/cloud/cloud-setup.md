# AGC 云服务配置手册

> 用途：记录「登录注册与云同步」计划 Wave 5（AGC 真实接线）所需的控制台配置流程；本配置已于 2026-10-01 全部完成并经模拟器实测。
> 状态：v0.5（2026-10-08）——配置记录 + 排错参考；§8 真短信手册（上架后执行）；§9 模拟器云同步鉴权全链修复记录（2026-10-08 端到端贯通）；标 ⚠ 的条目以控制台实际界面为准。
> v0.2 修订：修正 `payloadJson` 字段类型（String→Text——官方 String 上限 200 字符装不下聚合包，且字段类型部署后不可改）；补充存储区前置、证书指纹实值（§5）、`schema.json` 入仓路径与排错速查（§7）。配套材料见 `cloud/agc/`。
> v0.3 修订：§4 修正配置文件的工程路径与探测函数名；§6 回填完成状态；§7 补充实测排错条目。
> v0.4 修订：新增 §8「真短信启用手册（R2 路线 · 上架后执行）」（真短信计划 2026-10-04 批准）；§7 排错表相应更新。
> v0.5 修订（2026-10-08）：新增 §9「模拟器云同步鉴权全链修复记录」（签名单类方式 + 模拟器调试凭据两层根因，端到端贯通）；§7 排错表补两条模拟器鉴权条目。
> 配套：`.rivet/plans/fittracker-登录注册与云同步-agc-实现计划.md`（配置表 8 项即本手册章节 1-5）；Supabase 自托管后端（认证 + 数据同步）见 `docs/cloud/supabase-sync-setup.md`。

## 0. 前置条件

- 已注册华为开发者账号并登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)
- 已创建 AGC 项目与 HarmonyOS 应用，应用包名：`com.earthrhythm.fittracker`
  - 尚未创建时：AGC → 我的项目 → 新建项目 → 添加应用（平台选 HarmonyOS，填上述包名）

## 1. 开通认证服务（配置表项 1-4）

1. AGC →「开发与服务」→ 点击项目 → 左侧导航「**云开发（Serverless）→ 认证服务**」→ 立即开通
   - ⚠ 部分界面/旧文档路径为「构建 → 认证服务」，以控制台实际入口为准
   - 数据存储区域：中国大陆选 **CN**
2. 在「认证方式」区依次启用：
   - **手机号码**（测试验证码配置见第 2 节）
   - **邮箱地址**
   - **华为账号**
   - **微信 / QQ**（需微信开放平台 / QQ 互联的应用凭证；个人开发者资质限制以控制台为准）
3. 未启用的方式：应用内对应入口会提示「未就绪」并保持沙盒降级（不影响其余方式）

## 2. 配置测试手机号与测试验证码（配置表项 8）

1. 认证服务 → 手机号码方式配置区 → 找到「**测试验证码**」（或「测试手机号」）设置项 ⚠
2. 添加 1 个测试手机号，并设置其固定验证码
3. 完成后把「**测试手机号 + 测试验证码**」两个值告知——Wave 5 模拟器实测已用其走通真实 AGC 链路（测试号码不发真实短信；测试期验证码经 Webhook 转发至 `sms-hook` 云函数，从 AGC 控制台「质量 → 云监控 → 日志服务」读取）

> 📮 **真短信（上架后启用）**：「日志读码」是开发期过渡形态；真短信启用手册见 **§8**（R2 路线：上架后以「已上线App名称」申请短信签名 → 平台直发）。

## 3. 开通云数据库并创建 SyncSnapshot 对象类型（配置表项 5）

官方步骤参考：[新增对象类型 - 云数据库 - Cloud Foundation Kit](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/cloudfoundation-database-add-object)、[新增存储区](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/cloudfoundation-database-add-zone)

> **存储区前置**：对象类型归属某个「存储区」（云数据库下最多 4 个）。先在「存储区」页签按需新增（建议名 `菲特`）；创建对象类型时注意其实际归属——Wave 5 端侧以 `cloudDatabase.zone('<存储区名>')` 引用，**名字必须一致**。

1. AGC → 左侧导航「**云开发（Serverless）→ 云数据库**」→ 开通（若未开通）
2. 点击「**新增**」创建对象类型，对象类型名：`SyncSnapshot`
3. 按下表新增字段（**字段名大小写必须与代码一致**）：

| 字段名称 | 类型 | 主键 | 非空 | 加密 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `userId` | String | ✓ | ✓ | – | 用户标识（同步主体） |
| `payloadJson` | **Text** | – | – | – | 整包数据信封（JSON 字符串）。⚠️ **必须选 Text**：String 字段上限 200 字符（官方《创建数据条目》），装不下聚合包（预期 <200KB）；Text 上限 1 亿字符。定义文件见 `cloud/agc/SyncSnapshot.schema.json` |
| `updatedAt` | Long | – | ✓ | – | 快照更新时间（毫秒时间戳） |
| `deviceTag` | String | – | – | – | 写入设备标记 |
| `schemaVersion` | Integer | – | ✓ | – | 快照结构版本（当前 1） |

> 字段来源：`entry/src/main/ets/shared/services/CloudSnapshotStore.ets` 的 `CloudSnapshot` 接口（userId / payloadJson / updatedAt / deviceTag / schemaVersion）。
> ⚠ `updatedAt` 为毫秒时间戳（超出 Integer 范围，必须 Long）；若 SDK 侧 Long 映射有问题，可退化为 Double/String，Wave 5 实测校准。
> ⚠ 非空（notNull）取舍：官方规则「字段为非空时，必须设置默认值」——`payloadJson` 已按不设非空处理（端侧写入前校验非空，避免给 Text 配默认值）；`updatedAt` / `schemaVersion` 如保持非空，请同时配置默认值（0 / 1），控制器不接受则留空非空。

4. 索引：本对象按主键（userId）查询与覆盖写，**无需额外索引**（可跳过）。
5. 角色权限设置（「确定」前）：

| 角色 | query | upsert | delete | 操作 |
| --- | --- | --- | --- | --- |
| 数据创建者 | ✓ | ✓ | ✓ | 保持默认（全权限） |
| 认证用户 | ✓ | ✓ | ✓ | **取消** upsert、delete |
| 所有人 | ✓ | ✓ | ✓ | **取消** upsert、delete |
| 管理员 | ✓ | ✓ | ✓ | 保持默认（仅控制台使用） |

   即满足计划的「仅数据创建者读写」要求。**不要设置加密字段**（一旦设置，认证/所有人角色权限会被系统锁定，本项目不需要全程加密）。
   - ⚠ **写失败排查**（Wave 5 实测若同步报「权限不足 / permission denied」）：先确认端侧初始化已传入登录凭据（AccessToken，官方《初始化数据库访问》「需要登录才能操作数据库」一节）——凭据缺失时请求以未认证身份发出会被拒；仍失败则把「认证用户」upsert 勾回复测（权限可随时调整，不影响数据）。
   - ⚠ **行级边界实测项**：官方文档未明说「认证用户 query 是否触达他人行」——Wave 5 用双账号 A/B 实测「B 读不到 A 的快照」；发现越界立即回调本表收紧。

6. 创建完成后：勾选 `SyncSnapshot` → 点击「**导出**」→ 选择 json 格式 → 留存该文件
   - **该导出文件重命名为 `schema.json` 后放入工程：`AppScope/resources/rawfile/schema.json`**（官方《引入对象类型文件》——端侧云数据库 API 必须加载该文件；云侧后续修改对象类型后需重新导出覆盖，两侧不一致将报 `1008230002`）。
   - 字段定义参考已备于本仓 `cloud/agc/SyncSnapshot.schema.json`（创建/导入时的字段对照）；如需与导出格式做对齐，亦可回传导出样例。

## 4. 下载配置文件 agconnect-services.json（配置表项 6）

1. AGC → 应用「**项目设置**」（⚠ 或该应用「常规」页）→ 下载 `agconnect-services.json`
2. 放入工程路径（Wave 5 实际接线路径）：`AppScope/resources/rawfile/` 目录下的 `agconnect-services.json`
   - 依据：`CloudEnvironment.detectAndInitAgc()` 以 rawfile 探测该文件并执行 `auth.init`（`entry/src/main/ets/common/services/CloudEnvironment.ets`）
   - 该文件含密钥，`.gitignore` 已排除入库（`**/agconnect-services.json`）

## 5. 注册调试证书指纹（配置表项 7）

1. AGC → 项目设置 → 常规 → 「**证书指纹**」区 → 添加
2. 调试证书 SHA256 指纹获取途径 ⚠（以 DevEco 实际界面为准）：
   - **已代为提取**（openssl 实测本机自动签名证书 Leaf，可直接使用）：
     `12:3B:CE:0A:30:90:63:C2:58:AD:98:3B:C6:E9:EC:9F:CC:FF:42:DD:19:4E:9D:02:48:2A:A3:AC:6A:8F:CE:61`
     （来源 `C:\Users\19308\.ohos\config\default_菲特_….cer`，CN=`李凡(1794157958125343233)\,Development`；注意是证书链中的 **Leaf 证书**，不是根 CA/中间 CA，后两者指纹不通用）
   - 也可自行查看：DevEco Studio → File → Project Structure → Signing Configs；或
   - 本机 `C:\Users\19308\.ohos\config\default_菲特_*.cer`（自动签名证书）
3. 未注册指纹时：认证服务与云数据库调用可能返回 403

## 6. 完成后（联动清单与注意事项）

完成 1-5 后，把以下状态告知编排方（**5 项已于 2026-10-01 全部完成**；微信 / QQ 未启用，手机号 / 邮箱 / 华为账号已启用）：

- [x] 认证服务已开通（手机号 / 邮箱 / 华为账号已启用；微信 / QQ 未启用）
- [x] 测试手机号 + 测试验证码已配置（模拟器实测通过）
- [x] 云数据库已开通，`SyncSnapshot` 对象类型已创建（权限 = 仅数据创建者读写）
- [x] `agconnect-services.json` 已下载并放入工程（`AppScope/resources/rawfile/` 下，不入库）
- [x] 调试证书指纹已注册

**放入时机（已执行）**：`agconnect-services.json` 已随 Wave 5 接线放入 rawfile，`CloudEnvironment.isAgcConfigured()` 为 true，认证与云数据库均走真实 AGC；登录/注册页的沙盒提示逻辑已同步更新，全量测试已重跑。

**验证引用（完成情况，2026-10-01）**：
- ✅ 模拟器实测：发送验证码 → 输入测试验证码 → 登录成功（走 AGC；验证码经 Webhook 转发到 `sms-hook` 云函数）
- ⚠️ **更正（2026-10-02 走查实测，见 `test_run/wave2/release-walkthrough.md` §11.1/§12）**：AGC 控制台云数据库 SyncSnapshot **共 0 条**——原「同步成功」记录系沙盒假阳性（`resolveStore` 未初始化时静默降级本地沙盒，根因修复见提交 `eb4da28`）；模拟器环境云数据库调用恒返回 `401 token is expired`（服务端策略级，已转官方工单）。**云同步尚未完成一次真实端到端贯通**；真机环境验证待执行。
- ⏳ 第三方登录：华为账号待真机验证；微信 / QQ 未启用（SDK 无对应凭据类型，应用内保持「暂未开通」提示）
- ⏳ 行级隔离双账号 A/B 实测（§3 注记的「B 读不到 A 的快照」）未单独执行——权限已按 §3 收紧，建议并入后续真机验收

## 7. 排错速查

| 现象 | 处置 |
| --- | --- |
| 调用返回 403 | 证书指纹未注册 / 填错（须填调试证书 **Leaf** 指纹）→ 第 5 节 |
| `1008230002` Schema config error | 工程 `schema.json` 与云端对象类型不一致 → 重新导出一份覆盖（第 3 节步骤 6） |
| 仍是 sandbox / 演示模式未消失 | `agconnect-services.json` 缺失或未打进包 → 核对 rawfile 路径，clean 后重建 |
| 「认证用户未获得权限」类失败 | 第 3 节权限注记的排查两步（AccessToken 凭据 → 恢复认证用户 upsert） |
| `number of CloudDBZone exceeds the limit` | 存储区已 4 个 → 复用或删除旧存储区（删区连带删数据） |
| `existing fields cannot be modified` | 改动已部署对象类型的字段定义 → 删除对象类型重建（其中数据一并清除） |
| 手机收不到验证码 | 上架前：正常——开发期用**测试验证码**（第 2 节）；上架后：真短信未启用时属预期（按 §8 手册启用/排查） |
| `first sign in a user, please sign out at first.` | AGC SDK 残留登录态与本地会话快照不一致（卸载重装 / 清数据后常见）：`AgcAuthProvider.ensureNoActiveSession` 已在登录前清理（提交 `ca594ab`）；绕过 AuthService 直调 SDK 的新代码需自行处理 |
| 模拟器 401 `205525007 verify signature failed` | **签名方式错误**：应用须使用「关联注册应用进行自动签名」或「手动签名」——DevEco Studio：File → Project Structure → Project → Signing Configs → 勾选 **Associate with registered application**（详见 §9） |
| 模拟器 `create http task error`（1008210009 / 1008220009） | **模拟器调试凭据未生成或未注册**：触发 CFK 接口后从日志取 `[clouddevelopproxy.debugToken=…]` 注册到 AGC「模拟器调试凭据」（绑定正确应用）；申请可能被网络干扰阻断，需连续重试触发（详见 §9） |

## 8. 真短信启用手册（R2 路线 · 应用上架后执行）

> **背景**：开发期手机验证码「经 Webhook 转云函数日志读码」是过渡形态（§2）。真短信落地已另立已批准计划：`.rivet/plans/fittracker-真短信验证落地-agc-webhook-云函数接短信通道.md`（2026-10-04 批准，选定 **R2 路线：应用上架后以「已上线App名称」申请 AGC 认证服务国内短信签名**，零工商成本；R1 企业/个体户主体 → 华为云短信 为兜底）。
> **上架前不要执行本章**——保持现状（读码通道 / 邮箱登录 / 华为账号均可用）；本章步骤在上架完成后按序执行。

### 8.1 前置条件（缺一不可）

- [ ] 菲特 已上架华为应用市场（应用详情页可公开访问）——上架主线见 `.rivet/plans/fittracker-1-1-0-上架推进-发布工程-云同步真机验证-合规材料.md`
- [ ] AGC 控制台可正常登录

### 8.2 申请国内短信签名

1. AGC → 认证服务 → 手机号码方式配置区
2. 找到「**国内短信签名**」设置项 → 添加签名
3. 签名内容 = **应用上架名称**（运营商实名制报备要求签名符合「企事业单位名 / 已上线App名称 / 已注册商标名」之一，不再支持网站/公众号等来源）
4. 按控制台要求提交材料（应用市场详情页链接 / AppID、开发者实名信息等，以实际界面为准）
5. 提交后等待华为侧审核 + 运营商实名制报备

### 8.3 切换为平台直发

1. 签名报备通过后，回到认证服务 → 手机号码方式配置区
2. 处理「**短信请求接收地址**」设置（目标：验证码短信由平台直发）：
   - 若控制台提供「平台短信 / 自定义短信」切换项 → 切为平台短信
   - 若无切换项（配置地址即全走 Webhook）→ **先抄录当前地址值**（回退要用），再清除/停用
3. 保存配置

### 8.4 验证清单（逐项留证）

| # | 场景 | 期望结果 | 证据位置 |
| --- | --- | --- | --- |
| 1 | 真机 + 真实手机号请求验证码 | 手机收到短信（含验证码） | `test_run/real-sms/` |
| 2 | 输入收到的验证码 | 登录成功进入主壳 | 同上 |
| 3 | 60 秒内重复请求 | 限频生效（按提示稍后再试） | 日志 |
| 4 | 错误 / 过期验证码 | 既有错误文案（不回归） | 日志 |
| 5 | 邮箱验证码登录 / 华为账号登录 | 不受影响 | 走查 |
| 6 | 短信内容检查 | 含签名 + 验证码 + 时效提示 | 短信截图 |

### 8.5 待验证项（执行时逐项确认）

1. **个人开发者能否通过「已上线App名称」签名报备**——无权威结论（2026-10-04 调研未见官方明文）；以实际审核结果为准。若被拒 → 兜底：R1（企业/个体工商户主体 → 华为云短信）或维持现状。
2. **平台直发与「短信请求接收地址」是否互斥**——以控制台实际界面为准（8.3 两种形态均有预案）。
3. **短信计费与额度**——以控制台/账单为准。

### 8.6 回退路径

- 任何一步失败 → 恢复「短信请求接收地址」为 8.3 步骤 2 抄录的 sms-hook 地址 → 回到现状读码通道（§2），登录链路不受影响。
- **sms-hook 云函数在本路线下保持不动**（不改造、不删除）——既是回退通道，也是开发期调试观测点。

### 8.7 启用时同步更新

- **隐私政策复核**：真短信生效后核对 `docs/legal/privacy-policy.md` 第五节「认证服务」表述。现状已披露「手机号提交至 AGC 认证服务完成身份验证」，短信发送属该服务的组成部分；如审核认为需明示，预备文案：「验证码短信由 AGC 认证服务经国内运营商通道发送至你提交的手机号」。复核结论（已覆盖 / 已改动）回写本节。
- 应用内法律文档副本：若正文有改动，用 `node tools/convert-legal-docs.mjs` 重生成 rawfile 副本（维护约定见 `docs/legal/README.md`）。
- 8.4 证据归档 `test_run/real-sms/`；完成后在本节标注执行日期与结果。

## 9. 模拟器云同步鉴权全链修复记录（2026-10-08 · 端到端已贯通）

> **背景**：模拟器上 Cloud Foundation Kit（CloudDB / 云函数 / 云存储）调用长期被拒（`401:205525007 verify signature failed`）——认证服务（登录/发码）正常而数据面全挂。2026-10-08 按官方工单回复逐一排查，全链修复并**首次端到端贯通**（push `affected=1` / pull `rows=1`）。完整取证过程见 `test_run/cloud-sync-v2/probe-results.md`。

### 根因树（复合，全部已修）

1. **签名方式错误（主根因）**：项目使用「**未关联注册应用**」的自动签名（devecocli CLI 只能生成此形态）；CFK 要求「关联注册应用进行自动签名」或「手动签名」（官方《基本准备工作》《打包测试》原文）。
2. **模拟器调试凭据缺失（两层）**：a) 本地凭据申请依赖在线请求（`oucs applyCredential`），可被网络干扰（2300056）阻断 → 连续重试触发可成功；b) 生成的凭据（日志 `[clouddevelopproxy.debugToken=…]`）**必须注册到 AGC**「证书、APP ID 和 Profile → 模拟器调试凭据」并绑定正确应用。
3. **网络干扰（2300056）**：历史间歇性噪声，非阻塞（重试可穿窗；关系统代理无显著差异，非代理问题）。

### 修复步骤（可复制）

1. **改签名方式（DevEco Studio GUI）**：File → Project Structure → Project → Signing Configs → 勾选「**Associate with registered application**」→ 登录 + 选 Team → OK（Automatic 按 bundle name 在 AGC 关联应用并生成绑定版签名）。
   - 验证绑定：拆 `.p7b` 后 `bundle-info.app-identifier` 应与 `AppScope/resources/rawfile/agconnect-services.json` 的 `app_id` **一致**。
2. **重建 + 卸载重装**（调试验证必须重装，不可覆盖安装）。
3. **生成调试凭据**：模拟器中触发任意 CFK 接口（失败属预期）→ 抓日志（过滤 `debugToken`）取 `[clouddevelopproxy.debugToken=<值>]`；若日志显示 `ApplyCredential fail 15800002`（申请被网络阻断），连续重试触发直至出现该行。
4. **注册凭据**：AGC 控制台 →「证书、APP ID 和 Profile」→「模拟器调试凭据」→ 注册 token 值、**绑定正确应用**。生效后 `205525007` 消失（表现为 `404 Trigger not exist` 或成功——取决于目标函数是否存在）。
5. **验证**：app 真实登录 → 「立即同步」→ UI「已同步」+ hilog `AgcSnapshotStore: push ok: affected=N` / `pull ok: rows=N`。

### 快速自查表

| 现象 | 判定 |
| --- | --- |
| `401:205525007 verify signature failed` | 签名方式不对（未关联注册版） |
| `create http task error` | 调试凭据未生成/未注册 |
| `404: 160404 Trigger not exist` | **验签已通过**——仅是云函数不存在 |
| `2300056 Failed to receive data from the peer` | 网络干扰（重试即可，非配置问题） |
