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
  })
}
