package com.fittracker.app.ui.screens.profile

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import com.fittracker.app.R
import com.fittracker.app.data.auth.AuthService
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.WeekWindow
import com.fittracker.app.data.service.WeightUnit
import com.fittracker.app.data.service.WeightUtils
import com.fittracker.app.data.service.WorkoutRepository
import com.fittracker.app.data.service.WorkoutSessionService
import com.fittracker.app.data.service.currentLanguageTag
import com.fittracker.app.data.service.stats.PersonalRecordService
import java.util.Calendar

/**
 * 个人页（「我的」Tab）的状态持有者。
 *
 * 状态与装载从 [ProfileScreen] 迁入——`viewModel()` 取 NavBackStackEntry 作用域实例，
 * tab 切换（`saveState=true`）取回同一实例，首帧即真数据、装载只跑一次。
 *
 * **装载为何是公开 `suspend`**：同 [PlanViewModel]/[HomeViewModel]——
 * `viewModelScope` 在 `Dispatchers.Main` 调度，Robolectric 单测无 Main Looper 会死锁；
 * 公开 `suspend` 让屏侧 `LaunchedEffect(Unit)` 调用、测试 `runBlocking` 直接驱动。
 */
class ProfileViewModel(application: Application) : AndroidViewModel(application) {

    private val store: JsonStore = JsonStore(application.appDataStore)

    // ── 数据态（原 ProfileScreen.kt:117-135 的 remember 状态） ────────────────
    //
    // 首帧仍取空态/占位（同 68e797f 的收口口径：不用原型样例「林默」），
    // 但**只装载一次**——切回时状态已保有真数据。

    var name by mutableStateOf("")
        private set
    var avatarInitial by mutableStateOf("")
        private set

    /** 头像色键（落在 `UserProfile.avatar`）；空串/未知键 = 默认翡翠。 */
    var avatarKey by mutableStateOf("")
        private set
    var weekValue by mutableStateOf(FtProfileModel.WEEK_VALUE)
        private set
    var weekSessions by mutableStateOf(FtProfileModel.WEEK_METRICS[0].value)
        private set
    var streakActive by mutableStateOf(List(FtProfileModel.STREAK_DAYS.size) { false })
        private set
    var streakDays by mutableIntStateOf(0)
        private set
    var achievements by mutableStateOf<List<FtProfileAchievement>>(emptyList())
        private set
    var streakLabels by mutableStateOf(WeekWindow.dayLabels(WeekStart.MONDAY, currentLanguageTag()))
        private set
    /** 周范围：纯日期计算、不依赖 IO——初值即真值（默认周首日），装载后按设置周首日重算。 */
    var weekRangeText by mutableStateOf(
        WeekWindow.weekRangeText(System.currentTimeMillis(), WeekStart.MONDAY, currentLanguageTag()),
    )
        private set
    var weightUnit by mutableStateOf(WeightUnit.KG)
        private set

    /**
     * 装载个人页数据。逐行等价迁移自原 `ProfileScreen.kt:136-166` 的 `LaunchedEffect(Unit)`。
     * 见 [currentStreakDays]/[weekActiveDays]/[pad2] 的迁入说明。
     */
    suspend fun load() {
        val weekStart = SettingsService.loadSettings(store).weekStart
        // 周概览 meta：真实周范围（纯日期计算，与数据有无无关）
        weekRangeText = WeekWindow.weekRangeText(System.currentTimeMillis(), weekStart, currentLanguageTag())
        val res = getApplication<Application>().resources
        val profile = UserProfileService.loadProfile(store)
        weightUnit = profile.weightUnit
        avatarKey = profile.avatar
        // 昵称优先取本地资料，其次回落账号显示名；两者皆空时用「—」占位。
        // 原实现在昵称非空时才赋值，新装用户 header 会渲染成一片空白（本次修复的根因）。
        val accountName = AuthService.currentSession(store)?.displayName?.trim().orEmpty()
        val displayName = when {
            profile.nickname.isNotBlank() -> profile.nickname.trim()
            accountName.isNotEmpty() -> accountName
            else -> res.getString(R.string.profile_name_none)
        }
        name = displayName
        avatarInitial = displayName.first().toString()
        val sessions = WorkoutRepository.getSessions(store)
        if (sessions.isNotEmpty()) {
            val stats = WorkoutSessionService.weeklyStats(sessions, System.currentTimeMillis(), weekStart)
            weekValue = (stats.duration / 60).toString()
            weekSessions = stats.count.toString()
            streakActive = weekActiveDays(WorkoutSessionService.trainingDates(sessions).toSet(), weekStart)
            streakLabels = WeekWindow.dayLabels(weekStart, currentLanguageTag())
            // 成就卡派生：连续天数 + 本周次数 + 最大重量 PR（无 PR 记录时该项不出现）。
            val trainingDates = WorkoutSessionService.trainingDates(sessions).toSet()
            streakDays = currentStreakDays(trainingDates)
            val best = PersonalRecordService.createRecordDetails(sessions).maxByOrNull { it.bestOneRepMax }
            achievements = FtProfileModel.derivedAchievements(
                streakDays = streakDays,
                weekSessions = stats.count,
                bestExerciseName = best?.exerciseName,
                bestWeightText = best?.let {
                    WeightUtils.formatWeight(it.bestWeight, weightUnit) + " " + WeightUtils.unitLabel(weightUnit)
                },
                bestDateText = best?.bestDateText,
            )
        }
    }
}

// ── 连续记录派生（从 ProfileScreen.kt 迁入，随状态一起移入 ViewModel） ────────

/**
 * 连续训练天数：从最近一个有训练的日子往回数。
 * `dates` 为 `YYYY-MM-DD` 集合（口径同 [WorkoutSessionService.trainingDates]）。
 */
private fun currentStreakDays(trainingDates: Set<String>): Int {
    val formatter = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
    val calendar = Calendar.getInstance()
    if (formatter.format(calendar.time) !in trainingDates) {
        calendar.add(Calendar.DAY_OF_MONTH, -1)
    }
    var count = 0
    while (formatter.format(calendar.time) in trainingDates) {
        count++
        calendar.add(Calendar.DAY_OF_MONTH, -1)
    }
    return count
}

/**
 * 本设置周（周首由 [weekStart] 决定）每天是否有训练——返回长度 7 的布尔表，索引 0 = 周首日。
 */
private fun weekActiveDays(dates: Set<String>, weekStart: WeekStart): List<Boolean> {
    val weekStartDay = Calendar.getInstance().apply {
        val jsDayOfWeek = get(Calendar.DAY_OF_WEEK) - 1 // 0 = 周日
        add(Calendar.DAY_OF_MONTH, -WeekWindow.offsetFromWeekStart(jsDayOfWeek, weekStart))
    }
    return (0 until 7).map { i ->
        val day = (weekStartDay.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, i) }
        val text = "${day.get(Calendar.YEAR)}-${pad2(day.get(Calendar.MONTH) + 1)}-" +
            "${pad2(day.get(Calendar.DAY_OF_MONTH))}"
        dates.contains(text)
    }
}

private fun pad2(value: Int): String = if (value < 10) "0$value" else value.toString()
