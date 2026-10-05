/**
 * echo-probe —— 云同步 v2 通道探针云函数（【临时】验证后删除）
 *
 * 用途（对应计划：.rivet/plans/云同步云端通道更换-云函数中转方案-wave-0-双探针门禁.md Wave 0）：
 *  1. 验证端侧 cloudFunction.call 鉴权链是否可用——与 CloudDB 数据面 401 属不同鉴权链，
 *     是「云函数中转」方案（v2）的 GO/NO-GO 判据；
 *  2. 回显 event 全文结构——验证官方论断「云函数不会自动携带调用者身份」
 *     （HTTP 触发器 event 字段仅 path/httpMethod/headers/queryStringParameters/body/isBase64Encoded）。
 *
 * 部署：AGC 控制台 → 云开发（Serverless）→ 云函数 → 创建函数（Node.js）
 *  - 函数名：echo-probe
 *  - 函数代码：本文件内容粘贴（入口 handler = myHandler）
 *  - 触发器：HTTP 触发器；认证类型按“端侧调用”要求配置（以控制台实际界面为准，
 *    社区经验值 apigw-client；若控制台默认值即可用则保持默认）
 *
 * 端侧调用（AccountSyncPage「通道探针（临时）」按钮）：
 *  cloudFunction.call({ name: 'echo-probe', data: '{"hello":"probe"}', version: '$latest', timeout: 20000 })
 */
module.exports.myHandler = function (event, context, callback, logger) {
  try {
    callback({
      ok: true,
      ts: Date.now(),
      echo: JSON.stringify(event).slice(0, 4000)
    })
  } catch (err) {
    callback({ ok: false, error: String(err) })
  }
}
