package com.fittracker.app.notifications

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.fittracker.app.R

/**
 * 训练 / 成就提醒的本地通知封装（计划《设置模块功能实现》A6 · Wave 4）。
 *
 * 职责边界：**只负责「渠道 + 构造 + 投递」**，不含业务判定（是否该提醒由
 * [WorkoutReminderWorker] / 设置屏决定）。渠道为**惰性创建**——发通知前 [ensureChannel]
 * 一次，幂等：渠道已存在时直接返回既有实例，不覆盖用户对渠道的个性化设置
 *（重复 `createNotificationChannel` 同 id 亦为幂等，但读取既有实例可避免无谓写）。
 *
 * 通知小图标取项目已有 drawable [R.drawable.ic_launcher_foreground]（`app/src/main/res/drawable/`
 * 实存，无需回落 `android.R.drawable.ic_dialog_info`）；系统对小图标按 alpha 通道着色，
 * 故品牌色图形在状态栏呈现为单色剪影。
 */
object ReminderNotifications {

    /** 通知渠道 id（计划 A6 指定）。 */
    const val CHANNEL_ID: String = "fittracker_reminders"

    /** 渠道名（系统设置里对用户可见；计划 A6 指定）。 */
    const val CHANNEL_NAME: String = "训练提醒"

    /** 渠道说明（Android 8+ 渠道详情页展示）。 */
    const val CHANNEL_DESCRIPTION: String = "训练与成就提醒"

    /** 训练提醒通知 id（同一 id 重复投递为覆盖，不堆叠）。 */
    const val WORKOUT_NOTIFICATION_ID: Int = 4101

    /** 成就提醒通知 id。 */
    const val ACHIEVEMENT_NOTIFICATION_ID: Int = 4102

    /** 训练提醒标题。 */
    const val WORKOUT_TITLE: String = "该训练了"

    /** 训练提醒正文。 */
    const val WORKOUT_TEXT: String = "今天还没有训练记录，练一组吧。"

    /** 成就提醒标题。 */
    const val ACHIEVEMENT_TITLE: String = "连续训练达成"

    /** 成就提醒正文——里程碑天数由调用方传入。 */
    fun achievementText(streakDays: Int): String = "已连续训练 $streakDays 天，继续保持！"

    /**
     * 惰性 ensure 通知渠道（幂等）。Android 8.0 以下无渠道概念，返回 `null`。
     * 系统服务不可用时同样返回 `null`（投递侧会静默失败，不抛异常）。
     */
    fun ensureChannel(context: Context): NotificationChannel? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return null
        }
        val manager: NotificationManager =
            context.getSystemService(NotificationManager::class.java) ?: return null
        manager.getNotificationChannel(CHANNEL_ID)?.let { return it }
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply { description = CHANNEL_DESCRIPTION }
        manager.createNotificationChannel(channel)
        return channel
    }

    /** 训练提醒：今天还没有训练记录时提醒去练（判定见 [WorkoutReminderWorker]）。 */
    fun notifyWorkoutReminder(context: Context) {
        post(context, WORKOUT_NOTIFICATION_ID, WORKOUT_TITLE, WORKOUT_TEXT)
    }

    /** 成就提醒：连续训练天数命中里程碑时即时提醒。 */
    fun notifyAchievement(context: Context, streakDays: Int) {
        post(context, ACHIEVEMENT_NOTIFICATION_ID, ACHIEVEMENT_TITLE, achievementText(streakDays))
    }

    /**
     * 是否允许投递：渠道/应用通知总开关未关 **且** 通知权限已授予
     *（Android 13+ 为运行时权限；`minSdk 24` 下的低版本恒真）。
     */
    fun canPost(context: Context): Boolean =
        NotificationManagerCompat.from(context).areNotificationsEnabled() &&
            (
                Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                    ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
                    PackageManager.PERMISSION_GRANTED
                )

    /**
     * 构造并投递。投递前的权限 / 开关守卫见 [canPost]——lint 无法跨函数追踪该守卫，
     * 故在此显式声明 [SuppressLint]（权限确实已在本函数入口校验）。
     * 投递异常（系统服务缺失等）一律吞掉：提醒失败不得影响训练主流程。
     */
    @SuppressLint("MissingPermission")
    private fun post(context: Context, id: Int, title: String, text: String) {
        if (!canPost(context)) {
            return
        }
        ensureChannel(context)
        val notification: android.app.Notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(id, notification)
        } catch (error: Exception) {
            // 系统服务缺失 / 投递被拒：静默，不向上抛。
        }
    }
}
