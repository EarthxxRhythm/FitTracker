/**
 * providers.ts —— 第三方授权码换票纯函数（微信 / QQ / 华为）。
 *
 * 设计原则：
 * - **零网络耦合**：所有网络调用经 `fetchImpl` 参数注入，测试全用 fake，不触真实网络。
 * - **失败一律返回 null**，不抛异常（网络异常 / 非 2xx / 第三方 errcode 非零 / 响应畸形）。
 * - **密钥不落地**：appSecret / appKey / clientSecret 只作参数传入，永不写入日志或返回值。
 * - **本模块不读环境变量**（secrets 由调用方 index.ts 注入），便于独立测试。
 *
 * 调用方：server/supabase/functions/thirdparty-exchange/index.ts
 */

/** 第三方身份（三家归一后的形状）。 */
export interface ThirdPartyIdentity {
  openId: string
  unionId: string
  nickname: string
  /** 伪邮箱前缀：'wx' | 'qq' | 'hw'。 */
  prefix: string
}

/** 伪邮箱域（与客户端 INTERNAL_EMAIL_DOMAIN = 'phone.fittracker.app' 同构）。 */
export const THIRD_PARTY_EMAIL_DOMAIN: string = 'thirdparty.fittracker.app'

/**
 * 伪邮箱合成：`{prefix}_{stableId}@thirdparty.fittracker.app`。
 *
 * 与客户端 INTERNAL_EMAIL_DOMAIN（phone.fittracker.app）同构——GoTrue 是邮箱制后端，
 * 项目已有「手机号 → 伪邮箱」的成功先例，复用同构做法可零改动复用会话落库路径。
 *
 * stableId 为空或 prefix 为空 → 返回空串（调用方据此判失败）。
 */
export function buildThirdPartyEmail(prefix: string, stableId: string): string {
  if (prefix.length === 0 || stableId.length === 0) {
    return ''
  }
  return prefix + '_' + stableId + '@' + THIRD_PARTY_EMAIL_DOMAIN
}

/** 微信成功响应的 errcode 缺省值（微信失败时仍返回 HTTP 200，错误经 errcode 表达）。 */
const WECHAT_ERRCODE_OK: number = 0

/** 微信 payload 形状。 */
interface WeChatTokenPayload {
  access_token?: string
  openid?: string
  unionid?: string
  nickname?: string
  errcode?: number
  errmsg?: string
}

interface WeChatUserInfoPayload {
  nickname?: string
  errcode?: number
}

/** 安全 JSON 解析：失败返回 null，不抛。 */
function parseJsonObject(raw: string): Record<string, unknown> | null {
  try {
    const parsed: unknown = JSON.parse(raw)
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return null
    }
    return parsed as Record<string, unknown>
  } catch (error) {
    return null
  }
}

/** 取字符串字段（缺失 / 非字符串 → 空串）。 */
function readString(source: Record<string, unknown>, key: string): string {
  const value: unknown = source[key]
  return typeof value === 'string' ? value : ''
}

/** 取数字字段（缺失 / 非数字 → null）。 */
function readNumber(source: Record<string, unknown>, key: string): number | null {
  const value: unknown = source[key]
  return typeof value === 'number' ? value : null
}

/**
 * 微信换票（两步）。
 *
 * 端点（官方文档 https://developers.weixin.qq.com/doc/oplatform/Mobile_App/WeChat_Login/Development_Guide.html）：
 *  1) GET https://api.weixin.qq.com/sns/oauth2/access_token
 *       ?appid=&secret=&code=&grant_type=authorization_code
 *     → { access_token, openid, unionid?, errcode?, errmsg? }
 *     ⚠ 失败时微信仍返回 HTTP 200，错误经 errcode 字段表达（缺失或 0 才算成功）。
 *  2) GET https://api.weixin.qq.com/sns/userinfo?access_token=&openid= → { nickname, ... }
 *     失败不阻断（昵称兜底空串）——昵称仅用于展示，不应阻塞登录。
 *
 * unionId 缺失时回落 openId 作为稳定标识（单应用场景下 openId 已足够唯一）。
 */
export async function exchangeWeChat(
  authCode: string,
  fetchImpl: typeof fetch,
  appId: string,
  appSecret: string,
): Promise<ThirdPartyIdentity | null> {
  if (authCode.length === 0 || appId.length === 0 || appSecret.length === 0) {
    return null
  }
  const tokenUrl: string = 'https://api.weixin.qq.com/sns/oauth2/access_token'
    + '?appid=' + encodeURIComponent(appId)
    + '&secret=' + encodeURIComponent(appSecret)
    + '&code=' + encodeURIComponent(authCode)
    + '&grant_type=authorization_code'

  let tokenRaw: string = ''
  try {
    const response: Response = await fetchImpl(tokenUrl)
    tokenRaw = await response.text()
  } catch (error) {
    // 网络异常：不打印任何含 secret 的信息
    return null
  }
  const tokenPayload: Record<string, unknown> | null = parseJsonObject(tokenRaw)
  if (tokenPayload === null) {
    return null
  }
  const errcode: number | null = readNumber(tokenPayload, 'errcode')
  if (errcode !== null && errcode !== WECHAT_ERRCODE_OK) {
    // 微信业务错误（如 40029 = invalid code）
    return null
  }
  const accessToken: string = readString(tokenPayload, 'access_token')
  const openId: string = readString(tokenPayload, 'openid')
  if (accessToken.length === 0 || openId.length === 0) {
    return null
  }
  const unionId: string = readString(tokenPayload, 'unionid')

  // 第二步：取昵称（失败不阻断）
  let nickname: string = ''
  const userInfoUrl: string = 'https://api.weixin.qq.com/sns/userinfo'
    + '?access_token=' + encodeURIComponent(accessToken)
    + '&openid=' + encodeURIComponent(openId)
  try {
    const response: Response = await fetchImpl(userInfoUrl)
    const raw: string = await response.text()
    const payload: Record<string, unknown> | null = parseJsonObject(raw)
    if (payload !== null) {
      nickname = readString(payload, 'nickname')
    }
  } catch (error) {
    nickname = ''
  }

  const identity: ThirdPartyIdentity = {
    openId: openId,
    unionId: unionId.length > 0 ? unionId : openId,
    nickname: nickname,
    prefix: 'wx',
  }
  return identity
}

/** QQ token 响应（form-urlencoded 解析后）。 */
interface QqTokenFields {
  access_token: string
  refresh_token: string
}

/**
 * 解析 QQ /oauth2.0/token 响应——该端点默认返回 **form-urlencoded 文本**
 * （`access_token=X&expires_in=Y&refresh_token=Z`），传 fmt=json 时返回 JSON。
 * 两种形态都要容错，故此处统一按 urlencoded 解析（JSON 形态先转成等价的 k=v 串）。
 */
function parseQqTokenResponse(raw: string): QqTokenFields | null {
  const trimmed: string = raw.trim()
  if (trimmed.length === 0) {
    return null
  }
  let pairsSource: string = trimmed
  if (trimmed.startsWith('{')) {
    // JSON 形态：转换成 k=v 串复用同一解析（避免维护两套逻辑）
    const payload: Record<string, unknown> | null = parseJsonObject(trimmed)
    if (payload === null) {
      return null
    }
    const parts: string[] = []
    for (const key of Object.keys(payload)) {
      const value: unknown = payload[key]
      if (typeof value === 'string' || typeof value === 'number') {
        parts.push(key + '=' + String(value))
      }
    }
    pairsSource = parts.join('&')
  }
  const result: QqTokenFields = { access_token: '', refresh_token: '' }
  const segments: string[] = pairsSource.split('&')
  for (const segment of segments) {
    const eqIndex: number = segment.indexOf('=')
    if (eqIndex <= 0) {
      continue
    }
    const key: string = segment.substring(0, eqIndex)
    const value: string = segment.substring(eqIndex + 1)
    if (key === 'access_token') {
      result.access_token = decodeURIComponent(value)
    } else if (key === 'refresh_token') {
      result.refresh_token = decodeURIComponent(value)
    }
  }
  if (result.access_token.length === 0) {
    return null
  }
  return result
}

/**
 * 解析 QQ /oauth2.0/me 响应取 openid / unionid。
 *
 * ⚠ 该端点默认返回 **JSONP 包裹**：`callback( {"client_id":"...","openid":"..."} );`
 * 传 fmt=json 时可能返回纯 JSON，但历史行为不稳定——两种形态都要容错剥离。
 * unionid=1 参数会让响应附带 unionid 字段（需应用已获批 unionid 权限）。
 */
function parseQqOpenIdResponse(raw: string): Record<string, unknown> | null {
  const trimmed: string = raw.trim()
  if (trimmed.length === 0) {
    return null
  }
  let jsonText: string = trimmed
  if (!trimmed.startsWith('{')) {
    // JSONP 剥离：取第一个 '{' 到最后一个 '}' 之间的内容
    const start: number = trimmed.indexOf('{')
    const end: number = trimmed.lastIndexOf('}')
    if (start < 0 || end <= start) {
      return null
    }
    jsonText = trimmed.substring(start, end + 1)
  }
  return parseJsonObject(jsonText)
}

/**
 * QQ 换票（三步）。
 *
 * 端点（官方文档 https://wiki.connect.qq.com/）：
 *  1) GET https://graph.qq.com/oauth2.0/token
 *       ?grant_type=authorization_code&client_id=&client_secret=&code=&fmt=json&redirect_uri=
 *     ⚠ 默认返回 form-urlencoded，须能容错两种形态。
 *  2) GET https://graph.qq.com/oauth2.0/me?access_token=&fmt=json&unionid=1 → openid（+ unionid）
 *     ⚠ 默认返回 JSONP 包裹。
 *  3) GET https://graph.qq.com/user/get_user_info?access_token=&oauth_consumer_key=&openid=
 *     → { nickname }（失败不阻断）
 *
 * unionId 缺失时回落 openId（openid 为应用级唯一，单应用场景足够）。
 */
export async function exchangeQq(
  authCode: string,
  fetchImpl: typeof fetch,
  appId: string,
  appKey: string,
): Promise<ThirdPartyIdentity | null> {
  if (authCode.length === 0 || appId.length === 0 || appKey.length === 0) {
    return null
  }
  const tokenUrl: string = 'https://graph.qq.com/oauth2.0/token'
    + '?grant_type=authorization_code'
    + '&client_id=' + encodeURIComponent(appId)
    + '&client_secret=' + encodeURIComponent(appKey)
    + '&code=' + encodeURIComponent(authCode)
    + '&fmt=json'
    + '&redirect_uri='

  let tokenRaw: string = ''
  try {
    const response: Response = await fetchImpl(tokenUrl)
    tokenRaw = await response.text()
  } catch (error) {
    return null
  }
  const tokenFields: QqTokenFields | null = parseQqTokenResponse(tokenRaw)
  if (tokenFields === null) {
    return null
  }

  // 第二步：取 openid（+ unionid）
  const meUrl: string = 'https://graph.qq.com/oauth2.0/me'
    + '?access_token=' + encodeURIComponent(tokenFields.access_token)
    + '&fmt=json'
    + '&unionid=1'
  let meRaw: string = ''
  try {
    const response: Response = await fetchImpl(meUrl)
    meRaw = await response.text()
  } catch (error) {
    return null
  }
  const mePayload: Record<string, unknown> | null = parseQqOpenIdResponse(meRaw)
  if (mePayload === null) {
    return null
  }
  const openId: string = readString(mePayload, 'openid')
  if (openId.length === 0) {
    return null
  }
  const unionId: string = readString(mePayload, 'unionid')

  // 第三步：取昵称（失败不阻断）
  let nickname: string = ''
  const userInfoUrl: string = 'https://graph.qq.com/user/get_user_info'
    + '?access_token=' + encodeURIComponent(tokenFields.access_token)
    + '&oauth_consumer_key=' + encodeURIComponent(appId)
    + '&openid=' + encodeURIComponent(openId)
  try {
    const response: Response = await fetchImpl(userInfoUrl)
    const raw: string = await response.text()
    const payload: Record<string, unknown> | null = parseJsonObject(raw)
    if (payload !== null) {
      nickname = readString(payload, 'nickname')
    }
  } catch (error) {
    nickname = ''
  }

  const identity: ThirdPartyIdentity = {
    openId: openId,
    unionId: unionId.length > 0 ? unionId : openId,
    nickname: nickname,
    prefix: 'qq',
  }
  return identity
}

/**
 * base64url → UTF-8 字符串（id_token payload 解析用）。
 * 失败返回空串（不抛）。
 */
function decodeBase64Url(input: string): string {
  try {
    const normalized: string = input.replace(/-/g, '+').replace(/_/g, '/')
    const padded: string = normalized + '='.repeat((4 - (normalized.length % 4)) % 4)
    const binary: string = atob(padded)
    const bytes: Uint8Array = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i)
    }
    return new TextDecoder().decode(bytes)
  } catch (error) {
    return ''
  }
}

/** id_token payload 形状（华为；字段名官方为 snake_case）。 */
interface HuaweiIdTokenPayload {
  union_id?: string
  open_id?: string
  display_name?: string
  [key: string]: unknown
}

/**
 * 从 id_token JWT 解出华为用户标识。
 *
 * ⚠ **不做签名校验**——该 token 由华为经 TLS 直授给本服务端，本项目信任传输层。
 * 这是有意识的取舍：签名校验需拉取华为 JWKS 并实现 PS256 验签，成本与收益在当前
 * 自用规模下不成比例。若未来面向公网多租户，应补验签。
 *
 * 必须校验：段数 = 3、payload 可解析；畸形返回 null。
 */
export function parseHuaweiIdToken(idToken: string): HuaweiIdTokenPayload | null {
  const segments: string[] = idToken.split('.')
  if (segments.length !== 3) {
    return null
  }
  const payloadText: string = decodeBase64Url(segments[1])
  if (payloadText.length === 0) {
    return null
  }
  const payload: Record<string, unknown> | null = parseJsonObject(payloadText)
  if (payload === null) {
    return null
  }
  const result: HuaweiIdTokenPayload = {
    union_id: readString(payload, 'union_id'),
    open_id: readString(payload, 'open_id'),
    display_name: readString(payload, 'display_name'),
  }
  return result
}

/**
 * 华为 Account Kit 换票。
 *
 * 端点（官方文档 https://developer.huawei.com/consumer/cn/doc/development/HMSCore-References/get-user-level-token-0000001050784861）：
 *  POST https://oauth-login.cloud.huawei.com/oauth2/v3/token
 *    Content-Type: application/x-www-form-urlencoded
 *    body: grant_type=authorization_code&client_id=&client_secret=&code=&redirect_uri=
 *  → { access_token, id_token, refresh_token, expires_in }
 *
 * id_token 为 JWT，解 payload 取 union_id / open_id（见 parseHuaweiIdToken 的取舍说明）。
 * unionId 优先（跨应用统一），缺失回落 openId。
 */
export async function exchangeHuawei(
  authCode: string,
  fetchImpl: typeof fetch,
  clientId: string,
  clientSecret: string,
): Promise<ThirdPartyIdentity | null> {
  if (authCode.length === 0 || clientId.length === 0 || clientSecret.length === 0) {
    return null
  }
  const body: string = 'grant_type=authorization_code'
    + '&client_id=' + encodeURIComponent(clientId)
    + '&client_secret=' + encodeURIComponent(clientSecret)
    + '&code=' + encodeURIComponent(authCode)
    + '&redirect_uri='

  let raw: string = ''
  try {
    const response: Response = await fetchImpl('https://oauth-login.cloud.huawei.com/oauth2/v3/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body,
    })
    if (response.status < 200 || response.status > 299) {
      return null
    }
    raw = await response.text()
  } catch (error) {
    return null
  }
  const payload: Record<string, unknown> | null = parseJsonObject(raw)
  if (payload === null) {
    return null
  }
  const idToken: string = readString(payload, 'id_token')
  if (idToken.length === 0) {
    return null
  }
  const claims: HuaweiIdTokenPayload | null = parseHuaweiIdToken(idToken)
  if (claims === null) {
    return null
  }
  const unionId: string = claims.union_id !== undefined ? claims.union_id : ''
  const openId: string = claims.open_id !== undefined ? claims.open_id : ''
  if (unionId.length === 0 && openId.length === 0) {
    return null
  }
  const nickname: string = claims.display_name !== undefined ? claims.display_name : ''

  const identity: ThirdPartyIdentity = {
    openId: openId,
    unionId: unionId.length > 0 ? unionId : openId,
    nickname: nickname,
    prefix: 'hw',
  }
  return identity
}
