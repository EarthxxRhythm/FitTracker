/**
 * AppNotificationService — 应用内通知的渠道 / 授权 / 投递封装。
 *
 * 职责边界：只负责「渠道 + 授权 + 构造 + 投递」，不含业务判定（是否该提醒由
 * WorkoutReminderService 决定），语义对齐 Android ReminderNotifications。
 * 渠道为惰性创建（幂等）：投递前 ensureSlot 一次，已存在时不重复写入。
 * 投递全链静默——提醒失败不得影响训练主流程。
 *
 * 常量与 Android 侧保持一致：训练提醒 id=4101、成就提醒 id=4102。
 */
import { notificationManager } from '@kit.NotificationKit'
import { Context, common } from '@kit.AbilityKit'

/** 训练提醒通知 id（同一 id 重复投递为覆盖，不堆叠）。 */
const WORKOUT_NOTIFICATION_ID: number = 4101

/** 成就提醒通知 id。 */
const ACHIEVEMENT_NOTIFICATION_ID: number = 4102

/** 训练提醒标题。 */
const WORKOUT_TITLE: string = '该训练了'

/** 训练提醒正文。 */
const WORKOUT_TEXT: string = '今天还没有训练记录，练一组吧。'

/** 成就提醒标题。 */
const ACHIEVEMENT_TITLE: string = '连续训练达成'

class AppNotificationService {
  /**
   * 请求通知授权（弹出系统授权对话框）。
   * SDK 签名要求 UIAbilityContext（通知对话框需绑定能力上下文），故此处收窄转换；
   * 成功返回 true，用户拒绝或调用失败返回 false，不抛出。
   */
  async requestEnable(context: Context): Promise<boolean> {
    try {
      await notificationManager.requestEnableNotification(context as common.UIAbilityContext)
      return true
    } catch (error) {
      return false
    }
  }

  /** 应用通知总开关是否允许投递（失败按不允许处理）。 */
  async canPublish(context: Context): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled()
    } catch (error) {
      return false
    }
  }

  /** 惰性 ensure 通知渠道（幂等）；渠道已存在或系统不可用时静默。 */
  async ensureSlot(): Promise<void> {
    try {
      await notificationManager.addSlot(notificationManager.SlotType.SERVICE_INFORMATION)
    } catch (error) {
      // 渠道已存在 / 系统服务不可用：静默，投递侧会按需再试。
    }
  }

  /** 训练提醒：今天还没有训练记录时提醒去练（判定见 WorkoutReminderService）。 */
  async publishWorkoutReminder(context: Context): Promise<void> {
    await this.publish(context, WORKOUT_NOTIFICATION_ID, WORKOUT_TITLE, WORKOUT_TEXT)
  }

  /** 成就提醒：连续训练天数命中里程碑时即时提醒。 */
  async publishAchievement(context: Context, streakDays: number): Promise<void> {
    await this.publish(context, ACHIEVEMENT_NOTIFICATION_ID, ACHIEVEMENT_TITLE,
      '已连续训练 ' + streakDays.toString() + ' 天，继续保持！')
  }

  /**
   * 构造并投递。投递前先校验通知总开关；全链 try-catch 静默（系统服务缺失 / 投递被拒
   * 一律吞掉），不向上抛。
   */
  private async publish(context: Context, id: number, title: string, text: string): Promise<void> {
    try {
      const allowed: boolean = await this.canPublish(context)
      if (!allowed) {
        return
      }
      await this.ensureSlot()
      const request: notificationManager.NotificationRequest = {
        id: id,
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text
          }
        }
      }
      await notificationManager.publish(request)
    } catch (error) {
      // 系统服务缺失 / 投递被拒：静默，不向上抛。
    }
  }
}

export default new AppNotificationService()
