package com.fittracker.app.ui.screens.plans

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import com.fittracker.app.R
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.TrainingPlanRepository

/**
 * 计划组页的状态持有者。
 *
 * 状态与装载从 [PlansScreen] 迁入——`viewModel()` 取 NavBackStackEntry 作用域实例，
 * 返回本页取回同一实例、装载只跑一次。
 *
 * `currentName`/`currentMeta` 为 `String?`：`null` 表示尚未启用计划（对应
 * `PlansContent` 的「空＝尚未启用」语义，由 `CurrentPlanCard` 渲染空态）。
 */
class PlansViewModel(application: Application) : AndroidViewModel(application) {

    private val store: JsonStore = JsonStore(application.appDataStore)

    var currentName by mutableStateOf<String?>(null)
        private set
    var currentMeta by mutableStateOf<String?>(null)
        private set

    /**
     * 装载当前计划。逐行等价迁移自原 `PlansScreen.kt:96-108` 的 `LaunchedEffect(Unit)`。
     * 公开 `suspend`（同其他屏：runBlocking 可驱动）。
     *
     * **修复**：无当前计划时回置 `null`——原实现只在 `current != null` 时赋值，
     * 计划被移除/切走后本页停留旧卡片文案，重进也不刷新。
     */
    suspend fun load() {
        val res = getApplication<Application>().resources
        val current = TrainingPlanRepository.getCurrentPlan(store)
        if (current != null) {
            currentName = current.name.ifEmpty { res.getString(R.string.plans_current_fallback_name) }
            // 元信息口径同计划 Tab（`PlanContent.applyCurrentPlanState`）
            currentMeta = res.getString(
                R.string.plans_current_meta,
                current.targetAudience,
                current.days.size,
                current.weeklyFrequency,
            )
        } else {
            currentName = null
            currentMeta = null
        }
    }
}
