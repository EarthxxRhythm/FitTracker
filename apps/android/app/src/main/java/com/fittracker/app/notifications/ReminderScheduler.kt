package com.fittracker.app.notifications

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.SettingsService
import java.util.Calendar
import java.util.TimeZone
import java.util.concurrent.TimeUnit

/**
 * 训练提醒的调度登记（计划 A6 · Wave 4）。
 *
 * 唯一周期任务 [WORK_NAME]（24h 周期，首延至**下一个 19:30**）；关闭开关即取消。
 * 开 / 关都走 [syncWorkoutReminder]，故「设置屏 toggle」与「`MainActivity.onCreate` 幂等 ensure」
 * 是同一条路径——升级 / 清数据后调度丢失时，冷启动即恢复。
 *
 * 关于真实执行时刻（计划 A6 已如实标注）：WorkManager 的周期任务受系统批量调度（Doze / 省电
 * 策略）影响，实际可能晚数分钟至数小时；19:30 是**期望时刻**而非承诺时刻。
 *
 * [ExistingPeriodicWorkPolicy.UPDATE] 的语义：同名任务不存在 → 按新请求入队；已存在 → 就地更新
 * 规格（保留 next 计划时刻，不会重置周期相位）。因此它适合"配置变更 / 冷启动 ensure"，
 * 而不会因每次冷启动而无限推后首次执行。
 */
object ReminderScheduler {

    /** 唯一任务名——[WorkManager.cancelUniqueWork] 与 [WorkManager.enqueueUniquePeriodicWork] 共用。 */
    const val WORK_NAME: String = "workout_reminder"

    /** 期望提醒小时（设计假设：产品后续可配；见计划 A6）。 */
    const val REMINDER_HOUR: Int = 19

    /** 期望提醒分钟（同上）。 */
    const val REMINDER_MINUTE: Int = 30

    /** 周期 24 小时。 */
    const val REPEAT_INTERVAL_HOURS: Long = 24L

    /**
     * 开关同步：`enabled=true` → 登记（或就地更新）唯一周期任务；`false` → 取消。
     * 不做 IO / 网络，可在 `onCreate` 等主线程时机直接调用。
     */
    fun syncWorkoutReminder(context: Context, enabled: Boolean) {
        val workManager: WorkManager = WorkManager.getInstance(context)
        if (!enabled) {
            workManager.cancelUniqueWork(WORK_NAME)
            return
        }
        val request = PeriodicWorkRequestBuilder<WorkoutReminderWorker>(
            REPEAT_INTERVAL_HOURS,
            TimeUnit.HOURS,
        )
            .setInitialDelay(initialDelayMillis(), TimeUnit.MILLISECONDS)
            .build()
        workManager.enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.UPDATE, request)
    }

    /**
     * 读设置后同步（幂等 ensure，供 `MainActivity.onCreate` 调用，覆盖升级 / 清数据场景）。
     * 仅读本地偏好 + 登记调度，无网络 / 重活。
     */
    suspend fun syncFromSettings(context: Context) {
        val store = JsonStore(context.appDataStore)
        syncWorkoutReminder(context, SettingsService.loadSettings(store).workoutReminder)
    }

    /**
     * 距**下一个** 19:30 的毫秒数（纯函数，供单测）：
     * 今日 19:30 尚未到（含恰好等于）→ 今日；已过 → 次日。
     */
    fun initialDelayMillis(
        now: Long = System.currentTimeMillis(),
        timeZone: TimeZone = TimeZone.getDefault(),
    ): Long {
        val next: Calendar = Calendar.getInstance(timeZone).apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, REMINDER_HOUR)
            set(Calendar.MINUTE, REMINDER_MINUTE)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (next.timeInMillis <= now) {
            next.add(Calendar.DAY_OF_YEAR, 1)
        }
        return next.timeInMillis - now
    }
}
