package com.fittracker.app.data.service.stats

import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.model.estimateOneRepMax
import kotlin.math.roundToInt

/**
 * 训练回顾计算——逐函数移植自鸿蒙 `shared/services/ReviewService.ets`。
 *
 * 纯函数、无状态单例；供 `ReviewDashboardService`（回顾面板）与
 * `WorkoutSummaryService`（训练摘要）复用，是完成率/训练量统一口径的唯一来源。
 */
object ReviewService {

    /**
     * 训练量 = **非热身组** `weight * reps` 求和（源 `ReviewService.ets:9` `calculateVolume`）。
     *
     * 热身组（`isWarmup`）整组排除。
     */
    fun calculateVolume(sets: List<WorkoutSet>): Double {
        var volume = 0.0
        for (set in sets) {
            if (!set.isWarmup) {
                volume += set.weight * set.reps
            }
        }
        return volume
    }

    /**
     * 最佳估算 1RM——非热身组取最大值，保持 `estimateOneRepMax` 的**两位小数**口径
     * （源 `ReviewService.ets:20` `calculateBestEstimatedOneRepMax`）。
     *
     * 公式不在此重写，复用 `TrainingModels.kt` 的唯一实现点 `estimateOneRepMax`。
     * 消费点如需整数显示由调用方决定（对比 `PersonalRecordService` 的取整口径）。
     */
    fun calculateBestEstimatedOneRepMax(sets: List<WorkoutSet>): Double {
        var bestEstimatedOneRepMax = 0.0
        for (set in sets) {
            if (!set.isWarmup) {
                val estimatedOneRepMax = estimateOneRepMax(set.weight, set.reps)
                if (estimatedOneRepMax > bestEstimatedOneRepMax) {
                    bestEstimatedOneRepMax = estimatedOneRepMax
                }
            }
        }
        return bestEstimatedOneRepMax
    }

    /**
     * 完成率 = `round(completed * 100 / planned)`，取整到 0..100；`planned <= 0` 时归零
     * （源 `ReviewService.ets:34` `calculateCompletionRate`）。
     *
     * 注意必须用浮点除法（`* 100.0`）；JS `Math.round` 与 Kotlin `roundToInt`
     * 对正数同为「四舍五入、.5 向 +∞」。
     */
    fun calculateCompletionRate(completedExercises: Int, plannedExercises: Int): Int {
        if (plannedExercises <= 0) {
            return 0
        }
        return ((completedExercises * 100.0) / plannedExercises).roundToInt()
    }
}
