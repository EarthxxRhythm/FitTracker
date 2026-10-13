/**
 * SupabaseCloudSnapshotStore 测试（ohosTest）
 *
 * 覆盖（对齐 Android `SupabaseCloudSnapshotStoreTest` 的 15 用例口径）：
 *  - codec 纯函数：生成/解析互逆、微秒截断（Z 后缀与带偏移两例分开断言）、整秒补零、
 *    无时区后缀按 UTC、畸形串拒绝
 *  - pull：请求构造逐字段断言（URL / GET / 无 body / token 透传）+ 六类响应分支
 *  - push：请求构造（URL / POST / Prefer / body 三字段且 payload 内联）+ 2xx→true、
 *    非 2xx→false、非法载荷零请求
 *  - token 透传：provider 返回 null 时传输层收到的 accessToken 亦为 null
 *
 * 稳定性说明：hypium 1.0.25 的 Spec.run / runHookFunc 对 async 用例与钩子为裸调用
 * （不 await）。本套件所有异步断言都在单个 async 用例内串行 await 收敛，钩子只做同步的
 * 注入与复位。
 *
 * 隔离说明：本套件不 acquire AuthSyncTestGate —— 不触 preferences / 网络 / CloudEnvironment，
 * 只用内存替身（RecordingTransport / StaticTokenProvider）；全局单例状态由 beforeEach /
 * afterEach 显式注入与复位（SupabaseConfig、store 的 transport 与 tokenProvider 三者）。
 *
 * 边界说明：access token 透传只断言「传输层收到的 accessToken」；headers 构造在生产
 * 传输内部（`SupabaseHttp.headers`，含 publishableKey 回退），不在本套件的可观测边界内。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium'
import supabaseCloudSnapshotStore, {
  iso8601UtcFromEpochMillis,
  epochMillisFromIso8601,
  SnapshotTransport,
  AccessTokenProvider
} from '../../../main/ets/shared/services/SupabaseCloudSnapshotStore'
import SupabaseConfig, { SupabaseRuntimeConfig } from '../../../main/ets/common/services/SupabaseConfig'
import { SupabaseHttpResult } from '../../../main/ets/common/services/SupabaseHttp'
import { CloudSnapshot, createCloudSnapshot } from '../../../main/ets/shared/services/CloudSnapshotStore'

/** 测试用运行时配置（不落 rawfile：setForTesting 直接置内存配置）。 */
const TEST_CONFIG: SupabaseRuntimeConfig = {
  url: 'https://api.test.local',
  publishableKey: 'sb_publishable_test'
}

const TEST_USER_ID: string = 'user-1'
const TEST_TOKEN: string = 'test-access-token'
/** 2026-10-04T12:34:56.789Z 的 epoch 毫秒。 */
const TEST_MILLIS: number = 1791117296789
/** 2026-10-04T12:34:56Z 的 epoch 毫秒（整秒，毫秒位为 0）。 */
const TEST_MILLIS_SECOND: number = 1791117296000
const TEST_ISO: string = '2026-10-04T12:34:56.789Z'
const PULL_URL: string = 'https://api.test.local/rest/v1/snapshots?user_id=eq.user-1&select=payload,updated_at&limit=1'
const PUSH_URL: string = 'https://api.test.local/rest/v1/snapshots'
const PREFER_UPSERT: string = 'resolution=merge-duplicates,return=minimal'

function getTestContext(): Context {
  const appContext: Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  return appContext.getApplicationContext().createModuleContext('entry')
}

function makeResult(status: number, body: string): SupabaseHttpResult {
  const result: SupabaseHttpResult = { status: status, body: body }
  return result
}

/** push 请求体形状（断言用，与生产 SnapshotPushBody 同构）。 */
interface RecordedPushBody {
  user_id: string
  payload: Object
  updated_at: string
}

/** 录制传输：记录 method/url/accessToken/bodyJson/prefer/callCount，回放构造注入的响应。 */
class RecordingTransport extends SnapshotTransport {
  method: string = ''
  url: string = ''
  accessToken: string | null = null
  bodyJson: string = ''
  prefer: string = ''
  callCount: number = 0
  private response: SupabaseHttpResult

  constructor(response: SupabaseHttpResult) {
    super()
    this.response = response
  }

  async get(url: string, accessToken: string | null): Promise<SupabaseHttpResult> {
    this.method = 'GET'
    this.url = url
    this.accessToken = accessToken
    this.bodyJson = ''
    this.prefer = ''
    this.callCount = this.callCount + 1
    return this.response
  }

  async postWithPrefer(url: string, bodyJson: string, accessToken: string | null,
                       prefer: string): Promise<SupabaseHttpResult> {
    this.method = 'POST'
    this.url = url
    this.accessToken = accessToken
    this.bodyJson = bodyJson
    this.prefer = prefer
    this.callCount = this.callCount + 1
    return this.response
  }
}

/** 静态 token 提供者：恒返回构造注入的 token（含 null 场景）。 */
class StaticTokenProvider extends AccessTokenProvider {
  private token: string | null

  constructor(token: string | null) {
    super()
    this.token = token
  }

  async getAccessToken(context: Context): Promise<string | null> {
    return this.token
  }
}

/** 注入一份新响应，返回该录制传输（覆盖 beforeEach 的缺省注入）。 */
function useResponse(status: number, body: string): RecordingTransport {
  const transport: RecordingTransport = new RecordingTransport(makeResult(status, body))
  supabaseCloudSnapshotStore.setTransportForTesting(transport)
  return transport
}

/** 用例前隔离：配置 + 录制传输（空数组响应）+ 固定 token。 */
function beginIsolatedCase(): void {
  SupabaseConfig.setForTesting(TEST_CONFIG)
  useResponse(200, '[]')
  supabaseCloudSnapshotStore.setTokenProviderForTesting(new StaticTokenProvider(TEST_TOKEN))
}

/** 用例后复位全局单例，避免跨套件状态泄漏。 */
function endIsolatedCase(): void {
  SupabaseConfig.setForTesting(null)
  supabaseCloudSnapshotStore.setTransportForTesting(null)
  supabaseCloudSnapshotStore.setTokenProviderForTesting(null)
}

export default function supabaseCloudSnapshotStoreTest(): void {
  describe('SupabaseCloudSnapshotStore codec', () => {
    beforeEach(() => {
      beginIsolatedCase()
    })

    afterEach(() => {
      endIsolatedCase()
    })

    it('毫秒时间戳与 ISO8601 UTC 串互逆', 0, () => {
      expect(iso8601UtcFromEpochMillis(TEST_MILLIS)).assertEqual(TEST_ISO)
      expect(epochMillisFromIso8601(TEST_ISO)).assertEqual(TEST_MILLIS)
      // 纪元零点：输出固定宽度，逐字节可比
      expect(iso8601UtcFromEpochMillis(0)).assertEqual('1970-01-01T00:00:00.000Z')
      expect(epochMillisFromIso8601('1970-01-01T00:00:00.000Z')).assertEqual(0)
      expect(epochMillisFromIso8601(iso8601UtcFromEpochMillis(TEST_MILLIS))).assertEqual(TEST_MILLIS)
    })

    it('微秒精度截断到毫秒（Z 后缀）', 0, () => {
      const truncated: number | null = epochMillisFromIso8601('2026-10-04T12:34:56.789123Z')
      expect(truncated).assertEqual(epochMillisFromIso8601(TEST_ISO))
      expect(truncated).assertEqual(TEST_MILLIS)
    })

    it('微秒精度截断到毫秒（+08:00 偏移按绝对时刻归一）', 0, () => {
      // 2026-10-04T20:34:56.789123+08:00 与 2026-10-04T12:34:56.789Z 是同一绝对时刻
      const withOffset: number | null = epochMillisFromIso8601('2026-10-04T20:34:56.789123+08:00')
      expect(withOffset).assertEqual(epochMillisFromIso8601(TEST_ISO))
      expect(withOffset).assertEqual(TEST_MILLIS)
      // 带偏移的整点串同样归一到 UTC
      expect(epochMillisFromIso8601('2026-10-04T20:34:56+08:00')).assertEqual(TEST_MILLIS_SECOND)
    })

    it('整秒时间生成补零到毫秒', 0, () => {
      const parsed: number | null = epochMillisFromIso8601('2026-10-04T12:34:56Z')
      expect(parsed).assertEqual(TEST_MILLIS_SECOND)
      if (parsed !== null) {
        expect(iso8601UtcFromEpochMillis(parsed)).assertEqual('2026-10-04T12:34:56.000Z')
      }
    })

    it('无时区后缀按 UTC 解析', 0, () => {
      expect(epochMillisFromIso8601('2026-10-04T12:34:56.789')).assertEqual(TEST_MILLIS)
      expect(epochMillisFromIso8601('2026-10-04T12:34:56')).assertEqual(TEST_MILLIS_SECOND)
    })

    it('畸形时间串一律拒绝', 0, () => {
      expect(epochMillisFromIso8601('not-a-date')).assertNull()
      expect(epochMillisFromIso8601('')).assertNull()
      // 字段越界
      expect(epochMillisFromIso8601('2026-13-04T12:34:56Z')).assertNull()
      expect(epochMillisFromIso8601('2026-10-04T25:00:00Z')).assertNull()
      expect(epochMillisFromIso8601('2026-10-04T12:34:60Z')).assertNull()
      // 小数点后无数字
      expect(epochMillisFromIso8601('2026-10-04T12:34:56.Z')).assertNull()
      // 短串（长度不足）
      expect(epochMillisFromIso8601('2026-10-04T12:34')).assertNull()
      // 分隔符不符
      expect(epochMillisFromIso8601('2026-10-04X12:34:56Z')).assertNull()
      // 非法时区后缀（不足 ±HH 宽度）
      expect(epochMillisFromIso8601('2026-10-04T12:34:56+8')).assertNull()
      expect(epochMillisFromIso8601('2026-10-04T12:34:56QQ')).assertNull()
    })
  })

  describe('SupabaseCloudSnapshotStore pull', () => {
    beforeEach(() => {
      beginIsolatedCase()
    })

    afterEach(() => {
      endIsolatedCase()
    })

    it('pull 请求按 PostgREST 契约构造', 0, async () => {
      const transport: RecordingTransport = useResponse(
        200,
        '[{"payload":{"schemaVersion":1},"updated_at":"2026-10-04T12:34:56.789Z"}]'
      )
      await supabaseCloudSnapshotStore.pull(getTestContext(), TEST_USER_ID)
      expect(transport.callCount).assertEqual(1)
      expect(transport.method).assertEqual('GET')
      expect(transport.url).assertEqual(PULL_URL)
      expect(transport.bodyJson).assertEqual('')
      expect(transport.accessToken).assertEqual(TEST_TOKEN)
    })

    it('云端无快照（空数组）时返回 null', 0, async () => {
      const transport: RecordingTransport = useResponse(200, '[]')
      const snapshot: CloudSnapshot | null = await supabaseCloudSnapshotStore.pull(getTestContext(), TEST_USER_ID)
      expect(snapshot).assertNull()
      expect(transport.callCount).assertEqual(1)
    })

    it('单行 jsonb 内联解析为紧凑载荷与毫秒时间戳', 0, async () => {
      useResponse(200, '[{"payload":{"schemaVersion":1,"sessions":[]},"updated_at":"2026-10-04T12:34:56.789Z"}]')
      const snapshot: CloudSnapshot | null = await supabaseCloudSnapshotStore.pull(getTestContext(), TEST_USER_ID)
      expect(snapshot !== null).assertTrue()
      if (snapshot !== null) {
        expect(snapshot.userId).assertEqual(TEST_USER_ID)
        // jsonb 列内联为 JSON 值 → 序列化回紧凑字符串（无空格）
        expect(snapshot.payloadJson).assertEqual('{"schemaVersion":1,"sessions":[]}')
        expect(snapshot.updatedAt).assertEqual(TEST_MILLIS)
        expect(snapshot.deviceTag).assertEqual('local-device')
        expect(snapshot.schemaVersion).assertEqual(1)
      }
    })

    it('非 2xx 响应按无快照处理', 0, async () => {
      const context: Context = getTestContext()
      useResponse(401, '')
      expect(await supabaseCloudSnapshotStore.pull(context, TEST_USER_ID)).assertNull()
      useResponse(500, 'boom')
      expect(await supabaseCloudSnapshotStore.pull(context, TEST_USER_ID)).assertNull()
    })

    it('响应体非数组或非 JSON 时返回 null', 0, async () => {
      const context: Context = getTestContext()
      useResponse(200, '{"payload":{"a":1},"updated_at":"2026-10-04T12:34:56.789Z"}')
      expect(await supabaseCloudSnapshotStore.pull(context, TEST_USER_ID)).assertNull()
      useResponse(200, 'not-json')
      expect(await supabaseCloudSnapshotStore.pull(context, TEST_USER_ID)).assertNull()
    })

    it('行内缺少 payload 或 updated_at 时返回 null', 0, async () => {
      const context: Context = getTestContext()
      useResponse(200, '[{"updated_at":"2026-10-04T12:34:56.789Z"}]')
      expect(await supabaseCloudSnapshotStore.pull(context, TEST_USER_ID)).assertNull()
      useResponse(200, '[{"payload":{"a":1}}]')
      expect(await supabaseCloudSnapshotStore.pull(context, TEST_USER_ID)).assertNull()
    })

    it('updated_at 时间串畸形时返回 null', 0, async () => {
      useResponse(200, '[{"payload":{"a":1},"updated_at":"not-a-date"}]')
      expect(await supabaseCloudSnapshotStore.pull(getTestContext(), TEST_USER_ID)).assertNull()
    })
  })

  describe('SupabaseCloudSnapshotStore push', () => {
    beforeEach(() => {
      beginIsolatedCase()
    })

    afterEach(() => {
      endIsolatedCase()
    })

    it('push 请求按 PostgREST 契约构造', 0, async () => {
      const transport: RecordingTransport = useResponse(201, '')
      const snapshot: CloudSnapshot = createCloudSnapshot(TEST_USER_ID, '{"a":1}', TEST_MILLIS, 'local-device', 1)
      const pushed: boolean = await supabaseCloudSnapshotStore.push(getTestContext(), snapshot)
      expect(pushed).assertTrue()
      expect(transport.callCount).assertEqual(1)
      expect(transport.method).assertEqual('POST')
      expect(transport.url).assertEqual(PUSH_URL)
      expect(transport.prefer).assertEqual(PREFER_UPSERT)
      expect(transport.accessToken).assertEqual(TEST_TOKEN)
      const body: RecordedPushBody = JSON.parse(transport.bodyJson) as RecordedPushBody
      expect(body.user_id).assertEqual(TEST_USER_ID)
      expect(body.updated_at).assertEqual(TEST_ISO)
      // payload 以 JSON 值内联（交由 jsonb 列存储），非转义字符串
      expect(JSON.stringify(body.payload)).assertEqual('{"a":1}')
    })

    it('2xx 响应一律视为成功', 0, async () => {
      const context: Context = getTestContext()
      const snapshot: CloudSnapshot = createCloudSnapshot(TEST_USER_ID, '{"a":1}', TEST_MILLIS, 'local-device', 1)
      useResponse(200, '')
      expect(await supabaseCloudSnapshotStore.push(context, snapshot)).assertTrue()
      useResponse(201, '')
      expect(await supabaseCloudSnapshotStore.push(context, snapshot)).assertTrue()
    })

    it('非 2xx 响应一律视为失败', 0, async () => {
      const context: Context = getTestContext()
      const snapshot: CloudSnapshot = createCloudSnapshot(TEST_USER_ID, '{"a":1}', TEST_MILLIS, 'local-device', 1)
      useResponse(409, '')
      expect(await supabaseCloudSnapshotStore.push(context, snapshot)).assertFalse()
      useResponse(401, '')
      expect(await supabaseCloudSnapshotStore.push(context, snapshot)).assertFalse()
    })

    it('非法载荷不发请求直接失败', 0, async () => {
      const context: Context = getTestContext()
      const stringLiteral: CloudSnapshot = createCloudSnapshot(TEST_USER_ID, '"str"', TEST_MILLIS, 'local-device', 1)
      const arrayLiteral: CloudSnapshot = createCloudSnapshot(TEST_USER_ID, '[1]', TEST_MILLIS, 'local-device', 1)
      const brokenJson: CloudSnapshot = createCloudSnapshot(TEST_USER_ID, '{invalid', TEST_MILLIS, 'local-device', 1)
      const nullLiteral: CloudSnapshot = createCloudSnapshot(TEST_USER_ID, 'null', TEST_MILLIS, 'local-device', 1)

      const transport: RecordingTransport = useResponse(201, '')
      expect(await supabaseCloudSnapshotStore.push(context, stringLiteral)).assertFalse()
      expect(await supabaseCloudSnapshotStore.push(context, arrayLiteral)).assertFalse()
      expect(await supabaseCloudSnapshotStore.push(context, brokenJson)).assertFalse()
      expect(await supabaseCloudSnapshotStore.push(context, nullLiteral)).assertFalse()
      expect(transport.callCount).assertEqual(0)
    })
  })

  describe('SupabaseCloudSnapshotStore token 透传', () => {
    beforeEach(() => {
      beginIsolatedCase()
    })

    afterEach(() => {
      endIsolatedCase()
    })

    it('token 提供者返回 null 时原样透传给传输层', 0, async () => {
      supabaseCloudSnapshotStore.setTokenProviderForTesting(new StaticTokenProvider(null))
      const context: Context = getTestContext()

      const pullTransport: RecordingTransport = useResponse(200, '[]')
      await supabaseCloudSnapshotStore.pull(context, TEST_USER_ID)
      expect(pullTransport.accessToken).assertNull()

      const pushTransport: RecordingTransport = useResponse(201, '')
      const snapshot: CloudSnapshot = createCloudSnapshot(TEST_USER_ID, '{"a":1}', TEST_MILLIS, 'local-device', 1)
      await supabaseCloudSnapshotStore.push(context, snapshot)
      expect(pushTransport.accessToken).assertNull()
    })
  })
}
