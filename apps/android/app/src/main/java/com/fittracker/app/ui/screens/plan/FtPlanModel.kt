package com.fittracker.app.ui.screens.plan

import androidx.annotation.StringRes
import com.fittracker.app.R
import com.fittracker.app.data.model.PresetPlan
import com.fittracker.app.data.model.TrainingDay
import com.fittracker.app.data.model.UserPlan

/**
 * 计划页的数据模型。
 *
 * 样例数据逐字移植原型 `design/06_prototype_redraw/src/fittracker-plan.html`
 * 的 `PLANS`（L661-731），作为**无当前计划时的降级展示**保留；
 * 真实数据路径见文件尾 `ftPlanDaysFromUserPlan`（对齐鸿蒙 `PlanTabModel.ets`）。
 */
data class FtPlanExercise(
    val name: String,
    val muscle: String,
    /** 组数，原型 `sets` */
    val sets: String,
    /** 次数区间，原型 `reps` */
    val reps: String,
) {
    /** 展示剂次，原型拼接 `sets + ' × ' + reps`（L744）。 */
    val dose: String get() = "$sets × $reps"
}

/**
 * 卡片角标（`.dc-type`）——纯位置文案，与卡片内容无关：第 1/2/3 张为「今日/明日/后天」，
 * 其余「第 N 天」。资源 id + 可选天数参数（`第 %1$d 天` 用 [dayNumber]）。
 */
data class FtPlanBadge(@StringRes val labelRes: Int, val dayNumber: Int = 0)

/**
 * 计划中的一天（原型 `days[]`）。
 *
 * [tag] / [title] / [focus] / [duration] 与 [FtPlanExercise] 的字段是**内容数据**——
 * 真实路径由 [ftPlanDaysFromUserPlan] 从用户计划（`UserPlan.days`）填充，与静态 UI 文案不同源，
 * 故保持 `String`（模型层无 `Context`）；仅 [badge] 是位置文案，走资源。
 */
data class FtPlanDay(
    /** 单字肌群标签，用于卡片序号行「第 N 天 · 胸」。 */
    val tag: String,
    val title: String,
    /** 卡片的肌群/强度副题，如「胸部 · 推力」。 */
    val focus: String,
    val duration: String,
    /** 右上角角标（[FtPlanBadge]），如「今日」「明日」「后天」「第 4 天」。 */
    val badge: FtPlanBadge,
    /** 角标是否走强调底（原型 `.dc-type.is-today`）。 */
    val isToday: Boolean,
    val exercises: List<FtPlanExercise>,
)

/**
 * 原型 `PLANS.hypertrophy`（L662-731）。
 *
 * 静态文案改为字符串资源 ID（`values/strings_plan.xml` 的中文值为逐字真源），
 * 由 UI 层 `stringResource` / `context.getString` 解析——本对象只持有
 * `@StringRes Int` 与内容数据（见 [FtPlanDay] 注释）。
 */
object FtPlanDefaults {

    @StringRes
    val NAME_RES = R.string.plan_default_name

    @StringRes
    val META_RES = R.string.plan_default_meta

    /** 总计划卡右上角的周进度文案（原型 L564）。 */
    @StringRes
    val WEEK_PROGRESS_RES = R.string.plan_default_week_progress

    /** 进度条当前段文案（原型 L570）。 */
    @StringRes
    val PROGRESS_CAPTION_RES = R.string.plan_default_progress_caption

    /** 进度条已完成的百分比（原型 `style="width:20%"`）。 */
    const val PROGRESS_FRACTION = 0.20f

    /**
     * 原型样例（[FtPlanDay.tag] / [FtPlanDay.title] / [FtPlanDay.focus] / [FtPlanDay.duration]
     * 与动作名 / 肌群名为**内容数据**，保持 `String`；角标由 [positionBadge] 资源化）。
     */
    val days: List<FtPlanDay> = listOf(
        FtPlanDay(
            tag = "胸",
            title = "胸部日",
            focus = "胸部 · 推力",
            duration = "62 分钟",
            badge = positionBadge(0),
            isToday = true,
            exercises = listOf(
                FtPlanExercise("杠铃平板卧推", "胸部", "4", "8-12"),
                FtPlanExercise("上斜哑铃卧推", "胸部", "3", "8-12"),
                FtPlanExercise("哑铃飞鸟", "胸部", "3", "12-15"),
                FtPlanExercise("绳索夹胸", "胸部", "3", "12-15"),
                FtPlanExercise("双杠臂屈伸", "胸部", "3", "8-12"),
            ),
        ),
        FtPlanDay(
            tag = "背",
            title = "背部日",
            focus = "背部 · 拉力",
            duration = "58 分钟",
            badge = positionBadge(1),
            isToday = false,
            exercises = listOf(
                FtPlanExercise("引体向上", "背部", "4", "8-12"),
                FtPlanExercise("杠铃划船", "背部", "4", "8-12"),
                FtPlanExercise("高位下拉", "背部", "3", "10-12"),
                FtPlanExercise("坐姿划船", "背部", "3", "10-12"),
                FtPlanExercise("面拉", "背部", "3", "12-15"),
            ),
        ),
        FtPlanDay(
            tag = "腿",
            title = "腿部日",
            focus = "腿部 · 力量",
            duration = "66 分钟",
            badge = positionBadge(2),
            isToday = false,
            exercises = listOf(
                FtPlanExercise("杠铃深蹲", "腿部", "4", "8-12"),
                FtPlanExercise("罗马尼亚硬拉", "腿部", "3", "8-12"),
                FtPlanExercise("腿举", "腿部", "3", "10-12"),
                FtPlanExercise("腿弯举", "腿部", "3", "12-15"),
                FtPlanExercise("提踵", "腿部", "4", "15-20"),
            ),
        ),
        FtPlanDay(
            tag = "肩",
            title = "肩部日",
            focus = "肩部 · 泵感",
            duration = "52 分钟",
            badge = positionBadge(3),
            isToday = false,
            exercises = listOf(
                FtPlanExercise("杠铃推举", "肩部", "4", "8-12"),
                FtPlanExercise("哑铃侧平举", "肩部", "3", "12-15"),
                FtPlanExercise("前平举", "肩部", "3", "12-15"),
                FtPlanExercise("俯身飞鸟", "肩部", "3", "12-15"),
                FtPlanExercise("耸肩", "肩部", "3", "12-15"),
            ),
        ),
        FtPlanDay(
            tag = "臂",
            title = "手臂日",
            focus = "手臂 · 收尾",
            duration = "48 分钟",
            badge = positionBadge(4),
            isToday = false,
            exercises = listOf(
                FtPlanExercise("杠铃弯举", "手臂", "4", "8-12"),
                FtPlanExercise("哑铃锤式弯举", "手臂", "3", "10-12"),
                FtPlanExercise("窄距卧推", "手臂", "4", "8-12"),
                FtPlanExercise("绳索下压", "手臂", "3", "12-15"),
                FtPlanExercise("集中弯举", "手臂", "3", "12-15"),
            ),
        ),
    )

    /**
     * 动作序号：原型 `(j < 9 ? '0' : '') + (j + 1)`（L737），故第 1 项是「01」。
     */
    fun exerciseNumber(index: Int): String = if (index < 9) "0${index + 1}" else "${index + 1}"
}

// ─────────────────────────────────────────────────────────────
// 真实数据映射（Wave 4 接线）——逐条对齐鸿蒙
// `features/pencil/components/PlanTabModel.ets`
// ─────────────────────────────────────────────────────────────

/** 位置徽标（`PlanTabModel.positionBadge`）：第 1/2/3 天为 今日/明日/后天，其余「第 N 天」。 */
fun positionBadge(index: Int): FtPlanBadge = when (index) {
    0 -> FtPlanBadge(R.string.plan_badge_today)
    1 -> FtPlanBadge(R.string.plan_badge_tomorrow)
    2 -> FtPlanBadge(R.string.plan_badge_day_after)
    else -> FtPlanBadge(R.string.plan_badge_day_number, index + 1)
}

/**
 * 训练日短标签（`PlanTabModel.shortDayTag`）：首字为「周」时砍掉两字符再 trim 取首字
 * （「周一 胸部」→胸、「上肢A」→上）；空标签回落「练」（动态标签兜底，属内容数据，
 * 无 `Context` 可解析，故保持字面量）。
 */
fun shortDayTag(dayLabel: String): String {
    var text = dayLabel
    if (text.length >= 2 && text.startsWith("周")) {
        text = text.substring(2)
    }
    text = text.trim()
    return if (text.isEmpty()) "练" else text.substring(0, 1)
}

/** 训练日覆盖的目标肌群（`PlanTabModel.dayFocusMuscles`）：去重、按出现顺序，以「 · 」相连。 */
fun dayFocusMuscles(day: TrainingDay): String {
    val muscles = mutableListOf<String>()
    for (exercise in day.exercises) {
        val muscle = exercise.targetMuscle
        if (muscle.isNotEmpty() && muscle !in muscles) {
            muscles.add(muscle)
        }
    }
    return muscles.joinToString(" · ")
}

/**
 * 由「已启用的预置计划」构建计划页日卡
 * （`PlanTabModel.buildPlanDayItemsFromUserPlan` 的字段级对齐）。
 *
 * 与源一致的取舍：`duration` 传空（预置计划无单次时长），卡片副标题渲染时省略尾段
 * （`daySubtitle` 的「duration 为空不追加」口径）。
 */
fun ftPlanDaysFromUserPlan(plan: UserPlan): List<FtPlanDay> = ftPlanDaysFromDays(plan.days)

/**
 * 由「计划组」的预设计划构建日卡——**计划页动作清单的权威来源**。
 *
 * 为什么不能只用 [ftPlanDaysFromUserPlan]：启用计划时落盘的是**当时那份预设的克隆**，
 * 预设模板后续更新后两份内容会漂移。设备实测（PKB110）：同名「三分化 · 谭成义」在
 * 计划组详情有 5 个动作，而计划页读落盘副本只有 3 个、日标签还是旧版「拉」。
 * 计划页与计划组必须同源，故清单取预设模板最新的 `days`。
 */
fun ftPlanDaysFromPreset(plan: PresetPlan): List<FtPlanDay> = ftPlanDaysFromDays(plan.days)

private fun ftPlanDaysFromDays(days: List<TrainingDay>): List<FtPlanDay> = days.mapIndexed { index, day ->
    FtPlanDay(
        tag = shortDayTag(day.dayLabel),
        title = day.dayLabel,
        focus = dayFocusMuscles(day),
        duration = "",
        badge = positionBadge(index),
        isToday = index == 0,
        exercises = day.exercises.map { ref ->
            FtPlanExercise(
                name = ref.name,
                muscle = ref.targetMuscle,
                sets = ref.sets.toString(),
                reps = ref.reps,
            )
        },
    )
}
