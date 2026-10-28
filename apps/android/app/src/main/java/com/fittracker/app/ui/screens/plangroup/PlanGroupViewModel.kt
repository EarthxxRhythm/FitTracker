package com.fittracker.app.ui.screens.plangroup

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import com.fittracker.app.R
import com.fittracker.app.data.model.UserPlan
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.PlanProgressService
import com.fittracker.app.data.service.PlanProgressSummary
import com.fittracker.app.data.service.TrainingPlanRepository
import com.fittracker.app.data.service.WorkoutRepository

/**
 * 计划组详细页的状态持有者（「使用此计划」的真实启用链路）。
 *
 * **为什么存在**：本屏原先的 CTA 只做两件事——把按钮置灰 1600ms、弹一句「已切换到…」。
 * 它**从未调用** [TrainingPlanRepository.enablePlan]，也没有任何 `JsonStore` 实例，
 * 所以点完什么都不会落盘：计划页 / 首页 / 训练预览仍是旧计划，用户看到的就是
 * 「计划组切换功能没用」。
 *
 * 现在把「启用 + 回读校验 + 提示」收进本 ViewModel：
 * 1. 落盘：[TrainingPlanRepository.enablePlan] 返回 `null` 即写入失败；
 * 2. 校验：落盘后回读当前指针→预置 id，只有真的指向本计划才认为切换成功；
 * 3. 提示：成功/失败两套文案，**失败不再谎报成功**（鸿蒙侧同口径修复）。
 *
 * 装载语义与 `PlanViewModel` / `PlansViewModel` 一致：公开 `suspend` 由屏侧
 * `LaunchedEffect` 驱动（Robolectric 单测可直接 `runBlocking` 驱动，不依赖 Main Looper）。
 */
class PlanGroupViewModel(application: Application) : AndroidViewModel(application) {

    private val store: JsonStore = JsonStore(application.appDataStore)

    /** 本页展示的计划组是否已是当前计划（决定 CTA 文案与可点性）。 */
    var isCurrent by mutableStateOf(false)
        private set

    /** 启用请求进行中：防连点，也用于禁用 CTA。 */
    var busy by mutableStateOf(false)
        private set

    /** 浮层文案（屏侧 1800ms 后调 [dismissToast] 清空）。 */
    var toast by mutableStateOf<String?>(null)
        private set

    /** 该计划的真实训练进度（由已落库会话按 planId 聚合）；无数据时为零态。 */
    var progress by mutableStateOf(PlanProgressService.createEmpty(""))
        private set

    /** 切换成功次数——屏侧以它为键触发返回列表（对齐鸿蒙「启用后 back」）。 */
    var switchedTick by mutableStateOf(0)
        private set

    /**
     * 装载：判断 `planId` 是否已是当前计划，并聚合该计划的训练进度
     * （对齐鸿蒙 `PlanGroupDetailContent` 的 isCurrent + loadProgress）。
     */
    suspend fun load(planId: String) {
        isCurrent = planId.isNotEmpty() && TrainingPlanRepository.getCurrentPresetId(store) == planId
        progress = try {
            // 会话里落的是 `UserPlan.id`（`user_plan_<时间戳>`），本页拿到的是预置 id；
            // 当前计划就是本组时把它的 `UserPlan.id` 一并纳入匹配，否则聚合会全部落空。
            val ids = mutableListOf(planId)
            val current = TrainingPlanRepository.getCurrentPlan(store)
            if (current != null && TrainingPlanRepository.getPresetIdForPlan(current) == planId) {
                ids.add(current.id)
            }
            PlanProgressService.createSummaryForIds(WorkoutRepository.getSessions(store), planId, ids)
        } catch (e: Exception) {
            // 会话读取失败保持零态，不阻塞页面其余部分（同鸿蒙口径）。
            PlanProgressService.createEmpty(planId)
        }
    }

    /** 该训练日是否已完成过（供「每周节奏」标记）。 */
    fun isDayTrained(dayId: String): Boolean = PlanProgressService.isDayTrained(progress, dayId)

    /** 该训练日的完成次数（供训练日面板显示「已练 N 次」）。 */
    fun sessionCountForDay(dayId: String): Int = PlanProgressService.sessionCountForDay(progress, dayId)

    /**
     * 启用该计划组（真正落盘）。
     *
     * 幂等：已是当前计划时直接返回（不重写、不追加副本）。
     */
    suspend fun usePlan(planId: String, planName: String) {
        if (planId.isEmpty() || busy || isCurrent) {
            return
        }
        busy = true
        val enabled: UserPlan? = TrainingPlanRepository.enablePlan(store, planId)
        // 回读校验：落盘成功 ≠ 指针已指向本计划（写入可能只成功一半），以回读为准
        val currentPresetId: String = TrainingPlanRepository.getCurrentPresetId(store)
        isCurrent = currentPresetId == planId
        busy = false
        if (enabled != null && isCurrent) {
            toast = getApplication<Application>().resources.getString(R.string.plangroup_toast_switched, planName)
            // 切换成功 → 屏侧返回计划组列表：列表重载后顶部「当前计划」卡立即反映这次切换。
            switchedTick += 1
        } else {
            toast = getApplication<Application>().resources.getString(R.string.plangroup_toast_switch_failed)
        }
    }

    /** 动作行等屏内浮层复用同一出口。 */
    fun showToast(message: String) {
        toast = message
    }

    /** 浮层自动消失（原型 `showToast` 的 1800ms）。 */
    fun dismissToast() {
        toast = null
    }
}
