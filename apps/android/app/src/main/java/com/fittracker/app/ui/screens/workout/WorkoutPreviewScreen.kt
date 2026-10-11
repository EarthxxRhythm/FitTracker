package com.fittracker.app.ui.screens.workout

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.data.model.UserPlan
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.ActiveWorkoutService
import com.fittracker.app.data.service.ActiveWorkoutState
import com.fittracker.app.data.service.ContentRepository
import com.fittracker.app.data.service.TrainingPlanRepository
import com.fittracker.app.data.service.WorkoutDraftService
import com.fittracker.app.data.service.WorkoutDraftSnapshot
import com.fittracker.app.data.service.WorkoutExerciseDraft
import com.fittracker.app.data.service.WorkoutPreviewExercise
import com.fittracker.app.data.service.WorkoutPreviewSummary
import com.fittracker.app.data.service.WorkoutSetDraft
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 训练预览屏（原型 `fittracker-training-preview.html` 的 `screen-training-preview` 帧，L427-520）。
 *
 * 画布 390×844 直绘（`.pv-frame { position:absolute; inset:0 }`）。无底栏。
 *
 * 版式来源（原型 CSS 行号）：
 * `.pv-content` L179-186 · `.pv-topbar`/`.pv-icon-btn` L188-213 · `.pv-hero*` L215-238 ·
 * `.pv-emblem` L240-247 · `.pv-list`/`.pv-group*` L249-269 · `.pv-item*` L270-302 ·
 * `.pv-action`/`.pv-note`/`.pv-btn-primary` L304-337 · `.pv-home-indicator` L339-346 ·
 * `.pv-toast` L348-370。
 *
 * 两处**以源码为准**的取舍：
 * 1. 页脚文案称主按钮为「翡翠渐变填充」（L527），但 `.pv-btn-primary` 实为纯色
 *    `var(--accent)` + 阴影（L352-356），文件内无任何 gradient——按源码实现纯色。
 * 2. 样式表末尾有「Card Surface v1」覆盖层（L392），把 `.pv-item` 的底色与描边
 *    改写为 `rgba(255,255,255,.031)` / `--line-10`——按**末尾**规则实现。
 *
 * 路由（`window.FT_APP.routes`，L583）：返回 → `home`、主 CTA → `active`。
 * 「更多选项」无路由，原型只弹轻量反馈（`showToast('更多选项（原型）')`，L561）——
 * 本屏如实还原该反馈。返回与 CTA 在原型里同样调用 `showToast`，但两按钮的
 * `data-od-id` 也在 `FT_APP.routes` 表里（L583），点击**同时**触发路由跳转；
 * 因跳转会立即卸载本屏、浮层无从驻留，故仅保留导航语义（与原型可见效果一致）。
 */
@Composable
fun WorkoutPreviewScreen(
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var toast by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current
    val store = remember { JsonStore(context.appDataStore) }
    val scope = rememberCoroutineScope()
    var workout by remember { mutableStateOf<ActiveWorkoutState?>(null) }
    var planName by remember { mutableStateOf("") }
    // `stringResource` 只能在 @Composable 上下文调用：先解析，供下方非 composable 闭包（onMenu）使用
    val moreOptionsToast = stringResource(R.string.workout_toast_more_options)
    val fallbackPlanName = stringResource(R.string.workout_fallback_plan_name)

    // 训练域接线：进入时读「当前计划 → 今日训练」，编译为活跃训练预览态
    // （`ActiveWorkoutService.createState` 的输入契约 `WorkoutPreviewSummary`）。
    // 无当前计划 / 今日非训练日 → 回落 [fallbackWorkoutPreview]（原型默认「Day 01 · 上肢力量」）。
    LaunchedEffect(Unit) {
        val summary = loadTodayWorkoutPreview(store)
        planName = summary.title
        workout = ActiveWorkoutService.createState(summary)
    }

    // 原型 `showToast` 的 `setTimeout(…, 1800)`（L537-545）
    LaunchedEffect(toast) {
        if (toast != null) {
            delay(1800)
            toast = null
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(FtColor.ink0) // `.pv-frame` 底 var(--ink-0)
                .padding(start = 18.dp, end = 18.dp, top = 56.dp, bottom = 12.dp),
        ) {
            TopBar(
                onBack = onBack, // 原型 FT_APP.routes：父屏 home
                onMenu = { toast = moreOptionsToast },
            )

            Text(
                text = workout?.dayId?.takeIf { it.isNotEmpty() } ?: "Day 01",
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp),
                style = FtType.natural(11f, 400, FtType.mono).copy(letterSpacing = 1.98.sp), // .18em × 11px
                color = FtColor.accent,
                textAlign = TextAlign.Center,
            )
            Text(
                text = stringResource(R.string.workout_title),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                color = FtColor.txtHi,
                fontSize = 32.sp,
                lineHeight = 35.84.sp, // 1.12 × 32px（原型显式声明）
                fontWeight = FontWeight.Bold,
                letterSpacing = 0.32.sp, // .01em × 32px
                textAlign = TextAlign.Center,
            )
            Text(
                text = planName.ifEmpty { fallbackPlanName },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                color = FtColor.white54,
                fontSize = 13.sp,
                lineHeight = 19.5.sp, // 1.5 × 13px
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
            )

            Emblem(
                modifier = Modifier
                    .padding(top = 14.dp)
                    .size(64.dp)
                    .align(Alignment.CenterHorizontally),
            )

            Column(
                modifier = Modifier
                    .weight(1f) // `.pv-list { flex: 1 1 auto }`
                    .fillMaxWidth()
                    .padding(top = 16.dp),
            ) {
                // 训练域接线：有计划时渲染今日计划的真实动作清单（版式仍用 `.pv-group` / `.pv-item`）；
                // 无计划 / 休息日回落原型默认清单，保持无数据视野与原型一致。
                val exercises = workout?.exercises.orEmpty()
                if (exercises.isNotEmpty()) {
                    ExerciseGroup(label = stringResource(R.string.workout_group_main)) {
                        exercises.forEachIndexed { index, exercise ->
                            PreviewItem(
                                name = exercise.name,
                                meta = "${exercise.targetSets} × ${exercise.targetReps}",
                                current = index == 0,
                            )
                        }
                    }
                } else {
                    ExerciseGroup(label = stringResource(R.string.workout_group_warmup)) {
                        PreviewItem(name = stringResource(R.string.workout_fallback_ex_band_shoulder), meta = "2 × 15")
                        PreviewItem(name = stringResource(R.string.workout_fallback_ex_scapular_pushup), meta = "2 × 12")
                    }
                    ExerciseGroup(label = stringResource(R.string.workout_group_main), modifier = Modifier.padding(top = 18.dp)) {
                        PreviewItem(name = stringResource(R.string.workout_fallback_ex_bench_press), meta = "4 × 6", current = true)
                        PreviewItem(name = stringResource(R.string.workout_fallback_ex_incline_db_press), meta = "3 × 8")
                        PreviewItem(name = stringResource(R.string.workout_fallback_ex_seated_shoulder_press), meta = "3 × 10")
                        PreviewItem(name = stringResource(R.string.workout_fallback_ex_triceps_pushdown), meta = "3 × 12")
                    }
                }
            }

            Text(
                text = stringResource(R.string.workout_note),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp),
                color = FtColor.white54,
                fontSize = 12.sp,
                lineHeight = 18.sp, // 1.5 × 12px
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
            )

            val ctaShape = RoundedCornerShape(26.dp) // `.pv-btn-primary` border-radius: 26px
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp)
                    .shadow(14.dp, ctaShape)
                    .clip(ctaShape)
                    .background(FtColor.accent)
                    .clickableNoRipple {
                        scope.launch {
                            // 训练域接线：开工前把活跃训练态落草稿（active 屏据此重入恢复）；
                            // 无计划则清空草稿（active 屏按「无草稿 → 全新训练」降级）。
                            val state = workout
                            if (state != null && state.exercises.isNotEmpty()) {
                                WorkoutDraftService.saveDraft(
                                    store,
                                    activeStateToDraft(state, System.currentTimeMillis()),
                                )
                            } else {
                                WorkoutDraftService.clearDraft(store)
                            }
                            onNavigate("active")
                        }
                    },
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier = Modifier.height(52.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = stringResource(R.string.workout_cta_start),
                        style = FtType.natural(16f, 700),
                        color = FtColor.onAccent,
                    )
                }
            }

            // `.pv-home-indicator`（原型画布内的 mock home 条）——**明确不复刻**：
            // 真机上系统已有真实手势条，保留会出现双条叠影（2026-10-09 真机验收点名移除）。
        }

        // `.pv-toast`：`.pv-frame` 的绝对定位子元素，bottom 86px、水平居中，
        // **不随设计空间缩放**（与本屏同坐标系，故屏内实现）。
        PvToast(
            message = toast,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 86.dp),
        )
    }
}

/** `.pv-topbar` L188-213：左返回 + 标题、右侧更多。按钮 44×44 / 圆角 15。 */
@Composable
private fun TopBar(onBack: () -> Unit, onMenu: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            IconButton(
                onClick = onBack,
                contentDescription = stringResource(R.string.workout_a11y_back), // 原型 `back-home` 的 aria-label（L437）
            ) { BackArrowIcon(modifier = Modifier.size(21.dp), color = IconTint) }
            Text(
                text = stringResource(R.string.workout_title),
                style = FtType.natural(17f, 600),
                color = FtColor.txtHi,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        IconButton(
            onClick = onMenu,
            contentDescription = stringResource(R.string.workout_a11y_more), // 原型 `preview-menu` 的 aria-label（L444）
        ) { MoreIcon(modifier = Modifier.size(21.dp), color = IconTint) }
    }
}

@Composable
private fun IconButton(
    onClick: () -> Unit,
    contentDescription: String,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .clip(RoundedCornerShape(15.dp))
            .background(IconButtonFill)
            .border(1.dp, FtColor.line14, RoundedCornerShape(15.dp))
            .semantics { this.contentDescription = contentDescription }
            .clickableNoRipple(onClick = onClick),
        contentAlignment = Alignment.Center,
        content = { content() },
    )
}

/** 动作分组（`.pv-group`，L250-259）。 */
@Composable
private fun ExerciseGroup(
    label: String,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Text(
            text = label,
            modifier = Modifier.padding(start = 6.dp, end = 6.dp, bottom = 8.dp),
            style = FtType.natural(12f, 600).copy(letterSpacing = 0.96.sp), // .08em × 12px
            color = FtColor.white54,
        )
        content()
    }
}

/**
 * 单条动作（`.pv-item`，L261-302；底色与描边取样式表末尾的「Card Surface v1」覆盖值）。
 *
 * [current] 为真时走翡翠高亮（`.pv-item.current`）。
 */
@Composable
private fun PreviewItem(
    name: String,
    meta: String,
    current: Boolean = false,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 7.dp) // `.pv-item + .pv-item { margin-top: 7px }`
            .height(52.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(if (current) FtColor.accent10 else ItemFill)
            .border(
                1.dp,
                if (current) CurrentBorder else FtColor.line10,
                RoundedCornerShape(16.dp),
            )
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = name,
            modifier = Modifier.weight(1f, fill = false),
            style = FtType.natural(16f, if (current) 600 else 500),
            color = if (current) FtColor.txtHi else ItemNameColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = meta,
            modifier = Modifier.padding(start = 12.dp),
            style = FtType.natural(14f, 500, FtType.num),
            color = if (current) FtColor.accent else FtColor.white54,
            maxLines = 1,
        )
    }
}

/** `.pv-emblem` L240-247：64×64 内联 SVG（外环 r27 + 脉冲线），viewBox `0 0 64 64`。 */
@Composable
private fun Emblem(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / 64f
        drawCircle(
            color = EmblemRing,
            radius = 27f * k,
            center = Offset(32f * k, 32f * k),
            style = Stroke(2f * k),
        )
        val pulse = Path().apply {
            moveTo(18f * k, 32f * k)
            lineTo(25f * k, 32f * k)
            lineTo(28.5f * k, 23f * k)
            lineTo(35.5f * k, 41f * k)
            lineTo(39f * k, 32f * k)
            lineTo(46f * k, 32f * k)
        }
        drawPath(
            pulse,
            FtColor.accent,
            style = Stroke(3f * k, cap = StrokeCap.Round, join = StrokeJoin.Round),
        )
    }
}

// ── 图标（路径逐字取自本文件的内联 `<svg>`，L437-447） ──────────────────────

/** 返回箭头（L439-441）：`M15.5 5 8.5 12l7 7`，描边 1.8。 */
@Composable
private fun BackArrowIcon(modifier: Modifier = Modifier, color: Color = Color.Unspecified) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / 24f
        val p = Path().apply {
            moveTo(15.5f * k, 5f * k)
            lineTo(8.5f * k, 12f * k)
            lineTo(15.5f * k, 19f * k)
        }
        drawPath(p, color, style = Stroke(1.8f * k, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

/** 三点菜单（L446-448）：`cx 5/12/19, cy 12, r 1.8` 的实心圆，描边 1.8。 */
@Composable
private fun MoreIcon(modifier: Modifier = Modifier, color: Color = Color.Unspecified) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / 24f
        listOf(5f, 12f, 19f).forEach { cx ->
            drawCircle(color, radius = 1.8f * k, center = Offset(cx * k, 12f * k))
        }
    }
}

/**
 * 轻量反馈浮层（原型 `.pv-toast`，L372-392）。
 *
 * 与 `.auth-toast` 的差异（逐条对齐源码，不复用 auth 的浮层）：底边距画布 86px（非 48）、
 * 内边距 10/16（非 11/17）、**无投影**（`.pv-toast` 未声明 box-shadow）、
 * 入出场位移 10px（`translateY(10px)`）。出入场 `opacity .18s`，
 * 时长取自 [FtMotion.DURATION_COLOR_BASE]。
 */
@Composable
private fun PvToast(message: String?, modifier: Modifier = Modifier) {
    // 退场动画期间 message 已变 null，需留存最后一次文案作为内容
    var shown by remember { mutableStateOf("") }
    if (message != null && message != shown) {
        shown = message
    }

    // 原型 `translateY(10px)`：入出场位移固定 10px、不随内容高度变化
    val slideOffset = with(LocalDensity.current) { 10.dp.roundToPx() }

    AnimatedVisibility(
        visible = message != null,
        modifier = modifier,
        enter = fadeIn(tween(FtMotion.DURATION_COLOR_BASE)) +
            slideInVertically(tween(FtMotion.DURATION_COLOR_BASE)) { slideOffset },
        exit = fadeOut(tween(FtMotion.DURATION_COLOR_BASE)) +
            slideOutVertically(tween(FtMotion.DURATION_COLOR_BASE)) { slideOffset },
    ) {
        Box(
            modifier = Modifier
                .padding(horizontal = 24.dp)
                .widthIn(max = 320.dp)
                .clip(FtShape.pill)
                .background(PvToastFill)
                .border(1.dp, FtColor.line10, FtShape.pill)
                .padding(horizontal = 16.dp, vertical = 10.dp),
        ) {
            Text(
                text = shown,
                color = FtColor.txtHi,
                fontSize = 13.sp,
                lineHeight = 18.2.sp, // 1.4 × 13px
                textAlign = TextAlign.Center,
            )
        }
    }
}

// ── 屏内色值（原型 `:root` 无对应令牌，按 FtColorUtil 规则就地换算） ──
//
// 换算规则 AA = round(alpha × 255)

/** `.pv-icon-btn` 底 `rgba(255,255,255,.031)` → round(7.9) = 8 = 0x08 */
private val IconButtonFill = Color(0x08FFFFFF)

/** `.pv-icon-btn` 前景 `rgba(255,255,255,.82)` → round(209.1) = 209 = 0xD1 */
private val IconTint = Color(0xD1FFFFFF)

/** 末尾覆盖层 `.pv-item` 底 `rgba(255,255,255,.031)` → 8 = 0x08 */
private val ItemFill = Color(0x08FFFFFF)

/** `.pv-item-name` 色 `rgba(255,255,255,.88)` → round(224.4) = 224 = 0xE0 */
private val ItemNameColor = Color(0xE0FFFFFF)

/** `.pv-item.current` 描边 `rgba(80,236,167,.28)` → round(71.4) = 71 = 0x47 */
private val CurrentBorder = Color(0x4750ECA7)

/** `.pv-emblem` 外环 `rgba(80,236,167,.30)` → round(76.5) = 77 = 0x4D */
private val EmblemRing = Color(0x4D50ECA7)


/** `.pv-toast` 底 `rgba(13,17,23,.92)` → round(234.6) = 235 = 0xEB */
private val PvToastFill = Color(0xEB0D1117)

// ── 训练域接线共享件（workout / active 两屏共用；工单 scope 限定 3 屏文件，故不另建文件） ──

/**
 * 由「当前计划 + 今日训练」编译 [WorkoutPreviewSummary]
 * （`ActiveWorkoutService.createState` 的输入契约）。
 *
 * - 有当前计划且今日命中训练日 → 逐动作映射（`plannedExerciseId` = `计划id#日标签#序号`，
 *   `exerciseId` 经 [resolveExerciseId] 由动作名解析，`targetMuscle` 落在 `intensityNote`，
 *   与 [activeStateToDraft] / [draftToActiveState] 的往返口径一致）；
 * - 无当前计划 / 今日非训练日 / 计划日无动作 → [fallbackWorkoutPreview]。
 *
 * 注：`WorkoutPreviewService`（鸿蒙 Feature #9）尚未移植，故此处就地构造**消费子集**输入，
 * 待其移植后以之替换（字段为本文所用字段的超集，可直接兼容）。
 */
internal suspend fun loadTodayWorkoutPreview(store: JsonStore): WorkoutPreviewSummary {
    val plan: UserPlan = TrainingPlanRepository.getCurrentPlan(store) ?: return fallbackWorkoutPreview()
    val day = TrainingPlanRepository.getTodayTraining(plan) ?: return fallbackWorkoutPreview()
    val exercises = day.exercises.mapIndexed { index, ref ->
        WorkoutPreviewExercise(
            plannedExerciseId = "${plan.id}#${day.dayLabel}#$index",
            exerciseId = resolveExerciseId(ref.name),
            name = ref.name,
            targetSets = ref.sets,
            targetReps = ref.reps,
            intensityNote = ref.targetMuscle,
        )
    }
    if (exercises.isEmpty()) {
        return fallbackWorkoutPreview()
    }
    return WorkoutPreviewSummary(
        hasWorkout = true,
        planId = plan.id,
        dayId = day.dayLabel,
        title = plan.name,
        exercises = exercises,
    )
}

/**
 * 无计划时的降级预览——动作取自原型 `fittracker-training-preview.html` 的默认清单首项
 * （「杠铃卧推」），组数对齐 active 屏原型的 6 段进度条（`FtActiveModel.TARGET`）。
 * `dayId` / `title` 留空，由屏内分别回落「Day 01」/「第 1 天 · 上肢力量」文案模板。
 */
internal fun fallbackWorkoutPreview(): WorkoutPreviewSummary = WorkoutPreviewSummary(
    hasWorkout = true,
    planId = "",
    dayId = "Day 01",
    title = "",
    exercises = listOf(
        WorkoutPreviewExercise(
            plannedExerciseId = "day01_main_1",
            exerciseId = resolveExerciseId("杠铃卧推"),
            name = "杠铃卧推",
            targetSets = 6,
            targetReps = "6",
            intensityNote = "",
        ),
    ),
)

/**
 * 动作名 → 内容库 `exerciseId`：先精确匹配 `nameZh`，再双向子串匹配
 * （预置计划作「杠铃平板卧推」而内容库作「杠铃卧推」——两表名称存在差异，故需宽松匹配）；
 * 内容库未装载或无匹配时回落动作名本身。
 */
internal fun resolveExerciseId(name: String): String {
    val exercises = ContentRepository.exercises()
    exercises.firstOrNull { it.nameZh == name }?.let { return it.exerciseId }
    exercises.firstOrNull { it.nameZh in name || name in it.nameZh }?.let { return it.exerciseId }
    return name
}

/**
 * 活跃训练态 → 草稿快照（[WorkoutDraftService] 的持久化模型）。
 *
 * 口径映射：`title → planName`、`dayId → dayLabel`、`intensityNote ↔ targetMuscle`
 * （见 [loadTodayWorkoutPreview]）；`isWarmup` 在草稿模型里不存在（源草稿集即无此字段），
 * 故热身态过草稿会丢失——见报告「未接线项」。
 */
internal fun activeStateToDraft(state: ActiveWorkoutState, startedAt: Long): WorkoutDraftSnapshot =
    WorkoutDraftSnapshot(
        planId = state.planId,
        planName = state.title,
        dayLabel = state.dayId,
        startedAt = startedAt,
        totalTargetSets = state.totalTargetSets,
        completedSets = state.completedSets,
        currentExerciseName = state.currentExerciseName,
        currentExerciseProgress = state.currentExerciseSetProgress,
        exercises = state.exercises.map { exercise ->
            WorkoutExerciseDraft(
                exerciseId = exercise.exerciseId,
                name = exercise.name,
                targetMuscle = exercise.intensityNote,
                targetSets = exercise.targetSets,
                targetReps = exercise.targetReps,
                completedSets = exercise.completedSets,
                sets = exercise.sets.map { set ->
                    WorkoutSetDraft(
                        setIndex = set.setIndex,
                        weightText = set.weightText,
                        repsText = set.repsText,
                        estimatedOneRepMax = set.estimatedOneRepMax,
                        oneRepMaxText = set.oneRepMaxText,
                        isComplete = set.isComplete,
                    )
                },
            )
        },
        updatedAt = System.currentTimeMillis(),
    )

/**
 * 草稿快照 → 活跃训练态（重入恢复）。
 *
 * 以草稿里的动作清单重建预览摘要（草稿无 `plannedExerciseId` → 以 `exerciseId` 代位，
 * 与 `WorkoutSet.setId` 的 `{plannedExerciseId}_set_{n}` 口径存在偏差，见报告）；
 * 再按草稿逐组回填 `updateSetEntry`，最后 `createStateWithProgress` 重算聚合字段。
 */
internal fun draftToActiveState(draft: WorkoutDraftSnapshot): ActiveWorkoutState {
    val base = ActiveWorkoutService.createState(
        WorkoutPreviewSummary(
            hasWorkout = draft.exercises.isNotEmpty(),
            planId = draft.planId,
            dayId = draft.dayLabel,
            title = draft.planName,
            exercises = draft.exercises.map { exercise ->
                WorkoutPreviewExercise(
                    plannedExerciseId = exercise.exerciseId,
                    exerciseId = exercise.exerciseId,
                    name = exercise.name,
                    targetSets = exercise.targetSets,
                    targetReps = exercise.targetReps,
                    intensityNote = exercise.targetMuscle,
                )
            },
        ),
    )
    var exercises = base.exercises
    for (exercise in draft.exercises) {
        for (set in exercise.sets) {
            if (set.weightText.isEmpty() && set.repsText.isEmpty() && !set.isComplete) {
                continue
            }
            exercises = ActiveWorkoutService.updateSetEntry(
                exercises = exercises,
                plannedExerciseId = exercise.exerciseId,
                setIndex = set.setIndex,
                weightText = set.weightText,
                repsText = set.repsText,
            )
        }
    }
    return ActiveWorkoutService.createStateWithProgress(base, exercises)
}
