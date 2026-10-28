package com.fittracker.app.ui.screens.profile

import android.app.Application
import android.content.res.Resources
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import com.fittracker.app.R
import com.fittracker.app.data.auth.AuthService
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.AvatarImageService
import com.fittracker.app.data.service.Experience
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.GoalRepository
import com.fittracker.app.data.service.goalTypeLabel
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
    /** 头像图片沙箱路径；空串 = 未设置（回落色键 + 昵称首字）。 */
    var avatarImagePath by mutableStateOf("")
        private set
    /** 训练经验本地化标签（新手/进阶/高阶）；未填为空串，个人页据此隐藏徽标。 */
    var experienceLabel by mutableStateOf("")
        private set
    var weekValue by mutableStateOf(FtProfileModel.WEEK_VALUE)
        private set
    var weekSessions by mutableStateOf(FtProfileModel.WEEK_METRICS[0].value)
        private set
    /** 目标副标题：有真实目标时「增肌第 N 天 · 保持节奏」，否则「未设置目标」。 */
    var goalSubtitle by mutableStateOf("")
        private set
    var achievements by mutableStateOf<List<FtProfileAchievement>>(emptyList())
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
        // 文件已被系统清理时不展示失效路径，回到色键 + 首字。
        avatarImagePath = if (AvatarImageService.exists(profile.avatarImagePath)) profile.avatarImagePath else ""
        experienceLabel = experienceLabelOf(profile.experience, res)
        // 昵称优先取本地资料，其次回落账号显示名；两者皆空时用「—」占位。
        // 原实现在昵称非空时才赋值，新装用户 header 会渲染成一片空白（本次修复的根因）。
        val session = AuthService.currentSession(store)
        val accountName = session?.displayName?.trim().orEmpty()
        val displayName = when {
            profile.nickname.isNotBlank() -> profile.nickname.trim()
            accountName.isNotEmpty() -> accountName
            else -> res.getString(R.string.profile_name_none)
        }
        name = displayName
        avatarInitial = displayName.first().toString()
        // 目标副标题：读真实目标并按 goalType 出标签，替代原先恒「未设置目标」的占位。
        val goal = GoalRepository.loadGoal(store)
        goalSubtitle = if (goal != null && goal.createdAt > 0) {
            res.getString(R.string.profile_sub_goal, goalTypeLabel(goal.goalType), goalDayCount(goal.createdAt))
        } else {
            res.getString(R.string.profile_sub_none)
        }
        val sessions = WorkoutRepository.getSessions(store)
        if (sessions.isNotEmpty()) {
            val stats = WorkoutSessionService.weeklyStats(sessions, System.currentTimeMillis(), weekStart)
            weekValue = (stats.duration / 60).toString()
            weekSessions = stats.count.toString()
            // 成就卡派生：连续天数 + 本周次数 + 最大重量 PR（无 PR 记录时该项不出现）。
            val trainingDates = WorkoutSessionService.trainingDates(sessions).toSet()
            val streakDays = currentStreakDays(trainingDates)
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

/** 训练经验 → 本地化标签；未填返回空串（个人页据此隐藏徽标）。 */
private fun experienceLabelOf(experience: Experience, res: Resources): String = when (experience) {
    Experience.BEGINNER -> res.getString(R.string.profile_experience_beginner)
    Experience.INTERMEDIATE -> res.getString(R.string.profile_experience_intermediate)
    Experience.ADVANCED -> res.getString(R.string.profile_experience_advanced)
    Experience.UNSPECIFIED -> ""
}

/** 目标进行天数（含创建当天）：与鸿蒙 `ProfileState.computeGoalDayCount` 同口径。 */
private fun goalDayCount(createdAt: Long): Int {
    val oneDayMs = 24L * 60 * 60 * 1000
    val days = ((System.currentTimeMillis() - createdAt) / oneDayMs).toInt() + 1
    return if (days < 1) 1 else days
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
