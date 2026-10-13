/**
 * AchievementNoticeService — 成就提醒服务。
 *
 * 训练完成（会话落库）后由完成页调用：设置页「成就提醒」开关开 且 连续训练天数命中
 * 里程碑（3/7/14/30）→ 发一条成就通知。开关默认 false（不过则直接返回）。
 * 判定拆为两个纯函数（achievementMilestone / computeStreak）供单测；
 * checkAndNotify 为编排入口，任何失败静默——通知不得阻塞训练记录流程。
 * 依赖：WorkoutSessionService（训练日期集合）、SettingsService（开关）、
 * AppNotificationService（通知投递）。
 */
import SettingsService, { AppSettings } from './SettingsService'
import WorkoutSessionService from './WorkoutSessionService'
import AppNotificationService from './AppNotificationService'

/** 连续训练里程碑：命中 3/7/14/30 天返回该天数，其余返回 null。 */
export function achievementMilestone(streakDays: number): number | null {
  if (streakDays === 3 || streakDays === 7 || streakDays === 14 || streakDays === 30) {
    return streakDays
  }
  return null
}

/**
 * 从训练日期集合（`YYYY-MM-DD`，任意序）计算截至 today（`YYYY-MM-DD`）的连续训练天数。
 * 锚点：今天有训练 → 从今天数；否则昨天有 → 从昨天数（宽限一天）；否则 0。
 * 空数组 → 0；日期不可解析 → 0。
 */
export function computeStreak(dates: string[], today: string): number {
  if (dates.length === 0) {
    return 0
  }
  const dateSet: Set<string> = new Set<string>()
  for (const date of dates) {
    dateSet.add(date)
  }
  const anchor: Date | null = parseYmd(today)
  if (anchor === null) {
    return 0
  }
  let cursor: Date = anchor
  if (!dateSet.has(formatDate(cursor))) {
    // 今天未训练 → 从昨天起算（宽限一天）
    cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() - 1)
    if (!dateSet.has(formatDate(cursor))) {
      return 0
    }
  }
  let count: number = 0
  while (dateSet.has(formatDate(cursor))) {
    count++
    cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() - 1)
  }
  return count
}

/** `YYYY-MM-DD` → 本地时区 Date（与 formatDate 对称）；不可解析返回 null。 */
function parseYmd(value: string): Date | null {
  try {
    const parts: string[] = value.split('-')
    if (parts.length !== 3) {
      return null
    }
    const year: number = Number.parseInt(parts[0], 10)
    const month: number = Number.parseInt(parts[1], 10)
    const day: number = Number.parseInt(parts[2], 10)
    if (Number.isNaN(year) || Number.isNaN(month) || Number.isNaN(day)) {
      return null
    }
    return new Date(year, month - 1, day)
  } catch (error) {
    return null
  }
}

/** 两位补零。 */
function padTwoDigits(value: number): string {
  if (value < 10) {
    return '0' + value.toString()
  }
  return value.toString()
}

/** Date → `YYYY-MM-DD`（本地时区）。 */
function formatDate(date: Date): string {
  return date.getFullYear().toString() + '-' + padTwoDigits(date.getMonth() + 1) + '-' +
    padTwoDigits(date.getDate())
}

class AchievementNoticeService {
  /**
   * 训练完成（会话已落库）后调用：开关开 + 命中里程碑 → 发成就通知。全静默。
   */
  async checkAndNotify(context: Context): Promise<void> {
    try {
      const settings: AppSettings = await SettingsService.loadSettings(context)
      if (!settings.achievement) {
        return
      }
      const dates: string[] = await WorkoutSessionService.getTrainingDates(context)
      const today: string = formatDate(new Date())
      const milestone: number | null = achievementMilestone(computeStreak(dates, today))
      if (milestone === null) {
        return
      }
      await AppNotificationService.publishAchievement(context, milestone)
    } catch (error) {
      // 静默：通知失败不影响训练记录流程
    }
  }
}

export default new AchievementNoticeService()
