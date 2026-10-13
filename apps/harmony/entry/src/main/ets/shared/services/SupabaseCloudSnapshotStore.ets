/**
 * SupabaseCloudSnapshotStore —— 自托管 Supabase（PostgREST）快照存储。
 *
 * 逐条对齐 Android apps/android/app/src/main/java/com/fittracker/app/data/cloud/SupabaseCloudSnapshotStore.kt
 * （Wave 6 契约，含其 15 个纯 JVM 单测的断言口径）：
 *
 * ```
 * pull:  GET  {rest}/snapshots?user_id=eq.<user>&select=payload,updated_at&limit=1
 *          → 2xx + []      → null                （云端无快照，决策内核据此走 PUSH）
 *          → 2xx + [row]   → CloudSnapshot(row)  （payload jsonb 内联 → 字符串）
 *          → 非 2xx        → null
 *          → 非 JSON / 非数组 / 缺字段 / 坏时间 → null
 * push:  POST {rest}/snapshots   Prefer: resolution=merge-duplicates,return=minimal
 *          body {"user_id":…,"payload":<json>,"updated_at":<ISO8601 UTC 毫秒>}
 *          → 2xx → true / 其余 → false
 *          → 载荷解析后非 JSON 对象（null / 数组 / 原始值 / 非法 JSON）→ 不发请求直接 false
 * ```
 *
 * 两处口径：
 * - **jsonb 内联**：PostgREST 把 jsonb 列作为内联 JSON 值返回（非转义字符串），故 pull 侧
 *   用 JSON.stringify 序列化回字符串；push 侧把 payloadJson 解析成 JSON 对象再放进 body，
 *   交由列按 jsonb 存储。
 * - **时间单位 = 毫秒**：全库时间戳统一 epoch 毫秒，故 CloudSnapshot.updatedAt 亦为毫秒；
 *   ISO8601 生成 / 解析手写实现（见下方 codec），不依赖 Date.parse 的宽松歧义。
 *
 * deviceTag / schemaVersion 为本地字段，映射表 public.snapshots(user_id uuid PK / payload jsonb /
 * updated_at timestamptz) 中不持久化——pull 侧以本机缺省补齐。
 *
 * ArkTS 约束：本文件不使用对象索引访问（AGENTS.md 明列禁止）——JSON 解析用可空字段接口 +
 * as 断言 + 属性访问（先例 SupabaseAuthProvider.persistSessionFrom）；push body 用显式接口。
 */
import { Context } from '@kit.AbilityKit'
import { SupabaseHttp, SupabaseHttpResult } from '../../common/services/SupabaseHttp'
import SupabaseAuthProvider from '../../common/services/auth/SupabaseAuthProvider'
import {
  CloudSnapshot,
  CloudSnapshotStore,
  SNAPSHOT_SCHEMA_VERSION,
  createCloudSnapshot
} from './CloudSnapshotStore'

/** push 的 PostgREST 偏好头：按主键 upsert + 不返回行体（2xx 即成功）。 */
const PREFER_UPSERT_MINIMAL: string = 'resolution=merge-duplicates,return=minimal'

/** deviceTag 为本地字段（表中不持久化），与 CloudSyncService.resolveDeviceTag 缺省一致。 */
const DEVICE_TAG: string = 'local-device'

// ── 抽象层（依赖注入，供单测以 Fake 替换） ──────────────────────────────────

/**
 * HTTP 传输抽象——把「请求如何发出」从 store 中剥离，使请求构造（URL / 头 / body / Prefer）
 * 在无网络、无设备下可逐字段断言（对齐 Android RecordingTransport 的测试写法）。
 */
export abstract class SnapshotTransport {
  /** 无请求体的 GET。 */
  abstract get(url: string, accessToken: string | null): Promise<SupabaseHttpResult>

  /** 带 `Prefer` 头的 POST（bodyJson 为已序列化的 JSON 字符串）。 */
  abstract postWithPrefer(url: string, bodyJson: string, accessToken: string | null,
                          prefer: string): Promise<SupabaseHttpResult>
}

/** 生产传输实现——直接委托 SupabaseHttp 静态方法。 */
class SupabaseHttpSnapshotTransport extends SnapshotTransport {
  async get(url: string, accessToken: string | null): Promise<SupabaseHttpResult> {
    return SupabaseHttp.get(url, accessToken)
  }

  async postWithPrefer(url: string, bodyJson: string, accessToken: string | null,
                       prefer: string): Promise<SupabaseHttpResult> {
    return SupabaseHttp.postWithPrefer(url, bodyJson, accessToken, prefer)
  }
}

/**
 * Access token 提供者抽象——同步链路入口取「新鲜」token（含按需刷新），
 * 使 token 刷新语义可在单测中注入（token=null / 固定 token 场景）。
 */
export abstract class AccessTokenProvider {
  /** 取新鲜 access token；未登录 / 刷新失败 / 网络不可达均返回 null。 */
  abstract getAccessToken(context: Context): Promise<string | null>
}

/**
 * 生产 token 提供实现——委托 SupabaseAuthProvider.ensureFreshAccessToken（冻结契约）：
 * 先按需刷新、再做窗口判定（对齐 Android validAccessToken）。
 */
class SupabaseAuthTokenProvider extends AccessTokenProvider {
  async getAccessToken(context: Context): Promise<string | null> {
    return SupabaseAuthProvider.ensureFreshAccessToken(context)
  }
}

// ── codec 纯函数（模块级导出，可直测） ──────────────────────────────────────

/** 左侧补零到固定宽度（对齐 Android padNumber）。 */
function padNumber(value: number, width: number): string {
  let text: string = value.toString()
  while (text.length < width) {
    text = '0' + text
  }
  return text
}

/** 字符是否为 ASCII 数字 0-9。 */
function isDigit(ch: string): boolean {
  const code: number = ch.charCodeAt(0)
  return code >= 48 && code <= 57
}

/** 读取 start 起 length 位十进制数；越界 / 含非数字返回 null（对齐 Android readFixedInt）。 */
function readFixedInt(text: string, start: number, length: number): number | null {
  if (start < 0 || start + length > text.length) {
    return null
  }
  let value: number = 0
  let position: number = start
  while (position < start + length) {
    const digit: string = text.charAt(position)
    if (!isDigit(digit)) {
      return null
    }
    value = value * 10 + (digit.charCodeAt(0) - 48)
    position++
  }
  return value
}

/**
 * 解析时区后缀为相对 UTC 的毫秒偏移；`Z`/`z`/空 → 0，`±HH:MM` / `±HHMM` / `±HH` → 有符号偏移。
 * 非法后缀返回 null（对齐 Android parseZoneOffsetMillis）。
 */
function parseZoneOffsetMillis(zoneText: string): number | null {
  if (zoneText.length === 0 || zoneText === 'Z' || zoneText === 'z') {
    return 0
  }
  if (zoneText.length < 3) {
    return null
  }
  const sign: string = zoneText.charAt(0)
  if (sign !== '+' && sign !== '-') {
    return null
  }
  const offsetHour: number | null = readFixedInt(zoneText, 1, 2)
  if (offsetHour === null) {
    return null
  }
  const rest: string = zoneText.substring(3)
  let offsetMinute: number = 0
  if (rest.length > 0) {
    if (rest.charAt(0) === ':') {
      const parsedColon: number | null = readFixedInt(rest, 1, 2)
      if (parsedColon === null) {
        return null
      }
      offsetMinute = parsedColon
    } else {
      const parsedPlain: number | null = readFixedInt(rest, 0, 2)
      if (parsedPlain === null) {
        return null
      }
      offsetMinute = parsedPlain
    }
  }
  const magnitude: number = (offsetHour * 60 + offsetMinute) * 60000
  return sign === '-' ? -magnitude : magnitude
}

/**
 * epoch 毫秒 → ISO8601 UTC 串（毫秒精度）：`2026-10-04T12:34:56.789Z`。
 *
 * 输出恒定位数，便于逐字节断言（对齐 Android iso8601UtcFromEpochMillis）。
 */
export function iso8601UtcFromEpochMillis(millis: number): string {
  const date: Date = new Date(millis)
  return padNumber(date.getUTCFullYear(), 4) + '-' +
    padNumber(date.getUTCMonth() + 1, 2) + '-' +
    padNumber(date.getUTCDate(), 2) + 'T' +
    padNumber(date.getUTCHours(), 2) + ':' +
    padNumber(date.getUTCMinutes(), 2) + ':' +
    padNumber(date.getUTCSeconds(), 2) + '.' +
    padNumber(date.getUTCMilliseconds(), 3) + 'Z'
}

/**
 * ISO8601 串 → epoch 毫秒（与 iso8601UtcFromEpochMillis 互逆）。
 *
 * 接受 `YYYY-MM-DDTHH:MM:SS[.fraction][Z|z|±HH:MM|±HHMM|±HH]`（`T` 亦容忍 `t` / 空格分隔符，
 * 无时区后缀按 UTC）；小数秒截断 / 补齐到毫秒（第 4 位起丢弃）。格式不符 / 字段越界返回 null。
 *
 * ⚠ 不用 `Date.UTC(y,...)`：年份 0-99 会被加 1900（JS 遗留语义），改用 `new Date(0)` +
 * `setUTCFullYear` / `setUTCHours` 系列再减偏移毫秒（对齐 Android 的 Calendar.clear + set）。
 */
export function epochMillisFromIso8601(text: string): number | null {
  if (text.length < 19) {
    return null // 最短：YYYY-MM-DDTHH:MM:SS
  }
  const year: number | null = readFixedInt(text, 0, 4)
  if (year === null) {
    return null
  }
  if (text.charAt(4) !== '-') {
    return null
  }
  const month: number | null = readFixedInt(text, 5, 2)
  if (month === null) {
    return null
  }
  if (text.charAt(7) !== '-') {
    return null
  }
  const day: number | null = readFixedInt(text, 8, 2)
  if (day === null) {
    return null
  }
  const dateTimeSeparator: string = text.charAt(10)
  if (dateTimeSeparator !== 'T' && dateTimeSeparator !== 't' && dateTimeSeparator !== ' ') {
    return null
  }
  const hour: number | null = readFixedInt(text, 11, 2)
  if (hour === null) {
    return null
  }
  if (text.charAt(13) !== ':') {
    return null
  }
  const minute: number | null = readFixedInt(text, 14, 2)
  if (minute === null) {
    return null
  }
  if (text.charAt(16) !== ':') {
    return null
  }
  const second: number | null = readFixedInt(text, 17, 2)
  if (second === null) {
    return null
  }

  let index: number = 19
  let millisOfSecond: number = 0
  if (index < text.length && text.charAt(index) === '.') {
    index++
    const fractionStart: number = index
    while (index < text.length && isDigit(text.charAt(index))) {
      index++
    }
    if (index === fractionStart) {
      return null // 小数点后无数字
    }
    const fraction: string = text.substring(fractionStart, index)
    const millisText: string = (fraction + '000').substring(0, 3) // 前 3 位即毫秒
    const parsedMillis: number | null = readFixedInt(millisText, 0, 3)
    if (parsedMillis === null) {
      return null
    }
    millisOfSecond = parsedMillis
  }

  const offsetMillis: number | null = parseZoneOffsetMillis(text.substring(index))
  if (offsetMillis === null) {
    return null
  }
  if (month < 1 || month > 12 || day < 1 || day > 31 ||
    hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59) {
    return null
  }

  const date: Date = new Date(0)
  date.setUTCFullYear(year, month - 1, day)
  date.setUTCHours(hour, minute, second, 0)
  return date.getTime() - offsetMillis + millisOfSecond
}

/**
 * 解析快照载荷为 JSON 对象；非对象（null / 数组 / 原始值）或非法 JSON 返回 null。
 * （对齐 Android：kotlinx 宽松解析后 `as? JsonObject ?: return false`。）
 */
function parseJsonObject(payloadJson: string): Object | null {
  try {
    const parsed: string | number | boolean | Object | null = JSON.parse(payloadJson)
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return null
    }
    return parsed
  } catch (error) {
    return null
  }
}

// ── store 主体 ──────────────────────────────────────────────────────────────

/** pull 响应行（PostgREST 返回的 snapshots 列子集）。 */
interface SnapshotRow {
  payload?: Object
  updated_at?: string
}

/** push 请求体（显式接口，避开 ArkTS 匿名对象字面量的类型推断限制）。 */
interface SnapshotPushBody {
  user_id: string
  payload: Object
  updated_at: string
}

class SupabaseCloudSnapshotStore extends CloudSnapshotStore {
  private transport: SnapshotTransport = new SupabaseHttpSnapshotTransport()
  private tokenProvider: AccessTokenProvider = new SupabaseAuthTokenProvider()

  /** 测试注入传输层；传 null 恢复生产实现（SupabaseHttp）。 */
  setTransportForTesting(transport: SnapshotTransport | null): void {
    this.transport = transport === null ? new SupabaseHttpSnapshotTransport() : transport
  }

  /** 测试注入 token 提供者；传 null 恢复生产实现（SupabaseAuthProvider）。 */
  setTokenProviderForTesting(provider: AccessTokenProvider | null): void {
    this.tokenProvider = provider === null ? new SupabaseAuthTokenProvider() : provider
  }

  /** 拉取指定用户最新快照；云端无快照 / 非 2xx / 解析失败均返回 null。 */
  async pull(context: Context, userId: string): Promise<CloudSnapshot | null> {
    if (!SupabaseHttp.isConfigured()) {
      return null
    }
    const accessToken: string | null = await this.tokenProvider.getAccessToken(context)
    const query: string = 'snapshots?user_id=eq.' + userId + '&select=payload,updated_at&limit=1'
    const url: string = SupabaseHttp.restUrl(query)
    const response: SupabaseHttpResult = await this.transport.get(url, accessToken)
    if (response.status < 200 || response.status > 299) {
      return null // 鉴权失败 / 服务端错误 → 按「无快照」处理（决策内核据此走 PUSH）
    }
    let rows: SnapshotRow[] = []
    try {
      rows = JSON.parse(response.body) as SnapshotRow[]
    } catch (error) {
      return null // 非 JSON 响应体
    }
    if (!Array.isArray(rows) || rows.length === 0) {
      return null // 非数组 / 空数组 → 云端无快照
    }
    const row: SnapshotRow = rows[0]
    const payloadValue: Object | undefined = row.payload
    const updatedAtText: string | undefined = row.updated_at
    if (payloadValue === undefined || updatedAtText === undefined) {
      return null // 缺 payload / updated_at
    }
    const updatedAt: number | null = epochMillisFromIso8601(updatedAtText)
    if (updatedAt === null) {
      return null // 时间串解析失败
    }
    return createCloudSnapshot(
      userId,
      JSON.stringify(payloadValue), // jsonb 内联 → 序列化回字符串
      updatedAt,
      DEVICE_TAG,
      SNAPSHOT_SCHEMA_VERSION
    )
  }

  /** 写入 / 覆盖用户快照（upsert）；2xx 视为成功。 */
  async push(context: Context, snapshot: CloudSnapshot): Promise<boolean> {
    if (!SupabaseHttp.isConfigured()) {
      return false
    }
    const payloadValue: Object | null = parseJsonObject(snapshot.payloadJson)
    if (payloadValue === null) {
      return false // 载荷非 JSON 对象，拒绝上行（不发请求）
    }
    const accessToken: string | null = await this.tokenProvider.getAccessToken(context)
    const body: SnapshotPushBody = {
      user_id: snapshot.userId,
      payload: payloadValue, // 内联为 JSON 值交由 jsonb 列存储
      updated_at: iso8601UtcFromEpochMillis(snapshot.updatedAt)
    }
    const response: SupabaseHttpResult = await this.transport.postWithPrefer(
      SupabaseHttp.restUrl('snapshots'),
      JSON.stringify(body),
      accessToken,
      PREFER_UPSERT_MINIMAL
    )
    return response.status >= 200 && response.status <= 299
  }
}

export default new SupabaseCloudSnapshotStore()
