/**
 * UserProfileService — 用户个人资料持久化服务
 *
 * 功能 #5: 管理用户昵称、头像占位、体重单位偏好的本地存储。
 * 使用 @ohos.data.preferences 实现持久化，全局单例。
 */
import { preferences } from '@kit.ArkData'

const STORE_NAME = 'fit_tracker_profile'
const KEY_NICKNAME = 'nickname'
const KEY_AVATAR = 'avatar'
const KEY_WEIGHT_UNIT = 'weight_unit'

export type WeightUnit = 'kg' | 'lbs'

export interface UserProfile {
  nickname: string
  avatar: string
  weightUnit: WeightUnit
}

const DEFAULT_PROFILE: UserProfile = {
  nickname: '',
  avatar: '',
  weightUnit: 'kg'
}

class UserProfileService {
  async loadProfile(context: Context): Promise<UserProfile> {
    const prefs = await preferences.getPreferences(context, STORE_NAME)
    const nickname = await prefs.get(KEY_NICKNAME, '') as string
    const avatar = await prefs.get(KEY_AVATAR, '') as string
    const weightUnit = await prefs.get(KEY_WEIGHT_UNIT, 'kg') as string
    return {
      nickname: nickname || '',
      avatar: avatar || '',
      weightUnit: (weightUnit === 'lbs' ? 'lbs' : 'kg') as WeightUnit
    }
  }

  async saveNickname(context: Context, nickname: string): Promise<void> {
    const prefs = await preferences.getPreferences(context, STORE_NAME)
    await prefs.put(KEY_NICKNAME, nickname)
    await prefs.flush()
  }

  async saveAvatar(context: Context, avatar: string): Promise<void> {
    const prefs = await preferences.getPreferences(context, STORE_NAME)
    await prefs.put(KEY_AVATAR, avatar)
    await prefs.flush()
  }

  async saveWeightUnit(context: Context, unit: WeightUnit): Promise<void> {
    const prefs = await preferences.getPreferences(context, STORE_NAME)
    await prefs.put(KEY_WEIGHT_UNIT, unit)
    await prefs.flush()
  }

  getDefaultProfile(): UserProfile {
    return {
      nickname: DEFAULT_PROFILE.nickname,
      avatar: DEFAULT_PROFILE.avatar,
      weightUnit: DEFAULT_PROFILE.weightUnit
    }
  }
}

export default new UserProfileService()
