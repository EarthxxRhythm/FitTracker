package com.fittracker.app.data.service

import com.fittracker.app.data.model.WorkoutSession
import java.util.Calendar

/**
 * 训练会话服务——移植自鸿蒙 `common/services/WorkoutSessionService.ets` 的**统计/查询面**
 * （周统计 `:232` / 动作纪录 `:260` / 训练日期 `:298`）。
 *
 * **模型统一（与源的刻意差异，2026-10-03 整合决策）**：源在 common/services 侧使用 legacy
 * `SessionRecord`（按动作嵌套 `SavedSet`），shared/models 侧是新 `WorkoutSession`（扁平 `sets`）
 * ——两套由 `WorkoutSessionPersistenceBridgeService` 互转。Android 按迁移计划「不移植兼容层、
 * 统一新模型」的决策：本服务直接消费 `model.WorkoutSession`；集合 CRUD 由 [WorkoutRepository]
 * 承担（单一持久化路径，共用 [com.fittracker.app.data.persist.StoreNames.SESSIONS] 键，
 * `List<WorkoutSession>` JSON）。原 legacy 版的集合操作（saveSession/updateSession/removeSession/
 * restoreSession/replaceSessions，源 `:109-157`）因此删除——其语义已由 [WorkoutRepository] 覆盖，
 * 唯一口径差异 `removeSession` 首部 vs 尾部按 Repository 的「尾部」统一（源两处本就不同）。
 *
 * 口径对照：
 * - 日期基准：源的 `createdAt`（`YYYY-MM-DD` 字符串）↔ model 的 `startedAt`（epoch ms）
 *   经 [formatDate] 归一，周窗口的字符串含端点比较保持不变；
 * - 1RM：源 `Math.round(weight × (1 + reps / 30))` 整数口径，保持不变
 *   （与 `estimateOneRepMax` 的两位小数口径不同——源即如此）。
 */

/** 周统计聚合（源 `:232` 返回结构）。 */
data class WeeklyStats(val count: Int, val duration: Int, val sets: Int, val volume: Double)

/** 单动作最佳纪录（源 `:260`）。 */
data class ExerciseRecord(
    val exerciseName: String,
    val best1RM: Int,
    val bestWeight: Double,
    val bestReps: Int,
    val bestDate: String,
)

object WorkoutSessionService {

    /** 鸿蒙源库名（源 `:96`）——安卓侧折叠为整块 JSON @ [com.fittracker.app.data.persist.StoreNames.SESSIONS]，仅作对照。 */
    const val STORE_NAME: String = "fit_tracker_sessions"

    /** 鸿蒙源键名（源 `:97`）——同上，仅作对照。 */
    const val KEY_SESSIONS: String = "sessions"

    // --- 统计 / 纪录 / 训练日期 ---------------------------------------------

    /**
     * 源 `:232` `getWeeklyStats`——本**设置周**（周首 00:00 ~ 周首 + 6 日 23:59:59）内会话的
     * 次数 / 总时长（秒） / 有效组数 / 总容量聚合。
     *
     * 口径（逐条对齐源 `:234-257`）：
     * - 周窗口按 `formatDate(startedAt)`（`YYYY-MM-DD`）**含端点**字符串比较；周首日由 [weekStart]
     *   决定（周一态：周一 ~ 周日；周日态：周日 ~ 周六）——周首偏移一律经 [WeekWindow] 计算，
     *   不再硬编码周一（A5「周开始日」接线，2026-10 波次）；
     * - `duration` = Σ `durationSeconds`；`sets` = Σ [completedWorkingSetCount]（非热身且 weight>0 且 reps>0）；
     * - `volume` = Σ [sessionVolume]（**非热身**组的 weight×reps）。
     *
     * @param nowMillis 「现在」的时间戳——**显式传入、不设默认值**：漏传即编译期暴露，
     *   防「周窗口按系统当前时间算」这类静默漂移。
     * @param weekStart 周首日设置（周一 / 周日）。
     */
    fun weeklyStats(
        sessions: List<WorkoutSession>,
        nowMillis: Long,
        weekStart: WeekStart,
    ): WeeklyStats {
        // :235 源 `now.getDay()`（0=周日…6=周六）→ [WeekWindow] 统一偏移口径（周一态周日偏移 6、周日态 0）
        val weekOffset: Int = WeekWindow.offsetFromWeekStart(jsDayOfWeek(nowMillis), weekStart)

        val weekStartAtMidnight: Calendar = Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_MONTH, -weekOffset)
        }
        val weekStartStr: String = formatDate(weekStartAtMidnight.timeInMillis) // :239

        val weekEnd: Calendar = Calendar.getInstance().apply {
            timeInMillis = weekStartAtMidnight.timeInMillis
            add(Calendar.DAY_OF_MONTH, 6) // :241 源 `周首 + 6 * 24h`
        }
        val weekEndStr: String = formatDate(weekEnd.timeInMillis) // :242

        var count: Int = 0
        var duration: Int = 0
        var sets: Int = 0
        var volume: Double = 0.0

        for (session in sessions) { // :248-256
            val dateStr: String = formatDate(session.startedAt)
            if (dateStr >= weekStartStr && dateStr <= weekEndStr) {
                count++
                duration += session.durationSeconds
                sets += completedWorkingSetCount(session) // :252
                volume += sessionVolume(session) // :253
            }
        }

        return WeeklyStats(count = count, duration = duration, sets = sets, volume = volume)
    }

    /**
     * 源 `:260` `getAllExerciseRecords`——全历史扫描，按**动作名**取 Epley 1RM 最大的一组。
     *
     * 口径（对齐源 `:264-288`）：跳过热身组、`weight<=0` 或 `reps<=0` 的组；
     * `1RM = round(weight × (1 + reps / 30))`（**整数**，源用 `Math.round`）。返回顺序 = 首次出现顺序。
     *
     * model 版按 `exerciseId` 聚合，组名经 [nameOf] 解析（缺省查 [ContentRepository]，
     * 未命中回落 id 原文——源的分组键即动作名，此处保持结果形状不变）。
     */
    fun exerciseRecords(
        sessions: List<WorkoutSession>,
        nameOf: (String) -> String = { id -> ContentRepository.getExercise(id)?.nameZh ?: id },
    ): List<ExerciseRecord> {
        val recordMap: LinkedHashMap<String, ExerciseRecord> = LinkedHashMap() // :262 源 `Map`（保插入序）

        for (session in sessions) { // :264-289
            for (set in session.sets) {
                if (set.isWarmup || set.weight <= 0.0 || set.reps <= 0) {
                    continue
                }
                // Epley：1RM = weight * (1 + reps / 30)
                val oneRM: Int = Math.round(set.weight * (1 + set.reps / 30.0)).toInt()
                val name: String = nameOf(set.exerciseId)
                val existing: ExerciseRecord? = recordMap[name]

                if (existing == null || oneRM > existing.best1RM) {
                    recordMap[name] = ExerciseRecord(
                        exerciseName = name,
                        best1RM = oneRM,
                        bestWeight = set.weight,
                        bestReps = set.reps,
                        bestDate = formatDate(session.startedAt),
                    )
                }
            }
        }

        return recordMap.values.toList()
    }

    /** 源 `:298` `getTrainingDates`——去重后的训练日期集合（`YYYY-MM-DD`，保首次出现序）。 */
    fun trainingDates(sessions: List<WorkoutSession>): List<String> {
        val dateSet: LinkedHashSet<String> = LinkedHashSet() // :300 源 `Set`（保插入序）
        for (session in sessions) { // :301-303
            dateSet.add(formatDate(session.startedAt))
        }
        return dateSet.toList() // :305-308
    }

    // --- 内部：统计辅助 -----------------------------------------------------

    /** 源 `:311` `getCompletedWorkingSetCount`——非热身且 `weight>0` 且 `reps>0` 的组计数。 */
    private fun completedWorkingSetCount(session: WorkoutSession): Int {
        var count = 0
        for (set in session.sets) { // :312-320
            if (!set.isWarmup && set.weight > 0.0 && set.reps > 0) {
                count++
            }
        }
        return count
    }

    /** 源 `:323` `getSessionVolume`——非热身组的 `weight × reps` 之和。 */
    private fun sessionVolume(session: WorkoutSession): Double {
        var volume = 0.0
        for (set in session.sets) { // :324-332
            if (!set.isWarmup) {
                volume += set.weight * set.reps
            }
        }
        return volume
    }

    /**
     * 时间戳 → `YYYY-MM-DD`（本地时区）。口径与鸿蒙持久化桥
     * `WorkoutSessionPersistenceBridgeService.formatDate` 一致——用于周窗口边界与日期归一。
     */
    fun formatDate(millis: Long): String {
        val calendar: Calendar = Calendar.getInstance()
        calendar.timeInMillis = millis
        return "${calendar.get(Calendar.YEAR)}-${padTwoDigits(calendar.get(Calendar.MONTH) + 1)}-" +
            padTwoDigits(calendar.get(Calendar.DAY_OF_MONTH))
    }

    /** 当前星期（JS `Date.getDay()` 口径：0=周日…6=周六）。 */
    private fun jsDayOfWeek(millis: Long): Int {
        val calendar: Calendar = Calendar.getInstance()
        calendar.timeInMillis = millis
        return calendar.get(Calendar.DAY_OF_WEEK) - 1 // Calendar 周日=1 → 0=周日
    }

    /** 源占位对象 `padTwoDigits`（桥内）——两位补零。 */
    private fun padTwoDigits(value: Int): String = if (value < 10) "0$value" else value.toString()
}
