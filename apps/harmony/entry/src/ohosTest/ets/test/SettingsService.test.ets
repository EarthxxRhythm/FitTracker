/**
 * SettingsService unit test
 * 覆盖设置项持久化的 roundtrip、默认值、单键更新隔离与清空复位。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium'
import SettingsService, { AppSettings } from '../../../main/ets/common/services/SettingsService'

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
      // 体重目标：从未设置 → 0（复盘页据此渲染「设置目标」空态，不显示样例 68）。
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
      // 目标必须跨会话存在——否则每次进复盘页都回到「未设置」，等于假数据。
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
  })
}
