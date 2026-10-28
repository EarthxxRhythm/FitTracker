package com.fittracker.app.data.service

import com.fittracker.app.data.model.ExerciseRef
import com.fittracker.app.data.model.PresetPlan
import com.fittracker.app.data.model.TrainingDay
import com.fittracker.app.data.model.UserPlan
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import java.util.Calendar

/**
 * 训练计划仓储——我的计划 / 当前计划指针存取。逐方法移植自鸿蒙
 * `common/services/TrainingPlanService.ets`（功能 #9：启用预置计划并持久化）。
 *
 * 持久化模型（与源的映射）：
 * - 鸿蒙侧在 `fit_tracker_plans` 库里用**两个键** `my_plans` / `current_plan_id` 存取
 *   （源 `:40-42`）。安卓侧沿用 Wave 2 折叠模型：所有鸿蒙 preferences 库折叠进同一个
 *   DataStore，库名退化为键名——因此本仓储把「我的计划列表」整块 JSON 存到键
 *   [StoreNames.PLANS]，当前指针存到键 [StoreNames.CURRENT_PLAN_ID]。
 * - 预置计划数据在 [PresetPlans]（源 `PRESET_PLANS` :86）；本类只做「读取 / 克隆 / 落盘」。
 *
 * 与源的差异：
 * 1. 首参 `context: Context` → 注入 [JsonStore]；`async` → `suspend`。方法名逐一对齐。
 * 2. **不移植 `repairCurrentPlanIfNeeded`（源 `:533-590`）**——那是针对历史数据里
 *    「动作名含 `?` 占位符」的一次性修复桥（依赖 GoalRepository + PlanEngine + 内容库），
 *    属 legacy/兼容层；安卓新装无历史占位数据。故 [getCurrentPlan] 直接返回命中的计划。
 * 3. 源的内存缓存 `localPlans` / `localCurrentPlanId`（读库失败时的回落）**保留**；
 *    单例跨用例存活，测试用 [clearLocal] 复位。
 *
 * 互操作约束：`UserPlan` 字段名与鸿蒙 JSON 输出逐字一致（见 `data/model/PlanModels.kt`），
 * 备份包跨平台互通依赖于此。
 */
object TrainingPlanRepository {

    /** 实际 JsonStore 键——我的计划列表（鸿蒙库名 `fit_tracker_plans`）。 */
    const val STORE_KEY: String = StoreNames.PLANS

    /** 实际 JsonStore 键——当前计划指针。 */
    const val CURRENT_PLAN_KEY: String = StoreNames.CURRENT_PLAN_ID

    /** 鸿蒙源库名（源 `:40` 的 `STORE_NAME`）。安卓侧折叠为 [STORE_KEY] / [CURRENT_PLAN_KEY]。 */
    const val STORE_NAME: String = "fit_tracker_plans"

    /** 鸿蒙源键名（源 `:41` 的 `KEY_MY_PLANS`）。 */
    const val KEY_MY_PLANS: String = "my_plans"

    /** 鸿蒙源键名（源 `:42` 的 `KEY_CURRENT_PLAN_ID`）。 */
    const val KEY_CURRENT_PLAN_ID: String = "current_plan_id"

    /** 源 `:263` 的 `localPlans`——读库失败时的内存回落。 */
    private var localPlans: List<UserPlan> = emptyList()

    /** 源 `:264` 的 `localCurrentPlanId`——读库失败时的内存回落。 */
    private var localCurrentPlanId: String = ""

    /** 源 `:436` 的 `getTodayLabel` 所用的星期名表（下标 = JS `getDay()`：0=周日）。 */
    private val TODAY_LABELS: List<String> =
        listOf("星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六")

    // --- 源 :272-281：预置计划读取（数据在 PresetPlans） ----------------------

    /** 源 `:272` `getAllPresetPlans`。 */
    fun getAllPresetPlans(): List<PresetPlan> = PresetPlans.getAll()

    /** 源 `:276` `getPresetPlanById`——未命中返回 `null`（源 `undefined`）。 */
    fun getPresetPlanById(id: String): PresetPlan? = PresetPlans.getById(id)

    /** 源 `:280` `getPlanCount`。 */
    fun getPlanCount(): Int = PresetPlans.count()

    /**
     * 「我的计划」→ 其来源预置 id（对齐鸿蒙 `TrainingPlanService.getPresetIdForPlan`）。
     *
     * **为什么需要**：落盘副本是启用当刻的克隆，`id` 是 `user_plan_<毫秒>` 而非预置 id，
     * 于是「当前是否已是这个计划组」无法用 id 直比。此处按**计划名**回查预置表——
     * 名字是双端既有契约（克隆保留 `preset.name`，内容库也按名匹配）。
     *
     * 未命中（自定义计划 / 预置改名后的旧副本）返回空串，调用方按「非当前」处理。
     */
    fun getPresetIdForPlan(plan: UserPlan?): String {
        if (plan == null) {
            return ""
        }
        val preset: PresetPlan = PresetPlans.getAll().firstOrNull { it.name == plan.name } ?: return ""
        return preset.id
    }

    /** 当前计划对应的预置 id（无当前计划 / 自定义计划 → 空串）。 */
    suspend fun getCurrentPresetId(store: JsonStore): String = getPresetIdForPlan(getCurrentPlan(store))

    // --- 源 :284-326：启用计划（克隆预置 / 自定义 → 我的计划） ----------------

    /**
     * 源 `:284` `enablePlan`——把预置计划克隆为 `UserPlan` 并设为当前计划；
     * 预置 id 未命中返回 `null`（源 `undefined`）。
     */
    suspend fun enablePlan(store: JsonStore, presetId: String): UserPlan? {
        val preset: PresetPlan = getPresetPlanById(presetId) ?: return null // :285-288
        val userPlan: UserPlan = createUserPlan( // :289-296
            name = preset.name,
            coverColor = preset.coverColor,
            targetAudience = preset.targetAudience,
            weeklyFrequency = preset.weeklyFrequency,
            description = preset.description,
            days = preset.days,
        )
        return enableUserPlan(store, userPlan) // :297
    }

    /** 源 `:300` `enableCustomPlan`——自定义计划直接启用（不依赖预置表）。 */
    suspend fun enableCustomPlan(
        store: JsonStore,
        name: String,
        coverColor: String,
        targetAudience: String,
        weeklyFrequency: String,
        description: String,
        days: List<TrainingDay>,
    ): UserPlan? {
        val userPlan: UserPlan = createUserPlan( // :309-316
            name = name,
            coverColor = coverColor,
            targetAudience = targetAudience,
            weeklyFrequency = weeklyFrequency,
            description = description,
            days = days,
        )
        return enableUserPlan(store, userPlan) // :317
    }

    /**
     * 源 `:320` `enableUserPlan`——把克隆设为**唯一**当前计划。
     *
     * **修复（真机实测「计划组切换功能没用」的根因之一）**：源实现是
     * `myPlans.add(nextPlan)` 后整块回写，即**每次切换都追加一份完整克隆**
     * （单份 2~3 KB）。鸿蒙侧因此撞上 preferences 单值上限（≈8 KB）后写入抛错、
     * 被空 `catch` 吞掉——UI 照旧弹「已切换」，计划页却还是旧计划。安卓侧虽然
     * DataStore 没有该上限，但同一实现会让 `my_plans` 与备份包无限膨胀，且
     * 备份导入端 (`UserDataBackupService`) 会把这些僵尸副本一并回灌。
     *
     * 现语义：**切换 = 整块替换为这一份计划**（保留一份可读计划，备份/导出/播种
     * 照旧工作），旧计划副本随之清除——历史膨胀在下次切换时自愈。
     *
     * 返回 `null` 表示落盘失败（源签名 `UserPlan | null` 的 null 出口在此**恢复**）：
     * 调用方据此提示失败，不再谎报成功。
     */
    suspend fun enableUserPlan(store: JsonStore, userPlan: UserPlan): UserPlan? {
        val nextPlan: UserPlan = copyUserPlan(userPlan) // :322
        // 单活动计划：不再 `myPlans.add(...)` 追加克隆（源 :321-323 的追加语义已改）
        val persisted: Boolean = replaceMyPlans(store, listOf(nextPlan), nextPlan.id) // :324
        return if (persisted) nextPlan else null
    }

    // --- 源 :328-411：我的计划 / 当前指针读写 --------------------------------

    /**
     * 源 `:328` `getMyPlans`——读库并返回深拷贝，同时刷新内存缓存；
     * 缺键/空串回落空列表，读库异常回落 [localPlans]。
     */
    suspend fun getMyPlans(store: JsonStore): List<UserPlan> {
        return try {
            val raw: String? = store.readString(STORE_KEY) // :330-331
            if (raw.isNullOrEmpty()) {
                localPlans = emptyList()
                return emptyList()
            }
            val plans: List<UserPlan> =
                copyUserPlans(JsonCodec.json.decodeFromString<List<UserPlan>>(raw)) // :332
            localPlans = copyUserPlans(plans) // :333
            plans
        } catch (error: Exception) {
            copyUserPlans(localPlans) // :335-336
        }
    }

    /**
     * 源 `:340` `getCurrentPlan`——按当前指针在我的计划里查找；指针为空或未命中返回 `null`。
     *
     * 设计偏差：源在返回前调用 `repairCurrentPlanIfNeeded`（`:351`，占位动作名修复桥），
     * 本移植按 Wave 3 纪律**不搬运 legacy/兼容层**，直接返回命中的计划。
     */
    suspend fun getCurrentPlan(store: JsonStore): UserPlan? {
        return try {
            val currentId: String = getCurrentPlanId(store) // :342
            if (currentId.isEmpty()) {
                return null // :343-345
            }
            val myPlans: List<UserPlan> = getMyPlans(store) // :346
            myPlans.firstOrNull { it.id == currentId } // :347-350
        } catch (error: Exception) {
            null // :352-353
        }
    }

    /** 源 `:357` `getCurrentPlanId`——缺键回落空串，读库异常回落 [localCurrentPlanId]。 */
    suspend fun getCurrentPlanId(store: JsonStore): String {
        return try {
            val currentPlanId: String = store.readString(CURRENT_PLAN_KEY) ?: "" // :359-360
            localCurrentPlanId = currentPlanId
            currentPlanId
        } catch (error: Exception) {
            localCurrentPlanId // :364-365
        }
    }

    /**
     * 源 `:368` `replaceMyPlans`——整块替换我的计划 + 当前指针。
     *
     * 指针回退逻辑（源 `:370-373`）：若给定 `currentPlanId` 不在新列表中，
     * 回退为新列表首个 id；新列表为空则回退为 `''`。
     *
     * **修复**：源把写入异常静默吞掉（`:382-383`），失败与成功对调用方不可区分——
     * 这是「UI 弹成功、数据没落地」的另一半根因。现改为**返回落盘结果**，
     * 并只在写入成功后更新内存回落缓存（避免读库异常时缓存谎报新值）。
     *
     * @return `true` = 两个键均写入成功；`false` = 写入抛错（内存缓存保持旧值）。
     */
    suspend fun replaceMyPlans(store: JsonStore, plans: List<UserPlan>, currentPlanId: String): Boolean {
        val nextPlans: List<UserPlan> = dedupeById(copyUserPlans(plans)) // :369
        var nextCurrentPlanId: String = currentPlanId // :370
        if (!containsPlanId(nextPlans, nextCurrentPlanId)) { // :371
            nextCurrentPlanId = if (nextPlans.isNotEmpty()) nextPlans[0].id else "" // :372
        }

        return try {
            store.writeString(STORE_KEY, JsonCodec.json.encodeToString(nextPlans)) // :380
            store.writeString(CURRENT_PLAN_KEY, nextCurrentPlanId) // :381
            localPlans = copyUserPlans(nextPlans) // :375
            localCurrentPlanId = nextCurrentPlanId // :376
            true
        } catch (error: Exception) {
            false // 源 :382-383 的静默吞掉已改：失败必须可被上层识别
        }
    }

    /**
     * 源 `:387` `setCurrentPlan`——只改当前指针，**不校验** planId 是否存在于我的计划
     * （源同此）；持久化异常静默吞掉。
     */
    suspend fun setCurrentPlan(store: JsonStore, planId: String) {
        localCurrentPlanId = planId // :388
        try {
            store.writeString(CURRENT_PLAN_KEY, planId) // :391
        } catch (error: Exception) {
            // 源 :392-393：吞掉。
        }
    }

    /**
     * 源 `:397` `removeMyPlan`——移除指定计划；若删的是当前计划，
     * 指针回退为剩余首个 id（无剩余则 `''`），随后整块落盘。
     */
    suspend fun removeMyPlan(store: JsonStore, planId: String) {
        val myPlans: List<UserPlan> = getMyPlans(store).filter { it.id != planId } // :398-399
        val currentId: String = getCurrentPlanId(store) // :400
        var nextCurrentPlanId: String = currentId // :401
        if (currentId == planId) { // :402
            nextCurrentPlanId = if (myPlans.isNotEmpty()) myPlans[0].id else "" // :403
        }
        replaceMyPlans(store, myPlans, nextCurrentPlanId) // :405
    }

    /** 源 `:408` `hasMyPlans`。 */
    suspend fun hasMyPlans(store: JsonStore): Boolean = getMyPlans(store).isNotEmpty()

    // --- 源 :413-439：今日训练判定 ------------------------------------------

    /**
     * 源 `:413` `getTodayTraining`——先按 `dayOfWeek` 命中，未中再按 `dayLabel` 兜底。
     *
     * 测试缝：`todayOfWeek` 默认取当前星期（JS `getDay()` 口径：0=周日…6=周六），
     * 可注入以构造确定性日期（源从 `new Date()` 直取，本侧为可测性显式参数化）。
     */
    fun getTodayTraining(plan: UserPlan, todayOfWeek: Int = currentDayOfWeek()): TrainingDay? {
        for (day in plan.days) { // :415-421
            val dayOfWeek: List<Int>? = day.dayOfWeek
            if (!dayOfWeek.isNullOrEmpty() && todayOfWeek in dayOfWeek) {
                return day
            }
        }
        for (day in plan.days) { // :423-429
            if (getDayNumberFromLabel(day.dayLabel) == todayOfWeek) {
                return day
            }
        }
        return null // :430
    }

    /** 源 `:432` `isTrainingDay`。 */
    fun isTrainingDay(plan: UserPlan, todayOfWeek: Int = currentDayOfWeek()): Boolean =
        getTodayTraining(plan, todayOfWeek) != null // :433

    /** 源 `:436` `getTodayLabel`——当前星期中文名（`星期X`）。 */
    fun getTodayLabel(todayOfWeek: Int = currentDayOfWeek()): String =
        TODAY_LABELS[todayOfWeek] // :438

    // --- 内部：拷贝 / 辅助 ---------------------------------------------------

    /**
     * 测试缝：清空内存回落缓存。单例在 JVM 内跨用例存活，测试每例前调用以复位
     * （对应 `GoalRepository.clearLocal` 的既有约定）。
     */
    fun clearLocal() {
        localPlans = emptyList()
        localCurrentPlanId = ""
    }

    /** 源 `:441` `containsPlanId`。 */
    private fun containsPlanId(plans: List<UserPlan>, planId: String): Boolean =
        plans.any { it.id == planId } // :442-448

    /**
     * 按 id 去重（保序，保留首次出现）。
     *
     * 历史数据里可能残留同一 id 的重复副本（旧 `enableUserPlan` 的追加写入 + 备份导入
     * 合并都可能产生）；落盘前收敛，避免读端 `firstOrNull { it.id == currentId }` 命中哪份
     * 全凭顺序。**不按名字去重**：名字相同但 id 不同的两份是用户真实数据（克隆与导入件），
     * 由启用/删除路径显式处理。
     */
    private fun dedupeById(plans: List<UserPlan>): List<UserPlan> {
        val seen: MutableSet<String> = mutableSetOf()
        val result: MutableList<UserPlan> = mutableListOf()
        plans.forEach { plan ->
            if (seen.add(plan.id)) {
                result.add(plan)
            }
        }
        return result
    }

    /** 源 `:450` `createUserPlan`——id = `user_plan_<时间戳>`，`enabledAt` = 时间戳。 */
    private fun createUserPlan(
        name: String,
        coverColor: String,
        targetAudience: String,
        weeklyFrequency: String,
        description: String,
        days: List<TrainingDay>,
    ): UserPlan = UserPlan(
        id = "user_plan_" + System.currentTimeMillis(), // :458 源 `'user_plan_' + Date.now()`
        name = name,
        coverColor = coverColor,
        targetAudience = targetAudience,
        weeklyFrequency = weeklyFrequency,
        description = description,
        days = copyTrainingDays(days), // :465
        enabledAt = System.currentTimeMillis(), // :466
    )

    /** 源 `:471` `copyUserPlans`。 */
    private fun copyUserPlans(source: List<UserPlan>): List<UserPlan> = source.map { copyUserPlan(it) } // :472-477

    /** 源 `:479` `copyUserPlan`——重建计划并深拷贝 days。 */
    private fun copyUserPlan(source: UserPlan): UserPlan = source.copy(days = copyTrainingDays(source.days)) // :482-490

    /** 源 `:493` `copyTrainingDays`——逐日重建，深拷贝 `dayOfWeek` 与 `exercises`。 */
    private fun copyTrainingDays(source: List<TrainingDay>): List<TrainingDay> = source.map { day ->
        TrainingDay(
            dayLabel = day.dayLabel,
            dayOfWeek = copyDayOfWeek(day.dayOfWeek), // :499
            exercises = copyExercises(day.exercises), // :500
        )
    }

    /** 源 `:507` `copyExercises`——逐动作重建（Kotlin `data class` 不可变，重建即深拷贝）。 */
    private fun copyExercises(source: List<ExerciseRef>): List<ExerciseRef> = source.map {
        ExerciseRef(
            name = it.name,
            targetMuscle = it.targetMuscle,
            sets = it.sets,
            reps = it.reps,
        )
    }

    /** 源 `:522` `copyDayOfWeek`——`null` 透传（缺省=自动分配），否则复制为新列表。 */
    private fun copyDayOfWeek(source: List<Int>?): List<Int>? = source?.toList() // :523-531

    /** 源 `:266-270` `getDayNumberFromLabel`——按 `周X` 前缀反推 JS `getDay()` 值。 */
    private fun getDayNumberFromLabel(label: String): Int = when {
        "周一" in label -> 1
        "周二" in label -> 2
        "周三" in label -> 3
        "周四" in label -> 4
        "周五" in label -> 5
        "周六" in label -> 6
        "周日" in label -> 0
        else -> -1
    }

    /** 当前星期（JS `Date.getDay()` 口径：0=周日…6=周六）。 */
    private fun currentDayOfWeek(): Int {
        val calendar: Calendar = Calendar.getInstance()
        return calendar.get(Calendar.DAY_OF_WEEK) - 1 // Calendar 周日=1 → 0=周日
    }
}
