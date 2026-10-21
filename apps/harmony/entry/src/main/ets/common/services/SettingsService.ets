/**
 * SettingsService — 应用设置持久化服务。
 *
 * 功能 #5 设置模块：通用偏好（语言 / 周开始日）与各类开关状态的本地存储。
 * 存储：fit_tracker_settings（Preferences），模块级单例，调用方直接导入默认实例。
 * 归属边界：
 *  - 体重单位不在此 store —— 复用 UserProfileService.weightUnit（单一数据源，随云同步 envelope 流转）；
 *  - 云同步为恒定自动（无开关项），不在本 store。
 * 默认值与设置页原型（fittracker-settings.html）及现有 UI 初值一致。
 */
import { preferences } from '@kit.ArkData'
import { WeekStart } from '../utils/WeekUtils'

const STORE_NAME = 'fit_tracker_settings'
const KEY_LANGUAGE = 'language'
const KEY_WEEK_START = 'week_start'
const KEY_REMINDER = 'reminder'
const KEY_ACHIEVEMENT = 'achievement'
const KEY_SOUND = 'sound'
const KEY_KEEP_ON = 'keep_on'
const KEY_ANONYMOUS = 'anonymous'
/**
 * 体重目标（kg）；`0` = 用户从未设置。
 *
 * 归本 store 而不归 `UserProfileService`：单位是随云同步 envelope 流转的档案字段，而目标体重
 * 只是复盘页的展示辅助值——纳入 envelope 需同步改备份包与 `normalizePayloadForHash` 白名单，
 * 收益不抵风险（已在计划「同步失明陷阱」条目标注）。故仅本地持久化，换设备需重设。
 */
const KEY_WEIGHT_GOAL = 'weight_goal_kg'

/** 目标体重合法区间（kg）——与复盘页目标弹窗的越界校验同口径。 */
const WEIGHT_GOAL_MIN_KG = 30
const WEIGHT_GOAL_MAX_KG = 200

export type AppLanguage = 'zh-CN' | 'en-US'
export type SettingsToggleKey = 'reminder' | 'achievement' | 'sound' | 'keepOn' | 'anonymous'

export interface AppSettings {
  language: AppLanguage
  weekStart: WeekStart
  reminder: boolean
  achievement: boolean
  sound: boolean
  keepOn: boolean
  anonymous: boolean
  /** 复盘页体重目标（kg）；`0` = 未设置（不画目标线）。 */
  weightGoalKg: number
}

const DEFAULT_SETTINGS: AppSettings = {
  language: 'zh-CN',
  weekStart: 'monday',
  reminder: true,
  achievement: false,
  sound: true,
  keepOn: true,
  anonymous: false,
  weightGoalKg: 0
}

class SettingsService {
  private lastPersistenceError: string = ''

  getLastPersistenceError(): string {
    return this.lastPersistenceError
  }

  async loadSettings(context: Context): Promise<AppSettings> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      const language = await prefs.get(KEY_LANGUAGE, DEFAULT_SETTINGS.language) as string
      const weekStart = await prefs.get(KEY_WEEK_START, DEFAULT_SETTINGS.weekStart) as string
      const reminder = await prefs.get(KEY_REMINDER, DEFAULT_SETTINGS.reminder) as boolean
      const achievement = await prefs.get(KEY_ACHIEVEMENT, DEFAULT_SETTINGS.achievement) as boolean
      const sound = await prefs.get(KEY_SOUND, DEFAULT_SETTINGS.sound) as boolean
      const keepOn = await prefs.get(KEY_KEEP_ON, DEFAULT_SETTINGS.keepOn) as boolean
      const anonymous = await prefs.get(KEY_ANONYMOUS, DEFAULT_SETTINGS.anonymous) as boolean
      const weightGoalKg = await prefs.get(KEY_WEIGHT_GOAL, DEFAULT_SETTINGS.weightGoalKg) as number
      return {
        language: this.normalizeLanguage(language),
        weekStart: this.normalizeWeekStart(weekStart),
        reminder: reminder,
        achievement: achievement,
        sound: sound,
        keepOn: keepOn,
        anonymous: anonymous,
        weightGoalKg: this.normalizeGoalKg(weightGoalKg)
      }
    } catch (error) {
      this.lastPersistenceError = 'load_settings_failed'
      return this.getDefaultSettings()
    }
  }

  async saveLanguage(context: Context, language: AppLanguage): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_LANGUAGE, this.normalizeLanguage(language))
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'save_language_failed'
    }
  }

  async saveWeekStart(context: Context, weekStart: WeekStart): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_WEEK_START, this.normalizeWeekStart(weekStart))
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'save_week_start_failed'
    }
  }

  async saveToggle(context: Context, key: SettingsToggleKey, enabled: boolean): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(this.resolveToggleStoreKey(key), enabled)
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'save_toggle_failed'
    }
  }

  /**
   * 持久化复盘页体重目标（kg）；传 `0` 表示清除目标。
   *
   * 越界值不写入（`normalizeGoalKg` 归零），避免把越界值带进下次启动的展示态。
   */
  async saveWeightGoal(context: Context, kg: number): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_WEIGHT_GOAL, this.normalizeGoalKg(kg))
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'save_weight_goal_failed'
    }
  }

  getDefaultSettings(): AppSettings {
    return {
      language: DEFAULT_SETTINGS.language,
      weekStart: DEFAULT_SETTINGS.weekStart,
      reminder: DEFAULT_SETTINGS.reminder,
      achievement: DEFAULT_SETTINGS.achievement,
      sound: DEFAULT_SETTINGS.sound,
      keepOn: DEFAULT_SETTINGS.keepOn,
      anonymous: DEFAULT_SETTINGS.anonymous,
      weightGoalKg: DEFAULT_SETTINGS.weightGoalKg
    }
  }

  async clearSettings(context: Context): Promise<void> {
    this.lastPersistenceError = ''
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.delete(KEY_LANGUAGE)
      await prefs.delete(KEY_WEEK_START)
      await prefs.delete(KEY_REMINDER)
      await prefs.delete(KEY_ACHIEVEMENT)
      await prefs.delete(KEY_SOUND)
      await prefs.delete(KEY_KEEP_ON)
      await prefs.delete(KEY_ANONYMOUS)
      await prefs.delete(KEY_WEIGHT_GOAL)
      await prefs.flush()
    } catch (error) {
      this.lastPersistenceError = 'clear_settings_failed'
    }
  }

  private resolveToggleStoreKey(key: SettingsToggleKey): string {
    if (key === 'achievement') {
      return KEY_ACHIEVEMENT
    }
    if (key === 'sound') {
      return KEY_SOUND
    }
    if (key === 'keepOn') {
      return KEY_KEEP_ON
    }
    if (key === 'anonymous') {
      return KEY_ANONYMOUS
    }
    return KEY_REMINDER
  }

  private normalizeLanguage(value: string): AppLanguage {
    if (value === 'en-US') {
      return 'en-US'
    }
    return 'zh-CN'
  }

  private normalizeWeekStart(value: string): WeekStart {
    if (value === 'sunday') {
      return 'sunday'
    }
    return 'monday'
  }

  /**
   * 目标体重归一到「合法值或 0」。
   *
   * `0`、负数、`NaN`、越界值一律归 0（= 未设置）——UI 据此渲染空态。不静默收敛到边界值：
   * 那会把用户输入的 250 kg 变成 200 kg 并当作真实目标保存。
   */
  private normalizeGoalKg(value: number): number {
    if (!Number.isFinite(value)) {
      return 0
    }
    if (value < WEIGHT_GOAL_MIN_KG || value > WEIGHT_GOAL_MAX_KG) {
      return 0
    }
    return value
  }
}

export default new SettingsService()
