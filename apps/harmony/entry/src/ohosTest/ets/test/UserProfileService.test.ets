/**
 * UserProfileService unit test
 * Covers feature #23: nickname, avatar, and weight unit persistence.
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium'
import UserProfileService, { UserProfile } from '../../../main/ets/common/services/UserProfileService'

function getTestContext(): Context {
  const appContext: Context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
  return appContext.getApplicationContext().createModuleContext('entry')
}

export default function userProfileServiceTest(): void {
  describe('UserProfileService', () => {
    beforeEach(async () => {
      await UserProfileService.clearProfile(getTestContext())
    })

    afterEach(async () => {
      await UserProfileService.clearProfile(getTestContext())
    })

    it('saves and reloads nickname avatar and weight unit preferences', 0, async () => {
      const savedProfile: UserProfile = {
        nickname: 'Power Tester',
        avatar: 'avatar_strength_blue',
        weightUnit: 'lbs',
        heightCm: 178,
        gender: 'male',
        birthYear: 1995
      }

      await UserProfileService.saveProfile(getTestContext(), savedProfile)
      const reloadedProfile: UserProfile = await UserProfileService.loadProfile(getTestContext())

      expect(reloadedProfile.nickname).assertEqual('Power Tester')
      expect(reloadedProfile.avatar).assertEqual('avatar_strength_blue')
      expect(reloadedProfile.weightUnit).assertEqual('lbs')
      expect(reloadedProfile.heightCm).assertEqual(178)
      expect(reloadedProfile.gender).assertEqual('male')
      expect(reloadedProfile.birthYear).assertEqual(1995)
      expect(UserProfileService.getLastPersistenceError()).assertEqual('')
    })

    it('returns default profile after persisted preferences are cleared', 0, async () => {
      const savedProfile: UserProfile = {
        nickname: 'Temp User',
        avatar: 'avatar_power_red',
        weightUnit: 'kg',
        heightCm: 165,
        gender: 'female',
        birthYear: 2000
      }

      await UserProfileService.saveProfile(getTestContext(), savedProfile)
      await UserProfileService.clearProfile(getTestContext())
      const reloadedProfile: UserProfile = await UserProfileService.loadProfile(getTestContext())

      expect(reloadedProfile.nickname).assertEqual('')
      expect(reloadedProfile.avatar).assertEqual('')
      expect(reloadedProfile.weightUnit).assertEqual('kg')
      // 清库后身体档案回落未填状态（0 / 空串 / 0）。
      expect(reloadedProfile.heightCm).assertEqual(0)
      expect(reloadedProfile.gender).assertEqual('')
      expect(reloadedProfile.birthYear).assertEqual(0)
    })
  })
}
