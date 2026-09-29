# AGC 云服务配置手册（v0.1 预备稿）

> 用途：完成本手册后，工程具备执行「登录注册与云同步」计划 Wave 5（AGC 真实接线）的全部外部条件。
> 状态：v0.2（2026-09-30）——流程基于华为官方文档与工程代码事实编写；标 ⚠ 的条目以控制台实际界面为准。
> v0.2 修订：修正 `payloadJson` 字段类型（String→Text——官方 String 上限 200 字符装不下聚合包，且字段类型部署后不可改）；补充存储区前置、证书指纹实值（§5）、`schema.json` 入仓路径与排错速查（§7）。配套材料见 `cloud/agc/`。
> 配套：`.rivet/plans/fittracker-登录注册与云同步-agc-实现计划.md`（配置表 8 项即本手册章节 1-5）。

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
3. 完成后把「**测试手机号 + 测试验证码**」两个值告知——Wave 5 模拟器实测将用它们走通真实 AGC 链路（测试号码不发真实短信）

## 3. 开通云数据库并创建 SyncSnapshot 对象类型（配置表项 5）

官方步骤参考：[新增对象类型 - 云数据库 - Cloud Foundation Kit](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/cloudfoundation-database-add-object)、[新增存储区](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/cloudfoundation-database-add-zone)

> **存储区前置**：对象类型归属某个「存储区」（云数据库下最多 4 个）。先在「存储区」页签按需新增（建议名 `FitTracker`）；创建对象类型时注意其实际归属——Wave 5 端侧以 `cloudDatabase.zone('<存储区名>')` 引用，**名字必须一致**。

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
2. **先留存，暂不放入工程**（原因见第 6 节「放入时机」）
3. Wave 5 接线时放入路径：`entry/src/main/resources/rawfile/agconnect-services.json`
   - 依据：`CloudEnvironment.detectAgcConfig()` 以 rawfile 探测该文件（`entry/src/main/ets/common/services/CloudEnvironment.ets`）
   - 是否纳入版本控制由你决定（该文件属项目配置产物）

## 5. 注册调试证书指纹（配置表项 7）

1. AGC → 项目设置 → 常规 → 「**证书指纹**」区 → 添加
2. 调试证书 SHA256 指纹获取途径 ⚠（以 DevEco 实际界面为准）：
   - **已代为提取**（openssl 实测本机自动签名证书 Leaf，可直接使用）：
     `12:3B:CE:0A:30:90:63:C2:58:AD:98:3B:C6:E9:EC:9F:CC:FF:42:DD:19:4E:9D:02:48:2A:A3:AC:6A:8F:CE:61`
     （来源 `C:\Users\19308\.ohos\config\default_FitTracker_….cer`，CN=`李凡(1794157958125343233)\,Development`；注意是证书链中的 **Leaf 证书**，不是根 CA/中间 CA，后两者指纹不通用）
   - 也可自行查看：DevEco Studio → File → Project Structure → Signing Configs；或
   - 本机 `C:\Users\19308\.ohos\config\default_FitTracker_*.cer`（自动签名证书）
3. 未注册指纹时：认证服务与云数据库调用可能返回 403

## 6. 完成后（联动清单与注意事项）

完成 1-5 后，把以下状态告知编排方：

- [ ] 认证服务已开通，手机号 / 邮箱 / 华为账号 / 微信 / QQ 已按需启用
- [ ] 测试手机号 + 测试验证码已配置（提供两个值）
- [ ] 云数据库已开通，`SyncSnapshot` 对象类型已创建（权限 = 仅数据创建者读写）
- [ ] `agconnect-services.json` 已下载（告知暂存位置）
- [ ] 调试证书指纹已注册

**放入时机（重要）**：`agconnect-services.json` 一旦放入 rawfile，`CloudEnvironment.isAgcConfigured()` 即为 true。当前代码下（Wave 5 未接线）登录/注册页的「沙盒提示」会消失，而认证实际仍走沙盒（`AuthService.resolveProvider()` 尚有 `SandboxAuthProvider` 占位）——为避免「显示与行为不一致」，建议 Wave 5 接线时一并放入，放入后我会同步更新提示逻辑并重跑全量测试。

**验证引用**（Wave 5 完成时使用）：
- 模拟器实测：发送验证码 → 输入测试验证码 → 登录成功（走 AGC）
- 同步一次后，AGC 控制台云数据库可见该用户一行数据
- 第三方登录（华为账号/微信/QQ）真机验证（或标「待真机」）

## 7. 排错速查

| 现象 | 处置 |
| --- | --- |
| 调用返回 403 | 证书指纹未注册 / 填错（须填调试证书 **Leaf** 指纹）→ 第 5 节 |
| `1008230002` Schema config error | 工程 `schema.json` 与云端对象类型不一致 → 重新导出一份覆盖（第 3 节步骤 6） |
| 仍是 sandbox / 演示模式未消失 | `agconnect-services.json` 缺失或未打进包 → 核对 rawfile 路径，clean 后重建 |
| 「认证用户未获得权限」类失败 | 第 3 节权限注记的排查两步（AccessToken 凭据 → 恢复认证用户 upsert） |
| `number of CloudDBZone exceeds the limit` | 存储区已 4 个 → 复用或删除旧存储区（删区连带删数据） |
| `existing fields cannot be modified` | 改动已部署对象类型的字段定义 → 删除对象类型重建（其中数据一并清除） |
| 手机收不到验证码 | 正常——开发期用**测试验证码**（第 2 节） |
