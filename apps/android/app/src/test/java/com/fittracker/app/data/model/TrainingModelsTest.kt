package com.fittracker.app.data.model

import com.fittracker.app.data.persist.JsonCodec
import kotlinx.serialization.encodeToString
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 训练领域模型契约测试。
 *
 * 期望值来源：
 * - Epley 黄金值——`TrainingModels.ets:418`（`weight*(1+reps/30)`，两位小数）；
 * - JSON 键名——鸿蒙 `JSON.stringify` 直出属性名（camelCase），互操作契约。
 */
class TrainingModelsTest {

    // ── Epley 1RM ────────────────────────────────────────────────

    @Test
    fun `Epley黄金值 100kg乘5次`() {
        // 100 * (1 + 5/30) = 116.666… → 保留两位小数
        assertEquals(116.67, estimateOneRepMax(100.0, 5), 1e-9)
    }

    @Test
    fun `Epley单次复现为原重量`() {
        // 60 * (1 + 1/30) = 62.0
        assertEquals(62.0, estimateOneRepMax(60.0, 1), 1e-9)
    }

    @Test
    fun `Epley两位小数取整`() {
        // 62.5 * (1 + 3/30) = 68.75 → 68.75
        assertEquals(68.75, estimateOneRepMax(62.5, 3), 1e-9)
        // 47.5 * (1 + 8/30) = 60.1666… → 60.17
        assertEquals(60.17, estimateOneRepMax(47.5, 8), 1e-9)
    }

    // ── 序列化往返 ────────────────────────────────────────────────

    private val sampleSet = WorkoutSet(
        setId = "set-1", exerciseId = "ex-bench", weight = 62.5, reps = 10, rpe = 8.0, isWarmup = false,
    )

    private val sampleSession = WorkoutSession(
        sessionId = "sess-1", planId = "plan-1", dayId = "day-1",
        startedAt = 1_750_000_000_000, endedAt = 1_750_003_600_000, durationSeconds = 3600,
        totalSets = 12, totalVolume = 8450.5, fatigueScore = 7.5,
        notes = "target_sets=12 completed_sets=12", sets = listOf(sampleSet),
    )

    @Test
    fun `WorkoutSession JSON往返全等`() {
        val encoded = JsonCodec.json.encodeToString(WorkoutSession.serializer(), sampleSession)
        val decoded = JsonCodec.json.decodeFromString(WorkoutSession.serializer(), encoded)
        assertEquals(sampleSession, decoded)
    }

    @Test
    fun `UserGoal JSON往返全等`() {
        val goal = UserGoal(
            goalId = "goal-1", goalType = "muscle_gain", level = "intermediate",
            weeklyDays = 4, sessionMinutes = 60,
            equipmentIds = listOf("barbell", "dumbbell"), restrictedMuscleIds = emptyList(),
            createdAt = 1_759_000_000_000, updatedAt = 1_759_000_000_000,
        )
        val encoded = JsonCodec.json.encodeToString(UserGoal.serializer(), goal)
        assertEquals(goal, JsonCodec.json.decodeFromString(UserGoal.serializer(), encoded))
    }

    // ── 键名契约（互操作基石） ─────────────────────────────────────

    @Test
    fun `会话序列化键名与鸿蒙JSON逐字一致`() {
        val json = JsonCodec.json.encodeToString(WorkoutSession.serializer(), sampleSession)
        for (key in listOf("sessionId", "planId", "dayId", "startedAt", "endedAt",
            "durationSeconds", "totalSets", "totalVolume", "fatigueScore", "notes", "sets")) {
            assertTrue("缺键 $key: $json", json.contains("\"$key\""))
        }
        val setJson = JsonCodec.json.encodeToString(WorkoutSet.serializer(), sampleSet)
        for (key in listOf("setId", "exerciseId", "weight", "reps", "rpe", "isWarmup")) {
            assertTrue("缺键 $key: $setJson", setJson.contains("\"$key\""))
        }
    }

    @Test
    fun `计划序列化键名与鸿蒙JSON逐字一致`() {
        val plan = UserPlan(
            id = "preset_upper_lower", name = "二分化（上下肢）", coverColor = "#43A047",
            targetAudience = "初中级健身者", weeklyFrequency = "4 天/周", description = "…",
            days = listOf(
                TrainingDay(
                    dayLabel = "上肢A",
                    exercises = listOf(ExerciseRef("杠铃平板卧推", "胸部", 4, "8-12")),
                    dayOfWeek = listOf(1),
                ),
            ),
            enabledAt = 1_759_100_000_000,
        )
        val json = JsonCodec.json.encodeToString(UserPlan.serializer(), plan)
        for (key in listOf("id", "name", "coverColor", "targetAudience", "weeklyFrequency",
            "description", "days", "enabledAt", "dayLabel", "exercises", "dayOfWeek",
            "targetMuscle", "sets", "reps")) {
            assertTrue("缺键 $key: $json", json.contains("\"$key\""))
        }
    }

    @Test
    fun `PlannedExercise缺省selectionNote输出空串`() {
        // encodeDefaults=true 对齐鸿蒙 JSON.stringify 全字段输出
        val item = PlannedExercise(
            plannedExerciseId = "pe-1", exerciseId = "ex-1", targetSets = 4,
            targetReps = "8-12", intensityNote = "", alternativeExerciseIds = emptyList(),
        )
        val json = JsonCodec.json.encodeToString(PlannedExercise.serializer(), item)
        assertTrue(json.contains("\"selectionNote\":\"\""))
    }
}
