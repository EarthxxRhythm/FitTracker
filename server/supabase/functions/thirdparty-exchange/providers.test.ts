/**
 * providers.ts 单元测试（零网络——全部经 fake fetch 注入）。
 *
 * 运行：`deno test providers.test.ts`（工作目录 server/supabase/functions/thirdparty-exchange/）
 *
 * 覆盖矩阵（每个 provider 四类分支）：
 *  1. 正常路径 → 正确 identity（逐字段断言）
 *  2. 第三方 errcode 非零 / 非 2xx → null
 *  3. 网络异常（fetchImpl 抛错）→ null，不抛
 *  4. 响应畸形（空串 / 非 JSON / 缺关键字段 / JSONP 包裹）→ null
 */
import {
  buildThirdPartyEmail,
  exchangeHuawei,
  exchangeQq,
  exchangeWeChat,
  parseHuaweiIdToken,
  THIRD_PARTY_EMAIL_DOMAIN,
} from "./providers.ts";

function assertEq(actual: unknown, expected: unknown, label: string): void {
  if (actual !== expected) {
    throw new Error(`${label}\n  actual:   ${JSON.stringify(actual)}\n  expected: ${JSON.stringify(expected)}`);
  }
}

/** 构造按 URL 关键字分派的 fake fetch。 */
function fakeFetch(routes: Array<{ match: string; body: string; status?: number }>): typeof fetch {
  const impl = (input: string | URL | Request, _init?: RequestInit): Promise<Response> => {
    const url: string = typeof input === "string" ? input : (input instanceof URL ? input.toString() : input.url);
    for (const route of routes) {
      if (url.includes(route.match)) {
        return Promise.resolve(new Response(route.body, { status: route.status ?? 200 }));
      }
    }
    return Promise.resolve(new Response("", { status: 404 }));
  };
  return impl as unknown as typeof fetch;
}

/** 恒抛异常的 fake fetch（模拟网络不可达）。 */
const throwingFetch = (() => {
  return (() => Promise.reject(new Error("network unreachable"))) as unknown as typeof fetch;
})();

// ── buildThirdPartyEmail ────────────────────────────────────────────────

Deno.test("buildThirdPartyEmail —— 三前缀合成与空值边界", () => {
  assertEq(
    buildThirdPartyEmail("wx", "oABC123"),
    `wx_oABC123@${THIRD_PARTY_EMAIL_DOMAIN}`,
    "微信前缀",
  );
  assertEq(
    buildThirdPartyEmail("qq", "QQOPENID"),
    `qq_QQOPENID@${THIRD_PARTY_EMAIL_DOMAIN}`,
    "QQ 前缀",
  );
  assertEq(
    buildThirdPartyEmail("hw", "HWUNION"),
    `hw_HWUNION@${THIRD_PARTY_EMAIL_DOMAIN}`,
    "华为前缀",
  );
  assertEq(buildThirdPartyEmail("wx", ""), "", "stableId 为空 → 空串");
  assertEq(buildThirdPartyEmail("", "x"), "", "prefix 为空 → 空串");
  assertEq(buildThirdPartyEmail("", ""), "", "双空 → 空串");
  assertEq(THIRD_PARTY_EMAIL_DOMAIN, "thirdparty.fittracker.app", "域名常量");
});

// ── 微信 ────────────────────────────────────────────────────────────────

Deno.test("exchangeWeChat —— 正常路径（含 unionid 与昵称）", async () => {
  const fetchImpl = fakeFetch([
    {
      match: "sns/oauth2/access_token",
      body: JSON.stringify({
        access_token: "AT_WX",
        openid: "OPENID_WX",
        unionid: "UNIONID_WX",
        expires_in: 7200,
      }),
    },
    { match: "sns/userinfo", body: JSON.stringify({ nickname: "微信昵称" }) },
  ]);
  const identity = await exchangeWeChat("CODE", fetchImpl, "APPID", "SECRET");
  if (identity === null) throw new Error("期望非 null");
  assertEq(identity.openId, "OPENID_WX", "openId");
  assertEq(identity.unionId, "UNIONID_WX", "unionId");
  assertEq(identity.nickname, "微信昵称", "nickname");
  assertEq(identity.prefix, "wx", "prefix");
});

Deno.test("exchangeWeChat —— unionid 缺失时回落 openid", async () => {
  const fetchImpl = fakeFetch([
    { match: "sns/oauth2/access_token", body: JSON.stringify({ access_token: "AT", openid: "OPENID_ONLY" }) },
    { match: "sns/userinfo", body: JSON.stringify({ nickname: "N" }) },
  ]);
  const identity = await exchangeWeChat("CODE", fetchImpl, "APPID", "SECRET");
  if (identity === null) throw new Error("期望非 null");
  assertEq(identity.unionId, "OPENID_ONLY", "unionId 回落 openId");
});

Deno.test("exchangeWeChat —— errcode 非零（微信失败仍返回 HTTP 200）", async () => {
  const fetchImpl = fakeFetch([
    { match: "sns/oauth2/access_token", body: JSON.stringify({ errcode: 40029, errmsg: "invalid code" }) },
  ]);
  assertEq(await exchangeWeChat("BAD", fetchImpl, "APPID", "SECRET"), null, "errcode 非零 → null");
});

Deno.test("exchangeWeChat —— 网络异常 → null 不抛", async () => {
  assertEq(await exchangeWeChat("CODE", throwingFetch, "APPID", "SECRET"), null, "网络异常 → null");
});

Deno.test("exchangeWeChat —— 响应畸形四例", async () => {
  const empty = fakeFetch([{ match: "sns/oauth2/access_token", body: "" }]);
  assertEq(await exchangeWeChat("CODE", empty, "APPID", "SECRET"), null, "空串");

  const notJson = fakeFetch([{ match: "sns/oauth2/access_token", body: "<html>err</html>" }]);
  assertEq(await exchangeWeChat("CODE", notJson, "APPID", "SECRET"), null, "非 JSON");

  const noOpenId = fakeFetch([{ match: "sns/oauth2/access_token", body: JSON.stringify({ access_token: "AT" }) }]);
  assertEq(await exchangeWeChat("CODE", noOpenId, "APPID", "SECRET"), null, "缺 openid");

  const noToken = fakeFetch([{ match: "sns/oauth2/access_token", body: JSON.stringify({ openid: "O" }) }]);
  assertEq(await exchangeWeChat("CODE", noToken, "APPID", "SECRET"), null, "缺 access_token");
});

Deno.test("exchangeWeChat —— 参数为空即失败（不发请求）", async () => {
  assertEq(await exchangeWeChat("", throwingFetch, "APPID", "SECRET"), null, "authCode 空");
  assertEq(await exchangeWeChat("CODE", throwingFetch, "", "SECRET"), null, "appId 空");
  assertEq(await exchangeWeChat("CODE", throwingFetch, "APPID", ""), null, "appSecret 空");
});

Deno.test("exchangeWeChat —— 昵称接口失败不阻断登录", async () => {
  const fetchImpl = fakeFetch([
    { match: "sns/oauth2/access_token", body: JSON.stringify({ access_token: "AT", openid: "O", unionid: "U" }) },
    { match: "sns/userinfo", body: JSON.stringify({ errcode: 40001, errmsg: "invalid credential" }) },
  ]);
  const identity = await exchangeWeChat("CODE", fetchImpl, "APPID", "SECRET");
  if (identity === null) throw new Error("读取昵称失败不应阻断");
  assertEq(identity.nickname, "", "昵称兜底空串");
  assertEq(identity.openId, "O", "openId 仍可用");
});

Deno.test("exchangeWeChat —— 密钥不出现在错误路径（值不外泄）", async () => {
  const secret = "SUPER_SECRET_VALUE";
  const fetchImpl = fakeFetch([
    { match: "sns/oauth2/access_token", body: JSON.stringify({ errcode: 40013 }) },
  ]);
  const identity = await exchangeWeChat("CODE", fetchImpl, "APPID", secret);
  assertEq(identity, null, "失败返回 null");
  // 断言：返回值不含任何 secret 字样
  assertEq(JSON.stringify(identity).includes(secret), false, "返回值不含 secret");
});

// ── QQ ──────────────────────────────────────────────────────────────────

Deno.test("exchangeQq —— 正常路径（form-urlencoded token + JSONP me）", async () => {
  const fetchImpl = fakeFetch([
    {
      match: "oauth2.0/token",
      body: "access_token=AT_QQ&expires_in=7776000&refresh_token=RT_QQ",
    },
    { match: "oauth2.0/me", body: 'callback( {"client_id":"APPID","openid":"OPENID_QQ","unionid":"UNIONID_QQ"} );' },
    { match: "get_user_info", body: JSON.stringify({ nickname: "QQ昵称" }) },
  ]);
  const identity = await exchangeQq("CODE", fetchImpl, "APPID", "APPKEY");
  if (identity === null) throw new Error("期望非 null");
  assertEq(identity.openId, "OPENID_QQ", "openId");
  assertEq(identity.unionId, "UNIONID_QQ", "unionId");
  assertEq(identity.nickname, "QQ昵称", "nickname");
  assertEq(identity.prefix, "qq", "prefix");
});

Deno.test("exchangeQq —— token 端点 JSON 形态同样可解析", async () => {
  const fetchImpl = fakeFetch([
    { match: "oauth2.0/token", body: JSON.stringify({ access_token: "AT_JSON", expires_in: 7776000 }) },
    { match: "oauth2.0/me", body: 'callback( {"openid":"OPENID_JSON"} );' },
    { match: "get_user_info", body: JSON.stringify({ nickname: "N" }) },
  ]);
  const identity = await exchangeQq("CODE", fetchImpl, "APPID", "APPKEY");
  if (identity === null) throw new Error("JSON 形态应可解析");
  assertEq(identity.openId, "OPENID_JSON", "openId（JSON 形态）");
  assertEq(identity.unionId, "OPENID_JSON", "unionId 回落");
});

Deno.test("exchangeQq —— me 端点纯 JSON（非 JSONP）同样可解析", async () => {
  const fetchImpl = fakeFetch([
    { match: "oauth2.0/token", body: "access_token=AT&refresh_token=RT" },
    { match: "oauth2.0/me", body: JSON.stringify({ client_id: "APPID", openid: "OPENID_PLAIN" }) },
    { match: "get_user_info", body: JSON.stringify({ nickname: "N" }) },
  ]);
  const identity = await exchangeQq("CODE", fetchImpl, "APPID", "APPKEY");
  if (identity === null) throw new Error("纯 JSON 应可解析");
  assertEq(identity.openId, "OPENID_PLAIN", "openId");
});

Deno.test("exchangeQq —— token 响应无 access_token → null", async () => {
  const fetchImpl = fakeFetch([
    { match: "oauth2.0/token", body: "callback( {" + '"error":11001,"error_description":"code invalid"' + "} )" },
  ]);
  assertEq(await exchangeQq("CODE", fetchImpl, "APPID", "APPKEY"), null, "错误响应 → null");
});

Deno.test("exchangeQq —— me 响应缺 openid → null", async () => {
  const fetchImpl = fakeFetch([
    { match: "oauth2.0/token", body: "access_token=AT" },
    { match: "oauth2.0/me", body: 'callback( {"client_id":"APPID"} );' },
  ]);
  assertEq(await exchangeQq("CODE", fetchImpl, "APPID", "APPKEY"), null, "缺 openid → null");
});

Deno.test("exchangeQq —— 网络异常 → null 不抛", async () => {
  assertEq(await exchangeQq("CODE", throwingFetch, "APPID", "APPKEY"), null, "网络异常");
});

Deno.test("exchangeQq —— 响应畸形（空 token / 无花括号的 me）", async () => {
  const emptyToken = fakeFetch([{ match: "oauth2.0/token", body: "" }]);
  assertEq(await exchangeQq("CODE", emptyToken, "APPID", "APPKEY"), null, "空 token 响应");

  const badMe = fakeFetch([
    { match: "oauth2.0/token", body: "access_token=AT" },
    { match: "oauth2.0/me", body: "no json here" },
  ]);
  assertEq(await exchangeQq("CODE", badMe, "APPID", "APPKEY"), null, "me 无 JSON 内容");
});

Deno.test("exchangeQq —— 参数为空即失败", async () => {
  assertEq(await exchangeQq("", throwingFetch, "APPID", "APPKEY"), null, "authCode 空");
  assertEq(await exchangeQq("CODE", throwingFetch, "", "APPKEY"), null, "appId 空");
  assertEq(await exchangeQq("CODE", throwingFetch, "APPID", ""), null, "appKey 空");
});

// ── 华为 ────────────────────────────────────────────────────────────────

/** 构造一段三段式 JWT（payload 为给定对象；签名段为占位）。 */
function makeJwt(payload: Record<string, unknown>): string {
  const encode = (obj: Record<string, unknown>): string => {
    const json = JSON.stringify(obj);
    const bytes = new TextEncoder().encode(json);
    let binary = "";
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  };
  return `${encode({ alg: "PS256", typ: "JWT" })}.${encode(payload)}.SIGNATURE_PLACEHOLDER`;
}

Deno.test("parseHuaweiIdToken —— 三段解析与畸形拒绝", () => {
  const good = parseHuaweiIdToken(makeJwt({ union_id: "U1", open_id: "O1", display_name: "昵称" }));
  if (good === null) throw new Error("期望非 null");
  assertEq(good.union_id, "U1", "union_id");
  assertEq(good.open_id, "O1", "open_id");
  assertEq(good.display_name, "昵称", "display_name");

  assertEq(parseHuaweiIdToken("only.two"), null, "两段 → null");
  assertEq(parseHuaweiIdToken("a.b.c.d"), null, "四段 → null");
  assertEq(parseHuaweiIdToken(""), null, "空串 → null");
  assertEq(parseHuaweiIdToken("head.!!!notbase64!!!.sig"), null, "payload 非 base64 → null");
});

Deno.test("exchangeHuawei —— 正常路径（union_id 优先）", async () => {
  const idToken = makeJwt({ union_id: "HW_UNION", open_id: "HW_OPEN", display_name: "华为昵称" });
  const fetchImpl = fakeFetch([
    { match: "oauth2/v3/token", body: JSON.stringify({ access_token: "AT_HW", id_token: idToken, expires_in: 3600 }) },
  ]);
  const identity = await exchangeHuawei("CODE", fetchImpl, "CLIENT_ID", "CLIENT_SECRET");
  if (identity === null) throw new Error("期望非 null");
  assertEq(identity.unionId, "HW_UNION", "unionId 优先");
  assertEq(identity.openId, "HW_OPEN", "openId");
  assertEq(identity.nickname, "华为昵称", "nickname");
  assertEq(identity.prefix, "hw", "prefix");
});

Deno.test("exchangeHuawei —— union_id 缺失时回落 open_id", async () => {
  const idToken = makeJwt({ open_id: "HW_OPEN_ONLY" });
  const fetchImpl = fakeFetch([
    { match: "oauth2/v3/token", body: JSON.stringify({ id_token: idToken }) },
  ]);
  const identity = await exchangeHuawei("CODE", fetchImpl, "CID", "CSECRET");
  if (identity === null) throw new Error("期望非 null");
  assertEq(identity.unionId, "HW_OPEN_ONLY", "unionId 回落 openId");
  assertEq(identity.openId, "HW_OPEN_ONLY", "openId");
});

Deno.test("exchangeHuawei —— 非 2xx → null", async () => {
  const fetchImpl = fakeFetch([
    { match: "oauth2/v3/token", body: JSON.stringify({ error: "invalid_grant" }), status: 400 },
  ]);
  assertEq(await exchangeHuawei("BAD", fetchImpl, "CID", "CSECRET"), null, "400 → null");
});

Deno.test("exchangeHuawei —— 网络异常 → null 不抛", async () => {
  assertEq(await exchangeHuawei("CODE", throwingFetch, "CID", "CSECRET"), null, "网络异常");
});

Deno.test("exchangeHuawei —— 响应畸形（空 / 无 id_token / id_token 畸形）", async () => {
  const empty = fakeFetch([{ match: "oauth2/v3/token", body: "" }]);
  assertEq(await exchangeHuawei("CODE", empty, "CID", "CSECRET"), null, "空响应");

  const noIdToken = fakeFetch([{ match: "oauth2/v3/token", body: JSON.stringify({ access_token: "AT" }) }]);
  assertEq(await exchangeHuawei("CODE", noIdToken, "CID", "CSECRET"), null, "缺 id_token");

  const badJwt = fakeFetch([{ match: "oauth2/v3/token", body: JSON.stringify({ id_token: "not.a.jwt" }) }]);
  assertEq(await exchangeHuawei("CODE", badJwt, "CID", "CSECRET"), null, "id_token 畸形");
});

Deno.test("exchangeHuawei —— 无可识别用户标识 → null", async () => {
  const idToken = makeJwt({ some_other_claim: "x" });
  const fetchImpl = fakeFetch([
    { match: "oauth2/v3/token", body: JSON.stringify({ id_token: idToken }) },
  ]);
  assertEq(await exchangeHuawei("CODE", fetchImpl, "CID", "CSECRET"), null, "无 union_id/open_id");
});

Deno.test("exchangeHuawei —— 参数为空即失败", async () => {
  assertEq(await exchangeHuawei("", throwingFetch, "CID", "CSECRET"), null, "authCode 空");
  assertEq(await exchangeHuawei("CODE", throwingFetch, "", "CSECRET"), null, "clientId 空");
  assertEq(await exchangeHuawei("CODE", throwingFetch, "CID", ""), null, "clientSecret 空");
});
