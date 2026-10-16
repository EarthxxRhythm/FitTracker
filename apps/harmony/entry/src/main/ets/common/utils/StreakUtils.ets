/**
 * StreakUtils —— 训练连续记录与本周打卡派生（纯函数）。
 *
 * 原本内联在 `WorkoutCompletePage`（完成页）与 `ProfileContent`（个人页）各一份，
 * 其中个人页那份是写死的假数据。此处收敛为单一真实现，两处共用，避免同仓库
 * 「同一指标一份真一份假」。
 *
 * 日期口径：[trainingDates] 为 `YYYY-MM-DD` 字符串集合（与
 * `WorkoutSessionService.getTrainingDates` 产出一致），本地时区。
 */

/** 两位数补零。 */
export function padTwoDigits(value: number): string {
  if (value < 10) {
    return '0' + value.toString()
  }
  return value.toString()
}

/** 本地日期 → `YYYY-MM-DD`。 */
export function formatDateKey(date: Date): string {
  return date.getFullYear().toString() + '-' + padTwoDigits(date.getMonth() + 1) + '-' +
    padTwoDigits(date.getDate())
}

/**
 * 连续训练天数：从今天（或昨天，若今天尚未训练）向前逐日回溯计数。
 * 空输入返回 0。
 */
export function computeStreakCount(trainingDates: string[]): number {
  const dateSet: Set<string> = new Set<string>()
  trainingDates.forEach((date: string) => {
    dateSet.add(date)
  })
  let cursor: Date = new Date()
  if (!dateSet.has(formatDateKey(cursor))) {
    cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() - 1)
  }
  let count: number = 0
  while (dateSet.has(formatDateKey(cursor))) {
    count++
    cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() - 1)
  }
  return count
}

/**
 * 本周（周一→周日）打卡标记，长度恒 7。
 *
 * 注意：此处固定以**周一**为一周起点（与完成页原型一致）。个人页的打卡格若需
 * 跟随「设置 · 周开始日」，由调用方自行重排（见 ProfileContent）。
 */
export function computeWeekActiveFlags(trainingDates: string[]): boolean[] {
  const dateSet: Set<string> = new Set<string>()
  trainingDates.forEach((date: string) => {
    dateSet.add(date)
  })
  const today: Date = new Date()
  const dayOfWeek: number = today.getDay()
  const mondayOffset: number = dayOfWeek === 0 ? 6 : dayOfWeek - 1
  const monday: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - mondayOffset)
  const flags: boolean[] = []
  for (let index = 0; index < 7; index++) {
    const day: Date = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + index)
    flags.push(dateSet.has(formatDateKey(day)))
  }
  return flags
}

/**
 * 本周（周首由 [weekStart] 决定）打卡标记，长度恒 7——个人页的打卡格用此版以跟随设置。
 */
export function computeWeekActiveFlagsFrom(weekStart: string, trainingDates: string[]): boolean[] {
  const dateSet: Set<string> = new Set<string>()
  trainingDates.forEach((date: string) => {
    dateSet.add(date)
  })
  const today: Date = new Date()
  const base: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate())
  if (weekStart === 'sunday') {
    const sundayOffset: number = base.getDay()
    const sunday: Date = new Date(base.getFullYear(), base.getMonth(), base.getDate() - sundayOffset)
    const flags: boolean[] = []
    for (let index = 0; index < 7; index++) {
      const day: Date = new Date(sunday.getFullYear(), sunday.getMonth(), sunday.getDate() + index)
      flags.push(dateSet.has(formatDateKey(day)))
    }
    return flags
  }
  return computeWeekActiveFlags(trainingDates)
}
