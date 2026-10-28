/**
 * SettingsService unit test
 * 覆盖设置项持久化的 roundtrip、默认值、单键更新隔离与清空复位。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { i18n } from '@kit.LocalizationKit'
import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium'
import SettingsService, { AppSettings, resolveEffectiveAppLanguage, toAppLanguage } from '../../../main/ets/common/services/SettingsService'

function getTestContext(): Context {
  const appContext: Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  return appContext.getApplicationContext().createModuleContext('entry')
}

export default function settingsServiceTest(): void {
  describe('SettingsService', () => {
    beforeEach(async () => {
      await SettingsService.clearSettings(getTestContext())
    })

    afterEach(async () => {
      await SettingsService.clearSettings(getTestContext())
    })

    it('returns defaults after persisted settings are cleared', 0, async () => {
      const settings: AppSettings = await SettingsService.loadSettings(getTestContext())
      expect(settings.language).assertEqual('zh-CN')
      expect(settings.weekStart).assertEqual('monday')
      expect(settings.reminder).assertEqual(true)
      expect(settings.achievement).assertEqual(false)
      expect(settings.sound).assertEqual(true)
      expect(settings.keepOn).assertEqual(true)
      expect(settings.anonymous).assertEqual(false)
      // 体重目标：从未设置 → 0（回顾页据此渲染「设置目标」空态，不显示样例 68）。
      expect(settings.weightGoalKg).assertEqual(0)
    })

    it('saves and reloads all settings fields', 0, async () => {
      await SettingsService.saveLanguage(getTestContext(), 'en-US')
      await SettingsService.saveWeekStart(getTestContext(), 'sunday')
      await SettingsService.saveToggle(getTestContext(), 'reminder', false)
      await SettingsService.saveToggle(getTestContext(), 'achievement', true)
      await SettingsService.saveToggle(getTestContext(), 'sound', false)
      await SettingsService.saveToggle(getTestContext(), 'keepOn', false)
      await SettingsService.saveToggle(getTestContext(), 'anonymous', true)

      const settings: AppSettings = await SettingsService.loadSettings(getTestContext())
      expect(settings.language).assertEqual('en-US')
      expect(settings.weekStart).assertEqual('sunday')
      expect(settings.reminder).assertEqual(false)
      expect(settings.achievement).assertEqual(true)
      expect(settings.sound).assertEqual(false)
      expect(settings.keepOn).assertEqual(false)
      expect(settings.anonymous).assertEqual(true)
      expect(SettingsService.getLastPersistenceError()).assertEqual('')
    })

    it('updates one toggle without touching other keys', 0, async () => {
      await SettingsService.saveLanguage(getTestContext(), 'en-US')
      await SettingsService.saveToggle(getTestContext(), 'achievement', true)
      await SettingsService.saveToggle(getTestContext(), 'sound', false)
      await SettingsService.saveToggle(getTestContext(), 'sound', true)

      const settings: AppSettings = await SettingsService.loadSettings(getTestContext())
      expect(settings.language).assertEqual('en-US')
      expect(settings.achievement).assertEqual(true)
      expect(settings.sound).assertEqual(true)
      expect(settings.reminder).assertEqual(true)
      expect(settings.keepOn).assertEqual(true)
    })

    it('persists weight goal across reloads', 0, async () => {
      await SettingsService.saveWeightGoal(getTestContext(), 65.5)
      const settings: AppSettings = await SettingsService.loadSettings(getTestContext())
      // 目标必须跨会话存在——否则每次进回顾页都回到「未设置」，等于假数据。
      expect(settings.weightGoalKg).assertEqual(65.5)
      expect(SettingsService.getLastPersistenceError()).assertEqual('')
    })

    it('normalizes out-of-range weight goal to unset', 0, async () => {
      // 越界不静默收敛到边界：那会把用户输入的 250 kg 当成 200 kg 保存。
      await SettingsService.saveWeightGoal(getTestContext(), 250)
      expect((await SettingsService.loadSettings(getTestContext())).weightGoalKg).assertEqual(0)
      await SettingsService.saveWeightGoal(getTestContext(), 10)
      expect((await SettingsService.loadSettings(getTestContext())).weightGoalKg).assertEqual(0)
    })

    it('does not disturb weight goal when another toggle is saved', 0, async () => {
      await SettingsService.saveWeightGoal(getTestContext(), 70)
      await SettingsService.saveToggle(getTestContext(), 'sound', false)
      const settings: AppSettings = await SettingsService.loadSettings(getTestContext())
      expect(settings.weightGoalKg).assertEqual(70)
      expect(settings.sound).assertEqual(false)
    })

    it('maps language tags to supported app languages', 0, () => {
      // 与 Android settingsLanguageFor 同口径：只判 en 前缀，其余落回中文资源
      // （应用只有 zh_CN / en_US 两套资源，zh-Hant、fr 都渲染中文）。
      expect(toAppLanguage('en')).assertEqual('en-US')
      expect(toAppLanguage('en-US')).assertEqual('en-US')
      expect(toAppLanguage('EN-GB')).assertEqual('en-US')
      expect(toAppLanguage('zh')).assertEqual('zh-CN')
      expect(toAppLanguage('zh-Hans')).assertEqual('zh-CN')
      expect(toAppLanguage('zh-Hant')).assertEqual('zh-CN')
      expect(toAppLanguage('fr')).assertEqual('zh-CN')
      expect(toAppLanguage('')).assertEqual('zh-CN')
    })

    it('resolves effective language from app preference, not persisted value', 0, async () => {
      // 缺陷判据：存储为中文、但应用级偏好已是英文时，设置页必须显示英文。
      // 直接读 loadSettings().language 会得到 zh-CN——正是「英文界面勾简体中文」的成因。
      await SettingsService.saveLanguage(getTestContext(), 'zh-CN')
      const original: string = i18n.System.getAppPreferredLanguage()
      try {
        i18n.System.setAppPreferredLanguage('en-US')
        expect(resolveEffectiveAppLanguage()).assertEqual('en-US')
      } finally {
        i18n.System.setAppPreferredLanguage(original.length > 0 ? original : 'zh-Hans')
      }
    })
  })
}
