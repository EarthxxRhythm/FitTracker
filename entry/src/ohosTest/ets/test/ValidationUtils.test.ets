/**
 * ValidationUtils 单元测试
 * 覆盖手机号校验、密码校验、确认密码校验、登录表单校验、注册表单校验
 */
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium'
import {
  validatePhone,
  validatePassword,
  validateConfirmPassword,
  validateLoginForm,
  validateRegisterForm
} from '../../../main/ets/common/utils/ValidationUtils'

export default function validationUtilsTest(): void {
  describe('ValidationUtils', () => {
    beforeAll(() => {
    })

    afterAll(() => {
    })

    // ============================================================
    // validatePhone
    // ============================================================
    describe('validatePhone', () => {
      it('should return valid for correct phone numbers', 0, () => {
        const result = validatePhone('13812345678')
        expect(result.valid).assertTrue()
        expect(result.message).assertEqual('')
      })

      it('should accept 139 prefix', 0, () => {
        const result = validatePhone('13900001111')
        expect(result.valid).assertTrue()
      })

      it('should accept 150 prefix', 0, () => {
        const result = validatePhone('15012345678')
        expect(result.valid).assertTrue()
      })

      it('should accept 188 prefix', 0, () => {
        const result = validatePhone('18812345678')
        expect(result.valid).assertTrue()
      })

      it('should return invalid for empty string', 0, () => {
        const result = validatePhone('')
        expect(result.valid).assertFalse()
        expect(result.message).assertEqual('请输入手机号')
      })

      it('should return invalid for whitespace-only string', 0, () => {
        const result = validatePhone('   ')
        expect(result.valid).assertFalse()
        expect(result.message).assertEqual('请输入手机号')
      })

      it('should return invalid for non-11-digit number', 0, () => {
        const result = validatePhone('1381234567')
        expect(result.valid).assertFalse()
      })

      it('should return invalid for invalid prefix (120)', 0, () => {
        const result = validatePhone('12012345678')
        expect(result.valid).assertFalse()
      })

      it('should return invalid for invalid prefix (199)', 0, () => {
        const result = validatePhone('19999999999')
        expect(result.valid).assertFalse()
      })

      it('should return invalid for letters in phone', 0, () => {
        const result = validatePhone('138abc45678')
        expect(result.valid).assertFalse()
      })

      it('should return invalid for 12-digit number', 0, () => {
        const result = validatePhone('138123456789')
        expect(result.valid).assertFalse()
      })
    })

    // ============================================================
    // validatePassword
    // ============================================================
    describe('validatePassword', () => {
      it('should return valid for password with 6+ characters', 0, () => {
        const result = validatePassword('123456')
        expect(result.valid).assertTrue()
        expect(result.message).assertEqual('')
      })

      it('should return valid for long password', 0, () => {
        const result = validatePassword('abcdefghijklmnop')
        expect(result.valid).assertTrue()
      })

      it('should return invalid for empty password', 0, () => {
        const result = validatePassword('')
        expect(result.valid).assertFalse()
        expect(result.message).assertEqual('请输入密码')
      })

      it('should return invalid for password shorter than 6 characters', 0, () => {
        const result = validatePassword('12345')
        expect(result.valid).assertFalse()
        expect(result.message).assertContain('密码长度不能少于6位')
      })

      it('should return invalid for 5-character password', 0, () => {
        const result = validatePassword('abcde')
        expect(result.valid).assertFalse()
      })

      it('should accept exactly 6-character password', 0, () => {
        const result = validatePassword('abcdef')
        expect(result.valid).assertTrue()
      })
    })

    // ============================================================
    // validateConfirmPassword
    // ============================================================
    describe('validateConfirmPassword', () => {
      it('should return valid when passwords match', 0, () => {
        const result = validateConfirmPassword('123456', '123456')
        expect(result.valid).assertTrue()
        expect(result.message).assertEqual('')
      })

      it('should return invalid when passwords do not match', 0, () => {
        const result = validateConfirmPassword('123456', '654321')
        expect(result.valid).assertFalse()
        expect(result.message).assertEqual('两次输入的密码不一致')
      })

      it('should return invalid when confirm password is empty', 0, () => {
        const result = validateConfirmPassword('123456', '')
        expect(result.valid).assertFalse()
        expect(result.message).assertEqual('请再次输入密码')
      })

      it('should return invalid when original password is shorter and mismatch', 0, () => {
        const result = validateConfirmPassword('abc', 'abcd')
        expect(result.valid).assertFalse()
      })

      it('should return valid when both are empty', 0, () => {
        const result = validateConfirmPassword('', '')
        expect(result.valid).assertTrue()
      })
    })

    // ============================================================
    // validateLoginForm
    // ============================================================
    describe('validateLoginForm', () => {
      it('should return all valid for correct phone and password', 0, () => {
        const result = validateLoginForm('13812345678', '123456')
        expect(result.allValid).assertTrue()
        expect(result.phoneError).assertEqual('')
        expect(result.passwordError).assertEqual('')
      })

      it('should return phone error when phone is invalid', 0, () => {
        const result = validateLoginForm('123', '123456')
        expect(result.allValid).assertFalse()
        expect(result.phoneError).assertContain('手机号')
      })

      it('should return password error when password is too short', 0, () => {
        const result = validateLoginForm('13812345678', '12')
        expect(result.allValid).assertFalse()
        expect(result.passwordError).assertContain('密码长度不能少于6位')
      })

      it('should return both errors when both are invalid', 0, () => {
        const result = validateLoginForm('', '')
        expect(result.allValid).assertFalse()
        expect(result.phoneError).assertContain('手机号')
        expect(result.passwordError).assertContain('密码')
      })
    })

    // ============================================================
    // validateRegisterForm
    // ============================================================
    describe('validateRegisterForm', () => {
      it('should return all valid for correct inputs', 0, () => {
        const result = validateRegisterForm('13812345678', '123456', '123456')
        expect(result.allValid).assertTrue()
        expect(result.phoneError).assertEqual('')
        expect(result.passwordError).assertEqual('')
        expect(result.confirmError).assertEqual('')
      })

      it('should return confirm error when passwords mismatch', 0, () => {
        const result = validateRegisterForm('13812345678', '123456', '654321')
        expect(result.allValid).assertFalse()
        expect(result.confirmError).assertEqual('两次输入的密码不一致')
      })

      it('should return multiple errors for multiple invalid fields', 0, () => {
        const result = validateRegisterForm('', '12', '')
        expect(result.allValid).assertFalse()
        expect(result.phoneError).assertContain('手机号')
        expect(result.passwordError).assertContain('密码长度不能少于6位')
        expect(result.confirmError).assertContain('请再次输入密码')
      })

      it('should return confirm error when confirm is empty', 0, () => {
        const result = validateRegisterForm('13812345678', '123456', '')
        expect(result.allValid).assertFalse()
        expect(result.confirmError).assertEqual('请再次输入密码')
      })
    })
  })
}
