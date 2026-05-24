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
  private lastPersistenceError: string = ''

  getLastPersistenceError(): string {
    return this.lastPersistenceError
  }

  async loadProfile(context: Context): Promise<UserProfile> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      const nickname = await prefs.get(KEY_NICKNAME, '') as string
      const avatar = await prefs.get(KEY_AVATAR, '') as string
      const weightUnit = await prefs.get(KEY_WEIGHT_UNIT, 'kg') as string
      return {
        nickname: nickname || '',
        avatar: avatar || '',
        weightUnit: this.normalizeWeightUnit(weightUnit)
      }
    } catch (error) {
      this.lastPersistenceError = 'load_profile_failed'
      return this.getDefaultProfile()
    }
  }

  async saveNickname(context: Context, nickname: string): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_NICKNAME, nickname)
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'save_nickname_failed'
    }
  }

  async saveProfile(context: Context, profile: UserProfile): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_NICKNAME, profile.nickname)
      await prefs.put(KEY_AVATAR, profile.avatar)
      await prefs.put(KEY_WEIGHT_UNIT, this.normalizeWeightUnit(profile.weightUnit))
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'save_profile_failed'
    }
  }

  async saveAvatar(context: Context, avatar: string): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_AVATAR, avatar)
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'save_avatar_failed'
    }
  }

  async saveWeightUnit(context: Context, unit: WeightUnit): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_WEIGHT_UNIT, unit)
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'save_weight_unit_failed'
    }
  }

  getDefaultProfile(): UserProfile {
    return {
      nickname: DEFAULT_PROFILE.nickname,
      avatar: DEFAULT_PROFILE.avatar,
      weightUnit: DEFAULT_PROFILE.weightUnit
    }
  }

  async clearProfile(context: Context): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.delete(KEY_NICKNAME)
      await prefs.delete(KEY_AVATAR)
      await prefs.delete(KEY_WEIGHT_UNIT)
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'clear_profile_failed'
    }
  }

  private normalizeWeightUnit(value: string): WeightUnit {
    if (value === 'lbs') {
      return 'lbs'
    }
    return 'kg'
  }
}

export default new UserProfileService()
