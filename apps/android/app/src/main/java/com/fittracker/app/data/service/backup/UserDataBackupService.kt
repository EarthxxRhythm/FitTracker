package com.fittracker.app.data.service.backup

import androidx.annotation.StringRes
import com.fittracker.app.R
import com.fittracker.app.data.model.BACKUP_SCHEMA_VERSION
import com.fittracker.app.data.model.ExerciseRef
import com.fittracker.app.data.model.TrainingDay
import com.fittracker.app.data.model.UserDataBackupContentMeta
import com.fittracker.app.data.model.UserDataBackupImportResult
import com.fittracker.app.data.model.UserDataBackupPackage
import com.fittracker.app.data.model.UserGoal
import com.fittracker.app.data.model.UserPlan
import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.service.ContentRepository
import com.fittracker.app.data.service.GoalRepository
import com.fittracker.app.data.service.TrainingPlanRepository
import com.fittracker.app.data.service.WorkoutRepository
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * 手动 JSON 备份 / 恢复服务——逐方法移植自鸿蒙
 * `shared/services/UserDataBackupService.ets`（Feature #41）。
 *
 * 移植范围：目标（goal）、我的计划（plans）+ 当前计划指针、训练会话（sessions）的
 * 导出（[exportPackage]）与导入（[importPackage]）。包结构见
 * [com.fittracker.app.data.model.UserDataBackupPackage]。
 *
 * 与源的**注入式差异**（Wave 3 既定纪律）：
 * 1. 源各方法首参 `context: Context` → 安卓侧改为注入 [JsonStore]（仓储均为 `(store 参数)` 形式，
 *    便于单测注入临时文件）；`async` → `suspend`。方法名与源逐一对齐。
 * 2. 源的会话持久化走 `WorkoutSessionPersistenceBridgeService`（legacy `SessionRecord` ↔ 新
 *    `WorkoutSession` 互转）。安卓侧按「不移植兼容层、统一新模型」的决策，会话唯一持久化路径即
 *    [WorkoutRepository]（`StoreNames.SESSIONS` 键）。故 [exportPackage] 的 persisted 会话与
 *    repository 会话**同源**（源是两路合并），直接取一路即可；[importPackage] 的
 *    `replacePersistedSessions` 以「清空 + 逐条追加」实现整块替换。
 * 3. 源的 `ContentRepository.getLocalContentVersion()`（取全部动作 `contentVersion` 最大值）在
 *    安卓 [ContentRepository] 未暴露——本侧以 [localContentVersion] 内联等价实现。
 *
 * 互操作约束：导出 JSON 与鸿蒙 `JSON.stringify(pkg, null, 2)` 形态一致（`JsonCodec.prettyJson`），
 * 字段名逐字对齐模型；校验口径（顶层 `schemaVersion` 有限数 + `== 1`，再深层结构校验）逐条对齐源。
 */
object UserDataBackupService {

    // --- 源 L12-L18：文案资源引用（Wave 8 i18n；中文真源在 values/strings_backup.xml） ----

    /** 源 `UserDataBackupService.ets:13` `BACKUP_SCOPE_SUMMARY_TEXT`。 */
    @StringRes
    val BACKUP_SCOPE_SUMMARY_RES: Int = R.string.backup_scope_summary

    /** 源 `UserDataBackupService.ets:14` `BACKUP_USAGE_HINT_TEXT`。 */
    @StringRes
    val BACKUP_USAGE_HINT_RES: Int = R.string.backup_usage_hint

    /** 源 `UserDataBackupService.ets:15` `BACKUP_RESTORE_RULE_TEXT`。 */
    @StringRes
    val BACKUP_RESTORE_RULE_RES: Int = R.string.backup_restore_rule

    /** 源 `UserDataBackupService.ets:16` `BACKUP_EXPORT_SUCCESS_STATUS_TEXT`。 */
    @StringRes
    val BACKUP_EXPORT_SUCCESS_STATUS_RES: Int = R.string.backup_export_success_status

    /** 源 `UserDataBackupService.ets:17` `BACKUP_EXPORT_FAILURE_STATUS_TEXT`。 */
    @StringRes
    val BACKUP_EXPORT_FAILURE_STATUS_RES: Int = R.string.backup_export_failure_status

    /** 源 `UserDataBackupService.ets:18` `BACKUP_IMPORT_EMPTY_STATUS_TEXT`。 */
    @StringRes
    val BACKUP_IMPORT_EMPTY_STATUS_RES: Int = R.string.backup_import_empty_status

    // --- 源 L46-L50：状态标识 -------------------------------------------------

    /** 源 `:35` 的 `statusId` 取值：导入成功。 */
    const val STATUS_IMPORT_SUCCESS: String = "import_success"

    /** 源 `:224` 等处的 `statusId` 取值：非法 JSON / 结构不符。 */
    const val STATUS_BACKUP_INVALID_JSON: String = "backup_invalid_json"

    /** 源 `:239` 的 `statusId` 取值：schema 版本不受支持。 */
    const val STATUS_BACKUP_SCHEMA_UNSUPPORTED: String = "backup_schema_unsupported"

    /** 源 `:245` 的解析通过标识。 */
    private const val STATUS_BACKUP_VALID: String = "backup_valid"

    // --- 源 L77-L97：导出 ----------------------------------------------------

    /**
     * 源 `:77` `exportPackage`——读取目标 / 我的计划 / 当前指针 / 会话，打包为美化 JSON 字符串
     * （源 `JSON.stringify(backupPackage, null, 2)`，本侧 [JsonCodec.prettyJson]）。
     *
     * 会话差异：源合并「持久化桥」与「内存仓储」两路（`mergeSessions(persisted, repository)`）；
     * 安卓侧二者同源（[WorkoutRepository] 即唯一持久化路径），故直接取一路。
     */
    suspend fun exportPackage(store: JsonStore): String {
        val goal: UserGoal? = GoalRepository.loadGoal(store) // :78
        val plans: List<UserPlan> = TrainingPlanRepository.getMyPlans(store) // :79
        val currentPlanId: String = TrainingPlanRepository.getCurrentPlanId(store) // :80
        val sessions: List<WorkoutSession> = WorkoutRepository.getSessions(store) // :81-83
        val backupPackage: UserDataBackupPackage = createPackage(
            goal = goal,
            plans = plans,
            currentPlanId = currentPlanId,
            sessions = sessions,
            exportedAt = System.currentTimeMillis(), // :88
        )
        return JsonCodec.prettyJson.encodeToString(UserDataBackupPackage.serializer(), backupPackage) // :89
    }

    // --- 源 L91-L131：导入 ---------------------------------------------------

    /**
     * 源 `:91` `importPackage`——解析 → 归一化计划选择 → 落库（目标以包为准、计划整块替换、
     * 会话按 sessionId 去重合并）→ 返回带计数与文案的导入结果。
     */
    suspend fun importPackage(store: JsonStore, json: String): UserDataBackupImportResult {
        val parsedResult: ParsedUserDataBackupPackageResult = parsePackageImportCandidate(json) // :92
        val backupPackage: UserDataBackupPackage = parsedResult.backupPackage
            ?: return createImportResult( // :93-96
                success = false,
                statusId = parsedResult.statusId,
                importedPlanCount = 0,
                importedSessionCount = 0,
                mergedSessionCount = 0,
                effectiveCurrentPlanId = "",
                usedPlanFallback = false,
            )

        val normalizedPlanSelection: UserDataBackupPlanSelection = // :98-99
            normalizePlanSelection(backupPackage.plans, backupPackage.currentPlanId)

        if (backupPackage.goal == null) { // :101-105
            GoalRepository.clearSavedGoal(store)
        } else {
            GoalRepository.saveGoal(store, backupPackage.goal)
        }

        TrainingPlanRepository.replaceMyPlans( // :107-111
            store,
            normalizedPlanSelection.plans,
            normalizedPlanSelection.currentPlanId,
        )

        val existingSessions: List<WorkoutSession> = WorkoutRepository.getSessions(store) // :113
        val mergedSessions: List<WorkoutSession> = mergeSessions(existingSessions, backupPackage.sessions) // :114
        replacePersistedSessions(store, mergedSessions) // :115（源 replacePersistedSessions）+ :116 sync

        return createImportResult( // :118-129
            success = true,
            statusId = STATUS_IMPORT_SUCCESS, // :120
            importedPlanCount = normalizedPlanSelection.plans.size, // :121
            importedSessionCount = backupPackage.sessions.size, // :122
            mergedSessionCount = mergedSessions.size, // :123
            effectiveCurrentPlanId = normalizedPlanSelection.currentPlanId, // :124
            usedPlanFallback = normalizedPlanSelection.usedFallback, // :125
        ) // :126-128（文案由 UI 层依 statusId 与计数渲染，见 strings_backup.xml）
    }

    // --- 源 L133-L156：打包 --------------------------------------------------

    /**
     * 源 `:133` `createPackage`——用给定快照重建包；`contentMeta.contentVersion` 取内容库版本
     * （源 `:151` `ContentRepository.getLocalContentVersion()`）。深拷贝各字段（不可变模型 + 重建）。
     */
    fun createPackage(
        goal: UserGoal?,
        plans: List<UserPlan>,
        currentPlanId: String,
        sessions: List<WorkoutSession>,
        exportedAt: Long,
    ): UserDataBackupPackage = UserDataBackupPackage( // :142
        schemaVersion = BACKUP_SCHEMA_VERSION, // :143
        exportedAt = exportedAt, // :144
        goal = goal?.let { copyGoal(it) }, // :145
        plans = copyPlans(plans), // :146
        currentPlanId = currentPlanId, // :147
        sessions = copySessions(sessions), // :148
        contentMeta = UserDataBackupContentMeta( // :149-151
            contentVersion = localContentVersion(),
        ),
    )

    // --- 源 L158-L162：解析（仅取包） ---------------------------------------

    /** 源 `:158` `parsePackageJson`——校验失败返回 `null`（源 `undefined`）。 */
    fun parsePackageJson(json: String): UserDataBackupPackage? =
        parsePackageImportCandidate(json).backupPackage // :159-160

    // --- 源 L164-L184：会话合并 ---------------------------------------------

    /**
     * 源 `:164` `mergeSessions`——以 existing 为基底；逐条 imported：同 `sessionId` 命中则**就地替换**，
     * 否则**追加**。返回全新副本序列（不改动入参）。
     */
    fun mergeSessions(
        existingSessions: List<WorkoutSession>,
        importedSessions: List<WorkoutSession>,
    ): List<WorkoutSession> {
        val sessions: MutableList<WorkoutSession> = copySessions(existingSessions).toMutableList() // :165
        for (importedSession in importedSessions) { // :166-167
            var replaced: Boolean = false // :169
            for (existingIndex in sessions.indices) { // :170-171
                if (sessions[existingIndex].sessionId == importedSession.sessionId) { // :172
                    sessions[existingIndex] = copySession(importedSession) // :173
                    replaced = true // :174
                    break // :175
                }
            }
            if (!replaced) { // :178
                sessions.add(copySession(importedSession)) // :179
            }
        }
        return sessions // :182
    }

    // --- 源 L186-L203：计划选择归一 -----------------------------------------

    /**
     * 源 `:186` `normalizePlanSelection`——若 `currentPlanId` 不在 `plans` 中，
     * 回退为 `plans[0].id`（空列表则 `''`）；`usedFallback` = 「原指针非空」或「列表为空」。
     */
    fun normalizePlanSelection(plans: List<UserPlan>, currentPlanId: String): UserDataBackupPlanSelection {
        val copiedPlans: List<UserPlan> = copyPlans(plans) // :187
        var nextCurrentPlanId: String = currentPlanId // :188
        var usedFallback: Boolean = false // :189

        if (!containsPlanId(copiedPlans, nextCurrentPlanId)) { // :191
            nextCurrentPlanId = if (copiedPlans.isNotEmpty()) copiedPlans[0].id else "" // :192
            usedFallback = currentPlanId.isNotEmpty() || copiedPlans.isEmpty() // :193
        }

        return UserDataBackupPlanSelection( // :196
            plans = copiedPlans, // :197
            currentPlanId = nextCurrentPlanId, // :198
            usedFallback = usedFallback, // :199
        )
    }

    // --- 内部：结果构造 / 解析 / 文案 ---------------------------------------

    /** 源 `:205` `createImportResult`。 */
    private fun createImportResult(
        success: Boolean,
        statusId: String,
        importedPlanCount: Int,
        importedSessionCount: Int,
        mergedSessionCount: Int,
        effectiveCurrentPlanId: String,
        usedPlanFallback: Boolean,
    ): UserDataBackupImportResult = UserDataBackupImportResult(
        success = success, // :216
        statusId = statusId,
        importedPlanCount = importedPlanCount,
        importedSessionCount = importedSessionCount,
        mergedSessionCount = mergedSessionCount,
        effectiveCurrentPlanId = effectiveCurrentPlanId,
        usedPlanFallback = usedPlanFallback,
    )

    /**
     * 源 `:221` `parsePackageImportCandidate`——三步校验：
     * 1. 空串 → `backup_invalid_json`（源 `:222-225`）；
     * 2. 非 JSON / 顶层非对象 / `schemaVersion` 非有限数（缺失、非数字、`±Infinity`）→
     *    `backup_invalid_json`（源 `:228-237`）；
     * 3. `schemaVersion != 1` → `backup_schema_unsupported`（源 `:238-240`）；
     * 4. 深层结构校验（源 `:241-243` `isValidBackupPackage`）——本侧交由 kotlinx 严格解码等价实现：
     *    任一必填字段缺失 / 类型不符 → `SerializationException` → `backup_invalid_json`。
     */
    private fun parsePackageImportCandidate(json: String): ParsedUserDataBackupPackageResult {
        val trimmedJson: String = json.trim() // :222
        if (trimmedJson.isEmpty()) { // :223
            return ParsedUserDataBackupPackageResult(STATUS_BACKUP_INVALID_JSON, null) // :224
        }

        val root: JsonObject = try { // :228-233
            JsonCodec.json.parseToJsonElement(trimmedJson) as? JsonObject
                ?: return ParsedUserDataBackupPackageResult(STATUS_BACKUP_INVALID_JSON, null)
        } catch (error: Exception) {
            return ParsedUserDataBackupPackageResult(STATUS_BACKUP_INVALID_JSON, null)
        }

        // 源 `:235-237`：`!isFiniteNumberValue(schemaVersion)` → invalid。
        // `isString` 为 JsonPrimitive 成员：带引号的字符串字面量不算数（对齐源 Number.isFinite("1")=false）。
        val schemaPrimitive: JsonPrimitive? = root["schemaVersion"] as? JsonPrimitive
        val schemaNumber: Double? =
            if (schemaPrimitive != null && !schemaPrimitive.isString) {
                schemaPrimitive.content.toDoubleOrNull()
            } else {
                null
            }
        if (schemaNumber == null || !schemaNumber.isFinite()) {
            return ParsedUserDataBackupPackageResult(STATUS_BACKUP_INVALID_JSON, null)
        }
        // 源 `:238-240`：`schemaVersion !== 1` → unsupported。
        if (schemaNumber != BACKUP_SCHEMA_VERSION.toDouble()) {
            return ParsedUserDataBackupPackageResult(STATUS_BACKUP_SCHEMA_UNSUPPORTED, null)
        }

        // 源 `:241-243`：`isValidBackupPackage` 深层校验——严格解码等价。
        val decoded: UserDataBackupPackage = try {
            JsonCodec.json.decodeFromString(UserDataBackupPackage.serializer(), trimmedJson)
        } catch (error: Exception) {
            return ParsedUserDataBackupPackageResult(STATUS_BACKUP_INVALID_JSON, null)
        }

        return ParsedUserDataBackupPackageResult( // :245-253
            STATUS_BACKUP_VALID,
            createPackage(
                decoded.goal,
                decoded.plans,
                decoded.currentPlanId,
                decoded.sessions,
                decoded.exportedAt,
            ),
        )
    }

    /** 源 `:255` `createParsedPackageResult`。 */
    private data class ParsedUserDataBackupPackageResult(
        val statusId: String,
        val backupPackage: UserDataBackupPackage?,
    )

    /**
     * 源 `:301` `getImportFailureStatusText`——不含线（源按 statusId 二分）。
     *
     * Wave 8 i18n：返回资源 id（`values/strings_backup.xml`），由 UI 层解析；
     * 成功路径的计数插值与计划回退追加同理由 UI 层渲染。
     */
    @StringRes
    fun importFailureStatusRes(statusId: String): Int =
        if (statusId == STATUS_BACKUP_SCHEMA_UNSUPPORTED) { // :302
            R.string.backup_import_failure_unsupported // :303
        } else {
            R.string.backup_import_failure_invalid // :305
        }

    // --- 内部：落库 / 内容版本 / 拷贝辅助 -----------------------------------

    /**
     * 源的 `WorkoutSessionPersistenceBridgeService.replacePersistedSessions(context, merged)`（`:115`）。
     * 安卓侧 [WorkoutRepository] 无整块替换 API——以「[WorkoutRepository.clear] + 逐条 [WorkoutRepository.saveSession]」
     * 等价实现（最终落盘内容即 merged 顺序副本）。
     */
    private suspend fun replacePersistedSessions(store: JsonStore, sessions: List<WorkoutSession>) {
        WorkoutRepository.clear(store)
        for (session in sessions) {
            WorkoutRepository.saveSession(store, session)
        }
    }

    /**
     * 源 `ContentRepository.ets:352` `getLocalContentVersion`——取全部动作 `contentVersion` 最大值
     * （无动作回退 `0`）。安卓 [ContentRepository] 未暴露此方法，内联等价实现。
     */
    private fun localContentVersion(): Int =
        ContentRepository.exercises().maxOfOrNull { it.contentVersion } ?: 0

    /** 源 `:454` `copyGoal`——重建目标并复制两个字符串数组。 */
    private fun copyGoal(source: UserGoal): UserGoal = source.copy(
        equipmentIds = copyStringArray(source.equipmentIds),
        restrictedMuscleIds = copyStringArray(source.restrictedMuscleIds),
    )

    /** 源 `:473` `copyPlans`。 */
    private fun copyPlans(source: List<UserPlan>): List<UserPlan> = source.map { copyPlan(it) }

    /** 源 `:481` `copyPlan`——重建计划并深拷贝 days。 */
    private fun copyPlan(source: UserPlan): UserPlan = source.copy(days = copyPlanDays(source.days))

    /** 源 `:494` `copyPlanDays`——逐日重建，深拷贝 `dayOfWeek` 与 `exercises`。 */
    private fun copyPlanDays(source: List<TrainingDay>): List<TrainingDay> = source.map { day ->
        TrainingDay(
            dayLabel = day.dayLabel,
            exercises = copyExerciseRefs(day.exercises), // :500
            dayOfWeek = copyNumberArray(day.dayOfWeek), // :499
        )
    }

    /** 源 `:510` `copyExerciseRefs`——逐动作重建。 */
    private fun copyExerciseRefs(source: List<ExerciseRef>): List<ExerciseRef> = source.map {
        ExerciseRef(name = it.name, targetMuscle = it.targetMuscle, sets = it.sets, reps = it.reps)
    }

    /** 源 `:527` `copySessions`。 */
    private fun copySessions(source: List<WorkoutSession>): List<WorkoutSession> = source.map { copySession(it) }

    /** 源 `:535` `copySession`——重建会话并深拷贝组记录。 */
    private fun copySession(source: WorkoutSession): WorkoutSession = source.copy(sets = copySets(source.sets))

    /** 源 `:551` `copyWorkoutSet`——逐组 `WorkoutSet` 重建。 */
    private fun copySets(source: List<WorkoutSet>): List<WorkoutSet> = source.map { it.copy() }

    /** 源 `:564` `copyStringArray`——Kotlin `List` 不可变，快照即可。 */
    private fun copyStringArray(source: List<String>): List<String> = source.toList()

    /** 源 `:574` `copyNumberArray`——`null` 透传（缺省=自动分配），否则复制。 */
    private fun copyNumberArray(source: List<Int>?): List<Int>? = source?.toList()

    /** 源 `:584` `containsPlanId`。 */
    private fun containsPlanId(plans: List<UserPlan>, planId: String): Boolean =
        plans.any { it.id == planId }
}

/**
 * 源 `UserDataBackupService.ets:48-52` 的 `UserDataBackupPlanSelection`（非导出 interface）；
 * 安卓侧提升为公开 data class，供 [UserDataBackupService.normalizePlanSelection] 返回。
 */
data class UserDataBackupPlanSelection(
    val plans: List<UserPlan>,
    val currentPlanId: String,
    val usedFallback: Boolean,
)
