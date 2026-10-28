/**
 * thirdparty-exchange —— 第三方授权码 → GoTrue 会话票据 中转函数。
 *
 * 链路：端侧 SDK 拿到 authCode → POST 本函数 → 调第三方服务器换 openid/unionid
 *       → GoTrue Admin API 查/建用户（伪邮箱）→ generate_link 取 token_hash
 *       → 返回端侧 → 端侧走标准 /auth/v1/verify 换取正式会话。
 *
 * 安全不变量（本函数的设计红线）：
 * - appSecret / appKey / clientSecret 只从 Deno.env 读，**永不回传给客户端、永不写日志**。
 * - authCode 一次性：换票成功后不缓存、不重放。
 * - 错误响应**不含第三方原始报文**（避免泄露内部结构）；只回通用中文文案 + 自定义错误码。
 *
 * 契约（与客户端约定，见 apps/harmony/.../SupabaseAuthProvider.ets 与 android 同名实现）：
 *   POST /functions/v1/thirdparty-exchange
 *   Body: { provider: 'wechat'|'qq'|'huawei', authCode: string, state?: string }
 *   200:  { token_hash, type: 'magiclink', user_id, is_new_user }
 *   4xx:  { error: string, message_zh: string }
 *
 * ⚠ 未实测项（部署前必须验证，见 docs/cloud/supabase-sync-setup.md）：
 *  1. `/admin/generate_link` 的响应字段名 `properties.hashed_token`（GoTrue 官方契约，
 *     但本自托管 Supabase 栈版本未实测）。若字段名有差异，改 normalizeTokenHash 一处即可。
 *  2. 伪邮箱域 `thirdparty.fittracker.app` 是否被本栈的 GoTrue 接受
 *     （手机号伪邮箱 phone.fittracker.app 已在用，但域名不同需独立验证）。
 *  3. `/auth/v1/admin/users` 的幂等语义（本实现先查后建，规避重复建号）。
 *
 * 部署：
 *   npx supabase functions deploy thirdparty-exchange --project-ref <ref> --no-verify-jwt
 *   （--no-verify-jwt 必需：端侧在未登录状态下调用本函数，因而不带 Supabase JWT；
 *     函数自身以 service_role key 访问 Admin API。）
 */

import {
  buildThirdPartyEmail,
  exchangeHuawei,
  exchangeQq,
  exchangeWeChat,
  type ThirdPartyIdentity,
} from "./providers.ts";

// ── 环境变量读取 ────────────────────────────────────────────────────────────
//
// ⚠ 在**每次请求时**读取，而非模块加载时快照。
// 原因（实测发现）：若在顶层 `const ENV = {...}` 快照，测试在 import 本模块后
// 再 Deno.env.set 设置的环境变量不会被感知，导致全部用例误判为 server_misconfigured。
// 请求时读取也符合 Edge Function 的运行时语义（env 在容器启动后才注入完成）。

/** 运行时常量（非 secret）。 */
const SUPPORTED_PROVIDERS: string[] = ["wechat", "qq", "huawei"];

/** 每次调用都新读环境变量——见上方说明。 */
function readEnv() {
  return {
    supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
    serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    wechatAppId: Deno.env.get("WECHAT_APP_ID") ?? "",
    wechatAppSecret: Deno.env.get("WECHAT_APP_SECRET") ?? "",
    qqAppId: Deno.env.get("QQ_APP_ID") ?? "",
    qqAppKey: Deno.env.get("QQ_APP_KEY") ?? "",
    huaweiClientId: Deno.env.get("HUAWEI_CLIENT_ID") ?? "",
    huaweiClientSecret: Deno.env.get("HUAWEI_CLIENT_SECRET") ?? "",
  };
}

// ── 请求/响应形状（显式接口，便于测试与类型检查） ────────────────────────────

interface ExchangeRequest {
  provider?: string;
  authCode?: string;
  state?: string;
}

interface ExchangeSuccess {
  token_hash: string;
  type: string;
  user_id: string;
  is_new_user: boolean;
}

interface ExchangeError {
  error: string;
  message_zh: string;
}

/** 输出统一 JSON 响应（Content-Type 固定）。 */
function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status: status,
    headers: { "Content-Type": "application/json" },
  });
}

function errorResponse(code: string, messageZh: string, status: number): Response {
  const body: ExchangeError = { error: code, message_zh: messageZh };
  return jsonResponse(body, status);
}

// ── 第三方换票分派 ──────────────────────────────────────────────────────────

/**
 * 按 provider 调对应换票函数。
 *
 * 返回 null 表示换票失败（凭据无效 / 第三方报错 / 网络异常）——**不区分具体原因**，
 * 对外一律「授权已失效」；具体原因只写服务端日志（不含 secret）。
 */
async function exchangeIdentity(
  provider: string,
  authCode: string,
  fetchImpl: typeof fetch,
  env: ReturnType<typeof readEnv>,
): Promise<ThirdPartyIdentity | null> {
  if (provider === "wechat") {
    return await exchangeWeChat(authCode, fetchImpl, env.wechatAppId, env.wechatAppSecret);
  }
  if (provider === "qq") {
    return await exchangeQq(authCode, fetchImpl, env.qqAppId, env.qqAppKey);
  }
  if (provider === "huawei") {
    return await exchangeHuawei(authCode, fetchImpl, env.huaweiClientId, env.huaweiClientSecret);
  }
  return null;
}

// ── GoTrue Admin API 封装 ───────────────────────────────────────────────────

/**
 * Admin API 请求头（service_role 作为 Bearer，apikey 同值）。
 * ⚠ 该 header 含 service_role key——**绝不写入日志、绝不出现在响应里**。
 */
function adminHeaders(serviceRoleKey: string): Record<string, string> {
  return {
    "apikey": serviceRoleKey,
    "Authorization": "Bearer " + serviceRoleKey,
    "Content-Type": "application/json",
  };
}

/** Admin API 基础 URL。 */
function adminUrl(supabaseUrl: string, path: string): string {
  return supabaseUrl + "/auth/v1" + path;
}

/**
 * 查用户是否存在（按 email 过滤）。
 *
 * 用 GET /admin/users?email=<email> 精确查询；GoTrue 支持该过滤参数。
 * 网络异常 / 非 2xx 一律返回 null（调用方按「查不到」处理 → 走建号路径，
 * 若建号因已存在而失败，最终会由 generate_link 的失败兜底，不会产生脏数据）。
 */
async function findUserByEmail(
  email: string,
  fetchImpl: typeof fetch,
  env: ReturnType<typeof readEnv>,
): Promise<string | null> {
  let response: Response;
  try {
    response = await fetchImpl(
      adminUrl(env.supabaseUrl, "/admin/users?email=" + encodeURIComponent(email)),
      { method: "GET", headers: adminHeaders(env.serviceRoleKey) },
    );
  } catch (error) {
    return null;
  }
  if (response.status < 200 || response.status > 299) {
    return null;
  }
  let raw: string = "";
  try {
    raw = await response.text();
  } catch (error) {
    return null;
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    return null;
  }
  // 响应可能是 { users: [...] } 或直接数组（GoTrue 版本差异）——两种都容错
  const list: unknown[] = Array.isArray(parsed)
    ? parsed
    : (typeof parsed === "object" && parsed !== null && Array.isArray((parsed as { users?: unknown[] }).users)
      ? (parsed as { users: unknown[] }).users
      : []);
  if (list.length === 0) {
    return null;
  }
  const first: unknown = list[0];
  if (typeof first !== "object" || first === null) {
    return null;
  }
  const id: unknown = (first as { id?: unknown }).id;
  return typeof id === "string" && id.length > 0 ? id : null;
}

/**
 * 创建用户（伪邮箱 + 昵称写入 metadata）。
 *
 * ⚠ 必须写 user_metadata.nickname：客户端 SupabaseAuthProvider 的会话快照校验要求
 * displayName 为 string；缺 nickname 会导致「登录成功但重启掉线」
 * （见 apps/harmony/.../SupabaseAuthProvider.ets 的昵称兜底注释）。
 */
async function createUser(
  email: string,
  nickname: string,
  fetchImpl: typeof fetch,
  env: ReturnType<typeof readEnv>,
): Promise<string | null> {
  const body: Record<string, unknown> = {
    email: email,
    email_confirm: true,
    user_metadata: { nickname: nickname },
  };
  let response: Response;
  try {
    response = await fetchImpl(adminUrl(env.supabaseUrl, "/admin/users"), {
      method: "POST",
      headers: adminHeaders(env.serviceRoleKey),
      body: JSON.stringify(body),
    });
  } catch (error) {
    return null;
  }
  if (response.status < 200 || response.status > 299) {
    return null;
  }
  let raw: string = "";
  try {
    raw = await response.text();
  } catch (error) {
    return null;
  }
  try {
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== "object" || parsed === null) {
      return null;
    }
    const id: unknown = (parsed as { id?: unknown }).id;
    return typeof id === "string" && id.length > 0 ? id : null;
  } catch (error) {
    return null;
  }
}

/**
 * 生成 magiclink 并取 token_hash。
 *
 * 用 token_hash 而非直接签发 token：让客户端走标准 /auth/v1/verify，
 * access/refresh token 的签发与刷新语义完全由 GoTrue 承担（与手机验证码链路同形）。
 */
async function generateTokenHash(
  email: string,
  fetchImpl: typeof fetch,
  env: ReturnType<typeof readEnv>,
): Promise<string | null> {
  const body: Record<string, unknown> = { type: "magiclink", email: email };
  let response: Response;
  try {
    response = await fetchImpl(adminUrl(env.supabaseUrl, "/admin/generate_link"), {
      method: "POST",
      headers: adminHeaders(env.serviceRoleKey),
      body: JSON.stringify(body),
    });
  } catch (error) {
    return null;
  }
  if (response.status < 200 || response.status > 299) {
    return null;
  }
  let raw: string = "";
  try {
    raw = await response.text();
  } catch (error) {
    return null;
  }
  return normalizeTokenHash(raw);
}

/**
 * 从 generate_link 响应中取 token_hash。
 *
 * 独立成纯函数**便于适配 GoTrue 版本差异**：官方契约是 `properties.hashed_token`，
 * 但历史版本/不同部署可能把 hash 放在其他位置。此处按优先级依次尝试，
 * 一旦实测发现字段名不同，只需改本函数（不改调用方）。
 *
 * 表达式：解析为对象后依次读
 *   1. properties.hashed_token（官方 OpenAPI 契约）
 *   2. hashed_token（顶层平铺）
 *   3. token_hash（部分版本的别名）
 *   4. action_link 的查询串 `token=` / `token_hash=`（从 URL 反解，兜底）
 */
export function normalizeTokenHash(rawResponse: string): string | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(rawResponse);
  } catch (error) {
    return null;
  }
  if (typeof parsed !== "object" || parsed === null) {
    return null;
  }
  const root: Record<string, unknown> = parsed as Record<string, unknown>;

  // 1) properties.hashed_token
  const properties: unknown = root["properties"];
  if (typeof properties === "object" && properties !== null) {
    const hashedToken: unknown = (properties as Record<string, unknown>)["hashed_token"];
    if (typeof hashedToken === "string" && hashedToken.length > 0) {
      return hashedToken;
    }
  }
  // 2) 顶层 hashed_token
  const topHashed: unknown = root["hashed_token"];
  if (typeof topHashed === "string" && topHashed.length > 0) {
    return topHashed;
  }
  // 3) 顶层 token_hash
  const topTokenHash: unknown = root["token_hash"];
  if (typeof topTokenHash === "string" && topTokenHash.length > 0) {
    return topTokenHash;
  }
  // 4) 从 action_link 反解（兜底）
  const actionLink: unknown = root["action_link"];
  if (typeof actionLink === "string" && actionLink.length > 0) {
    const fromLink: string | null = extractTokenFromLink(actionLink);
    if (fromLink !== null) {
      return fromLink;
    }
  }
  return null;
}

/** 从 action_link 的查询串提取 token（兜底路径）。 */
function extractTokenFromLink(link: string): string | null {
  const queryIndex: number = link.indexOf("?");
  if (queryIndex < 0) {
    return null;
  }
  const query: string = link.substring(queryIndex + 1);
  for (const pair of query.split("&")) {
    const eq: number = pair.indexOf("=");
    if (eq <= 0) {
      continue;
    }
    const key: string = pair.substring(0, eq);
    if (key === "token" || key === "token_hash") {
      const value: string = decodeURIComponent(pair.substring(eq + 1));
      if (value.length > 0) {
        return value;
      }
    }
  }
  return null;
}

// ── 主流程 ──────────────────────────────────────────────────────────────────

/**
 * 处理换票请求（导出以便单测直接调用，不经 Deno.serve）。
 */
export async function handleExchange(
  req: Request,
  fetchImpl: typeof fetch = fetch,
): Promise<Response> {
  // 请求时读取环境变量（见 readEnv 说明）
  const env = readEnv();
  // 1) 方法校验
  if (req.method !== "POST") {
    return errorResponse("method_not_allowed", "仅支持 POST", 405);
  }
  // 2) 配置就绪校验（缺失时明确报配置问题，而非笼统失败）
  if (env.supabaseUrl.length === 0 || env.serviceRoleKey.length === 0) {
    return errorResponse("server_misconfigured", "服务端未就绪，请稍后重试", 500);
  }
  // 3) 载荷解析
  let body: ExchangeRequest;
  try {
    const raw: string = await req.text();
    body = JSON.parse(raw) as ExchangeRequest;
  } catch (error) {
    return errorResponse("invalid_payload", "请求格式错误", 400);
  }
  const provider: string = body.provider ?? "";
  const authCode: string = body.authCode ?? "";
  if (!SUPPORTED_PROVIDERS.includes(provider)) {
    return errorResponse("unsupported_provider", "不支持的登录方式", 400);
  }
  if (authCode.length === 0) {
    return errorResponse("missing_auth_code", "授权参数缺失，请重试", 400);
  }

  // 4) 第三方换票
  const identity: ThirdPartyIdentity | null = await exchangeIdentity(provider, authCode, fetchImpl, env);
  if (identity === null) {
    // 不区分「凭据无效 / 第三方报错 / 网络异常」——对外统一文案，细节不出网
    return errorResponse("exchange_failed", "授权已失效，请重新登录", 401);
  }

  // 5) 伪邮箱合成
  const email: string = buildThirdPartyEmail(identity.prefix, identity.unionId);
  if (email.length === 0) {
    return errorResponse("identity_incomplete", "未能获取账号标识，请重试", 400);
  }

  // 6) 查用户 → 不存在则建（幂等：先查后建，避免重复建号报错）
  let userId: string | null = await findUserByEmail(email, fetchImpl, env);
  let isNewUser: boolean = false;
  if (userId === null) {
    userId = await createUser(email, identity.nickname, fetchImpl, env);
    isNewUser = userId !== null;
    if (userId === null) {
      return errorResponse("user_provision_failed", "登录服务暂时不可用，请稍后重试", 500);
    }
  }

  // 7) 生成 magiclink token_hash
  const tokenHash: string | null = await generateTokenHash(email, fetchImpl, env);
  if (tokenHash === null) {
    return errorResponse("token_issue_failed", "登录服务暂时不可用，请稍后重试", 500);
  }

  const success: ExchangeSuccess = {
    token_hash: tokenHash,
    type: "magiclink",
    user_id: userId,
    is_new_user: isNewUser,
  };
  return jsonResponse(success, 200);
}

// Deno Deploy / Supabase Edge Functions 入口。
//
// ⚠ 用 import.meta.main 守护：仅在「作为主模块运行」时启动 HTTP 服务。
// 若不加守护，测试文件 import 本模块时会连带执行 Deno.serve()，
// 导致测试进程尝试监听端口（NotCapable: Requires net access）而整体失败。
// 这是实测发现的约束（见 index.test.ts 的导入方式）。
if (import.meta.main) {
  Deno.serve((req: Request): Promise<Response> => handleExchange(req));
}
