/**
 * AuthService 单元测试
 *
 * 测试模拟认证服务：
 *   - 注册新用户
 *   - 重复注册检测
 *   - 登录已注册用户
 *   - 未注册用户登录检测
 *   - 密码错误检测
 */
import { describe, it, expect } from '@ohos/hypium'
import AuthService from '../main/ets/common/services/AuthService'

export default function authServiceTest() {
  describe('AuthService — register', () => {

    it('should register a new user successfully', 0, () => {
      const result = AuthService.register('15000000001', '123456')
      expect(result.success).assertTrue()
      expect(result.message).assertContain('成功')
    })

    it('should reject duplicate registration', 0, () => {
      AuthService.register('15000000002', 'password')
      const result = AuthService.register('15000000002', 'password')
      expect(result.success).assertFalse()
      expect(result.message).assertContain('已注册')
    })
  })

  describe('AuthService — login', () => {

    it('should reject login with unregistered phone', 0, () => {
      const result = AuthService.login('15000000099', '123456')
      expect(result.success).assertFalse()
      expect(result.message).assertContain('尚未注册')
    })

    it('should reject login with wrong password', 0, () => {
      AuthService.register('15000000003', 'correct')
      const result = AuthService.login('15000000003', 'wrong')
      expect(result.success).assertFalse()
      expect(result.message).assertContain('密码错误')
    })

    it('should login successfully with correct credentials', 0, () => {
      AuthService.register('15000000004', 'mypassword')
      const result = AuthService.login('15000000004', 'mypassword')
      expect(result.success).assertTrue()
      expect(result.message).assertContain('成功')
    })
  })

  describe('AuthService — isRegistered', () => {

    it('should return false for unregistered phone', 0, () => {
      expect(AuthService.isRegistered('15000000999')).assertFalse()
    })

    it('should return true for registered phone', 0, () => {
      AuthService.register('15000000005', 'test123')
      expect(AuthService.isRegistered('15000000005')).assertTrue()
    })
  })
}
