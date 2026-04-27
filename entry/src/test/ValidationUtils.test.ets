/**
 * ValidationUtils 单元测试
 *
 * 测试注册表单所有校验规则：
 *   - 手机号格式（空值、错误格式、正确格式、边界字符）
 *   - 密码长度（空值、不足6位、≥6位）
 *   - 确认密码（空值、不一致、一致）
 *   - 全量表单校验（组合场景、错误优先）
 */
import { describe, it, expect } from '@ohos/hypium'
import {
  validatePhone,
  validatePassword,
  validateConfirmPassword,
  validateRegisterForm,
  validateLoginForm
} from '../main/ets/common/utils/ValidationUtils'

export default function validationUtilsTest() {
  describe('validatePhone', () => {

    it('should reject empty phone', 0, () => {
      const result = validatePhone('')
      expect(result.valid).assertFalse()
      expect(result.message).assertContain('请输入手机号')
    })

    it('should reject non-numeric phone', 0, () => {
      const result = validatePhone('abcdefghijk')
      expect(result.valid).assertFalse()
      expect(result.message).assertContain('正确的手机号格式')
    })

    it('should reject short phone', 0, () => {
      const result = validatePhone('1380013800')
      expect(result.valid).assertFalse()
    })

    it('should reject phone starting with 2', 0, () => {
      const result = validatePhone('23800138000')
      expect(result.valid).assertFalse()
    })

    it('should accept valid 11-digit phone', 0, () => {
      const result = validatePhone('13800138000')
      expect(result.valid).assertTrue()
    })

    it('should accept valid phone with whitespace trim', 0, () => {
      const result = validatePhone(' 13912345678 ')
      expect(result.valid).assertTrue()
    })
  })

  describe('validatePassword', () => {

    it('should reject empty password', 0, () => {
      const result = validatePassword('')
      expect(result.valid).assertFalse()
      expect(result.message).assertContain('请输入密码')
    })

    it('should reject password shorter than 6 chars', 0, () => {
      const result = validatePassword('12345')
      expect(result.valid).assertFalse()
      expect(result.message).assertContain('6')
    })

    it('should reject password of exactly 5 chars', 0, () => {
      const result = validatePassword('abcde')
      expect(result.valid).assertFalse()
    })

    it('should accept password of exactly 6 chars', 0, () => {
      const result = validatePassword('123456')
      expect(result.valid).assertTrue()
    })

    it('should accept long password', 0, () => {
      const result = validatePassword('a'.repeat(20))
      expect(result.valid).assertTrue()
    })
  })

  describe('validateConfirmPassword', () => {

    it('should reject empty confirm password', 0, () => {
      const result = validateConfirmPassword('123456', '')
      expect(result.valid).assertFalse()
      expect(result.message).assertContain('请再次输入密码')
    })

    it('should reject mismatched passwords', 0, () => {
      const result = validateConfirmPassword('123456', '654321')
      expect(result.valid).assertFalse()
      expect(result.message).assertContain('不一致')
    })

    it('should accept matching passwords', 0, () => {
      const result = validateConfirmPassword('123456', '123456')
      expect(result.valid).assertTrue()
    })
  })

  describe('validateRegisterForm — 全量校验', () => {

    it('should return allValid=true when all fields are valid', 0, () => {
      const result = validateRegisterForm('13800138000', '123456', '123456')
      expect(result.allValid).assertTrue()
      expect(result.phoneError).assertEqual('')
      expect(result.passwordError).assertEqual('')
      expect(result.confirmError).assertEqual('')
    })

    it('should return allValid=false with phone error only', 0, () => {
      const result = validateRegisterForm('123', '123456', '123456')
      expect(result.allValid).assertFalse()
      expect(result.phoneError.length).assertLarger(0)
      expect(result.passwordError).assertEqual('')
      expect(result.confirmError).assertEqual('')
    })

    it('should return allValid=false with password error only', 0, () => {
      const result = validateRegisterForm('13800138000', '123', '123')
      expect(result.allValid).assertFalse()
      expect(result.passwordError.length).assertLarger(0)
    })

    it('should return allValid=false with confirm mismatch only', 0, () => {
      const result = validateRegisterForm('13800138000', '123456', '654321')
      expect(result.allValid).assertFalse()
      expect(result.confirmError.length).assertLarger(0)
      expect(result.phoneError).assertEqual('')
      expect(result.passwordError).assertEqual('')
    })

    it('should return allValid=false with all fields invalid', 0, () => {
      const result = validateRegisterForm('', '', '')
      expect(result.allValid).assertFalse()
      expect(result.phoneError.length).assertLarger(0)
      expect(result.passwordError.length).assertLarger(0)
      expect(result.confirmError.length).assertLarger(0)
    })

    it('should return allValid=false when confirm does not match despite valid password', 0, () => {
      const result = validateRegisterForm('13800138000', 'password123', 'password456')
      expect(result.allValid).assertFalse()
      expect(result.phoneError).assertEqual('')
      expect(result.passwordError).assertEqual('')
      expect(result.confirmError.length).assertLarger(0)
    })
  })

  describe('validateLoginForm — 登录校验', () => {

    it('should return allValid=true when phone and password are valid', 0, () => {
      const result = validateLoginForm('13800138000', '123456')
      expect(result.allValid).assertTrue()
      expect(result.phoneError).assertEqual('')
      expect(result.passwordError).assertEqual('')
    })

    it('should return allValid=false with empty phone', 0, () => {
      const result = validateLoginForm('', '123456')
      expect(result.allValid).assertFalse()
      expect(result.phoneError.length).assertLarger(0)
      expect(result.passwordError).assertEqual('')
    })

    it('should return allValid=false with invalid phone format', 0, () => {
      const result = validateLoginForm('123', '123456')
      expect(result.allValid).assertFalse()
      expect(result.phoneError.length).assertLarger(0)
    })

    it('should return allValid=false with empty password', 0, () => {
      const result = validateLoginForm('13800138000', '')
      expect(result.allValid).assertFalse()
      expect(result.phoneError).assertEqual('')
      expect(result.passwordError.length).assertLarger(0)
    })

    it('should return allValid=false with password shorter than 6 chars', 0, () => {
      const result = validateLoginForm('13800138000', '12345')
      expect(result.allValid).assertFalse()
      expect(result.passwordError).assertContain('6')
    })

    it('should return allValid=false with both phone and password invalid', 0, () => {
      const result = validateLoginForm('', '')
      expect(result.allValid).assertFalse()
      expect(result.phoneError.length).assertLarger(0)
      expect(result.passwordError.length).assertLarger(0)
    })
  })
}
