/**
 * index.ts 端点逻辑测试（零网络——全部经 fetchImpl 注入）。
 *
 * 运行：`deno test`（工作目录 server/supabase/functions/thirdparty-exchange/）
 *
 * 覆盖重点：
 *  1. 方法/参数校验（405 / 400 各分支）
 *  2. 换票失败 → 401 且**不含第三方原始报文**
 *  3. 新用户 / 已存在用户两条路径（幂等）
 *  4. **密钥不外泄**：响应体、以及 service_role / appSecret 不出现在任何输出中
 *  5. normalizeTokenHash 的四种字段位置容错
 */
import { handleExchange, normalizeTokenHash } from "./index.ts";

function assertEq(actual: unknown, expected: unknown, label: string): void {
  if (actual !== expected) {
    throw new Error(`${label}\n  actual:   ${JSON.stringify(actual)}\n  expected: ${JSON.stringify(expected)}`);
  }
}

function assertTrue(value: boolean, label: string): void {
  if (!value) {
    throw new Error(label);
  }
}

/** 测试用环境变量（handleExchange 从 Deno.env 读取，故测试前须设置）。 */
const TEST_SERVICE_KEY: string = "TEST_SERVICE_ROLE_KEY_DO_NOT_LEAK";
const TEST_WECHAT_SECRET: string = "TEST_WECHAT_SECRET_DO_NOT_LEAK";

function setupEnv(): void {
  Deno.env.set("SUPABASE_URL", "https://test.local");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", TEST_SERVICE_KEY);
  Deno.env.set("WECHAT_APP_ID", "wx_test");
  Deno.env.set("WECHAT_APP_SECRET", TEST_WECHAT_SECRET);
  Deno.env.set("QQ_APP_ID", "123456");
  Deno.env.set("QQ_APP_KEY", "qq_test_key");
  Deno.env.set("HUAWEI_CLIENT_ID", "hw_test");
  Deno.env.set("HUAWEI_CLIENT_SECRET", "hw_test_secret");
}

/**
 * 按 URL 关键字分派的 fake fetch。
 * routes 的顺序即优先级——先匹配者胜。
 */
function fakeFetch(
  routes: Array<{ match: string; body: string; status?: number }>,
): typeof fetch {
  const impl = (input: string | URL | Request, _init?: RequestInit): Promise<Response> => {
    const url: string = typeof input === "string"
      ? input
      : (input instanceof URL ? input.toString() : input.url);
    for (const route of routes) {
      if (url.includes(route.match)) {
        return Promise.resolve(new Response(route.body, { status: route.status ?? 200 }));
      }
    }
    return Promise.resolve(new Response("", { status: 404 }));
  };
  return impl as unknown as typeof fetch;
}

/** 构造 POST 请求。 */
function postRequest(body: unknown): Request {
  return new Request("https://test.local/functions/v1/thirdparty-exchange", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

/** 微信换票成功的 fake 响应（含 userinfo 二次调用）。 */
function wechatSuccessRoutes(userInfoSuffix: Array<{ match: string; body: string; status?: number }>): Array<{ match: string; body: string; status?: number }> {
  return [
    {
      match: "sns/oauth2/access_token",
      body: JSON.stringify({ access_token: "AT", openid: "OPENID", unionid: "UNIONID", expires_in: 7200 }),
    },
    ...userInfoSuffix,
  ];
}

// ── 参数与配置校验 ──────────────────────────────────────────────────────────

Deno.test("handleExchange —— 非 POST 返回 405", async () => {
  setupEnv();
  const req = new Request("https://test.local/x", { method: "GET" });
  const response = await handleExchange(req, fakeFetch([]));
  assertEq(response.status, 405, "GET 应 405");
  const body = await response.json() as { error: string };
  assertEq(body.error, "method_not_allowed", "错误码");
});

Deno.test("handleExchange —— 服务端未配置返回 500", async () => {
  Deno.env.set("SUPABASE_URL", "");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "");
  const response = await handleExchange(postRequest({ provider: "wechat", authCode: "C" }), fakeFetch([]));
  assertEq(response.status, 500, "未配置应 500");
  const body = await response.json() as { error: string };
  assertEq(body.error, "server_misconfigured", "错误码");
  setupEnv(); // 复位
});

Deno.test("handleExchange —— 载荷非 JSON 返回 400", async () => {
  setupEnv();
  const response = await handleExchange(postRequest("not json at all"), fakeFetch([]));
  assertEq(response.status, 400, "畸形载荷应 400");
  const body = await response.json() as { error: string };
  assertEq(body.error, "invalid_payload", "错误码");
});

Deno.test("handleExchange —— 不支持的 provider 返回 400", async () => {
  setupEnv();
  const response = await handleExchange(postRequest({ provider: "facebook", authCode: "C" }), fakeFetch([]));
  assertEq(response.status, 400, "未知 provider 应 400");
  const body = await response.json() as { error: string };
  assertEq(body.error, "unsupported_provider", "错误码");
});

Deno.test("handleExchange —— 缺 authCode 返回 400", async () => {
  setupEnv();
  const response = await handleExchange(postRequest({ provider: "wechat" }), fakeFetch([]));
  assertEq(response.status, 400, "缺 code 应 400");
  const body = await response.json() as { error: string };
  assertEq(body.error, "missing_auth_code", "错误码");
});

// ── 换票失败 ────────────────────────────────────────────────────────────────

Deno.test("handleExchange —— 第三方换票失败返回 401（微信 errcode 非零）", async () => {
  setupEnv();
  const fetchImpl = fakeFetch([
    { match: "sns/oauth2/access_token", body: JSON.stringify({ errcode: 40029, errmsg: "invalid code" }) },
  ]);
  const response = await handleExchange(postRequest({ provider: "wechat", authCode: "BAD" }), fetchImpl);
  assertEq(response.status, 401, "应 401");
  const body = await response.json() as { error: string; message_zh: string };
  assertEq(body.error, "exchange_failed", "错误码");
  assertEq(body.message_zh, "授权已失效，请重新登录", "中文文案");
});

Deno.test("handleExchange —— 换票失败响应不含第三方原始报文", async () => {
  setupEnv();
  // 第三方返回包含内部细节的报文
  const fetchImpl = fakeFetch([
    {
      match: "sns/oauth2/access_token",
      body: JSON.stringify({ errcode: 40029, errmsg: "invalid code; internal-trace-id=abc123" }),
    },
  ]);
  const response = await handleExchange(postRequest({ provider: "wechat", authCode: "BAD" }), fetchImpl);
  const raw: string = await response.text();
  assertTrue(!raw.includes("internal-trace-id"), "响应不应含第三方内部标识");
  assertTrue(!raw.includes("40029"), "响应不应含第三方错误码");
  assertTrue(!raw.includes("invalid code"), "响应不应含第三方错误文案");
});

Deno.test("handleExchange —— 网络异常返回 401", async () => {
  setupEnv();
  const throwing = (() => Promise.reject(new Error("network down"))) as unknown as typeof fetch;
  const response = await handleExchange(postRequest({ provider: "qq", authCode: "C" }), throwing);
  assertEq(response.status, 401, "网络异常应 401");
});

// ── 密钥不外泄（核心安全不变量） ────────────────────────────────────────────

Deno.test("handleExchange —— 成功响应不含任何 secret", async () => {
  setupEnv();
  const fetchImpl = fakeFetch([
    ...wechatSuccessRoutes([{ match: "sns/userinfo", body: JSON.stringify({ nickname: "昵称" }) }]),
    { match: "/admin/users?email=", body: JSON.stringify({ users: [{ id: "USER_ID_1" }] }) },
    {
      match: "/admin/generate_link",
      body: JSON.stringify({ properties: { hashed_token: "TOKEN_HASH_1" } }),
    },
  ]);
  const response = await handleExchange(postRequest({ provider: "wechat", authCode: "GOOD" }), fetchImpl);
  assertEq(response.status, 200, "应 200");
  const raw: string = await response.text();
  assertTrue(!raw.includes(TEST_SERVICE_KEY), "响应不得含 service_role key");
  assertTrue(!raw.includes(TEST_WECHAT_SECRET), "响应不得含 appSecret");
  assertTrue(!raw.includes("Bearer"), "响应不得含认证头片段");
});

Deno.test("handleExchange —— 失败响应不含任何 secret", async () => {
  setupEnv();
  // 建号失败（Admin API 500）——此时响应由服务端生成，仍不得泄露 secret
  const fetchImpl = fakeFetch([
    ...wechatSuccessRoutes([{ match: "sns/userinfo", body: JSON.stringify({ nickname: "N" }) }]),
    { match: "/admin/users?email=", body: JSON.stringify({ users: [] }) },
    { match: "/admin/users", body: JSON.stringify({ msg: "boom" }), status: 500 },
  ]);
  const response = await handleExchange(postRequest({ provider: "wechat", authCode: "C" }), fetchImpl);
  const raw: string = await response.text();
  assertTrue(!raw.includes(TEST_SERVICE_KEY), "失败响应不得含 service_role key");
  assertTrue(!raw.includes(TEST_WECHAT_SECRET), "失败响应不得含 appSecret");
});

// ── 用户供应（幂等） ────────────────────────────────────────────────────────

Deno.test("handleExchange —— 已存在用户复用 id（is_new_user=false）", async () => {
  setupEnv();
  const fetchImpl = fakeFetch([
    ...wechatSuccessRoutes([{ match: "sns/userinfo", body: JSON.stringify({ nickname: "N" }) }]),
    { match: "/admin/users?email=", body: JSON.stringify({ users: [{ id: "EXISTING_ID" }] }) },
    { match: "/admin/generate_link", body: JSON.stringify({ properties: { hashed_token: "H" } }) },
  ]);
  const response = await handleExchange(postRequest({ provider: "wechat", authCode: "C" }), fetchImpl);
  assertEq(response.status, 200, "应 200");
  const body = await response.json() as { user_id: string; is_new_user: boolean; type: string };
  assertEq(body.user_id, "EXISTING_ID", "复用既有 id");
  assertEq(body.is_new_user, false, "非新用户");
  assertEq(body.type, "magiclink", "type");
});

Deno.test("handleExchange —— 新用户经建号获得 id（is_new_user=true）", async () => {
  setupEnv();
  // 注意路由顺序：更具体的 "/admin/users?email=" 必须排在 "/admin/users" 之前
  const fetchImpl = fakeFetch([
    ...wechatSuccessRoutes([{ match: "sns/userinfo", body: JSON.stringify({ nickname: "新用户" }) }]),
    { match: "/admin/users?email=", body: JSON.stringify({ users: [] }) },
    { match: "/admin/users", body: JSON.stringify({ id: "NEW_ID" }) },
    { match: "/admin/generate_link", body: JSON.stringify({ properties: { hashed_token: "H2" } }) },
  ]);
  const response = await handleExchange(postRequest({ provider: "wechat", authCode: "C" }), fetchImpl);
  assertEq(response.status, 200, "应 200");
  const body = await response.json() as { user_id: string; is_new_user: boolean };
  assertEq(body.user_id, "NEW_ID", "新用户 id");
  assertEq(body.is_new_user, true, "是新用户");
});

Deno.test("handleExchange —— generate_link 失败返回 500", async () => {
  setupEnv();
  const fetchImpl = fakeFetch([
    ...wechatSuccessRoutes([{ match: "sns/userinfo", body: JSON.stringify({ nickname: "N" }) }]),
    { match: "/admin/users?email=", body: JSON.stringify({ users: [{ id: "U" }] }) },
    { match: "/admin/generate_link", body: JSON.stringify({ msg: "err" }), status: 500 },
  ]);
  const response = await handleExchange(postRequest({ provider: "wechat", authCode: "C" }), fetchImpl);
  assertEq(response.status, 500, "generate_link 失败应 500");
  const body = await response.json() as { error: string };
  assertEq(body.error, "token_issue_failed", "错误码");
});

// ── normalizeTokenHash 容错 ─────────────────────────────────────────────────

Deno.test("normalizeTokenHash —— 四种字段位置", () => {
  assertEq(
    normalizeTokenHash(JSON.stringify({ properties: { hashed_token: "A" } })),
    "A",
    "1) properties.hashed_token（官方契约）",
  );
  assertEq(normalizeTokenHash(JSON.stringify({ hashed_token: "B" })), "B", "2) 顶层 hashed_token");
  assertEq(normalizeTokenHash(JSON.stringify({ token_hash: "C" })), "C", "3) 顶层 token_hash");
  assertEq(
    normalizeTokenHash(JSON.stringify({ action_link: "https://x/y?token=D&type=magiclink" })),
    "D",
    "4) action_link 反解",
  );
});

Deno.test("normalizeTokenHash —— 畸形输入返回 null", () => {
  assertEq(normalizeTokenHash(""), null, "空串");
  assertEq(normalizeTokenHash("not json"), null, "非 JSON");
  assertEq(normalizeTokenHash("[]"), null, "数组");
  assertEq(normalizeTokenHash(JSON.stringify({ properties: {} })), null, "properties 空");
  assertEq(normalizeTokenHash(JSON.stringify({ action_link: "https://x/y" })), null, "link 无查询串");
});

Deno.test("normalizeTokenHash —— 优先级：properties 优先于顶层", () => {
  const raw = JSON.stringify({ properties: { hashed_token: "PROPS" }, hashed_token: "TOP" });
  assertEq(normalizeTokenHash(raw), "PROPS", "properties 优先");
});
