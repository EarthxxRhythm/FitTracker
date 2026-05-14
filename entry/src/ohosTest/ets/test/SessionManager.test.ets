/**
 * SessionManager 单元测试
 * 覆盖 token 生成、校验、过期判断、用户ID提取
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import sessionManager from '../../../main/ets/common/services/SessionManager'

export default function sessionManagerTest(): void {
  describe('SessionManager', () => {
    beforeAll(() => {
    })

    afterAll(() => {
    })

    // ============================================================
    // generateToken
    // ============================================================
    describe('generateToken', () => {
      it('should generate a non-empty token', 0, () => {
        const token = sessionManager.generateToken('13812345678')
        expect(token.length).assertLarger(0)
      })

      it('should produce a JWT-like three-part token', 0, () => {
        const token = sessionManager.generateToken('13812345678')
        const parts = token.split('.')
        expect(parts.length).assertEqual(3)
      })

      it('should generate different tokens for different users', 0, () => {
        const token1 = sessionManager.generateToken('13811111111')
        const token2 = sessionManager.generateToken('13822222222')
        expect(token1).assertNotEqual(token2)
      })

      it('should generate fresh token each call for same user', 0, () => {
        const token1 = sessionManager.generateToken('13812345678')
        const token2 = sessionManager.generateToken('13812345678')
        expect(token1).assertNotEqual(token2)
      })
    })

    // ============================================================
    // validateToken
    // ============================================================
    describe('validateToken', () => {
      it('should return true for a freshly generated token', 0, () => {
        const token = sessionManager.generateToken('13812345678')
        expect(sessionManager.validateToken(token)).assertTrue()
      })

      it('should return false for an empty string', 0, () => {
        expect(sessionManager.validateToken('')).assertFalse()
      })

      it('should return false for a malformed token (no dots)', 0, () => {
        expect(sessionManager.validateToken('not-a-valid-token')).assertFalse()
      })

      it('should return false for a token with only one dot', 0, () => {
        expect(sessionManager.validateToken('header.payload')).assertFalse()
      })

      it('should return false for null-like string', 0, () => {
        expect(sessionManager.validateToken('null.null.null')).assertFalse()
      })

      it('should return false for garbled base64', 0, () => {
        expect(sessionManager.validateToken('!!!.@@@.###')).assertFalse()
      })
    })

    // ============================================================
    // getUserIdFromToken
    // ============================================================
    describe('getUserIdFromToken', () => {
      it('should extract phone number from valid token', 0, () => {
        const token = sessionManager.generateToken('13898765432')
        const userId = sessionManager.getUserIdFromToken(token)
        expect(userId).assertEqual('13898765432')
      })

      it('should return empty string for invalid token', 0, () => {
        expect(sessionManager.getUserIdFromToken('invalid')).assertEqual('')
      })

      it('should return empty string for empty token', 0, () => {
        expect(sessionManager.getUserIdFromToken('')).assertEqual('')
      })
    })
  })
}
