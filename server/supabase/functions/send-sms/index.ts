/**
 * Supabase「Send SMS Hook」→ 阿里云短信 中转函数（FitTracker）
 *
 * 链路：GoTrue 需要发验证码短信 → POST 本函数（standardwebhooks 签名）
 *       → 验签 → 解析 { user.phone, sms.otp } → **立即应答 200** → 后台调阿里云 SendSmsVerifyCode。
 *
 * 关键设计（2026-10-04 端到端实测驱动的修正）：
 * - **GoTrue 对 Hook 的硬超时为 5 秒**（超过即 `hook_timeout` 422）——而「边缘冷启动 + 跨境调用
 *   阿里云」耗时可能超过 5s。故采用 **`EdgeRuntime.waitUntil` 异步化**：验签+解析完成后立即
 *   返回 200，阿里云调用在后台完成。发送失败不再反馈给 GoTrue，只在函数日志（console.error）可见
 *   ——自用场景可接受（记录为已知取舍）。
 * - 阿里云调用带 20s AbortController 超时（避免后台任务无限挂起）。
 *
 * 规范来源：
 * - Hook 输入/输出：https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook
 * - 阿里云 SendSmsVerifyCode：https://help.aliyun.com/zh/pnvs/developer-reference/api-dypnsapi-2017-05-25-sendsmsverifycode
 * - 阿里云 RPC 签名（v1.0）：见 ./aliyun.ts
 *
 * 部署（实测可用命令）：
 * `npx supabase functions deploy send-sms --project-ref <ref> --use-api --no-verify-jwt`
 * （`--no-verify-jwt` 必需：Hook 调用不带 Supabase JWT，签名验证由本函数承担。）
 *
 * Secrets（Edge Function → Settings → Secrets）：
 * - SEND_SMS_HOOK_SECRET      Supabase Auth Hook 生成的 secret（形如 `v1,whsec_xxx`）
 * - ALIYUN_ACCESS_KEY_ID      RAM 子账号 AccessKeyId（已授权 AliyunDypnsFullAccess）
 * - ALIYUN_ACCESS_KEY_SECRET  RAM 子账号 AccessKeySecret
 * - ALIYUN_SMS_SIGN_NAME      号码认证控制台的**赠送签名**（恒创联众）
 * - ALIYUN_SMS_TEMPLATE_CODE  控制台的**赠送模板** CODE（100001）
 * - ALIYUN_SMS_TEMPLATE_PARAM_KEY  模板变量名（`code`）
 * - ALIYUN_SMS_TEMPLATE_EXTRA_JSON 模板附加静态变量（`{"min":"5"}`）
 */

import {
  aliyunSign,
  aliyunTimestamp,
  buildSendSmsVerifyCodeParams,
  DYPNS_API_HOST,
  percentEncode,
} from "./aliyun.ts";

/** 边缘运行时注入的后台任务 API（本地/测试环境不存在 → typeof 守卫）。 */
declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void } | undefined;

const encoder = new TextEncoder();

/** base64 → Uint8Array（`whsec_` secret 的解码）。 */
function base64ToBytes(base64: string): Uint8Array<ArrayBuffer> {
  const normalized = base64.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(normalized);
  const bytes = new Uint8Array(new ArrayBuffer(binary.length));
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function bytesToBase64(bytes: ArrayBuffer): string {
  const view = new Uint8Array(bytes);
  let binary = "";
  for (let i = 0; i < view.length; i++) {
    binary += String.fromCharCode(view[i]);
  }
  return btoa(binary);
}

/**
 * 校验 Hook 请求签名（standardwebhooks 规范）：
 * signedContent = `${webhookId}.${webhookTimestamp}.${rawBody}`
 * signature     = base64(HMAC-SHA256(signedContent, secretBytes))，头形如 `v1,<base64>`。
 */
async function verifyHookSignature(
  webhookId: string,
  webhookTimestamp: string,
  webhookSignature: string,
  rawBody: string,
  hookSecret: string,
): Promise<boolean> {
  const secretPart = hookSecret.includes(",") ? hookSecret.split(",")[1] : hookSecret;
  const rawSecret = secretPart.startsWith("whsec_") ? secretPart.slice("whsec_".length) : secretPart;
  const secretBytes = base64ToBytes(rawSecret);

  const key = await crypto.subtle.importKey(
    "raw",
    secretBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signedContent = `${webhookId}.${webhookTimestamp}.${rawBody}`;
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(signedContent));
  const expected = bytesToBase64(signature);

  return webhookSignature
    .split(" ")
    .map((part) => part.split(",")[1] ?? "")
    .some((candidate) => candidate === expected);
}

interface HookPayload {
  user?: { phone?: string };
  sms?: { otp?: string };
}

/**
 * 解析 `ALIYUN_SMS_TEMPLATE_EXTRA_JSON`——模板的附加静态变量。
 * 默认 `{"min":"5"}`（赠送模板内容含 `${min}分钟内有效`）；解析失败回落默认值。
 */
function parseTemplateExtra(raw: string | undefined): Record<string, string> {
  const fallback: Record<string, string> = { min: "5" };
  if (raw === undefined || raw.trim() === "") {
    return fallback;
  }
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    const result: Record<string, string> = {};
    for (const key of Object.keys(parsed)) {
      result[key] = String(parsed[key]);
    }
    return result;
  } catch (error) {
    return fallback;
  }
}

/** 后台发送任务：调阿里云 SendSmsVerifyCode（20s 超时；失败写 console.error）。 */
async function sendViaAliyun(phone: string, otp: string): Promise<void> {
  const params = buildSendSmsVerifyCodeParams(phone, otp, {
    keyId: Deno.env.get("ALIYUN_ACCESS_KEY_ID") ?? "",
    signName: Deno.env.get("ALIYUN_SMS_SIGN_NAME") ?? "",
    templateCode: Deno.env.get("ALIYUN_SMS_TEMPLATE_CODE") ?? "",
    templateParamKey: Deno.env.get("ALIYUN_SMS_TEMPLATE_PARAM_KEY") ?? "code",
    extraParams: parseTemplateExtra(Deno.env.get("ALIYUN_SMS_TEMPLATE_EXTRA_JSON")),
    nonce: crypto.randomUUID(),
    timestamp: aliyunTimestamp(),
  });
  const signature = await aliyunSign(params, Deno.env.get("ALIYUN_ACCESS_KEY_SECRET") ?? "");
  const query = Object.keys(params)
    .map((key) => `${percentEncode(key)}=${percentEncode(params[key])}`)
    .join("&") + `&Signature=${percentEncode(signature)}`;

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 20000);
  let aliyunResponse: Response;
  try {
    aliyunResponse = await fetch(`https://${DYPNS_API_HOST}/?${query}`, {
      method: "GET",
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeoutId);
  }
  const aliyunBody = await aliyunResponse.json() as { Code?: string; Message?: string };
  if (aliyunBody.Code !== "OK") {
    console.error(`aliyun send failed: ${aliyunBody.Code ?? "unknown"} ${aliyunBody.Message ?? ""}`);
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  try {
    const rawBody = await req.text();

    // 1. 验签（standardwebhooks）
    const hookSecret = Deno.env.get("SEND_SMS_HOOK_SECRET") ?? "";
    const webhookId = req.headers.get("webhook-id") ?? "";
    const webhookTimestamp = req.headers.get("webhook-timestamp") ?? "";
    const webhookSignature = req.headers.get("webhook-signature") ?? "";
    const verified = hookSecret !== "" &&
      await verifyHookSignature(webhookId, webhookTimestamp, webhookSignature, rawBody, hookSecret);
    if (!verified) {
      return new Response(JSON.stringify({ error: "invalid webhook signature" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 2. 解析载荷（Hook 规范：{ user: { phone }, sms: { otp } }）
    const payload = JSON.parse(rawBody) as HookPayload;
    const phone = payload.user?.phone ?? "";
    const otp = payload.sms?.otp ?? "";
    if (phone === "" || otp === "") {
      return new Response(JSON.stringify({ error: "missing phone or otp" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 3. 后台发送（EdgeRuntime.waitUntil）——立即应答，规避 GoTrue 5s Hook 超时
    const sendTask: Promise<void> = sendViaAliyun(phone, otp).catch((error: unknown) => {
      console.error("sendViaAliyun unexpected error:", error);
    });
    if (typeof EdgeRuntime !== "undefined") {
      EdgeRuntime.waitUntil(sendTask);
    } else {
      await sendTask; // 本地/非边缘环境：同步等待（测试语义）
    }

    // 4. 立即成功应答（Hook 规范：200 = 已接受）
    return new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "unexpected error" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
