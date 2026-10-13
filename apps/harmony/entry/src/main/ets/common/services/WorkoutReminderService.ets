/**
 * WorkoutReminderService — 训练提醒的调度登记与降级校准。
 *
 * 语义对齐 Android ReminderScheduler / WorkoutReminderWorker（同一判定函数 + 同一 19:30 期望时刻）。
 * 平台差异：Android 由 WorkManager 以 24h 周期任务在后台「每日现读设置与数据」判定；鸿蒙无同等
 * 的后台周期判定通道，改为「代理提醒固定时刻 + 应用活跃期校准」——
 *   1) 登记每日 19:30 的日历代理提醒（由系统在固定时刻拉起），关闭开关即全部取消；
 *   2) 在冷启动 / 训练完成等活跃时机按同一判定函数重排：今天已训练 → 顺延到明天 19:30；
 *   3) 代理提醒需要受限权限 PUBLISH_AGENT_REMINDER（未申请时 publishReminder 失败），
 *      失败自动降级为应用内通知通道（calibrateOnActive 在活跃期补发当日的提醒）。
 * 与 Android 的一致性：19:30 是「期望时刻」而非承诺时刻；所有失败路径静默，不阻断训练主流程。
 *
 * 存储：fit_tracker_reminder（Preferences），键 last_notified_date / degraded。
 */
import { preferences } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Context } from '@kit.AbilityKit'
import { reminderAgentManager } from '@kit.BackgroundTasksKit'
import { notificationManager } from '@kit.NotificationKit'
import SettingsService, { AppSettings } from './SettingsService'
import WorkoutSessionService from './WorkoutSessionService'
import TrainingPlanService, { UserPlan } from './TrainingPlanService'
import AppNotificationService from './AppNotificationService'

const DOMAIN: number = 0x0000
const TAG: string = 'WorkoutReminder'
/** 期望提醒小时（对齐 Android ReminderScheduler.REMINDER_HOUR）。 */
const REMINDER_HOUR: number = 19
/** 期望提醒分钟（对齐 Android ReminderScheduler.REMINDER_MINUTE）。 */
const REMINDER_MINUTE: number = 30
const STORE_NAME: string = 'fit_tracker_reminder'
const KEY_LAST_NOTIFIED_DATE: string = 'last_notified_date'
const KEY_DEGRADED: string = 'degraded'
const REMINDER_TITLE: string = '该训练了'
const REMINDER_CONTENT: string = '今天还没有训练记录，练一组吧。'
const REMINDER_NOTIFICATION_ID: number = 4101
/** 真实包名（以 apps/harmony/AppScope/app.json5 为准）。 */
const BUNDLE_NAME: string = 'com.earthrhythm.fittracker'
const ENTRY_ABILITY_NAME: string = 'EntryAbility'
const EMPTY_DATE: string = ''
/** 每周七天全部命中 —— 等价于「每日重复」。 */
const DAILY_WEEKDAYS: number[] = [1, 2, 3, 4, 5, 6, 7]

/** 下一次提醒时刻（月份 1-12）。 */
export interface ReminderTimePoint {
  year: number
  month: number
  day: number
  hour: number
  minute: number
}

/**
 * 训练提醒判定函数（对齐 Android workoutReminderDecision，逐条对应）：
 * - 开关关 → 不发；
 * - 今天已有训练会话 → 不发；
 * - 有当前计划且今天非训练日（休息日）→ 不发；
 * - 无当前计划（isTrainingDay 为 null）→ 不受「训练日」约束，照发。
 */
export function shouldRemind(enabled: boolean, hasSessionToday: boolean, isTrainingDay: boolean | null): boolean {
  if (!enabled) {
    return false
  }
  if (hasSessionToday) {
    return false
  }
  if (isTrainingDay === null) {
    return true
  }
  return isTrainingDay
}

/**
 * 距下一个 19:30 的时刻（纯函数，供单测）：
 * remindToday 且 now 严格早于今天 19:30:00.000 → 今天；否则（含 now 恰好等于/晚于 19:30、
 * 或 remindToday=false）→ 明天（对齐 Android `next <= now → +1 天` 语义）。
 */
export function nextReminderTime(now: Date, remindToday: boolean): ReminderTimePoint {
  const todayAt: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate(),
    REMINDER_HOUR, REMINDER_MINUTE, 0, 0)
  if (remindToday && now.getTime() < todayAt.getTime()) {
    return {
      year: todayAt.getFullYear(),
      month: todayAt.getMonth() + 1,
      day: todayAt.getDate(),
      hour: REMINDER_HOUR,
      minute: REMINDER_MINUTE
    }
  }
  const tomorrowAt: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1,
    REMINDER_HOUR, REMINDER_MINUTE, 0, 0)
  return {
    year: tomorrowAt.getFullYear(),
    month: tomorrowAt.getMonth() + 1,
    day: tomorrowAt.getDate(),
    hour: REMINDER_HOUR,
    minute: REMINDER_MINUTE
  }
}

class WorkoutReminderService {
  /**
   * 读设置后同步代理提醒登记（幂等，供冷启动 / 设置 toggle 调用）：
   * 关 → 取消全部提醒；开 → 按当日判定重排下一次 19:30，并登记每日重复的日历代理提醒。
   * 失败写 degraded=true 并 hilog.error，不抛出。
   */
  async syncFromSettings(context: Context): Promise<void> {
    try {
      const settings: AppSettings = await SettingsService.loadSettings(context)
      if (!settings.reminder) {
        await this.cancelAllReminders()
        return
      }
      const dates: string[] = await WorkoutSessionService.getTrainingDates(context)
      const today: string = this.formatDate(new Date())
      const hasSessionToday: boolean = dates.includes(today)
      const plan: UserPlan | null = await TrainingPlanService.getCurrentPlan(context)
      const isTrainingDay: boolean | null = plan === null ? null : TrainingPlanService.isTrainingDay(plan)
      const remindToday: boolean = shouldRemind(true, hasSessionToday, isTrainingDay)
      const point: ReminderTimePoint = nextReminderTime(new Date(), remindToday)
      const reminder: reminderAgentManager.ReminderRequestCalendar = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
        dateTime: {
          year: point.year,
          month: point.month,
          day: point.day,
          hour: REMINDER_HOUR,
          minute: REMINDER_MINUTE
        },
        daysOfWeek: DAILY_WEEKDAYS,
        title: REMINDER_TITLE,
        content: REMINDER_CONTENT,
        notificationId: REMINDER_NOTIFICATION_ID,
        slotType: notificationManager.SlotType.SERVICE_INFORMATION,
        wantAgent: {
          pkgName: BUNDLE_NAME,
          abilityName: ENTRY_ABILITY_NAME
        }
      }
      try {
        // 先清旧（同名 notificationId 覆盖 + 换日重排都靠这一步保持幂等）。
        await reminderAgentManager.cancelAllReminders()
        await reminderAgentManager.publishReminder(reminder)
        await this.writeDegraded(context, false)
      } catch (error) {
        // 代理提醒失败（含未授权 PUBLISH_AGENT_REMINDER）→ 标记降级，交由应用内通道兜底。
        await this.writeDegraded(context, true)
        hilog.error(DOMAIN, TAG, 'publishReminder failed, degrade to in-app channel')
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'syncFromSettings failed')
    }
  }

  /**
   * 冷启动组合入口：先按设置重排代理提醒，再执行降级校准。各自内部 try-catch，整体不抛。
   */
  async calibrateFromLaunch(context: Context): Promise<void> {
    await this.syncFromSettings(context)
    await this.calibrateOnActive(context)
  }

  /**
   * 训练完成后调用：开关开 → 复用 syncFromSettings（内部已含「今天已训练 → 顺延明天」语义），
   * 再执行降级校准；开关关 → 直接返回。不抛。
   */
  async onSessionSaved(context: Context): Promise<void> {
    try {
      const settings: AppSettings = await SettingsService.loadSettings(context)
      if (!settings.reminder) {
        return
      }
      await this.syncFromSettings(context)
      await this.calibrateOnActive(context)
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'onSessionSaved failed')
    }
  }

  /**
   * 降级通道（代理提醒失败时的应用内补发）：
   * 开关关 → 返回；degraded 非 true → 返回（代理提醒正常时不打扰）；
   * 今天已训练 → 返回；当前时间已过 19:30 且当日未补发过 → 发应用内通知并记录日期。
   * 全链 try-catch 静默。
   */
  async calibrateOnActive(context: Context): Promise<void> {
    try {
      const settings: AppSettings = await SettingsService.loadSettings(context)
      if (!settings.reminder) {
        return
      }
      const degraded: boolean = await this.readDegraded(context)
      if (!degraded) {
        return
      }
      const now: Date = new Date()
      const today: string = this.formatDate(now)
      const dates: string[] = await WorkoutSessionService.getTrainingDates(context)
      if (dates.includes(today)) {
        return
      }
      if (!this.isAtOrAfterReminderTime(now)) {
        return
      }
      const lastNotified: string = await this.readLastNotifiedDate(context)
      if (lastNotified === today) {
        return
      }
      await AppNotificationService.publishWorkoutReminder(context)
      await this.writeLastNotifiedDate(context, today)
    } catch (error) {
      // 降级通道失败不阻断主流程。
    }
  }

  /** 取消全部代理提醒（静默）。 */
  private async cancelAllReminders(): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders()
    } catch (error) {
      // 无登记或系统不可用：静默。
    }
  }

  /** 当前时刻是否已到（或已过）今天的 19:30。 */
  private isAtOrAfterReminderTime(now: Date): boolean {
    const at: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate(),
      REMINDER_HOUR, REMINDER_MINUTE, 0, 0)
    return now.getTime() >= at.getTime()
  }

  /** 'YYYY-MM-DD'（本地时区），与 WorkoutSessionService 的 createdAt 口径一致。 */
  private formatDate(date: Date): string {
    return date.getFullYear().toString() + '-' + this.padTwoDigits(date.getMonth() + 1) + '-' +
      this.padTwoDigits(date.getDate())
  }

  private padTwoDigits(value: number): string {
    if (value < 10) {
      return '0' + value.toString()
    }
    return value.toString()
  }

  /** 读降级标记（缺省 / 读取失败按 false = 代理提醒正常）。 */
  private async readDegraded(context: Context): Promise<boolean> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      return await prefs.get(KEY_DEGRADED, false) as boolean
    } catch (error) {
      return false
    }
  }

  /** 写降级标记（失败静默）。 */
  private async writeDegraded(context: Context, degraded: boolean): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_DEGRADED, degraded)
      await prefs.flush()
    } catch (error) {
      // 持久化失败：不影响调度结果。
    }
  }

  /** 读最近一次应用内补发日期（缺省 / 读取失败为空串）。 */
  private async readLastNotifiedDate(context: Context): Promise<string> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      return await prefs.get(KEY_LAST_NOTIFIED_DATE, EMPTY_DATE) as string
    } catch (error) {
      return EMPTY_DATE
    }
  }

  /** 写最近一次应用内补发日期（失败静默）。 */
  private async writeLastNotifiedDate(context: Context, date: string): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, STORE_NAME)
      await prefs.put(KEY_LAST_NOTIFIED_DATE, date)
      await prefs.flush()
    } catch (error) {
      // 持久化失败：至多导致同日重复补发一次，不抛出。
    }
  }
}

export default new WorkoutReminderService()
