/**
 * UserProfileService 单元测试
 *
 * 测试个人资料持久化服务的纯函数部分：
 *   - 默认资料值
 *   - 类型定义正确性
 */
import { describe, it, expect } from '@ohos/hypium'
import UserProfileService from '../main/ets/common/services/UserProfileService'

export default function userProfileServiceTest() {
  describe('UserProfileService — getDefaultProfile', () => {

    it('should return default profile with empty nickname', 0, () => {
      const profile = UserProfileService.getDefaultProfile()
      expect(profile.nickname).assertEqual('')
    })

    it('should return default profile with empty avatar', 0, () => {
      const profile = UserProfileService.getDefaultProfile()
      expect(profile.avatar).assertEqual('')
    })

    it('should return default profile with kg as weight unit', 0, () => {
      const profile = UserProfileService.getDefaultProfile()
      expect(profile.weightUnit).assertEqual('kg')
    })
  })

  describe('UserProfileService — type integrity', () => {

    it('should have all required fields in profile', 0, () => {
      const profile = UserProfileService.getDefaultProfile()
      expect(profile.nickname !== undefined).assertTrue()
      expect(profile.avatar !== undefined).assertTrue()
      expect(profile.weightUnit !== undefined).assertTrue()
    })

    it('should default weightUnit to kg not lbs', 0, () => {
      const profile = UserProfileService.getDefaultProfile()
      expect(profile.weightUnit).assertEqual('kg')
      expect(profile.weightUnit === 'lbs').assertFalse()
    })

    it('should return a new object each call', 0, () => {
      const p1 = UserProfileService.getDefaultProfile()
      const p2 = UserProfileService.getDefaultProfile()
      expect(p1 === p2).assertFalse()
    })
  })
}
