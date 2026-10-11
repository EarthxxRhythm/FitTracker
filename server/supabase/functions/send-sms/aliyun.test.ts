/**
 * aliyun.ts 单元测试 + 独立通道对账（WebCrypto vs `node:crypto`）。
 * 运行：`deno test supabase/functions/send-sms/`
 */
import { createHmac } from "node:crypto";
import {
  aliyunSign,
  aliyunTimestamp,
  buildAliyunParams,
  buildSendSmsVerifyCodeParams,
  DYPNS_API_HOST,
  DYSMS_API_HOST,
  percentEncode,
  toMainlandPhone,
} from "./aliyun.ts";

function assertEq(actual: unknown, expected: unknown, label: string): void {
  if (actual !== expected) {
    throw new Error(`${label}\n  actual:   ${actual}\n  expected: ${expected}`);
  }
}

Deno.test("percentEncode —— RFC3986 边界", () => {
  assertEq(percentEncode("a b"), "a%20b", "空格→%20");
  assertEq(percentEncode("a+b"), "a%2Bb", "加号转义");
  assertEq(percentEncode("~"), "~", "波浪线保留");
  assertEq(percentEncode("!*'()"), "%21%2A%27%28%29", "四条补充编码字符");
  assertEq(percentEncode("中"), "%E4%B8%AD", "UTF-8 多字节");
  assertEq(percentEncode("2026-10-04T12:34:56Z"), "2026-10-04T12%3A34%3A56Z", "冒号转义");
});

Deno.test("aliyunTimestamp —— 剔除毫秒保留 Z", () => {
  assertEq(aliyunTimestamp(new Date("2026-10-04T12:34:56.789Z")), "2026-10-04T12:34:56Z", "毫秒剔除");
});

Deno.test("toMainlandPhone —— E.164 去前缀", () => {
  assertEq(toMainlandPhone("+8613900000001"), "13900000001", "+86 前缀剥离");
  assertEq(toMainlandPhone("13900000001"), "13900000001", "裸号透传");
});

Deno.test("buildAliyunParams —— 关键字段与模板变量", () => {
  const params = buildAliyunParams("+8613900000001", "123456", {
    keyId: "AKID",
    signName: "FitTracker",
    templateCode: "SMS_100",
    templateParamKey: "code",
    nonce: "nonce-1",
    timestamp: "2026-10-04T00:00:00Z",
  });
  assertEq(params.Action, "SendSms", "Action");
  assertEq(params.PhoneNumbers, "13900000001", "号码转换");
  assertEq(params.TemplateParam, '{"code":"123456"}', "模板参数 JSON");
  assertEq(params.SignatureMethod, "HMAC-SHA1", "签名方法");
  assertEq(params.Version, "2017-05-25", "API 版本");
  assertEq(params.SignatureVersion, "1.0", "签名版本");
});

Deno.test("aliyunSign —— 确定性 / 键序无关 / 与 node:crypto 对账", async () => {
  const params: Record<string, string> = { Action: "SendSms", B: "2", A: "1", PhoneNumbers: "13900000001" };
  const signature = await aliyunSign(params, "secret123");
  assertEq(await aliyunSign(params, "secret123"), signature, "确定性");

  const reordered: Record<string, string> = { PhoneNumbers: "13900000001", A: "1", Action: "SendSms", B: "2" };
  assertEq(await aliyunSign(reordered, "secret123"), signature, "键序无关（排序后等价）");

  // 独立通道对账：use node:crypto 复算同一 StringToSign 的 HMAC-SHA1
  const canonicalized = Object.keys(params)
    .sort()
    .map((key) => `${percentEncode(key)}=${percentEncode(params[key])}`)
    .join("&");
  const stringToSign = `GET&%2F&${percentEncode(canonicalized)}`;
  const independent = createHmac("sha1", "secret123&").update(stringToSign, "utf8").digest("base64");
  assertEq(signature, independent, "WebCrypto 与 node:crypto 结果一致");

  if (!/^[A-Za-z0-9+/]+=*$/.test(signature)) {
    throw new Error("签名非 base64 形态: " + signature);
  }
});

Deno.test("buildSendSmsVerifyCodeParams —— 号码认证通道（具体验证码值直发 + 附加变量）", () => {
  const params = buildSendSmsVerifyCodeParams("+8613900000001", "561166", {
    keyId: "AKID",
    signName: "恒创联众",
    templateCode: "100001",
    templateParamKey: "code",
    extraParams: { min: "5" },
    nonce: "nonce-2",
    timestamp: "2026-10-04T00:00:00Z",
  });
  assertEq(params.Action, "SendSmsVerifyCode", "Action");
  assertEq(params.PhoneNumber, "13900000001", "手机号（单数参数名）");
  assertEq(params.TemplateParam, '{"min":"5","code":"561166"}', "具体验证码值直发 + 附加变量");
  assertEq(params.SignName, "恒创联众", "赠送签名");
  assertEq(params.TemplateCode, "100001", "赠送模板 CODE");
  assertEq(params.SignatureVersion, "1.0", "签名版本");
  assertEq(params.Version, "2017-05-25", "API 版本");
  assertEq(DYPNS_API_HOST, "dypnsapi.aliyuncs.com", "dypns 主机（主线）");
  assertEq(DYSMS_API_HOST, "dysmsapi.aliyuncs.com", "dysms 主机（备用，需资质）");
});

Deno.test("buildSendSmsVerifyCodeParams —— 无附加变量时仅含验证码字段", () => {
  const params = buildSendSmsVerifyCodeParams("13900000001", "123456", {
    keyId: "AKID",
    signName: "S",
    templateCode: "T",
    templateParamKey: "code",
    nonce: "n",
    timestamp: "2026-10-04T00:00:00Z",
  });
  assertEq(params.TemplateParam, '{"code":"123456"}', "仅 code 字段");
});
