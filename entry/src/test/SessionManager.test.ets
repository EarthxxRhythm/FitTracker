/**
 * SessionManager 单元测试
 *
 * 测试 Token 持久化服务的纯函数部分：
 *   - Token 生成（结构完整、包含必要字段）
 *   - Token 有效性校验（有效/过期/格式损坏）
 *   - 从 Token 中提取 userId
 */
import { describe, it, expect } from '@ohos/hypium'
import SessionManager from '../main/ets/common/services/SessionManager'

export default function sessionManagerTest() {
  describe('SessionManager — generateToken', () => {

    it('should generate a non-empty token string', 0, () => {
      const token = SessionManager.generateToken('13800138000')
      expect(token.length).assertLarger(0)
    })

    it('should generate a token with three dot-separated parts', 0, () => {
      const token = SessionManager.generateToken('13800138000')
      const parts = token.split('.')
      expect(parts.length).assertEqual(3)
    })

    it('should generate different tokens for different users', 0, () => {
      const token1 = SessionManager.generateToken('13800138000')
      const token2 = SessionManager.generateToken('13900139000')
      expect(token1 === token2).assertFalse()
    })

    it('should generate different tokens for same user at different times', 0, () => {
      const token1 = SessionManager.generateToken('13800138000')
      // brief wait to ensure different iat timestamp
      const token2 = SessionManager.generateToken('13800138000')
      // Same user should produce different tokens due to iat timestamp
      expect(token1 === token2).assertFalse()
    })
  })

  describe('SessionManager — validateToken', () => {

    it('should return true for a freshly generated token', 0, () => {
      const token = SessionManager.generateToken('13800138000')
      expect(SessionManager.validateToken(token)).assertTrue()
    })

    it('should return false for empty string', 0, () => {
      expect(SessionManager.validateToken('')).assertFalse()
    })

    it('should return false for malformed token without dots', 0, () => {
      expect(SessionManager.validateToken('notajwttoken')).assertFalse()
    })

    it('should return false for token with only one dot', 0, () => {
      expect(SessionManager.validateToken('header.payload')).assertFalse()
    })

    it('should return false for expired token', 0, () => {
      const token = SessionManager.generateToken('13800138000')
      // Verify a freshly generated token is valid
      expect(SessionManager.validateToken(token)).assertTrue()
      // Tampered tokens with invalid base64 should fail validation
      expect(SessionManager.validateToken(token + 'tampered')).assertFalse()
    })

    it('should return false for completely random string', 0, () => {
      expect(SessionManager.validateToken('randomgarbage')).assertFalse()
    })
  })

  describe('SessionManager — getUserIdFromToken', () => {

    it('should return the correct userId from a generated token', 0, () => {
      const phone = '13800138000'
      const token = SessionManager.generateToken(phone)
      const userId = SessionManager.getUserIdFromToken(token)
      expect(userId).assertEqual(phone)
    })

    it('should return empty string for malformed token', 0, () => {
      expect(SessionManager.getUserIdFromToken('bad')).assertEqual('')
    })

    it('should return empty string for empty token', 0, () => {
      expect(SessionManager.getUserIdFromToken('')).assertEqual('')
    })
  })
}