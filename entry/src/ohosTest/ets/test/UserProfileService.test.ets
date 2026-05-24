/**
 * UserProfileService 单元测试
 * 覆盖功能 #23：昵称、头像和体重单位偏好保存后可再次读取。
 */
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium'
import UserProfileService, { UserProfile } from '../../../main/ets/common/services/UserProfileService'

function getTestContext(): Context {
  return abilityDelegatorRegistry.getAbilityDelegator().getAppContext()
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
        nickname: '力量训练者',
        avatar: 'avatar_strength_blue',
        weightUnit: 'lbs'
      }

      await UserProfileService.saveProfile(getTestContext(), savedProfile)
      const reloadedProfile: UserProfile = await UserProfileService.loadProfile(getTestContext())

      expect(reloadedProfile.nickname).assertEqual('力量训练者')
      expect(reloadedProfile.avatar).assertEqual('avatar_strength_blue')
      expect(reloadedProfile.weightUnit).assertEqual('lbs')
      expect(UserProfileService.getLastPersistenceError()).assertEqual('')
    })

    it('returns default profile after persisted preferences are cleared', 0, async () => {
      const savedProfile: UserProfile = {
        nickname: '临时用户',
        avatar: 'avatar_power_red',
        weightUnit: 'kg'
      }

      await UserProfileService.saveProfile(getTestContext(), savedProfile)
      await UserProfileService.clearProfile(getTestContext())
      const reloadedProfile: UserProfile = await UserProfileService.loadProfile(getTestContext())

      expect(reloadedProfile.nickname).assertEqual('')
      expect(reloadedProfile.avatar).assertEqual('')
      expect(reloadedProfile.weightUnit).assertEqual('kg')
    })
  })
}
