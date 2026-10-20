package com.fittracker.app.ui.screens.plan

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fittracker.app.R
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.StoreNames
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.TrainingPlanRepository
import com.fittracker.app.data.service.WorkoutRepository
import com.fittracker.app.data.service.WorkoutSessionService
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

/**
 * 计划屏（「计划」Tab）的状态持有者。
 *
 * **为什么存在**：状态原先由 [PlanScreen] 的 `remember {}` 持有，而 Tab 切换会重建屏幕
 * （`navigateToTab` 的 `saveState/restoreState` 只保存 `rememberSaveable` 状态，本屏全部
 * 用 `remember`），导致每次切回都经历「复位到初值 → 装载重跑 → 真数据到达」的二次渲染。
 *
 * 把状态与装载移到 ViewModel 后，`viewModel()` 在 NavHost 的 `composable {}` 内取最近的
 * `ViewModelStoreOwner`（即 `NavBackStackEntry`）；`saveState=true` 时该 store 不被清除，
 * 故切回时取回**同一实例**——状态与已装载数据均存活，首帧即真数据。
 *
 * **服务层用法不变**：仍直调 `object` 单例 Service（项目约定），不引入 Repository 抽象。
 * 文案资源经 `getApplication<Application>().resources` 解析（ViewModel 无 `LocalResources`）。
 */
class PlanViewModel(application: Application) : AndroidViewModel(application) {

    private val store: JsonStore = JsonStore(application.appDataStore)

    // ── 数据态（原 PlanScreen.kt:110-117 的 remember 状态） ──────────────────
    //
    // 初值仍取空态（与装载逻辑的 else 分支同值）——首帧语义不变，但**只装载一次**。

    /** `.master-card` 计划名。 */
    var planName by mutableStateOf("")
        private set

    /** `.master-card` 副题（目标人群 · N 练分化 · 每周频次）。 */
    var planMeta by mutableStateOf("")
        private set

    /** 进度条右侧文案（本周 N / M 天）。 */
    var weeklyProgress by mutableStateOf("")
        private set

    /** 进度条已完成的百分比（0f..1f）。 */
    var progressFraction by mutableStateOf(0f)
        private set

    /** 日期卡数据（「第 N 天 · 肌群」）。 */
    var days by mutableStateOf<List<FtPlanDay>>(emptyList())
        private set

    /** 当前卡片堆索引（原型 `syncActive` 的 `card`）。 */
    var activeIndex by mutableIntStateOf(0)
        private set

    /** 当前计划 id；空串表示无当前计划（写回 `PLAN_STATE` 时用）。 */
    var planId by mutableStateOf("")
        private set

    /**
     * 装载是否已完成。用于抑制「装载前的卡片位置回写」——装载完成前 `activeIndex` 还是初值 0，
     * 此时回写会覆盖用户已保存的位置（原 `PlanScreen` 用 `restored` 做同一件事）。
     */
    var restored by mutableStateOf(false)
        private set

    // ── 装载 ────────────────────────────────────────────────────────────────

    /**
     * 装载当前计划。逐行等价迁移自原 `PlanScreen.kt:119-150` 的 `LaunchedEffect(Unit)`：
     * ① 读设置周首日 → ② 读当前计划 → ③ 有则填真数据 / 无则空态 →
     * ④ 恢复上次浏览的卡片位置（带 clamp）。
     *
     * **为什么是公开 `suspend` 而非 `init{ viewModelScope.launch }`**：
     * `viewModelScope` 在 `Dispatchers.Main` 上调度；Robolectric 单测没有驱动 Main Looper，
     * `viewModelScope.launch` 的协程永不执行，测试里 `join()` 会永久阻塞。改成公开 `suspend` 后：
     * - 屏侧 `LaunchedEffect(Unit) { vm.load() }` 在 Main dispatcher 上正常调用；
     * - 单测 `runBlocking { vm.load() }` 在调用线程直接驱动，不经 Main dispatcher。
     *
     * 幂等性由「状态字段保留旧值 + 屏重建不重跑 LaunchedEffect」保证：VM 存活期间
     * `load()` 由屏侧的 `LaunchedEffect(Unit)` 只触发一次（组件重建不重跑）。
     */
    suspend fun load() {
        val res = getApplication<Application>().resources
        val weekStart = SettingsService.loadSettings(store).weekStart
        val current = TrainingPlanRepository.getCurrentPlan(store)
        if (current != null) {
            planId = current.id
            days = ftPlanDaysFromUserPlan(current)
            planName = current.name.ifEmpty { res.getString(R.string.plan_fallback_name) }
            planMeta = res.getString(
                R.string.plan_meta_format,
                current.targetAudience,
                current.days.size,
                current.weeklyFrequency,
            )
            val stats = WorkoutSessionService.weeklyStats(
                WorkoutRepository.getSessions(store),
                System.currentTimeMillis(),
                weekStart,
            )
            val total = current.days.size
            weeklyProgress = res.getString(R.string.plan_week_progress, stats.count, total)
            progressFraction = if (total > 0) (stats.count.toFloat() / total).coerceIn(0f, 1f) else 0f
        } else {
            // 空态（`PlanContent.applyEmptyState`）
            days = emptyList()
            planName = res.getString(R.string.plan_fallback_name)
            planMeta = res.getString(R.string.plan_empty_meta)
            weeklyProgress = res.getString(R.string.plan_week_progress, 0, 0)
            progressFraction = 0f
        }
        // 恢复上次浏览的卡片位置（原型 plan.html:743-746：localStorage 'fittracker-plan-state'
        // 的 `card` 字段）。原型不做边界校验，本侧补 clamp——天数变化后旧索引会落到空位。
        val saved = PlanStateWire.decode(store.readString(StoreNames.PLAN_STATE))?.card
        activeIndex = if (saved != null && saved in days.indices) saved else 0
        restored = true
    }

    // ── 交互 ────────────────────────────────────────────────────────────────

    /**
     * 用户滑动卡片堆：切到指定索引。
     *
     * 越界忽略（`days` 装载前为空，任何索引都越界）；索引未变不重复写。
     * 变更后立即回写位置（对应原 `LaunchedEffect(activeIndex, restored)` 的写回）。
     */
    fun selectCard(index: Int) {
        if (index !in days.indices || index == activeIndex) return
        activeIndex = index
        persistActiveIndex()
    }

    /** 卡片位置回写（原型 `syncActive`，plan.html:820-824）。装载完成前不回写。 */
    private fun persistActiveIndex() {
        if (!restored) return
        viewModelScope.launch {
            store.writeString(StoreNames.PLAN_STATE, PlanStateWire.encode(planId, activeIndex))
        }
    }
}

/**
 * 卡片位置的落盘形态——逐字段对齐原型 `localStorage['fittracker-plan-state']`
 * （`{ plan: activePlan, card: activeCard }`，plan.html:822）。
 *
 * Android 侧暂无计划选择器（原型 `plan` 字段对应多计划切换），故 `plan` 只作记录；
 * 恢复语义只消费 `card`。
 *
 * 从 `PlanScreen.kt` 移入本文件——读写两端（装载恢复 / 交互回写）现均在本 ViewModel 内，
 * 类型不再需要跨文件可见。
 */
@Serializable
internal data class PlanStateWire(val plan: String = "", val card: Int = 0) {

    companion object {

        fun encode(planId: String, card: Int): String =
            JsonCodec.json.encodeToString(PlanStateWire.serializer(), PlanStateWire(planId, card))

        /** 宽容解析：无存档 / 坏 JSON → `null`，由调用方回落默认位置。 */
        fun decode(raw: String?): PlanStateWire? = if (raw.isNullOrEmpty()) {
            null
        } else {
            runCatching { JsonCodec.json.decodeFromString(PlanStateWire.serializer(), raw) }.getOrNull()
        }
    }
}
