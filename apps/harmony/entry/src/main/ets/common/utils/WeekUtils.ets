/**
 * WeekUtils — 周起点计算的纯函数工具。
 *
 * 项目内全部周聚合（首页周进度、回顾周趋势/周柱状/日历、个人页周区间）统一走这里；
 * 周开始日由设置页「周开始日」驱动（SettingsService.weekStart，'monday' | 'sunday'）。
 */

export type WeekStart = 'monday' | 'sunday'

/**
 * 求 value 所在周的起始日 0 点（本地时区）。
 * 'monday'：周一为起点（历史/默认行为）；'sunday'：周日为起点。
 */
export function resolveWeekStart(value: Date, weekStart: WeekStart): Date {
  const dayOfWeek: number = value.getDay() // 0=周日 … 6=周六
  const offset: number = weekStart === 'sunday'
    ? dayOfWeek
    : (dayOfWeek === 0 ? 6 : dayOfWeek - 1)
  return new Date(value.getFullYear(), value.getMonth(), value.getDate() - offset)
}
