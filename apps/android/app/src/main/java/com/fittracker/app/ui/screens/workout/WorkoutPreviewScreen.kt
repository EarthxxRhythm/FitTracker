package com.fittracker.app.ui.screens.workout

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
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
import com.fittracker.app.ui.theme.DuTokens
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
    val context = LocalContext.current
    val store = remember { JsonStore(context.appDataStore) }
    val scope = rememberCoroutineScope()
    var workout by remember { mutableStateOf<ActiveWorkoutState?>(null) }
    var planName by remember { mutableStateOf("") }
    val fallbackPlanName = stringResource(R.string.workout_fallback_plan_name)

    // 训练域接线：进入时读「当前计划 → 今日训练」，编译为活跃训练预览态
    // （`ActiveWorkoutService.createState` 的输入契约 `WorkoutPreviewSummary`）。
    // 无当前计划 / 今日非训练日 → 回落 [fallbackWorkoutPreview]（原型默认「Day 01 · 上肢力量」）。
    LaunchedEffect(Unit) {
        val summary = loadTodayWorkoutPreview(store)
        planName = summary.title
        workout = ActiveWorkoutService.createState(summary)
    }

    Box(modifier = modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(FtColor.ink0) // `.pv-frame` 底 var(--ink-0)
                .padding(start = 18.dp, end = 18.dp, top = 56.dp, bottom = 25.dp), // 与鸿蒙对齐：底部留白 25
        ) {
            TopBar(onClose = onBack) // 原型 FT_APP.routes：父屏 home；现在由右上角 × 触发

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
            // 与鸿蒙 `PencilPreviewPage` 对齐：原来的 elevation 阴影换成 Duolingo 硬边厚底。
            // 外层是全高的深色底（=厚底），内层亮色块在按下时撑满、厚底被压平并整体下移
            // （鸿蒙：`border.bottom` 4→0 且 `translate y` +2）。
            val ctaInteraction = remember { MutableInteractionSource() }
            val ctaPressed by ctaInteraction.collectIsPressedAsState()
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp)
                    .height(52.dp)
                    .graphicsLayer {
                        translationY = if (ctaPressed) DuTokens.PRESS_SHIFT.toPx() else 0f
                    }
                    .clip(ctaShape)
                    .background(FtColor.accentDeep)
                    .clickable(
                        interactionSource = ctaInteraction,
                        indication = null,
                        onClick = {
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
                    ),
                contentAlignment = Alignment.TopCenter,
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(if (ctaPressed) 52.dp else 52.dp - DuTokens.PRESS_DEPTH)
                        .background(FtColor.accent),
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

    }
}

/** `.pv-topbar` L188-213（2026-10-28 改形）：左标题、右侧纯线条关闭。 */
@Composable
private fun TopBar(onClose: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = stringResource(R.string.workout_title),
            style = FtType.natural(17f, 600),
            color = FtColor.txtHi,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        CloseButton(onClick = onClose)
    }
}

/**
 * 纯线条关闭键：44dp 触摸区（对齐鸿蒙 `.width(44).height(44)`，并撑住顶栏高度），
 * 视觉是 12dp 画布上的两条对角线（线长 12√2 ≈ 17dp）、1.8dp 圆头、恒定 `IconTint`。
 * 按压走物理弹簧（与鸿蒙 `SPRING_PRESS` 同源：response 0.28s / damping 0.85），
 * 不叠任何 tween——按下缩到 0.86，松手带过冲弹回。
 */
@Composable
private fun CloseButton(onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) FtMotion.PRESS_CLOSE_SCALE else 1f,
        animationSpec = spring(
            dampingRatio = FtMotion.PRESS_SPRING_DAMPING,
            stiffness = FtMotion.PRESS_SPRING_STIFFNESS,
        ),
        label = "preview-close-press",
    )
    val closeDescription = stringResource(R.string.workout_a11y_close)
    Box(
        modifier = Modifier
            .size(44.dp)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .semantics { contentDescription = closeDescription }
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.size(12.dp)) {
            val stroke = 1.8.dp.toPx()
            drawLine(
                color = IconTint,
                start = Offset(0f, 0f),
                end = Offset(size.width, size.height),
                strokeWidth = stroke,
                cap = StrokeCap.Round,
            )
            drawLine(
                color = IconTint,
                start = Offset(size.width, 0f),
                end = Offset(0f, size.height),
                strokeWidth = stroke,
                cap = StrokeCap.Round,
            )
        }
    }
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
        // 行间距 7 只加在**行与行之间**（与鸿蒙 `Column(space 7)` 同构）；
        // 原实现是每行自带 `padding(top = 7)`，连首行也被顶下去 7。
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(7.dp),
        ) {
            content()
        }
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
            .height(52.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(if (current) FtColor.accent10 else ItemFill)
            .border(
                1.dp,
                if (current) CurrentBorder else ItemBorder,
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

// ── 屏内色值（原型 `:root` 无对应令牌，按 FtColorUtil 规则就地换算） ──
//
// 换算规则 AA = round(alpha × 255)

/** `.pv-icon-btn` 前景 `rgba(255,255,255,.82)` → round(209.1) = 209 = 0xD1 */
private val IconTint = Color(0xD1FFFFFF)

/** 末尾覆盖层 `.pv-item` 底 `rgba(255,255,255,.031)` → 8 = 0x08 */
private val ItemFill = Color(0x08FFFFFF)

/** `.pv-item-name` 色 `rgba(255,255,255,.88)` → round(224.4) = 224 = 0xE0 */
private val ItemNameColor = Color(0xE0FFFFFF)

/** 非当前动作行描边：与鸿蒙 `#0EFFFFFF`（α .055）对齐，原为 `line10`（α .10）。 */
private val ItemBorder = Color(0x0EFFFFFF)

/** `.pv-item.current` 描边 `rgba(80,236,167,.28)` → round(71.4) = 71 = 0x47 */
private val CurrentBorder = Color(0x4750ECA7)

/** `.pv-emblem` 外环 `rgba(80,236,167,.30)` → round(76.5) = 77 = 0x4D */
private val EmblemRing = Color(0x4D50ECA7)



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
