/**
 * ValidationUtils — 表单校验纯函数
 * 所有函数为纯函数，无 UI 依赖，可直接单元测试。
 */

const PHONE_REGEX = /^1[3-9]\d{9}$/
const MIN_PASSWORD_LENGTH = 6

export interface ValidationResult {
  valid: boolean
  message: string
}

/**
 * 校验手机号格式（中国大陆手机号）
 * @returns { valid: false, message } 或 { valid: true, message: '' }
 */
export function validatePhone(phone: string): ValidationResult {
  if (!phone || phone.trim().length === 0) {
    return { valid: false, message: '请输入手机号' }
  }
  if (!PHONE_REGEX.test(phone.trim())) {
    return { valid: false, message: '请输入正确的手机号格式' }
  }
  return { valid: true, message: '' }
}

/**
 * 校验密码长度（≥6 位）
 */
export function validatePassword(password: string): ValidationResult {
  if (!password) {
    return { valid: false, message: '请输入密码' }
  }
  if (password.length < MIN_PASSWORD_LENGTH) {
    return { valid: false, message: `密码长度不能少于${MIN_PASSWORD_LENGTH}位` }
  }
  return { valid: true, message: '' }
}

/**
 * 校验两次密码是否一致
 */
export function validateConfirmPassword(password: string, confirmPassword: string): ValidationResult {
  if (!confirmPassword) {
    return { valid: false, message: '请再次输入密码' }
  }
  if (password !== confirmPassword) {
    return { valid: false, message: '两次输入的密码不一致' }
  }
  return { valid: true, message: '' }
}

/**
 * 一次性校验登录字段（手机号 + 密码）
 */
export function validateLoginForm(
  phone: string,
  password: string
): { phoneError: string; passwordError: string; allValid: boolean } {
  const phoneResult = validatePhone(phone)
  const passwordResult = validatePassword(password)

  return {
    phoneError: phoneResult.valid ? '' : phoneResult.message,
    passwordError: passwordResult.valid ? '' : passwordResult.message,
    allValid: phoneResult.valid && passwordResult.valid
  }
}

/**
 * 一次性校验所有注册字段，返回所有错误信息
 */
export function validateRegisterForm(
  phone: string,
  password: string,
  confirmPassword: string
): { phoneError: string; passwordError: string; confirmError: string; allValid: boolean } {
  const phoneResult = validatePhone(phone)
  const passwordResult = validatePassword(password)
  const confirmResult = validateConfirmPassword(password, confirmPassword)

  return {
    phoneError: phoneResult.valid ? '' : phoneResult.message,
    passwordError: passwordResult.valid ? '' : passwordResult.message,
    confirmError: confirmResult.valid ? '' : confirmResult.message,
    allValid: phoneResult.valid && passwordResult.valid && confirmResult.valid
  }
}
