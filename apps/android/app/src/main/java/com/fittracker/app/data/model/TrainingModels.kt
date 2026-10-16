package com.fittracker.app.data.model

import kotlinx.serialization.Serializable
import kotlin.math.round

/**
 * 训练领域数据模型——逐字段移植自鸿蒙工程 `shared/models/TrainingModels.ets`。
 *
 * 互操作约束：字段名与鸿蒙 JSON 序列化输出**逐字一致**（camelCase），
 * 这是备份包跨平台互通与数据迁移的基石——重命名任何字段前先检查备份互通测试。
 */

/** 目标设置（`TrainingModels.ets:5`）。 */
@Serializable
data class UserGoal(
    val goalId: String,
    val goalType: String,
    val level: String,
    val weeklyDays: Int,
    val sessionMinutes: Int,
    val equipmentIds: List<String>,
    val restrictedMuscleIds: List<String>,
    val createdAt: Long,
    val updatedAt: Long,
)

/**
 * 肌群（`TrainingModels.ets:17`）。
 *
 * [nameEn] 为 Wave 8 内容双语新增：英文展示名，随 `assets/exercise-content.json` 的
 * `muscles[].nameEn` 载入。默认 `""` 兼容旧数据（鸿蒙互通包 / 旧版本资产无此字段），
 * 空时由 `ContentRepository.muscleDisplayName` 回落中文名。
 */
@Serializable
data class MuscleGroup(
    val muscleId: String,
    val nameZh: String,
    val region: String,
    val nameEn: String = "",
)

/**
 * 器械（`TrainingModels.ets:23`）。
 *
 * [nameEn] 语义同 [MuscleGroup.nameEn]（Wave 8 内容双语；默认 `""` 兼容旧数据）。
 */
@Serializable
data class EquipmentItem(
    val equipmentId: String,
    val nameZh: String,
    val nameEn: String = "",
)

/** 动作库条目（`TrainingModels.ets:28`）。 */
@Serializable
data class ExerciseContent(
    val exerciseId: String,
    val nameZh: String,
    val nameEn: String,
    val aliases: List<String>,
    val primaryMuscleIds: List<String>,
    val secondaryMuscleIds: List<String>,
    val equipmentIds: List<String>,
    val difficulty: String,
    val goalTags: List<String>,
    val videoUrl: String,
    val coverUrl: String,
    val coverSourceLabel: String,
    val videoSourceLabel: String,
    val mediaLicenseText: String,
    val steps: List<String>,
    val cues: List<String>,
    val commonMistakes: List<String>,
    val safetyNotes: List<String>,
    val alternativeExerciseIds: List<String>,
    val contentVersion: Int,
)

/** 计划日内的一个动作处方（`TrainingModels.ets:51`；`selectionNote` 默认 `''`）。 */
@Serializable
data class PlannedExercise(
    val plannedExerciseId: String,
    val exerciseId: String,
    val targetSets: Int,
    val targetReps: String,
    val intensityNote: String,
    val alternativeExerciseIds: List<String>,
    val selectionNote: String = "",
)

/** 计划中的一天（`TrainingModels.ets:61`）。 */
@Serializable
data class PlanDay(
    val dayId: String,
    val dayOfWeek: Int,
    val title: String,
    val focusMuscleIds: List<String>,
    val exercises: List<PlannedExercise>,
)

/** 目标生成计划（`TrainingModels.ets:69`；`generatedBy=rule_v1` 为 PlanEngine 产物）。 */
@Serializable
data class TrainingPlan(
    val planId: String,
    val goalId: String,
    val name: String,
    val cycleWeeks: Int,
    val days: List<PlanDay>,
    val generatedBy: String,
    val status: String,
)

/** 单组记录（`TrainingModels.ets:79`）。 */
@Serializable
data class WorkoutSet(
    val setId: String,
    val exerciseId: String,
    val weight: Double,
    val reps: Int,
    val rpe: Double,
    val isWarmup: Boolean,
)

/**
 * 训练会话（`TrainingModels.ets:88`）。
 *
 * `notes` 可能内嵌 `target_sets=` / `completed_sets=` 前缀（复盘解析依赖），不可清理。
 */
@Serializable
data class WorkoutSession(
    val sessionId: String,
    val planId: String,
    val dayId: String,
    val startedAt: Long,
    val endedAt: Long,
    val durationSeconds: Int,
    val totalSets: Int,
    val totalVolume: Double,
    val fatigueScore: Double,
    /** 本次训练整体努力程度（RPE 1–10）；0 表示未评价（旧数据/未采集）。 */
    val sessionRpe: Int = 0,
    val notes: String,
    val sets: List<WorkoutSet>,
)

/** 内容同步状态（`TrainingModels.ets:102`）。 */
@Serializable
data class ContentSyncStatus(
    val localVersion: Int,
    val remoteVersion: Int,
    val lastCheckedAt: Long,
    val lastSyncAttemptAt: Long,
    val lastAppliedAt: Long,
    val activeSourceId: String,
    val activeSourceName: String,
    val fallbackSourceId: String,
    val status: String,
    val failureReason: String,
)

/** 内容包清单（`TrainingModels.ets:115`）。 */
@Serializable
data class ContentSyncManifest(
    val syncSchemaVersion: Int,
    val packageKind: String,
    val packageVersion: Int,
    val packageUrl: String,
    val packageChecksum: String,
    val packageSizeBytes: Long,
    val generatedAt: Long,
    val exerciseCount: Int,
    val releaseChannel: String,
    val sourceNote: String,
)

/** 内容同步元数据（`TrainingModels.ets:128`）。 */
@Serializable
data class ContentSyncMetadata(
    val syncSchemaVersion: Int,
    val localVersion: Int,
    val lastKnownRemoteVersion: Int,
    val lastCheckedAt: Long,
    val lastSyncAttemptAt: Long,
    val lastAppliedAt: Long,
    val activeSourceId: String,
    val fallbackSourceId: String,
    val status: String,
    val failureReason: String,
)

/**
 * Epley 1RM 估算——全项目唯一实现点（逐字段对齐 `TrainingModels.ets:418`，两位小数）。
 *
 * 鸿蒙侧存在消费点取整（`WorkoutSessionEditService.ets:173` 的 `Math.round(...)`），
 * 显示层取整由各屏决定，本函数保持两位小数口径不变。
 */
fun estimateOneRepMax(weight: Double, reps: Int): Double =
    round(weight * (1 + reps / 30.0) * 100) / 100
