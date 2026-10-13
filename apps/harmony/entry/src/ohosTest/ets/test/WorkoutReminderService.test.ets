/**
 * WorkoutReminderService unit test
 * 只覆盖纯函数（不触达 preferences / reminderAgentManager）：
 *  - shouldRemind：开关 × 今日会话 × 训练日（含 null）全组合矩阵；
 *  - nextReminderTime：今天未到 / 已过 / 恰好 19:30:00.000 / remindToday=false / 跨月 / 跨年。
 * 语义蓝本：Android workoutReminderDecision 与 ReminderScheduler.initialDelayMillis。
 */
import { describe, it, expect } from '@ohos/hypium'
import { shouldRemind, nextReminderTime, ReminderTimePoint } from '../../../main/ets/common/services/WorkoutReminderService'

const REMINDER_HOUR: number = 19
const REMINDER_MINUTE: number = 30

export default function workoutReminderServiceTest(): void {
  describe('WorkoutReminderService', () => {
    it('suppresses reminder when the toggle is off', 0, () => {
      expect(shouldRemind(false, false, true)).assertFalse()
      expect(shouldRemind(false, false, null)).assertFalse()
      expect(shouldRemind(false, true, false)).assertFalse()
    })

    it('suppresses reminder when a session already exists today', 0, () => {
      expect(shouldRemind(true, true, true)).assertFalse()
      expect(shouldRemind(true, true, false)).assertFalse()
      expect(shouldRemind(true, true, null)).assertFalse()
    })

    it('suppresses on rest day, fires on training day and when no plan exists', 0, () => {
      expect(shouldRemind(true, false, false)).assertFalse()
      expect(shouldRemind(true, false, true)).assertTrue()
      expect(shouldRemind(true, false, null)).assertTrue()
    })

    it('schedules today when now is strictly before 19:30', 0, () => {
      const now: Date = new Date(2026, 9, 13, 18, 0)
      const point: ReminderTimePoint = nextReminderTime(now, true)
      expect(point.year).assertEqual(2026)
      expect(point.month).assertEqual(10)
      expect(point.day).assertEqual(13)
      expect(point.hour).assertEqual(REMINDER_HOUR)
      expect(point.minute).assertEqual(REMINDER_MINUTE)
    })

    it('rolls to tomorrow when now is past 19:30', 0, () => {
      const now: Date = new Date(2026, 9, 13, 20, 0)
      const point: ReminderTimePoint = nextReminderTime(now, true)
      expect(point.year).assertEqual(2026)
      expect(point.month).assertEqual(10)
      expect(point.day).assertEqual(14)
      expect(point.hour).assertEqual(REMINDER_HOUR)
      expect(point.minute).assertEqual(REMINDER_MINUTE)
    })

    it('rolls to tomorrow when now is exactly 19:30:00.000', 0, () => {
      const now: Date = new Date(2026, 9, 13, REMINDER_HOUR, REMINDER_MINUTE, 0, 0)
      const point: ReminderTimePoint = nextReminderTime(now, true)
      expect(point.year).assertEqual(2026)
      expect(point.month).assertEqual(10)
      expect(point.day).assertEqual(14)
      expect(point.hour).assertEqual(REMINDER_HOUR)
      expect(point.minute).assertEqual(REMINDER_MINUTE)
    })

    it('rolls to tomorrow when remindToday is false even before 19:30', 0, () => {
      const now: Date = new Date(2026, 9, 13, 18, 0)
      const point: ReminderTimePoint = nextReminderTime(now, false)
      expect(point.year).assertEqual(2026)
      expect(point.month).assertEqual(10)
      expect(point.day).assertEqual(14)
      expect(point.hour).assertEqual(REMINDER_HOUR)
      expect(point.minute).assertEqual(REMINDER_MINUTE)
    })

    it('rolls across a month boundary', 0, () => {
      const now: Date = new Date(2026, 9, 31, 20, 0)
      const point: ReminderTimePoint = nextReminderTime(now, true)
      expect(point.year).assertEqual(2026)
      expect(point.month).assertEqual(11)
      expect(point.day).assertEqual(1)
      expect(point.hour).assertEqual(REMINDER_HOUR)
      expect(point.minute).assertEqual(REMINDER_MINUTE)
    })

    it('rolls across a year boundary', 0, () => {
      const now: Date = new Date(2026, 11, 31, 20, 0)
      const point: ReminderTimePoint = nextReminderTime(now, true)
      expect(point.year).assertEqual(2027)
      expect(point.month).assertEqual(1)
      expect(point.day).assertEqual(1)
      expect(point.hour).assertEqual(REMINDER_HOUR)
      expect(point.minute).assertEqual(REMINDER_MINUTE)
    })
  })
}
