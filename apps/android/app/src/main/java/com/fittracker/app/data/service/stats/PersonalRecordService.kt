package com.fittracker.app.data.service.stats

import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.model.estimateOneRepMax
import com.fittracker.app.data.service.ContentRepository
import java.util.Calendar
import kotlin.math.roundToInt

/** 单动作用户纪录（源 `PersonalRecordService.ets:9` `ExercisePersonalRecord`）。 */
data class ExercisePersonalRecord(
    var exerciseId: String = "",
    var exerciseName: String = "",
    var bestOneRepMax: Int = 0,
    var bestWeight: Double = 0.0,
    var bestReps: Int = 0,
    var bestDateText: String = "",
)

/** 单动作纪录明细（源 `PersonalRecordService.ets:18` `ExercisePersonalRecordDetail`）。 */
data class ExercisePersonalRecordDetail(
    var exerciseId: String = "",
    var exerciseName: String = "",
    var bestOneRepMax: Int = 0,
    var bestWeight: Double = 0.0,
    var bestReps: Int = 0,
    var bestDateText: String = "",
    var lastPerformedAt: Long = 0,
    var lastPerformedDateText: String = "",
    var sessionCount: Int = 0,
    var performedSetCount: Int = 0,
    var recentOneRepMax: Int = 0,
    var recentWeight: Double = 0.0,
    var recentReps: Int = 0,
    var recentVolume: Double = 0.0,
    var trendText: String = "",
)

/**
 * 动作个人纪录——逐函数移植自鸿蒙 `shared/services/PersonalRecordService.ets`。
 *
 * Feature #25：历史最佳 1RM / 最佳重量 / 最佳次数 + 最近表现趋势。
 *
 * 1RM 消费点口径：源 `Math.round(estimateOneRepMax(...))` **对 1RM 取整**
 * （`updateRecord` `:98`、`updateRecordDetail` `:161`）——因此本服务字段用 `Int`，
 * 与 `ReviewService`（保留两位小数）不同；公式本身仍复用 `estimateOneRepMax`。
 */
object PersonalRecordService {

    /**
     * 动作名反查插槽——默认接 `ContentRepository.getExercise(id)?.nameZh`；
     * 回落 `null` 时用 `exerciseId`（源 `getExerciseById` 未命中分支）。测试可注入。
     */
    var exerciseNameResolver: (String) -> String? = { id -> ContentRepository.getExercise(id)?.nameZh }

    /** 源 `createRecords`（`PersonalRecordService.ets:37`）。按动作首次出现顺序返回纪录。 */
    fun createRecords(sessions: List<WorkoutSession>): List<ExercisePersonalRecord> {
        val records = ArrayList<ExercisePersonalRecord>()
        for (session in sessions) {
            for (set in session.sets) {
                if (!isRecordableSet(set)) {
                    continue
                }
                val record = findOrCreateRecord(records, set.exerciseId)
                updateRecord(record, session, set)
            }
        }
        return records
    }

    /** 源 `createRecordDetails`（`:53`）。含 sessionCount / 最近表现，最后按 1RM 降序排序。 */
    fun createRecordDetails(sessions: List<WorkoutSession>): List<ExercisePersonalRecordDetail> {
        val details = ArrayList<ExercisePersonalRecordDetail>()
        for (session in sessions) {
            val countedExerciseIds = ArrayList<String>()
            for (set in session.sets) {
                if (!isRecordableSet(set)) {
                    continue
                }
                val detail = findOrCreateRecordDetail(details, set.exerciseId)
                if (set.exerciseId !in countedExerciseIds) {
                    countedExerciseIds.add(set.exerciseId)
                    detail.sessionCount += 1
                }
                detail.performedSetCount += 1
                updateRecordDetail(detail, session, set)
            }
        }
        sortRecordDetails(details)
        return details
    }

    /** 源 `createEmptyRecordDetail`（`:76`）。 */
    fun createEmptyRecordDetail(): ExercisePersonalRecordDetail = ExercisePersonalRecordDetail(
        exerciseId = "",
        exerciseName = "",
        bestOneRepMax = 0,
        bestWeight = 0.0,
        bestReps = 0,
        bestDateText = "",
        lastPerformedAt = 0,
        lastPerformedDateText = "",
        sessionCount = 0,
        performedSetCount = 0,
        recentOneRepMax = 0,
        recentWeight = 0.0,
        recentReps = 0,
        recentVolume = 0.0,
        trendText = "完成训练后，这里会显示动作纪录变化。",
    )

    /** 源 `updateRecord`（`:97`）。 */
    private fun updateRecord(record: ExercisePersonalRecord, session: WorkoutSession, set: WorkoutSet) {
        val oneRepMax = estimateOneRepMax(set.weight, set.reps).roundToInt()
        if (oneRepMax > record.bestOneRepMax) {
            record.bestOneRepMax = oneRepMax
            record.bestDateText = formatDate(session.startedAt)
        } else if (oneRepMax == record.bestOneRepMax && record.bestDateText.isEmpty()) {
            record.bestDateText = formatDate(session.startedAt)
        }
        if (set.weight > record.bestWeight) {
            record.bestWeight = set.weight
        }
        if (set.reps > record.bestReps) {
            record.bestReps = set.reps
        }
    }

    /** 源 `findOrCreateRecord`（`:113`）。 */
    private fun findOrCreateRecord(
        records: MutableList<ExercisePersonalRecord>,
        exerciseId: String,
    ): ExercisePersonalRecord {
        for (record in records) {
            if (record.exerciseId == exerciseId) {
                return record
            }
        }
        val record = ExercisePersonalRecord(
            exerciseId = exerciseId,
            exerciseName = getExerciseName(exerciseId),
            bestOneRepMax = 0,
            bestWeight = 0.0,
            bestReps = 0,
            bestDateText = "",
        )
        records.add(record)
        return record
    }

    /** 源 `findOrCreateRecordDetail`（`:132`）。 */
    private fun findOrCreateRecordDetail(
        details: MutableList<ExercisePersonalRecordDetail>,
        exerciseId: String,
    ): ExercisePersonalRecordDetail {
        for (detail in details) {
            if (detail.exerciseId == exerciseId) {
                return detail
            }
        }
        val detail = ExercisePersonalRecordDetail(
            exerciseId = exerciseId,
            exerciseName = getExerciseName(exerciseId),
        )
        details.add(detail)
        return detail
    }

    /** 源 `updateRecordDetail`（`:160`）。 */
    private fun updateRecordDetail(
        detail: ExercisePersonalRecordDetail,
        session: WorkoutSession,
        set: WorkoutSet,
    ) {
        val oneRepMax = estimateOneRepMax(set.weight, set.reps).roundToInt()
        if (oneRepMax > detail.bestOneRepMax) {
            detail.bestOneRepMax = oneRepMax
            detail.bestDateText = formatDate(session.startedAt)
        } else if (oneRepMax == detail.bestOneRepMax && detail.bestDateText.isEmpty()) {
            detail.bestDateText = formatDate(session.startedAt)
        }
        if (set.weight > detail.bestWeight) {
            detail.bestWeight = set.weight
        }
        if (set.reps > detail.bestReps) {
            detail.bestReps = set.reps
        }

        val setVolume = set.weight * set.reps
        if (session.startedAt > detail.lastPerformedAt) {
            detail.lastPerformedAt = session.startedAt
            detail.lastPerformedDateText = formatDate(session.startedAt)
            detail.recentOneRepMax = oneRepMax
            detail.recentWeight = set.weight
            detail.recentReps = set.reps
            detail.recentVolume = setVolume
        } else if (session.startedAt == detail.lastPerformedAt) {
            if (oneRepMax >= detail.recentOneRepMax) {
                detail.recentOneRepMax = oneRepMax
                detail.recentWeight = set.weight
                detail.recentReps = set.reps
            }
            detail.recentVolume += setVolume
        }

        detail.trendText = createTrendText(detail)
    }

    /** 源 `createTrendText`（`:195`）。 */
    private fun createTrendText(detail: ExercisePersonalRecordDetail): String {
        if (detail.lastPerformedDateText.isEmpty()) {
            return "完成训练后，这里会显示动作纪录变化。"
        }
        if (detail.recentOneRepMax >= detail.bestOneRepMax) {
            return "最近一次训练已追平当前 PR。"
        }
        return "最近一次距离 PR 还差 ${detail.bestOneRepMax - detail.recentOneRepMax} kg。"
    }

    /** 源 `sortRecordDetails`（`:214`）。冒泡排序（稳定性对齐源实现）。 */
    private fun sortRecordDetails(details: MutableList<ExercisePersonalRecordDetail>) {
        for (outerIndex in details.indices) {
            for (innerIndex in (outerIndex + 1) until details.size) {
                if (shouldSwapDetails(details[outerIndex], details[innerIndex])) {
                    val current = details[outerIndex]
                    details[outerIndex] = details[innerIndex]
                    details[innerIndex] = current
                }
            }
        }
    }

    /** 源 `shouldSwapDetails`（`:226`）。1RM 降序，其次 `lastPerformedAt` 降序。 */
    private fun shouldSwapDetails(
        current: ExercisePersonalRecordDetail,
        candidate: ExercisePersonalRecordDetail,
    ): Boolean {
        if (candidate.bestOneRepMax > current.bestOneRepMax) {
            return true
        }
        if (candidate.bestOneRepMax == current.bestOneRepMax &&
            candidate.lastPerformedAt > current.lastPerformedAt
        ) {
            return true
        }
        return false
    }

    /** 源 `isRecordableSet`（`:236`）。有效动作 id、非热身、重量/次数均 > 0。 */
    private fun isRecordableSet(set: WorkoutSet): Boolean =
        set.exerciseId.isNotEmpty() && !set.isWarmup && set.weight > 0 && set.reps > 0

    /** 源 `getExerciseName`（`:240`）。内容库未命中回落 `exerciseId`。 */
    private fun getExerciseName(exerciseId: String): String = exerciseNameResolver(exerciseId) ?: exerciseId

    /** 源 `formatDate`（`:248`）：`YYYY-MM-DD`（本地时区）。 */
    private fun formatDate(timestamp: Long): String {
        val date = Calendar.getInstance().apply { timeInMillis = timestamp }
        return "${date.get(Calendar.YEAR)}-${padTwoDigits(date.get(Calendar.MONTH) + 1)}-" +
            padTwoDigits(date.get(Calendar.DAY_OF_MONTH))
    }

    /** 源 `padTwoDigits`（`:254`）。 */
    private fun padTwoDigits(value: Int): String = if (value < 10) "0$value" else value.toString()
}
