package com.fittracker.app.data.model

import kotlinx.serialization.Serializable

/**
 * 备份包模型——移植自鸿蒙工程 `shared/services/UserDataBackupService.ets:22-45`。
 *
 * 互通目标：鸿蒙导出的备份 JSON 可直接由本应用解析导入（反之亦然）。
 * 包结构、字段名、`schemaVersion` 语义（有限数 + `== 1` 校验）逐条对齐源实现。
 */

/** 备份包 schema 版本（`UserDataBackupService.ets:12`，`BACKUP_SCHEMA_VERSION = 1`）。 */
const val BACKUP_SCHEMA_VERSION: Int = 1

/** 内容元信息（`UserDataBackupService.ets:22`）。 */
@Serializable
data class UserDataBackupContentMeta(
    val contentVersion: Int,
)

/** 备份包（`UserDataBackupService.ets:26`）。 */
@Serializable
data class UserDataBackupPackage(
    val schemaVersion: Int = BACKUP_SCHEMA_VERSION,
    val exportedAt: Long,
    val goal: UserGoal?,
    val plans: List<UserPlan>,
    val currentPlanId: String,
    val sessions: List<WorkoutSession>,
    val contentMeta: UserDataBackupContentMeta,
    /**
     * 体重记录。**可选**（默认 null = 包内无该字段）：本版本导出的包恒包含（可能是空数组，
     * 表示「导出时确无记录」）；旧版本备份包无此字段 → 导入时保留本地既有记录，不被清空。
     */
    val bodyRecords: List<WeightRecord>? = null,
    /** 身体测量记录（围度 + 体成分）。语义同 [bodyRecords]。 */
    val bodyMeasurements: List<BodyMeasurement>? = null,
)

/**
 * 导入结果（`UserDataBackupService.ets:35`）。
 *
 * `statusId` 取值（源实现）：`backup_invalid_json` / `backup_schema_unsupported` / `import_success`。
 *
 * Wave 8 i18n：不再携带用户可见的 `statusText`——文案真源在 `values/strings_backup.xml`，
 * 由 UI 层依本结构（`success` / `statusId` / 计数 / `usedPlanFallback`）渲染。
 * 数据层保持无 `Context`、无文案，纯 JVM 可单测。
 */
@Serializable
data class UserDataBackupImportResult(
    val success: Boolean,
    val statusId: String,
    val importedPlanCount: Int,
    val importedSessionCount: Int,
    val mergedSessionCount: Int,
    val effectiveCurrentPlanId: String,
    val usedPlanFallback: Boolean,
)
