# echo-probe —— 云同步 v2 通道探针（临时）

> 归属计划：`.rivet/plans/云同步云端通道更换-云函数中转方案-wave-0-双探针门禁.md`（Wave 0 探针 A）
> 生命周期：**临时**——Wave 0 GO/NO-GO 判定使用；v2 正式函数（`sync-api`）落地后本函数连同端侧探针按钮一并删除。

## 用途

1. **通道可用性判据**：端侧 `cloudFunction.call` 能否成功调用云函数（绕开 CloudDB 数据面 401 的另一条鉴权链）。
2. **event 结构回显**：验证官方论断「云函数不自动携带调用者身份」——回显内容中应无 uid/openId/unionId 字段。

## 部署（AGC 控制台）

1. AGC → 项目 → 云开发（Serverless）→ 云函数 → 创建函数
2. 函数名：`echo-probe`；运行时：Node.js（版本以控制台可选为准）
3. 函数代码：粘贴 `handler.js` 全文（入口 `myHandler`）
4. 触发器：HTTP 触发器；认证类型按「端侧调用」要求配置（以控制台实际界面为准）
5. 保存并在控制台「测试」页以任意 payload 触发一次，确认返回 `{ ok: true, ... }`

## 端侧触发（模拟器实测）

「账号与同步」页 → 「通道探针（临时）」按钮 → 结果进 toast + hilog（tag `ChannelProbe`）。

成功样例判据：`ok: {...}`（结果里含 `echo` 回显 JSON）。
失败判据：`fail: code=...`（对照 cloudFunction 错误码表：1008210001 网络 / 1008210009 客户端 / 1008211001 服务端 / 401 参数）。

## 清理

- 控制台：删除函数 `echo-probe`
- 仓库：删除本目录
- 端侧：删除 AccountSyncPage 的「通道探针（临时）」按钮与 `runChannelProbe`
