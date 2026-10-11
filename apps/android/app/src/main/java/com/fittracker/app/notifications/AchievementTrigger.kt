package com.fittracker.app.notifications

import android.content.Context
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.WorkoutRepository
import com.fittracker.app.data.service.WorkoutSessionService
import java.util.Calendar

/**
 * 成就提醒触发（计划 A6 第 5 条）——训练完成保存后调用：
 * 开关开 且 连续训练天数命中里程碑（3/7/14/30）→ 发一条成就通知。
 *
 * 判定拆为两个纯函数（[achievementMilestone] / [currentStreak]）供单测；
 * [checkAndNotifyAchievement] 为编排入口，任何失败静默（通知不得阻塞训练流程）。
 */

/** 连续训练里程碑：命中 3/7/14/30 天返回该天数，其余返回 null。 */
fun achievementMilestone(streakDays: Int): Int? = when (streakDays) {
    3, 7, 14, 30 -> streakDays
    else -> null
}

/**
 * 从训练日期集合（`YYYY-MM-DD`，任意序）计算截至 [today]（`YYYY-MM-DD`）的连续训练天数。
 * 锚点：今天有训练 → 从今天数；否则昨天有 → 从昨天数（宽限一天）；否则 0。
 */
fun currentStreak(dates: List<String>, today: String): Int {
    if (dates.isEmpty()) return 0
    val set = dates.toSet()
    val todayMillis = parseYmd(today) ?: return 0
    val cursor: Calendar = Calendar.getInstance().apply { timeInMillis = todayMillis }
    if (WorkoutSessionService.formatDate(cursor.timeInMillis) !in set) {
        cursor.add(Calendar.DAY_OF_MONTH, -1) // 今天未训练 → 从昨天起算（宽限一天）
        if (WorkoutSessionService.formatDate(cursor.timeInMillis) !in set) return 0
    }
    var count = 0
    while (WorkoutSessionService.formatDate(cursor.timeInMillis) in set) {
        count++
        cursor.add(Calendar.DAY_OF_MONTH, -1)
    }
    return count
}

/** 训练完成（会话已落库）后调用：开关开 + 命中里程碑 → 发成就通知。全静默。 */
suspend fun checkAndNotifyAchievement(store: JsonStore, context: Context) {
    try {
        if (!SettingsService.loadSettings(store).achievementReminder) return
        val today = WorkoutSessionService.formatDate(System.currentTimeMillis())
        val streak = currentStreak(
            WorkoutSessionService.trainingDates(WorkoutRepository.getSessions(store)),
            today,
        )
        val milestone = achievementMilestone(streak) ?: return
        ReminderNotifications.notifyAchievement(context, milestone)
    } catch (_: Exception) {
        // 静默：通知失败不影响训练记录流程
    }
}

/** `YYYY-MM-DD` → epoch millis（本地时区，与 [WorkoutSessionService.formatDate] 对称）。 */
private fun parseYmd(value: String): Long? = try {
    val parts = value.split("-")
    Calendar.getInstance().apply {
        clear()
        set(parts[0].toInt(), parts[1].toInt() - 1, parts[2].toInt())
    }.timeInMillis
} catch (_: Exception) {
    null
}
