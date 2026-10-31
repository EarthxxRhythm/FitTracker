package com.fittracker.app.ui.screens.review

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fittracker.app.R
import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.BodyRecordService
import com.fittracker.app.data.service.ContentRepository
import com.fittracker.app.data.service.PlanProgressService
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.TrainingPlanRepository
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.WeekWindow
import com.fittracker.app.data.service.WeeklyStats
import com.fittracker.app.data.service.WeightUnit
import com.fittracker.app.data.service.WeightUtils
import com.fittracker.app.data.service.WorkoutRepository
import com.fittracker.app.data.service.WorkoutSessionService
import com.fittracker.app.data.service.currentLanguageTag
import com.fittracker.app.data.service.stats.PersonalRecordService
import kotlinx.coroutines.launch

/**
 * 回顾页（「回顾」Tab）的状态持有者。
 *
 * 数据态与装载从 [ReviewScreen] 迁入——`viewModel()` 取 NavBackStackEntry 作用域实例，
 * tab 切换（`saveState=true`）取回同一实例，首帧即真数据、装载只跑一次。
 *
 * **迁移边界**：
 * - 迁入：全部数据态（~25 个）与 `LaunchedEffect(Unit)` 装载（周/月尺度派生、1RM、体重记录）。
 * - 留屏内：`scale`/`muscleMode`/`selectedMuscle`/`effortMetric`/`goalModalOpen`
 *   等纯 UI 交互态；`data`/`goalLineY` 等渲染期派生值也留屏内（它们随 UI 态变化）。
 *
 * `load()` 公开 `suspend`（同其他屏：runBlocking 可驱动，规避 Robolectric Main dispatcher 死锁）。
 */
class ReviewViewModel(application: Application) : AndroidViewModel(application) {

    private val store: JsonStore = JsonStore(application.appDataStore)

    // ── 数据态（原 ReviewScreen.kt:124-197 的 remember 状态） ────────────────
    //
    // 首帧语义保持 0bef901/61fe4f7 的收口口径：纯日期计算的字段首帧即真值，
    // 依赖数据的字段首帧空态，装载后替换。迁移后 VM 只装载一次。

    /** 体重目标（kg）；`0` = 从未设置（目标线与按钮走空态）。 */
    var goal by mutableDoubleStateOf(0.0)
        private set

    var oneRmRows by mutableStateOf<List<OneRmRow>>(emptyList())
        private set
    var weekStats by mutableStateOf<WeeklyStats?>(null)
        private set
    var weekHeadText by mutableStateOf("")
        private set
    var monthHeadText by mutableStateOf("")
        private set
    var badgeText by mutableStateOf(FtReviewModel.BADGE_IDLE)
        private set
    var monthStats by mutableStateOf<WeeklyStats?>(null)
        private set
    var chartLoKg by mutableDoubleStateOf(0.0)
        private set
    var chartHiKg by mutableDoubleStateOf(0.0)
        private set
    var weightCurrent by mutableStateOf<String?>(null)
        private set
    var weightDelta by mutableStateOf("")
        private set
    var weightPoints by mutableStateOf<List<Pair<Float, Float>>>(emptyList())
        private set
    var weightUnit by mutableStateOf(WeightUnit.KG)
        private set
    var hasWeightRecords by mutableStateOf(false)
        private set
    var weightDeltaValue by mutableStateOf("")
        private set
    var effortLevels by mutableStateOf<List<Int>>(emptyList())
        private set
    var muscleVolume by mutableStateOf<List<Int>>(emptyList())
        private set
    var reviewSessions by mutableStateOf<List<WorkoutSession>>(emptyList())
        private set
    var reviewWeekStart by mutableStateOf(WeekStart.MONDAY)
        private set
    var reviewNow by mutableStateOf(0L)
        private set

    /** 当前启用的计划名；null = 尚未启用计划。回顾此前完全不感知计划归属。 */
    var currentPlanName by mutableStateOf<String?>(null)
        private set

    /** 当前计划下的训练次数（按 `session.planId` 聚合）；无计划时为 0。 */
    var currentPlanSessionCount by mutableStateOf(0)
        private set

    /**
     * 装载回顾数据。逐行等价迁移自原 `ReviewScreen.kt:198-292` 的 `LaunchedEffect(Unit)`。
     */
    suspend fun load() {
        val res = getApplication<Application>().resources
        val now = System.currentTimeMillis()
        val settings = SettingsService.loadSettings(store)
        val weekStart = settings.weekStart
        // 体重目标：`0` = 从未设置（目标线与按钮走空态）。
        goal = settings.weightGoalKg
        weightUnit = UserProfileService.loadProfile(store).weightUnit
        // 周/月尺度抬头：纯日期计算（与数据有无无关）
        weekHeadText = res.getString(R.string.review_head_week, WeekWindow.weekRangeText(now, weekStart, currentLanguageTag()))
        val monthCal = java.util.Calendar.getInstance().apply { timeInMillis = now }
        monthHeadText = res.getString(R.string.review_head_month, monthCal.get(java.util.Calendar.MONTH) + 1)
        val sessions = WorkoutRepository.getSessions(store)
        reviewSessions = sessions
        reviewWeekStart = weekStart
        reviewNow = now
        // 计划归属：会话里的 planId 一直存在但此前无人读取，回顾因此看不到「练的是哪个计划」。
        // 与计划组详情共用 PlanProgressService 的聚合口径。
        val currentPlan = TrainingPlanRepository.getCurrentPlan(store)
        if (currentPlan == null) {
            currentPlanName = null
            currentPlanSessionCount = 0
        } else {
            currentPlanName = currentPlan.name
            // 会话里落的是 `UserPlan.id`（`user_plan_<时间戳>`）；预置 id 一并纳入匹配，
            // 否则按预置 id 聚合会全部落空。
            val presetId = TrainingPlanRepository.getPresetIdForPlan(currentPlan)
            val ids = mutableListOf(currentPlan.id)
            if (presetId.isNotEmpty()) ids.add(presetId)
            currentPlanSessionCount = PlanProgressService
                .createSummaryForIds(sessions, presetId, ids)
                .totalSessions
        }
        // 概览徽标与月度汇总：无会话即空态（徽标「待积累」、月度统计 null → `--`）。
        badgeText = FtReviewModel.badgeText(sessions, now, weekStart)
        monthStats = FtReviewModel.monthlyStats(sessions, now)
        if (sessions.isNotEmpty()) {
            weekStats = WorkoutSessionService.weeklyStats(sessions, now, weekStart)
            // 努力程度（近 8 次训练的整体 RPE）与肌群训练量：真实派生，供图表着色。
            effortLevels = FtReviewModel.effortLevels(sessions, 8)
            muscleVolume = FtReviewModel.muscleVolume(
                sessions,
                { exerciseId -> ContentRepository.getExercise(exerciseId)?.primaryMuscleIds.orEmpty() },
                8,
            )
            val details = PersonalRecordService.createRecordDetails(sessions)
            if (details.isNotEmpty()) {
                oneRmRows = details.take(4).map { detail ->
                    OneRmRow(
                        name = detail.exerciseName,
                        src = detail.bestDateText,
                        value = FtReviewModel.oneRmValueText(detail.bestOneRepMax.toDouble(), weightUnit),
                        unit = WeightUtils.unitLabel(weightUnit),
                    )
                }
            }
        }
        // W3-1 体重记录服务：有记录用真实值；无记录时主数值/脚注为 `--` 空态（不回落原型样例）。
        // 「较上月」脚注口径：近 30 天首尾之差（对齐原型 fittracker-review.html:1321 与鸿蒙侧）。
        val records = BodyRecordService.loadRecords(store)
        if (records.isNotEmpty()) {
            val monthTrend = BodyRecordService.monthTrend(records, now)
            val deltaKg = monthTrend?.deltaKg ?: BodyRecordService.weekDeltaKg(records, now)
            weightCurrent = FtReviewModel.weightCurrentText(records.last().kg, weightUnit)
            weightDelta = res.getString(
                R.string.review_weight_delta_month,
                FtReviewModel.weightDeltaValue(deltaKg, weightUnit) + " " + WeightUtils.unitLabel(weightUnit),
            )
            weightDeltaValue = FtReviewModel.weightDeltaValue(deltaKg, weightUnit)
            hasWeightRecords = true
            val trend = BodyRecordService.weekTrend(records, now, weekStart, currentLanguageTag())
            if (trend != null) {
                weightPoints = FtReviewModel.weightPoints(trend.values)
                // 量程随折线一起记录：目标线必须落在同一坐标系里，否则线位置是假的。
                chartLoKg = (trend.values.minOrNull() ?: 0f).toDouble()
                chartHiKg = (trend.values.maxOrNull() ?: 0f).toDouble()
            }
        } else {
            // 记录被清空（删除 / 切账号）时复位折线与量程——否则残留上一次的曲线与目标线。
            hasWeightRecords = false
            weightCurrent = null
            weightDelta = res.getString(R.string.review_weight_delta_month, FtReviewModel.EMPTY_VALUE)
            weightDeltaValue = ""
            weightPoints = emptyList()
            chartLoKg = 0.0
            chartHiKg = 0.0
        }
    }

    /**
     * 保存体重目标（目标弹窗的 onSave）。目标必须跨会话存在，否则每次进页都回到未设置态。
     * 更新本地状态 + 持久化（`SettingsService.saveWeightGoal`）。
     */
    fun saveGoal(value: Double) {
        goal = value
        viewModelScope.launch {
            SettingsService.saveWeightGoal(store, value)
        }
    }
}
