package com.fittracker.app.ui.screens.active

import androidx.annotation.StringRes
import com.fittracker.app.R
import com.fittracker.app.data.service.ActiveWorkoutExercise
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/**
 * 一条已完成的组记录（原型 `records` 数组的条目，L694-697）。
 *
 * [setNumber] 是「动作内」组号（1 起）——记录按动作分开，组号不从全场累计。
 */
data class FtSetRecord(val setNumber: Int, val weight: Int, val reps: Int)

/** 进度条单格的角色（原型 `updateProgress` 的 `done` / `current` / 无，L748-762）。 */
enum class FtSegRole { Done, Current, Plain }

/**
 * 一个彩带粒子的飞散参数（原型 `spawnConfetti` 为每个粒子写的 inline 变量，L779-796）。
 *
 * [colorIndex] 是四色循环的下标（`colors[i % colors.length]`），
 * 取值含义由屏内色表给出，本层不引入 Compose 依赖。
 */
data class FtConfetti(
    /** `--tx`：水平位移（px，正为右）。 */
    val offsetX: Float,
    /** `--ty`：垂直位移（px，正为下）。 */
    val offsetY: Float,
    /** `--rot`：终态旋转角（度）。 */
    val rotationDeg: Float,
    /** 配色下标（0–3）。 */
    val colorIndex: Int,
    /** `animation-delay`（秒）。 */
    val delaySeconds: Float,
    /** `animation-duration`（秒）。 */
    val durationSeconds: Float,
)

/**
 * 一条带参文案的「资源 ID + 位置参数」载体。
 *
 * 模型层无 `Context`（保持可单测），故不解出字符串，只持资源 ID 与参数；
 * 由 UI 层 `stringResource(res, *args)` 解析（Wave 7 i18n）。
 */
data class FtLabelRes(@StringRes val res: Int, val args: List<Any> = emptyList())

/**
 * 训练执行屏的纯逻辑层——无 Compose 依赖，可单测。
 *
 * 规格源：原型 `design/06_prototype_redraw/src/fittracker-training.html` 内联脚本
 * （`formatClock` L700-712 · `renderSets` L727-740 · `updateProgress` L741-776 ·
 * `spawnConfetti` L779-796 · 步进 clamp L864-880）。
 */
object FtActiveModel {

    /** `var target = 6`（L693）。 */
    const val TARGET = 6

    /** 首屏预置记录（L694-697）：2/6，故首个可见进度格是 `.current`。 */
    val INITIAL_RECORDS: List<FtSetRecord> =
        listOf(FtSetRecord(1, 30, 10), FtSetRecord(2, 32, 9))

    /** 重量步进：`data-increment="1" data-min="20" data-max="200"`。 */
    const val WEIGHT_MIN = 20
    const val WEIGHT_MAX = 200

    /** 次数步进：`data-increment="1" data-min="1" data-max="15"`。 */
    const val REPS_MIN = 1
    const val REPS_MAX = 15

    /** 弹窗打开时两个 `.val` 的初值（L641/L649：`32` / `9`）。 */
    const val WEIGHT_INIT = 32
    const val REPS_INIT = 9

    /** `var count = 36`（L782）。 */
    const val CONFETTI_COUNT = 36

    /**
     * `formatClock(total)`（L700-712）：`h > 0` 时 `h:mm:ss`，否则 `mm:ss`；
     * 秒/分补零，小时不补零；负值先夹到 0。
     */
    fun formatClock(totalSeconds: Int): String {
        val total = max(0, totalSeconds)
        val h = total / 3600
        val m = (total % 3600) / 60
        val s = total % 60
        val mm = if (m < 10) "0$m" else "$m"
        val ss = if (s < 10) "0$s" else "$s"
        return if (h > 0) "$h:$mm:$ss" else "$mm:$ss"
    }

    /**
     * `updateProgress` 的标签（L769-773）：满 [target] 时改文案。
     * 返回「资源 ID + 参数」（模型无 `Context`），由 UI 层 `stringResource(res, *args)` 解析。
     */
    fun progressLabel(completed: Int, target: Int = TARGET): FtLabelRes =
        if (completed >= target) FtLabelRes(R.string.active_progress_done, listOf(target))
        else FtLabelRes(R.string.active_progress_step, listOf(completed + 1, target))

    /** `updateProgress` 的分格规则（L748-762）：`i < completed` 为 done，`i == completed`（未满）为 current。 */
    fun segRole(index: Int, completed: Int, target: Int = TARGET): FtSegRole = when {
        index < completed -> FtSegRole.Done
        index == completed && completed < target -> FtSegRole.Current
        else -> FtSegRole.Plain
    }

    /** `renderSets` 的按钮文案与可用性（L731-733）：满 [target] 时置灰并改写为「已完成」。 */
    fun submitLabel(completed: Int, target: Int = TARGET): FtLabelRes =
        if (completed >= target) FtLabelRes(R.string.active_submit_done)
        else FtLabelRes(R.string.active_submit)

    /** `renderSets` 的按钮可用性（L732：`btnSubmit.disabled = completed >= target`）。 */
    fun submitEnabled(completed: Int, target: Int = TARGET): Boolean = completed < target

    /**
     * 当前动作的已完成正式组 → 视觉记录（组号为动作内序号，从 1 起）。
     *
     * 训练页的记录按动作分开、只显示当前动作：切到下一个动作后，上一动作的组不再显示，
     * 组号与页面上「第 N 组」始终属于同一个动作。
     *
     * 当前动作的口径与 `ActiveWorkoutService` 的写入口径一致——首个未录满的动作，
     * 全部录满取末个；无动作返回空列表。只收已录完的正式组（跳过未完成与热身），
     * 重量/次数按草稿里的整数字面解析（不可解析按 0）。
     */
    fun currentRecords(exercises: List<ActiveWorkoutExercise>): List<FtSetRecord> {
        val current = exercises.firstOrNull { it.completedSets < it.targetSets }
            ?: exercises.lastOrNull()
            ?: return emptyList()
        val result = mutableListOf<FtSetRecord>()
        for (index in current.sets.indices) {
            val set = current.sets[index]
            if (!set.isComplete || set.isWarmup) continue
            result.add(
                FtSetRecord(
                    setNumber = index + 1,
                    weight = set.weightText.toIntOrNull() ?: 0,
                    reps = set.repsText.toIntOrNull() ?: 0,
                ),
            )
        }
        return result
    }

    /**
     * 步进按钮的取值（L864-880）：
     * `n = clamp(delta == up ? n + inc : n - inc, min, max)`。
     *
     * [delta] 取 `+1` / `-1`。
     */
    fun stepValue(value: Int, delta: Int, increment: Int = 1, min: Int, max: Int): Int =
        (value + delta * increment).coerceIn(min, max)

    /**
     * `spawnConfetti()`（L779-796）的几何与配色。
     *
     * 每个粒子按序消耗 5 个 `[0,1)` 随机数：角度抖动、距离、旋转、延迟、时长——
     * [rnd] 由调用方注入（屏内传 `Random.nextFloat()`，测试传定值以断言几何）。
     *
     * 公式逐字对齐原型：
     * `angle = 2π·(i/count) + (rnd−0.5)·0.5`；`dist = 90 + rnd·150`；
     * `tx = cos(angle)·dist`；`ty = sin(angle)·dist`；`rot = rnd·540 − 270`；
     * `delay = rnd·0.08`；`duration = 0.9 + rnd·0.35`；`colorIndex = i % 4`。
     */
    fun confetti(count: Int = CONFETTI_COUNT, rnd: () -> Float): List<FtConfetti> =
        List(count) { i ->
            val angle = ((2.0 * Math.PI) * (i.toDouble() / count) + (rnd() - 0.5) * 0.5).toFloat()
            val dist = 90f + rnd() * 150f
            FtConfetti(
                offsetX = cos(angle) * dist,
                offsetY = sin(angle) * dist,
                rotationDeg = rnd() * 540f - 270f,
                colorIndex = i % 4,
                delaySeconds = rnd() * 0.08f,
                durationSeconds = 0.9f + rnd() * 0.35f,
            )
        }
}
