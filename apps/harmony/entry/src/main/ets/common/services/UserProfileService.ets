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
// 身体档案（用于 BMI / 基础代谢派生；未填时为空态占位，不参与派生）。
const KEY_HEIGHT_CM = 'height_cm'
const KEY_GENDER = 'gender'
const KEY_BIRTH_YEAR = 'birth_year'
// 训练经验：仅用于展示与后续计划推荐；未填为空串。
const KEY_EXPERIENCE = 'experience'
// 头像图片：本机沙箱绝对路径（跨设备经云快照信封的 base64 字段恢复）；空串表示未设置。
const KEY_AVATAR_IMAGE_PATH = 'avatar_image_path'

export type WeightUnit = 'kg' | 'lbs'

/** 生理性别——仅用于基础代谢公式（Mifflin-St Jeor）的性别常数；未填为空串。 */
export type Gender = '' | 'male' | 'female'

/** 训练经验；未填为空串。 */
export type Experience = '' | 'beginner' | 'intermediate' | 'advanced'

export interface UserProfile {
  nickname: string
  avatar: string
  weightUnit: WeightUnit
  /** 身高（厘米）；0 表示未填写。 */
  heightCm: number
  /** 性别；空串表示未填写。 */
  gender: Gender
  /** 出生年份；0 表示未填写。 */
  birthYear: number
  /** 训练经验；空串表示未填写。 */
  experience: Experience
  /** 头像图片的本机沙箱路径；空串表示未设置（回落色键 + 昵称首字）。 */
  avatarImagePath: string
}

const DEFAULT_PROFILE: UserProfile = {
  nickname: '',
  avatar: '',
  weightUnit: 'kg',
  heightCm: 0,
  gender: '',
  birthYear: 0,
  experience: '',
  avatarImagePath: ''
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
      const heightCm = await prefs.get(KEY_HEIGHT_CM, 0) as number
      const gender = await prefs.get(KEY_GENDER, '') as string
      const birthYear = await prefs.get(KEY_BIRTH_YEAR, 0) as number
      const experience = await prefs.get(KEY_EXPERIENCE, '') as string
      const avatarImagePath = await prefs.get(KEY_AVATAR_IMAGE_PATH, '') as string
      return {
        nickname: nickname || '',
        avatar: avatar || '',
        weightUnit: this.normalizeWeightUnit(weightUnit),
        heightCm: this.normalizeHeightCm(heightCm),
        gender: this.normalizeGender(gender),
        birthYear: this.normalizeBirthYear(birthYear),
        experience: this.normalizeExperience(experience),
        avatarImagePath: avatarImagePath || ''
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
      await prefs.put(KEY_HEIGHT_CM, this.normalizeHeightCm(profile.heightCm))
      await prefs.put(KEY_GENDER, this.normalizeGender(profile.gender))
      await prefs.put(KEY_BIRTH_YEAR, this.normalizeBirthYear(profile.birthYear))
      await prefs.put(KEY_EXPERIENCE, this.normalizeExperience(profile.experience))
      await prefs.put(KEY_AVATAR_IMAGE_PATH, profile.avatarImagePath)
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'save_profile_failed'
    }
  }

  /** 只改身体档案（身高/性别/出生年），其余字段保留。 */
  async saveBodyProfile(context: Context, heightCm: number, gender: Gender, birthYear: number): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_HEIGHT_CM, this.normalizeHeightCm(heightCm))
      await prefs.put(KEY_GENDER, this.normalizeGender(gender))
      await prefs.put(KEY_BIRTH_YEAR, this.normalizeBirthYear(birthYear))
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'save_body_profile_failed'
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
      weightUnit: DEFAULT_PROFILE.weightUnit,
      heightCm: DEFAULT_PROFILE.heightCm,
      gender: DEFAULT_PROFILE.gender,
      birthYear: DEFAULT_PROFILE.birthYear,
      experience: DEFAULT_PROFILE.experience,
      avatarImagePath: DEFAULT_PROFILE.avatarImagePath
    }
  }

  async clearProfile(context: Context): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.delete(KEY_NICKNAME)
      await prefs.delete(KEY_AVATAR)
      await prefs.delete(KEY_WEIGHT_UNIT)
      await prefs.delete(KEY_HEIGHT_CM)
      await prefs.delete(KEY_GENDER)
      await prefs.delete(KEY_BIRTH_YEAR)
      await prefs.delete(KEY_EXPERIENCE)
      await prefs.delete(KEY_AVATAR_IMAGE_PATH)
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

  /** 身高归一：非有限、负数或超出 [0, 300] cm 一律按 0（未填写）。 */
  private normalizeHeightCm(value: number): number {
    if (!Number.isFinite(value) || value < 0 || value > 300) {
      return 0
    }
    return value
  }

  /** 性别归一：仅 'male' / 'female' 有效，其余为空串（未填写）。 */
  private normalizeGender(value: string): Gender {
    if (value === 'male' || value === 'female') {
      return value
    }
    return ''
  }

  /** 出生年归一：非有限或不在 [1900, 当前年] 一律按 0（未填写）。 */
  private normalizeBirthYear(value: number): number {
    const currentYear: number = new Date().getFullYear()
    if (!Number.isFinite(value) || value < 1900 || value > currentYear) {
      return 0
    }
    return Math.floor(value)
  }

  /** 训练经验归一：仅三个枚举值有效，其余为空串（未填写）。 */
  private normalizeExperience(value: string): Experience {
    if (value === 'beginner' || value === 'intermediate' || value === 'advanced') {
      return value
    }
    return ''
  }
}

export default new UserProfileService()
