package com.fittracker.app.notifications

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.TrainingPlanRepository
import com.fittracker.app.data.service.WorkoutRepository
import com.fittracker.app.data.service.WorkoutSessionService

/**
 * 训练提醒的判定函数（计划 A6 · Wave 4，D-5 同族的新增设计定义）。
 *
 * 语义（与 [WorkoutReminderWorker.doWork] 逐条对应，抽出以便 JVM 单测穷举）：
 * - 开关关 → 不发；
 * - 今天已有训练会话（按本地日期）→ 不发；
 * - 有当前计划且今天非训练日（休息日）→ 不发；
 * - 无当前计划（[isTrainingDay] 为 `null`）→ 不受"训练日"约束，照发。
 *
 * @param enabled 设置里的「训练提醒」开关（`FtSettings.workoutReminder`）
 * @param hasSessionToday 今天是否已有训练会话（本地日期 `YYYY-MM-DD` 比对）
 * @param isTrainingDay 今天是否训练日；`null` 表示没有当前计划（无从判定）
 */
fun workoutReminderDecision(
    enabled: Boolean,
    hasSessionToday: Boolean,
    isTrainingDay: Boolean?,
): Boolean = enabled && !hasSessionToday && (isTrainingDay == null || isTrainingDay)

/**
 * 每日训练提醒 Worker（计划 A6 · Wave 4，`CoroutineWorker`）。
 *
 * 由 [ReminderScheduler] 以 24h 周期唯一任务登记（首延至下一个 19:30）。每次执行**现读**设置与
 * 会话/计划库——开关或数据变化在下一次执行即生效，无需重新调度。
 *
 * 判定不变量：所有"不提醒"的分支都返回 [Result.success]（本 Worker 没有"失败"语义，
 * 只有"今天不发"）；仅当读库抛异常时返回 [Result.retry]（周期任务按退避重试，成功即恢复
 * 下一个周期，不会永久停止）。
 */
class WorkoutReminderWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result = try {
        val store = JsonStore(applicationContext.appDataStore)
        val today: String = WorkoutSessionService.formatDate(System.currentTimeMillis())

        val hasSessionToday: Boolean = WorkoutRepository.getSessions(store)
            .any { WorkoutSessionService.formatDate(it.startedAt) == today }

        // 无当前计划 → 无从判定训练日，传 null（判定函数按"不受约束"处理）
        val isTrainingDay: Boolean? = TrainingPlanRepository.getCurrentPlan(store)
            ?.let { TrainingPlanRepository.isTrainingDay(it) }

        val enabled: Boolean = SettingsService.loadSettings(store).workoutReminder
        if (workoutReminderDecision(enabled, hasSessionToday, isTrainingDay)) {
            ReminderNotifications.notifyWorkoutReminder(applicationContext)
        }
        Result.success()
    } catch (error: Exception) {
        Result.retry()
    }
}
