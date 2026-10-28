package com.fittracker.app.data.service

import com.fittracker.app.data.model.WorkoutSession

/** 单个训练日的完成情况。 */
data class PlanDayProgress(
    val dayId: String,
    val sessionCount: Int,
    val totalDurationSeconds: Int,
    /** 最近一次练该训练日的时间戳（毫秒）；0 表示尚未练过。 */
    val lastTrainedAt: Long,
)

/** 一个计划下的聚合进度。 */
data class PlanProgressSummary(
    val planId: String,
    /** 该计划下的训练总次数。 */
    val totalSessions: Int,
    val totalDurationSeconds: Int,
    /** 最近一次训练时间戳（毫秒）；0 表示尚未训练。 */
    val lastTrainedAt: Long,
    /** 已练过的训练日 id（去重，顺序按首次出现）。 */
    val trainedDayIds: List<String>,
    /** 每个训练日的完成情况（仅含有会话的训练日）。 */
    val dayProgress: List<PlanDayProgress>,
)

/**
 * 按计划聚合训练会话的派生服务（对齐鸿蒙 `PlanProgressService.ets`）。
 *
 * 背景：[WorkoutSession] 一直带 `planId` / `dayId` 并正确落库，但此前没有任何读取方
 * 按计划聚合，导致「计划组」看不到进度、回顾也不感知计划归属。
 *
 * 纯函数、无 IO：调用方自己加载 `List<WorkoutSession>` 再传入，便于单测。
 */
object PlanProgressService {

    /** 空进度：`planId` 保留传入值，其余归零。 */
    fun createEmpty(planId: String): PlanProgressSummary = PlanProgressSummary(
        planId = planId,
        totalSessions = 0,
        totalDurationSeconds = 0,
        lastTrainedAt = 0L,
        trainedDayIds = emptyList(),
        dayProgress = emptyList(),
    )

    /**
     * 聚合指定计划的进度。
     *
     * 只统计 `session.planId == planId` 的会话；`planId` 为空时返回空进度，
     * 避免把「未归属计划」的历史会话错误算到某个计划上。
     */
    fun createSummary(sessions: List<WorkoutSession>, planId: String): PlanProgressSummary {
        val ids = if (planId.isEmpty()) emptyList() else listOf(planId)
        return createSummaryForIds(sessions, planId, ids)
    }

    /**
     * 按「一组等价计划 id」聚合。
     *
     * 为什么需要：启用计划走 `enablePlan` 时 `UserPlan.id` 是 `user_plan_<时间戳>`，
     * 而计划组详情拿到的是**预置 id**（`preset_ppl` 等）；会话里落库的 `planId` 又是
     * `UserPlan.id`。两者不相等，只比单个 id 会让聚合全部落空。
     * 调用方把预置 id 与当前 `UserPlan.id` 一起传入即可覆盖两种历史数据。
     */
    fun createSummaryForIds(
        sessions: List<WorkoutSession>,
        planId: String,
        planIds: List<String>,
    ): PlanProgressSummary {
        if (planIds.isEmpty() || sessions.isEmpty()) {
            return createEmpty(planId)
        }
        val matched = sessions.filter { planIds.contains(it.planId) }
        if (matched.isEmpty()) {
            return createEmpty(planId)
        }

        val dayMap = LinkedHashMap<String, PlanDayProgress>()
        for (session in matched) {
            if (session.dayId.isEmpty()) continue
            val existing = dayMap[session.dayId]
            dayMap[session.dayId] = if (existing == null) {
                PlanDayProgress(
                    dayId = session.dayId,
                    sessionCount = 1,
                    totalDurationSeconds = session.durationSeconds,
                    lastTrainedAt = session.endedAt,
                )
            } else {
                existing.copy(
                    sessionCount = existing.sessionCount + 1,
                    totalDurationSeconds = existing.totalDurationSeconds + session.durationSeconds,
                    lastTrainedAt = maxOf(existing.lastTrainedAt, session.endedAt),
                )
            }
        }

        return PlanProgressSummary(
            planId = planId,
            totalSessions = matched.size,
            totalDurationSeconds = matched.sumOf { it.durationSeconds },
            lastTrainedAt = matched.maxOf { it.endedAt },
            trainedDayIds = dayMap.keys.toList(),
            dayProgress = dayMap.values.toList(),
        )
    }

    /** 判断某训练日是否已完成过（供计划组详情的「每周节奏」标记）。 */
    fun isDayTrained(summary: PlanProgressSummary, dayId: String): Boolean =
        dayId.isNotEmpty() && summary.trainedDayIds.contains(dayId)

    /** 某训练日的完成次数；未练过返回 0（供训练日面板显示「已练 N 次」）。 */
    fun sessionCountForDay(summary: PlanProgressSummary, dayId: String): Int =
        if (dayId.isEmpty()) 0 else summary.dayProgress.firstOrNull { it.dayId == dayId }?.sessionCount ?: 0
}
