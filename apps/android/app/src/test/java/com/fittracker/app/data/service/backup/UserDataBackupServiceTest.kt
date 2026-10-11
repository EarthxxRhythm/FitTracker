package com.fittracker.app.data.service.backup

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.R
import com.fittracker.app.data.model.BACKUP_SCHEMA_VERSION
import com.fittracker.app.data.model.ExerciseRef
import com.fittracker.app.data.model.TrainingDay
import com.fittracker.app.data.model.UserDataBackupContentMeta
import com.fittracker.app.data.model.UserDataBackupPackage
import com.fittracker.app.data.model.UserGoal
import com.fittracker.app.data.model.UserPlan
import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.service.GoalRepository
import com.fittracker.app.data.service.TrainingPlanRepository
import com.fittracker.app.data.service.WorkoutRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.encodeToString
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.util.concurrent.atomic.AtomicInteger

/**
 * [UserDataBackupService] 契约测试——口径逐条对齐源
 * `shared/services/UserDataBackupService.ets`（Feature #41）。
 *
 * 覆盖：导出→解析→再导入往返；导入语义（目标/计划以包为准 + 会话按 `sessionId` 去重合并）；
 * [UserDataBackupService.normalizePlanSelection] 回退规则；[UserDataBackupService.mergeSessions]
 * 同 id 替换 / 新 id 追加；校验分支（`backup_schema_unsupported` / `backup_invalid_json`）；
 * `statusText` 文案（含计数插值与回退追加语）。
 *
 * 测试手段照 `RepositoriesTest` / `SessionAndPlanTest`：以 [PreferenceDataStoreFactory] 把每个用例的
 * 存储指向独立临时文件（互不污染、不触真实应用存储）。
 *
 * `@Config(sdk = [34])`：项目 targetSdk 37 超出 Robolectric 4.16 支持范围，必须钉到受支持 SDK
 * （原因同 `JsonStoreTest`）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class UserDataBackupServiceTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "backup_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    /** 单例在 JVM 内跨用例存活——每例前清掉仓储内存缓存，避免串场。 */
    @Before
    fun resetSingletonState() {
        GoalRepository.clearLocal()
        TrainingPlanRepository.clearLocal()
    }

    // --- 样本构造 -----------------------------------------------------------

    private fun sampleGoal(goalId: String = "goal-1"): UserGoal = UserGoal(
        goalId = goalId,
        goalType = "muscle_gain",
        level = "intermediate",
        weeklyDays = 4,
        sessionMinutes = 60,
        equipmentIds = listOf("barbell", "dumbbell"),
        restrictedMuscleIds = emptyList(),
        createdAt = 1_759_000_000_000,
        updatedAt = 1_759_000_000_000,
    )

    private fun samplePlan(id: String, name: String): UserPlan = UserPlan(
        id = id,
        name = name,
        coverColor = "#43A047",
        targetAudience = "初中级健身者",
        weeklyFrequency = "4 天/周",
        description = "测试计划",
        days = listOf(
            TrainingDay(
                dayLabel = "上肢A",
                exercises = listOf(ExerciseRef("杠铃平板卧推", "胸部", 4, "8-12")),
                dayOfWeek = listOf(1),
            ),
        ),
        enabledAt = 1_759_100_000_000,
    )

    private fun sampleSession(id: String, notes: String = ""): WorkoutSession = WorkoutSession(
        sessionId = id,
        planId = "plan-1",
        dayId = "上肢A",
        startedAt = 1_759_300_000_000,
        endedAt = 1_759_303_600_000,
        durationSeconds = 3600,
        totalSets = 1,
        totalVolume = 625.0,
        fatigueScore = 7.5,
        notes = notes,
        sets = listOf(
            WorkoutSet(setId = "set-1", exerciseId = "ex-bench", weight = 62.5, reps = 10, rpe = 8.0, isWarmup = false),
        ),
    )

    private fun samplePackage(
        schemaVersion: Int = BACKUP_SCHEMA_VERSION,
        goal: UserGoal? = sampleGoal(),
        plans: List<UserPlan> = listOf(samplePlan("p1", "计划一")),
        currentPlanId: String = "p1",
        sessions: List<WorkoutSession> = emptyList(),
    ): UserDataBackupPackage = UserDataBackupPackage(
        schemaVersion = schemaVersion,
        exportedAt = 1_759_430_400_000,
        goal = goal,
        plans = plans,
        currentPlanId = currentPlanId,
        sessions = sessions,
        contentMeta = UserDataBackupContentMeta(contentVersion = 3),
    )

    /** 序列化为紧凑 JSON（`JsonCodec.json`），等价于源导出的可解析形态。 */
    private fun pkgJson(pkg: UserDataBackupPackage): String =
        JsonCodec.json.encodeToString(UserDataBackupPackage.serializer(), pkg)

    // --- 往返 ---------------------------------------------------------------

    @Test
    fun `导出_解析_再导入往返全等`() = runBlocking {
        val store = createStore()
        val goal = sampleGoal()
        GoalRepository.saveGoal(store, goal)
        val p1 = samplePlan("user_plan_1", "二分化（上下肢）")
        val p2 = samplePlan("user_plan_2", "三分化")
        TrainingPlanRepository.replaceMyPlans(store, listOf(p1, p2), p2.id)
        val s1 = sampleSession("sess-1", notes = "target_sets=1")
        WorkoutRepository.saveSession(store, s1)

        val json = UserDataBackupService.exportPackage(store)

        val parsed = UserDataBackupService.parsePackageJson(json)
        assertNotNull(parsed)
        parsed!!
        assertEquals(BACKUP_SCHEMA_VERSION, parsed.schemaVersion)
        assertEquals(goal, parsed.goal)
        assertEquals(listOf(p1, p2), parsed.plans)
        assertEquals(p2.id, parsed.currentPlanId)
        assertEquals(listOf(s1), parsed.sessions)

        // 再导入到全新 store
        val target = createStore()
        val result = UserDataBackupService.importPackage(target, json)
        assertTrue(result.success)
        assertEquals(UserDataBackupService.STATUS_IMPORT_SUCCESS, result.statusId)
        assertEquals(2, result.importedPlanCount)
        assertEquals(1, result.importedSessionCount)
        assertEquals(1, result.mergedSessionCount)
        assertFalse(result.usedPlanFallback)

        assertEquals(goal, GoalRepository.loadGoal(target))
        TrainingPlanRepository.clearLocal()
        assertEquals(listOf(p1, p2), TrainingPlanRepository.getMyPlans(target))
        assertEquals(p2.id, TrainingPlanRepository.getCurrentPlanId(target))
        assertEquals(listOf(s1), WorkoutRepository.getSessions(target))
    }

    // --- 导入语义 -----------------------------------------------------------

    @Test
    fun `导入_目标与计划以包为准_会话按sessionId去重合并`() = runBlocking {
        val store = createStore()
        // 预置会被覆盖 / 保留的本地状态。
        GoalRepository.saveGoal(store, sampleGoal(goalId = "old-goal"))
        TrainingPlanRepository.replaceMyPlans(store, listOf(samplePlan("local_plan", "本地计划")), "local_plan")
        WorkoutRepository.saveSession(store, sampleSession("sess-1", notes = "old"))
        WorkoutRepository.saveSession(store, sampleSession("sess-2", notes = "keep"))

        val importedGoal = sampleGoal(goalId = "pack-goal")
        val importedPlan = samplePlan("pack_plan", "包计划")
        val pkg = samplePackage(
            goal = importedGoal,
            plans = listOf(importedPlan),
            currentPlanId = "pack_plan",
            sessions = listOf(sampleSession("sess-1", notes = "new"), sampleSession("sess-3", notes = "added")),
        )

        val result = UserDataBackupService.importPackage(store, pkgJson(pkg))

        assertTrue(result.success)
        // 目标以包为准。
        GoalRepository.clearLocal()
        assertEquals(importedGoal, GoalRepository.loadGoal(store))
        // 计划以包为准。
        TrainingPlanRepository.clearLocal()
        assertEquals(listOf(importedPlan), TrainingPlanRepository.getMyPlans(store))
        assertEquals("pack_plan", TrainingPlanRepository.getCurrentPlanId(store))
        // 会话合并：sess-1 就地替换、sess-2 保留、sess-3 追加（保序）。
        val sessions = WorkoutRepository.getSessions(store)
        assertEquals(listOf("sess-1", "sess-2", "sess-3"), sessions.map { it.sessionId })
        assertEquals("new", sessions.first { it.sessionId == "sess-1" }.notes)
        assertEquals("keep", sessions.first { it.sessionId == "sess-2" }.notes)
        assertEquals("added", sessions.first { it.sessionId == "sess-3" }.notes)

        assertEquals(1, result.importedPlanCount)
        assertEquals(2, result.importedSessionCount)
        assertEquals(3, result.mergedSessionCount)
        assertEquals("pack_plan", result.effectiveCurrentPlanId)
        assertFalse(result.usedPlanFallback)
    }

    @Test
    fun `导入_包goal为null_清空本地目标`() = runBlocking {
        val store = createStore()
        GoalRepository.saveGoal(store, sampleGoal())
        assertTrue(GoalRepository.hasSavedGoal(store))

        val result = UserDataBackupService.importPackage(store, pkgJson(samplePackage(goal = null)))
        assertTrue(result.success)

        GoalRepository.clearLocal()
        assertNull(GoalRepository.loadGoal(store))
        assertFalse(GoalRepository.hasSavedGoal(store))
    }

    // --- mergeSessions 直接单测 --------------------------------------------

    @Test
    fun `mergeSessions_同id就地替换_新id追加_保序且不改入参`() {
        val a = sampleSession("id-1", notes = "a")
        val b = sampleSession("id-2", notes = "b")
        val b2 = sampleSession("id-2", notes = "b2")
        val c = sampleSession("id-3", notes = "c")

        val merged = UserDataBackupService.mergeSessions(listOf(a, b), listOf(b2, c))

        assertEquals(listOf("id-1", "id-2", "id-3"), merged.map { it.sessionId })
        assertEquals("a", merged[0].notes)
        assertEquals("b2", merged[1].notes)
        assertEquals("c", merged[2].notes)
        // 入参不被改动（返回为全新副本）。
        assertEquals("b", b.notes)
    }

    // --- normalizePlanSelection --------------------------------------------

    @Test
    fun `normalizePlanSelection_命中不变_未命中回退首个_空列表回退空串`() {
        val p1 = samplePlan("p1", "A")
        val p2 = samplePlan("p2", "B")

        val hit = UserDataBackupService.normalizePlanSelection(listOf(p1, p2), "p2")
        assertEquals("p2", hit.currentPlanId)
        assertFalse(hit.usedFallback)

        val miss = UserDataBackupService.normalizePlanSelection(listOf(p1, p2), "absent")
        assertEquals("p1", miss.currentPlanId)
        assertTrue(miss.usedFallback)

        // 空列表 + 非空指针 → 回退空串，usedFallback = true。
        val emptyWithId = UserDataBackupService.normalizePlanSelection(emptyList(), "absent")
        assertEquals("", emptyWithId.currentPlanId)
        assertTrue(emptyWithId.usedFallback)

        // 空列表 + 空指针 → currentPlanId 空（usedFallback = false || true = true，对齐源）。
        val emptyNoId = UserDataBackupService.normalizePlanSelection(emptyList(), "")
        assertEquals("", emptyNoId.currentPlanId)
        assertTrue(emptyNoId.usedFallback)
    }

    // --- 校验分支 -----------------------------------------------------------

    @Test
    fun `校验_schemaVersion不为1_返回schemaUnsupported`() = runBlocking {
        val store = createStore()
        val result = UserDataBackupService.importPackage(store, pkgJson(samplePackage(schemaVersion = 2)))
        assertFalse(result.success)
        assertEquals("backup_schema_unsupported", result.statusId)
    }

    @Test
    fun `校验_空串或纯空白_返回invalidJson`() = runBlocking {
        val store = createStore()
        val result = UserDataBackupService.importPackage(store, "   ")
        assertFalse(result.success)
        assertEquals("backup_invalid_json", result.statusId)
    }

    @Test
    fun `校验_非JSON文本_返回invalidJson`() = runBlocking {
        val store = createStore()
        val result = UserDataBackupService.importPackage(store, "{ not json")
        assertFalse(result.success)
        assertEquals("backup_invalid_json", result.statusId)
    }

    @Test
    fun `校验_schemaVersion缺失_返回invalidJson`() = runBlocking {
        val store = createStore()
        val json = pkgJson(samplePackage()).replace("\"schemaVersion\":1,", "")
        assertFalse(json.contains("schemaVersion"))
        val result = UserDataBackupService.importPackage(store, json)
        assertEquals("backup_invalid_json", result.statusId)
    }

    /**
     * 源 `:235-237`：`!isFiniteNumberValue(schemaVersion)` → `backup_invalid_json`
     * （与 `schemaVersion !== 1` 的 `backup_schema_unsupported` 分支相区分）。
     */
    @Test
    fun `校验_schemaVersion非有限数_返回invalidJson`() = runBlocking {
        val store = createStore()
        val json = pkgJson(samplePackage()).replace("\"schemaVersion\":1", "\"schemaVersion\":1e999")
        val result = UserDataBackupService.importPackage(store, json)
        assertEquals("backup_invalid_json", result.statusId)
    }

    @Test
    fun `校验_深层结构不符_返回invalidJson`() = runBlocking {
        val store = createStore()
        // plans 写成字符串——源 `isValidBackupPackage` 的 Array 判定失败。
        val json = """
        {
          "schemaVersion": 1, "exportedAt": 0, "goal": null,
          "plans": "not-an-array", "currentPlanId": "", "sessions": [],
          "contentMeta": { "contentVersion": 0 }
        }
        """.trimIndent()
        val result = UserDataBackupService.importPackage(store, json)
        assertEquals("backup_invalid_json", result.statusId)
    }

    // --- parsePackageJson ---------------------------------------------------

    @Test
    fun `parsePackageJson_非法包返回null_合法包返回包`() {
        assertNull(UserDataBackupService.parsePackageJson(""))
        assertNull(UserDataBackupService.parsePackageJson("{}"))
        assertNull(UserDataBackupService.parsePackageJson(pkgJson(samplePackage(schemaVersion = 2))))

        val pkg = samplePackage()
        val parsed = UserDataBackupService.parsePackageJson(pkgJson(pkg))
        assertNotNull(parsed)
        parsed!!
        // 解析路径经 createPackage 重建（源 `:245-253`）——contentMeta 被替换为**本地**内容版本
        // （源 `:151` getLocalContentVersion），故不参与逐字段等同比较。
        assertEquals(pkg.schemaVersion, parsed.schemaVersion)
        assertEquals(pkg.exportedAt, parsed.exportedAt)
        assertEquals(pkg.goal, parsed.goal)
        assertEquals(pkg.plans, parsed.plans)
        assertEquals(pkg.currentPlanId, parsed.currentPlanId)
        assertEquals(pkg.sessions, parsed.sessions)
    }

    // --- 导入结果结构（文案渲染移至 UI 层 BackupStatusTextTest） -----------------

    @Test
    fun `导入成功_结果含状态标识与计数`() = runBlocking {
        val store = createStore()
        val pkg = samplePackage(
            goal = null,
            plans = listOf(samplePlan("p1", "A")),
            currentPlanId = "p1",
            sessions = listOf(sampleSession("s1")),
        )
        val result = UserDataBackupService.importPackage(store, pkgJson(pkg))
        assertTrue(result.success)
        assertEquals(UserDataBackupService.STATUS_IMPORT_SUCCESS, result.statusId)
        assertEquals(1, result.importedPlanCount)
        assertEquals(1, result.mergedSessionCount)
        assertFalse(result.usedPlanFallback)
    }

    @Test
    fun `导入_指针无效_回退首个可用计划`() = runBlocking {
        val store = createStore()
        val pkg = samplePackage(plans = listOf(samplePlan("p1", "A")), currentPlanId = "absent", sessions = emptyList())
        val result = UserDataBackupService.importPackage(store, pkgJson(pkg))
        assertTrue(result.usedPlanFallback)
        assertEquals("p1", result.effectiveCurrentPlanId)
        assertEquals(0, result.mergedSessionCount)
    }

    @Test
    fun `导入_无可用计划_回退空指针`() = runBlocking {
        val store = createStore()
        val pkg = samplePackage(plans = emptyList(), currentPlanId = "absent", sessions = emptyList())
        val result = UserDataBackupService.importPackage(store, pkgJson(pkg))
        assertTrue(result.usedPlanFallback)
        assertEquals("", result.effectiveCurrentPlanId)
    }

    // --- 文案资源映射（逐字渲染见 UI 层 BackupStatusTextTest） -----------------

    @Test
    fun `文案常量_映射到备份域资源`() {
        assertEquals(R.string.backup_scope_summary, UserDataBackupService.BACKUP_SCOPE_SUMMARY_RES)
        assertEquals(R.string.backup_usage_hint, UserDataBackupService.BACKUP_USAGE_HINT_RES)
        assertEquals(R.string.backup_restore_rule, UserDataBackupService.BACKUP_RESTORE_RULE_RES)
        assertEquals(R.string.backup_export_success_status, UserDataBackupService.BACKUP_EXPORT_SUCCESS_STATUS_RES)
        assertEquals(R.string.backup_export_failure_status, UserDataBackupService.BACKUP_EXPORT_FAILURE_STATUS_RES)
        assertEquals(R.string.backup_import_empty_status, UserDataBackupService.BACKUP_IMPORT_EMPTY_STATUS_RES)
        assertEquals(1, BACKUP_SCHEMA_VERSION)
    }
}
