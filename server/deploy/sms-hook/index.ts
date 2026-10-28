/**
 * FitTracker · 自托管 Supabase 栈的 GoTrue「Send SMS Hook」接收端（独立容器版）
 *
 * 链路：自托管 GoTrue 需要发验证码短信 → POST 本服务（standardwebhooks 签名）
 *       → 验签 → 解析 { user.phone, sms.otp } → **立即应答 200** → 后台调阿里云 SendSmsVerifyCode。
 *
 * 与 `supabase/functions/send-sms/`（旧托管栈边缘函数）的关系：
 * - 本文件是其平移版；验签 / 解析 / 阿里云调用逻辑逐行一致，仅两处环境适配：
 *   ① 边缘专有 `EdgeRuntime.waitUntil` → 常驻进程的 fire-and-forget（`void sendTask`）；
 *   ② `Deno.serve` 显式绑定端口（`PORT`，默认 8787）。
 * - 两份文件有意保持独立（旧托管栈在切换完成前继续服务），修改时需同步。
 *
 * 关键设计（继承自边缘版，2026-10-04 端到端实测驱动）：
 * - **GoTrue 对 Hook 的硬超时为 5 秒**——立即返回 200，阿里云调用在后台完成。
 *   发送失败不反馈给 GoTrue，只在容器日志（console.error）可见——自用场景已知取舍。
 * - 阿里云调用带 20s AbortController 超时（避免后台任务无限挂起）。
 *
 * 规范来源：
 * - Hook 输入/输出：https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook
 * - 阿里云 SendSmsVerifyCode：https://help.aliyun.com/zh/pnvs/developer-reference/api-dypnsapi-2017-05-25-sendsmsverifycode
 *
 * 部署：见 deploy/README.md（docker build + docker run --env-file）。
 * 环境变量：
 * - SEND_SMS_HOOK_SECRET      GoTrue 侧 Hook secret（形如 `v1,whsec_xxx`，两端配对）
 * - ALIYUN_ACCESS_KEY_ID      RAM 子账号 AccessKeyId
 * - ALIYUN_ACCESS_KEY_SECRET  RAM 子账号 AccessKeySecret
 * - ALIYUN_SMS_SIGN_NAME      号码认证控制台的**赠送签名**（恒创联众）
 * - ALIYUN_SMS_TEMPLATE_CODE  控制台的**赠送模板** CODE（100001）
 * - ALIYUN_SMS_TEMPLATE_PARAM_KEY  模板变量名（`code`）
 * - ALIYUN_SMS_TEMPLATE_EXTRA_JSON 模板附加静态变量（`{"min":"5"}`）
 * - PORT                       监听端口（默认 8787）
 */

import {
  aliyunSign,
  aliyunTimestamp,
  buildSendSmsVerifyCodeParams,
  DYPNS_API_HOST,
  percentEncode,
} from "./aliyun.ts";

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
  } else {
    // 成功也留痕（2026-10-10 教训：成功静默使「短信是否已发出」难以核实）
    console.log("aliyun send ok");
  }
}

Deno.serve({ port: Number(Deno.env.get("PORT") || "8787") }, async (req: Request): Promise<Response> => {
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

    // 3. 后台发送——常驻容器版采用 fire-and-forget（与边缘版 EdgeRuntime.waitUntil 语义一致：
    //    立即应答规避 GoTrue 5s Hook 超时；sendTask 自身已 catch，不会产生未处理拒绝）。
    const sendTask: Promise<void> = sendViaAliyun(phone, otp).catch((error: unknown) => {
      console.error("sendViaAliyun unexpected error:", error);
    });
    void sendTask;

    // 4. 立即成功应答（Hook 规范：200 = 已接受）
    return new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "unexpected error" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
