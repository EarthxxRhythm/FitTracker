/**
 * AuthService 单元测试
 * 覆盖注册、登录、重复注册、密码错误、isRegistered
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import authService from '../../../main/ets/common/services/AuthService'

export default function authServiceTest(): void {
  describe('AuthService', () => {
    // Note: AuthService uses in-memory Map, so state persists within a describe block.
    // We use distinct phone numbers per test to avoid interference.

    beforeAll(() => {
    })

    afterAll(() => {
    })

    // ============================================================
    // register
    // ============================================================
    describe('register', () => {
      it('should register a new user successfully', 0, () => {
        const result = authService.register('13800001111', '123456')
        expect(result.success).assertTrue()
        expect(result.message).assertEqual('注册成功')
        expect(result.token).assertContain('.')
      })

      it('should fail when phone is already registered', 0, () => {
        // Register first
        authService.register('13900001111', '123456')
        // Try duplicate
        const result = authService.register('13900001111', '654321')
        expect(result.success).assertFalse()
        expect(result.message).assertEqual('该手机号已注册')
        expect(result.token).assertEqual('')
      })

      it('should trim phone number before registration', 0, () => {
        authService.register('13800002222', '123456')
        const result = authService.register('  13800002222  ', '654321')
        expect(result.success).assertFalse()
        expect(result.message).assertEqual('该手机号已注册')
      })
    })

    // ============================================================
    // login
    // ============================================================
    describe('login', () => {
      beforeAll(() => {
        // Ensure a known user exists
        authService.register('13800003333', 'testpass')
      })

      it('should login successfully with correct credentials', 0, () => {
        const result = authService.login('13800003333', 'testpass')
        expect(result.success).assertTrue()
        expect(result.message).assertEqual('登录成功')
        expect(result.token).assertContain('.')
      })

      it('should fail with wrong password', 0, () => {
        const result = authService.login('13800003333', 'wrongpass')
        expect(result.success).assertFalse()
        expect(result.message).assertEqual('密码错误，请重试')
        expect(result.token).assertEqual('')
      })

      it('should fail for unregistered phone', 0, () => {
        const result = authService.login('13899999999', '123456')
        expect(result.success).assertFalse()
        expect(result.message).assertEqual('该手机号尚未注册，请先注册')
        expect(result.token).assertEqual('')
      })

      it('should trim phone on login', 0, () => {
        const result = authService.login('  13800003333  ', 'testpass')
        expect(result.success).assertTrue()
      })
    })

    // ============================================================
    // isRegistered
    // ============================================================
    describe('isRegistered', () => {
      beforeAll(() => {
        authService.register('13800004444', '123456')
      })

      it('should return true for registered phone', 0, () => {
        expect(authService.isRegistered('13800004444')).assertTrue()
      })

      it('should return false for unregistered phone', 0, () => {
        expect(authService.isRegistered('13888888888')).assertFalse()
      })

      it('should trim phone before check', 0, () => {
        expect(authService.isRegistered('  13800004444  ')).assertTrue()
      })
    })
  })
}
