package com.fittracker.app.ui.screens.home

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import com.fittracker.app.R
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.TrainingPlanRepository
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.WeekWindow
import com.fittracker.app.data.service.WorkoutDraftService
import com.fittracker.app.data.service.hasWorkoutDraftProgress
import com.fittracker.app.data.service.WorkoutRepository
import com.fittracker.app.data.service.WorkoutSessionService
import com.fittracker.app.data.service.currentLanguageTag
import com.fittracker.app.data.service.stats.HomePlanService
import com.fittracker.app.ui.screens.plan.dayFocusMuscles

/**
 * 首页（「首页」Tab）的状态持有者。
 *
 * 状态与装载从 [HomeScreen] 迁入——`viewModel()` 取 NavBackStackEntry 作用域实例，
 * tab 切换（`saveState=true`）取回同一实例，首帧即真数据、装载只跑一次。
 *
 * **装载为何是公开 `suspend`**：`viewModelScope` 在 `Dispatchers.Main` 上调度，
 * Robolectric 单测无 Main Looper 会死锁（Wave 1 PlanViewModel 的教训）；
 * 公开 `suspend` 让屏侧 `LaunchedEffect(Unit)` 正常调用、测试 `runBlocking` 直接驱动。
 */
class HomeViewModel(application: Application) : AndroidViewModel(application) {

    private val store: JsonStore = JsonStore(application.appDataStore)

    // ── 数据态（原 HomeScreen.kt:85-97 的 remember 状态） ──────────────────

    var dateText by mutableStateOf("")
        private set
    var greetingText by mutableStateOf("")
        private set
    var weeklyProgressPercent by mutableStateOf(0)
        private set
    var todayTitle by mutableStateOf("")
        private set
    var todayMuscleText by mutableStateOf("")
        private set
    var todayStatusText by mutableStateOf("")
        private set
    var todayExerciseCount by mutableStateOf(0)
        private set
    var todayDurationMinutes by mutableStateOf(0)
        private set
    var todayMuscleGroupCount by mutableStateOf(0)
        private set
    var weeklyPlannedDays by mutableStateOf(0)
        private set
    var weeklyTrainedCount by mutableStateOf(0)
        private set

    /**
     * 是否存在可续练的训练草稿。
     *
     * 决定首页主 CTA 的文案与去向：有草稿时是「继续训练」→ 直达 active 屏。
     * 不能让它走「开始训练 → 预览」那条路——预览页的 saveDraft 会用**今日计划**
     * 覆盖草稿，进而导致「第二次训练动作不匹配」与「收起后没有胶囊」。
     */
    var resumeAvailable by mutableStateOf(false)
        private set
    var weekDays by mutableStateOf<List<HomeWeekDay>>(emptyList())
        private set

    /**
     * 装载首页数据。逐行等价迁移自原 `HomeScreen.kt:98-175` 的 `LaunchedEffect(Unit)`。
     * 见 [HomeWeekDay]/[buildHomeWeekDays]/[weekDateKey] 的迁入说明。
     */
    suspend fun load() {
        val res = getApplication<Application>().resources

        // 草稿态先读：它只影响主 CTA 的文案与去向，不参与今日训练卡的派生。
        resumeAvailable = WorkoutDraftService.getDraft(store)
            ?.let { hasWorkoutDraftProgress(it) } == true

        // 日期与问候（`HomeContent.applyDateAndGreeting`）
        val now = java.util.Calendar.getInstance()
        val weekdayRes = intArrayOf(
            R.string.home_weekday_sunday,
            R.string.home_weekday_monday,
            R.string.home_weekday_tuesday,
            R.string.home_weekday_wednesday,
            R.string.home_weekday_thursday,
            R.string.home_weekday_friday,
            R.string.home_weekday_saturday,
        )
        dateText = res.getString(
            R.string.home_date_format,
            now.get(java.util.Calendar.MONTH) + 1,
            now.get(java.util.Calendar.DAY_OF_MONTH),
            res.getString(weekdayRes[now.get(java.util.Calendar.DAY_OF_WEEK) - 1]),
        )
        greetingText = res.getString(
            when (now.get(java.util.Calendar.HOUR_OF_DAY)) {
                in 5..10 -> R.string.home_greeting_morning
                in 11..17 -> R.string.home_greeting_afternoon
                else -> R.string.home_greeting_evening
            },
        )

        val sessions = WorkoutRepository.getSessions(store)
        val weekStart = SettingsService.loadSettings(store).weekStart
        val stats = WorkoutSessionService.weeklyStats(sessions, System.currentTimeMillis(), weekStart)
        val trainingDates = WorkoutSessionService.trainingDates(sessions)
        weeklyTrainedCount = stats.count
        weekDays = buildHomeWeekDays(trainingDates, weekStart)

        val current = TrainingPlanRepository.getCurrentPlan(store)
        if (current != null) {
            val todayTraining = TrainingPlanRepository.getTodayTraining(current)
            // 预置计划模型无单次时长字段；目标设置能力未引入时 sessionMinutes 取 0
            // （对齐鸿蒙同口径：未设置目标时为 0，属数据缺口）
            val summary = HomePlanService.createSummaryFromCurrentPlan(
                current,
                TrainingPlanRepository.getTodayLabel(),
                todayTraining,
                0,
            )
            todayTitle = summary.todayTitle
            todayMuscleText = if (todayTraining == null) {
                res.getString(R.string.home_today_no_training)
            } else {
                dayFocusMuscles(todayTraining)
            }
            todayStatusText = res.getString(
                if (summary.hasTodayWorkout) R.string.home_status_training_day else R.string.home_status_rest_day,
            )
            todayExerciseCount = summary.todayExerciseCount
            todayDurationMinutes = summary.sessionMinutes
            todayMuscleGroupCount = summary.todayMuscleGroupCount
            weeklyPlannedDays = summary.weeklyDays
            weeklyProgressPercent = if (summary.weeklyDays > 0) {
                ((stats.count * 100) / summary.weeklyDays).coerceAtMost(100)
            } else {
                0
            }
        } else {
            // 空态（`HomeContent.applyEmptyState`）
            todayTitle = res.getString(R.string.home_empty_plan_title)
            todayMuscleText = res.getString(R.string.home_empty_plan_subtitle)
            todayStatusText = res.getString(R.string.home_status_pending)
            todayExerciseCount = 0
            todayDurationMinutes = 0
            todayMuscleGroupCount = 0
            weeklyPlannedDays = 0
            weeklyProgressPercent = 0
        }
    }
}

// ── 周节奏数据（对齐鸿蒙 `HomeContent.HomeWeekDayItem` / `createWeekDayItems`） ──
//
// 从 HomeScreen.kt 迁入——这些是「状态派生」逻辑（`weekDays` 的构造），随状态一起
// 移入 ViewModel。`weekRangeSubtitle` 因依赖 `stringResource`（@Composable）仍留在屏内。

/** 周节奏单日：`active` = 该日有训练记录。 */
data class HomeWeekDay(val label: String, val date: Int, val active: Boolean)

/**
 * 周节奏七格：自**设置周首日**起七天（标签序唯一真源 [WeekWindow.dayLabels]），
 * 按训练日期集合标记 `active`。
 */
private fun buildHomeWeekDays(trainingDates: List<String>, weekStart: WeekStart): List<HomeWeekDay> {
    val calendar = java.util.Calendar.getInstance()
    val dayOfWeek = calendar.get(java.util.Calendar.DAY_OF_WEEK) - 1 // 0 = 周日
    calendar.add(
        java.util.Calendar.DAY_OF_MONTH,
        -WeekWindow.offsetFromWeekStart(dayOfWeek, weekStart),
    )
    val labels = WeekWindow.dayLabels(weekStart, currentLanguageTag())
    return (0..6).map { index ->
        val date = (calendar.clone() as java.util.Calendar).apply {
            add(java.util.Calendar.DAY_OF_MONTH, index)
        }
        HomeWeekDay(
            label = labels[index],
            date = date.get(java.util.Calendar.DAY_OF_MONTH),
            active = weekDateKey(date) in trainingDates,
        )
    }
}

/** `YYYY-MM-DD` 键（`HomeContent.formatDateKey`）。 */
private fun weekDateKey(date: java.util.Calendar): String {
    val pad = { value: Int -> if (value < 10) "0$value" else value.toString() }
    return "${date.get(java.util.Calendar.YEAR)}-${pad(date.get(java.util.Calendar.MONTH) + 1)}-" +
        pad(date.get(java.util.Calendar.DAY_OF_MONTH))
}
