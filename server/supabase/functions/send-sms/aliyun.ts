/**
 * 阿里云短信 RPC 签名（v1.0 / HMAC-SHA1）——纯函数模块（可单测、无 Deno.serve 副作用）。
 *
 * 规范：https://help.aliyun.com/zh/sdk/product-overview/rpc-mechanism
 * 由 `index.ts`（Send SMS Hook 中转）引用；测试见 `aliyun_test.ts`
 * （含与 node:crypto 的独立实现对账）。
 */

const encoder = new TextEncoder();

function bytesToBase64(bytes: ArrayBuffer): string {
  const view = new Uint8Array(bytes);
  let binary = "";
  for (let i = 0; i < view.length; i++) {
    binary += String.fromCharCode(view[i]);
  }
  return btoa(binary);
}

/**
 * RFC3986 百分号编码（阿里云签名规范）：
 * `encodeURIComponent` 之上补编码 `!'()*`（其默认不转），且空格 → `%20`（非 `+`）。
 */
export function percentEncode(value: string): string {
  return encodeURIComponent(value)
    .replace(/[!'()*]/g, (ch) => `%${ch.charCodeAt(0).toString(16).toUpperCase()}`)
    .replace(/\+/g, "%20");
}

/** 时间戳：阿里云要求 `YYYY-MM-DDTHH:mm:ssZ`（UTC，无毫秒）。 */
export function aliyunTimestamp(now: Date = new Date()): string {
  return now.toISOString().replace(/\.\d{3}Z$/, "Z");
}

/**
 * 构造阿里云 RPC 签名：参数按 key 字典序 → RFC3986 编码 →
 * StringToSign = `GET&%2F&${percentEncode(canonicalizedQuery)}` →
 * Signature = base64(HMAC-SHA1(`${accessKeySecret}&`, StringToSign))。
 */
export async function aliyunSign(
  params: Record<string, string>,
  accessKeySecret: string,
): Promise<string> {
  const canonicalized = Object.keys(params)
    .sort()
    .map((key) => `${percentEncode(key)}=${percentEncode(params[key])}`)
    .join("&");
  const stringToSign = `GET&%2F&${percentEncode(canonicalized)}`;

  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(`${accessKeySecret}&`),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(stringToSign));
  return bytesToBase64(signature);
}

/** 阿里云要求 11 位国内号码；E.164（`+86…`）→ 去前缀。 */
export function toMainlandPhone(phone: string): string {
  return phone.replace(/^\+86/, "").replace(/\s/g, "");
}

/** 组装 SendSms 的完整参数表（不含 Signature——签名在 [aliyunSign] 后拼入）。 */
export function buildAliyunParams(
  phone: string,
  otp: string,
  env: {
    keyId: string;
    signName: string;
    templateCode: string;
    templateParamKey: string;
    nonce: string;
    timestamp: string;
  },
): Record<string, string> {
  return {
    AccessKeyId: env.keyId,
    Action: "SendSms",
    Format: "JSON",
    PhoneNumbers: toMainlandPhone(phone),
    RegionId: "cn-hangzhou",
    SignName: env.signName,
    SignatureMethod: "HMAC-SHA1",
    SignatureNonce: env.nonce,
    SignatureVersion: "1.0",
    TemplateCode: env.templateCode,
    TemplateParam: JSON.stringify({ [env.templateParamKey]: otp }),
    Timestamp: env.timestamp,
    Version: "2017-05-25",
  };
}

// ── 号码认证服务「短信认证」——个人免资质通道（当前主线） ─────────────────

/** 号码认证服务 API 主机（短信认证：免申请资质/签名/模板，用控制台赠送资源）。 */
export const DYPNS_API_HOST: string = "dypnsapi.aliyuncs.com";

/** 短信服务 API 主机（dysmsapi——自定义签名需资质审核，保留备用）。 */
export const DYSMS_API_HOST: string = "dysmsapi.aliyuncs.com";

/**
 * 组装「SendSmsVerifyCode」（号码认证服务）参数表——个人免资质通道主线。
 *
 * 与 dysms 通道的关键差异（官方 OpenAPI 元数据确认）：
 * - 使用控制台**赠送的签名与模板**（系统签名必须搭配系统模板）；
 * - `TemplateParam` **直接传入具体验证码值**（如 `{"code":"561166"}`）——
 *   官方文档明确：非动态生成的码阿里云不校验、直接下发——校验由 GoTrue 完成
 *   （`{"code":"##code##"}` 占位符模式才会走阿里云生成+校验，本场景不使用）；
 * - 手机号参数名为单数 `PhoneNumber`。
 */
export function buildSendSmsVerifyCodeParams(
  phone: string,
  otp: string,
  env: {
    keyId: string;
    signName: string;
    templateCode: string;
    templateParamKey: string;
    /** 模板的附加静态变量（如赠送模板含 `${min}` → `{"min":"5"}`）。 */
    extraParams?: Record<string, string>;
    nonce: string;
    timestamp: string;
  },
): Record<string, string> {
  const templateParam: Record<string, string> = {
    ...(env.extraParams ?? {}),
    [env.templateParamKey]: otp,
  };
  return {
    AccessKeyId: env.keyId,
    Action: "SendSmsVerifyCode",
    Format: "JSON",
    PhoneNumber: toMainlandPhone(phone),
    RegionId: "cn-hangzhou",
    SignName: env.signName,
    SignatureMethod: "HMAC-SHA1",
    SignatureNonce: env.nonce,
    SignatureVersion: "1.0",
    TemplateCode: env.templateCode,
    TemplateParam: JSON.stringify(templateParam),
    Timestamp: env.timestamp,
    Version: "2017-05-25",
  };
}
