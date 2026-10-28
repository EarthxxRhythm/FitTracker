/**
 * AvatarTint —— 头像色键配色与昵称首字（个人页 `ProfileContent` 与编辑页 `ProfileEditContent` 共用）。
 *
 * 色键写入 `UserProfile.avatar`；空串或未知键回落默认翡翠，与安卓 `avatarTintOf` 同口径。
 */
import { PrototypeTokens } from '../../../common/styles/PrototypeTokens'

export interface AvatarTint {
  fill: string
  text: string
  border: string
}

/** 头像色键顺序：首项空串 = 默认翡翠（与 `UserProfile.avatar` 空值同义）。 */
export const AVATAR_KEYS: string[] = ['', 'gold', 'sky', 'rose', 'violet', 'amber']

/** 色键 → 头像配色；未知键回落默认翡翠（同安卓 `avatarTintOf`）。 */
export function avatarTintOf(key: string): AvatarTint {
  if (key === 'gold') {
    return { fill: '#1AD3B487', text: '#D3B487', border: '#4DD3B487' }
  }
  if (key === 'sky') {
    return { fill: '#1A5AC8FA', text: '#8CD1FF', border: '#4D5AC8FA' }
  }
  if (key === 'rose') {
    return { fill: '#1AFF8A9B', text: '#FF9FB0', border: '#4DFF8A9B' }
  }
  if (key === 'violet') {
    return { fill: '#1AA78BFA', text: '#C4B5FD', border: '#4DA78BFA' }
  }
  if (key === 'amber') {
    return { fill: '#1AFFC46B', text: '#FFD08A', border: '#4DFFC46B' }
  }
  return { fill: PrototypeTokens.ACCENT_A10, text: PrototypeTokens.ACCENT, border: PrototypeTokens.ACCENT_A30 }
}

/** 头像首字：昵称去空格后的首个字符；空昵称回落「—」（与个人页占位一致）。 */
export function avatarInitialOf(nickname: string): string {
  const trimmed: string = nickname.trim()
  return trimmed.length === 0 ? '—' : trimmed.charAt(0)
}
