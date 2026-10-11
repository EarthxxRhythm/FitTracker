package com.fittracker.app.data.model

import kotlinx.serialization.Serializable

/**
 * 训练计划族模型——移植自鸿蒙工程 `common/services/TrainingPlanService.ets`（`:11-32`）。
 *
 * 与 `TrainingModels.kt` 的 `TrainingPlan`（目标生成计划）是**两套不同模型**：
 * 这里的是「预置计划 → 启用的我的计划」结构（`UserPlan`），备份包 `plans` 字段用后者。
 */

/** 计划日内一个动作引用（`TrainingPlanService.ets:11`）。 */
@Serializable
data class ExerciseRef(
    val name: String,
    val targetMuscle: String,
    val sets: Int,
    val reps: String,
)

/** 计划日（`TrainingPlanService.ets:18`；`dayOfWeek` 缺省表示自动分配）。 */
@Serializable
data class TrainingDay(
    val dayLabel: String,
    val exercises: List<ExerciseRef>,
    val dayOfWeek: List<Int>? = null,
)

/** 预置计划模板（`TrainingPlanService.ets:24`）。 */
@Serializable
data class PresetPlan(
    val id: String,
    val name: String,
    val coverColor: String,
    val targetAudience: String,
    val weeklyFrequency: String,
    val description: String,
    val days: List<TrainingDay>,
)

/**
 * 用户启用的计划（`TrainingPlanService.ets:32`，`UserPlan extends PresetPlan`）。
 *
 * Kotlin 无结构继承，字段展开保持与鸿蒙 JSON 扁平等价。
 */
@Serializable
data class UserPlan(
    val id: String,
    val name: String,
    val coverColor: String,
    val targetAudience: String,
    val weeklyFrequency: String,
    val description: String,
    val days: List<TrainingDay>,
    val enabledAt: Long,
)
