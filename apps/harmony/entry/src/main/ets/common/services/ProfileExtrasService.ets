/**
 * ProfileExtrasService — 个人资料的「名片类」附加字段持久化服务。
 *
 * 只存放不进入身体档案/云同步信封的本地个人信息：地区、拍一拍、个性签名、常用健身房。
 * 头像、昵称、性别、身高、出生年、经验与体重单位仍归 \`UserProfileService\` 管；两者边界固定，
 * 不要把这些字段搬进 \`UserProfile\`（那会改变云同步信封结构与跨端契约）。
 *
 * 存储：preferences store \`fit_tracker_profile_extras\`，写入后 flush。
 * 全部字段为展示型文本，未填一律空串。
 */
import { preferences } from '@kit.ArkData'

const STORE_NAME = 'fit_tracker_profile_extras'
const KEY_REGION = 'region'
const KEY_WHATS_UP = 'whats_up'
const KEY_TICKLE = 'tickle'
const KEY_GYM_ADDRESS = 'gym_address'

export interface ProfileExtras {
  /** 地区；空串表示未填写。 */
  region: string
  /** 拍一拍文案；空串表示未填写。 */
  tickle: string
  /** 个性签名；空串表示未填写。 */
  whatsUp: string
  /** 常用健身房（地址类文本）；空串表示未填写。 */
  gymAddress: string
}

const EMPTY_EXTRAS: ProfileExtras = {
  region: '',
  tickle: '',
  whatsUp: '',
  gymAddress: ''
}

class ProfileExtrasService {
  private lastPersistenceError: string = ''

  getLastPersistenceError(): string {
    return this.lastPersistenceError
  }

  getEmptyExtras(): ProfileExtras {
    return {
      region: EMPTY_EXTRAS.region,
      tickle: EMPTY_EXTRAS.tickle,
      whatsUp: EMPTY_EXTRAS.whatsUp,
      gymAddress: EMPTY_EXTRAS.gymAddress
    }
  }

  async loadExtras(context: Context): Promise<ProfileExtras> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      const region: string = await prefs.get(KEY_REGION, '') as string
      const tickle: string = await prefs.get(KEY_TICKLE, '') as string
      const whatsUp: string = await prefs.get(KEY_WHATS_UP, '') as string
      const gymAddress: string = await prefs.get(KEY_GYM_ADDRESS, '') as string
      return {
        region: region || '',
        tickle: tickle || '',
        whatsUp: whatsUp || '',
        gymAddress: gymAddress || ''
      }
    } catch (error) {
      this.lastPersistenceError = 'load_extras_failed'
      return this.getEmptyExtras()
    }
  }

  async saveExtras(context: Context, extras: ProfileExtras): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_REGION, extras.region)
      await prefs.put(KEY_TICKLE, extras.tickle)
      await prefs.put(KEY_WHATS_UP, extras.whatsUp)
      await prefs.put(KEY_GYM_ADDRESS, extras.gymAddress)
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'save_extras_failed'
    }
  }

  /** 退出登录时清空（与 \`UserProfileService.clearProfile\` 同一时机调用）。 */
  async clearExtras(context: Context): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.clear()
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'clear_extras_failed'
    }
  }
}

export default new ProfileExtrasService()
