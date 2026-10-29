package com.fittracker.app.ui.screens.complete

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.sync.SyncOrchestrator
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.AvatarImageService
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.WeekWindow
import com.fittracker.app.data.service.currentLanguageTag
import com.fittracker.app.data.service.WorkoutRepository
import com.fittracker.app.data.service.WorkoutSessionService
import com.fittracker.app.data.service.WorkoutSummaryService
import com.fittracker.app.ui.components.FtSegmentedPill
import com.fittracker.app.ui.components.SegContainer
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import java.util.Calendar
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.random.Random

/**
 * 训练完成屏（原型 `fittracker-training-complete.html` 的 `screen-training-complete` 帧，L387-441）。
 *
 * 画布 **430×930.56 缩放**（`.cf-frame { width:430px; height:calc(844px / var(--scale));
 * transform:scale(.90698) }`，L174-185）——屏内一律按 430 设计空间布局，缩放由 `FtCanvas` 施加。
 * 无底栏（非 Tab 一级路由）。
 *
 * 版式来源（原型 CSS 行号）：
 * `.cf-frame` L174-185 · `.cf-scroll`/`.cf-content` L187-203 · `.cf-hero`/`.cf-badge`/`.cf-title`/`.cf-sub` L205-232 ·
 * `.cf-streak`/`.streak-*` L234-260 · `.cf-dock`/`.cf-btn` L262-289 ·
 * `.confetti-layer`/`.confetti-piece` L291-312 · `.cf-toast` L313-334 · `@keyframes` L336-350。
 *
 * 两处**以源码为准**的取舍：
 * 1. 样式表末尾「Card Surface v1」（L356）把 `.cf-streak` 的底色与描边改写为
 *    `rgba(255,255,255,.031)` / `--line-10`——按**末尾**规则实现。
 * 2. `.cf-content` 的 `justify-content:center` 让内容在滚动区垂直居中；因缩放画布恒为
 *    430×930.56、内容（约 447 高）恒小于滚动区（约 846 高），`.cf-scroll` **永不滚动**，
 *    故直接用 `contentAlignment = Center` 复刻，不引入滚动容器。
 *
 * 交互（原型脚本 L449-508）：唯一交互是 `.cf-btn-primary` 的 `cta-continue` → `review`
 * （`FT_APP.routes`，L510）。原型点击时另弹 `showToast('原型：跳转到训练总结页')`，
 * 但导航会立即卸载本屏、浮层无从驻留——与 `workout` 的返回/CTA 同理，只保留导航语义。
 */
@Composable
fun CompleteScreen(
    onNavigate: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    // 38 片彩带：入场只生成一次（原型 L459-472）
    val pieces = remember { FtCompleteModel.confetti { Random.nextFloat() } }
    // 整层在 4600ms 后淡出（原型 L474-478），5200ms 后被移除（L479-481）
    var confettiVisible by remember { mutableStateOf(true) }
    val layerAlpha = remember { Animatable(1f) }

    LaunchedEffect(Unit) {
        delay(4600)
        layerAlpha.animateTo(0f, tween(500, easing = LinearEasing))
        confettiVisible = false
    }

    // 训练域接线：会话库（`WorkoutRepository`）为空 → 空态（连续记录卡全灰、计数 0）；
    // 有会话 → `WorkoutSummaryService` 摘要判定会话态 + `WorkoutSessionService` 训练日期
    // 驱动「连续记录」卡的真实打卡状态。
    val context = LocalContext.current
    val store = remember { JsonStore(context.appDataStore) }
    var streakCount by remember { mutableIntStateOf(0) }
    var streakDays by remember {
        mutableStateOf(FtCompleteModel.STREAK_DAYS.map { it.copy(active = false) })
    }
    // 本次训练整体 RPE（1–10）：0 = 未评价。落库写入 `WorkoutSession.sessionRpe`。
    // 这是回顾页「努力程度」柱状图的唯一真数据来源（逐组采集成本高，故按次）。
    var sessionRpe by remember { mutableIntStateOf(0) }
    // 最近一次已保存会话的 id（写回 RPE 用）；空串 = 尚未读到。
    var latestSessionId by remember { mutableStateOf("") }
    // RPE 已保存的即时反馈（避免重复点击；下一次读回覆盖）。
    var rpeSaved by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        val sessions = WorkoutRepository.getSessions(store)
        val summary = if (sessions.isEmpty()) {
            WorkoutSummaryService.createEmptySummary()
        } else {
            WorkoutSummaryService.createSummaryWithHistory(sessions.last(), sessions)
        }
        val trainingDates: Set<String> = if (summary.hasSession) {
            WorkoutSessionService.trainingDates(sessions).toSet()
        } else {
            emptySet()
        }
        streakCount = currentStreak(trainingDates)
        streakDays = weekActivity(trainingDates, SettingsService.loadSettings(store).weekStart)
        // RPE 读回：以最新一条会话为准，避免默认值覆盖已存值
        // （对齐鸿蒙 `loadWorkoutStats`，`WorkoutCompletePage.ets`）
        val latest = sessions.lastOrNull()
        latestSessionId = latest?.sessionId ?: ""
        sessionRpe = latest?.sessionRpe ?: 0
        rpeSaved = false
    }

    // 训练完成后静默同步（源 `requestBackgroundSync`；自动同步开启时生效，失败不抛出。
    // 隐私政策第五节「训练完成」上行时机的实现点）
    LaunchedEffect(Unit) {
        SyncOrchestrator.requestBackgroundSync(
            store,
            SyncOrchestrator.forFilesDir(context.filesDir),
            AvatarImageService.resolveDir(context),
        )
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(FtColor.completeBg), // `.cf-frame` 底 var(--complete-bg)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // `.cf-scroll > .cf-content`：垂直居中（见类注释取舍 2）
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 48.dp), // `.cf-content { padding: 48px 20px }`
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Hero()
                    StreakCard(
                        streakCount = streakCount,
                        days = streakDays,
                        modifier = Modifier.padding(top = 30.dp), // `.cf-streak { margin-top: 30px }`
                    )
                    RpeCard(
                        value = sessionRpe,
                        saved = rpeSaved,
                        onSelect = { picked ->
                            // 顺序对齐鸿蒙 selectSessionRpe：① 同值去重 → ② 立即更新界面态
                            // → ③ 才尝试写回。界面反馈不依赖写回是否可行——否则新装应用
                            // 首轮训练（尚无会话 id）点选将毫无反应。
                            if (FtCompleteModel.shouldUpdateRpeSelection(picked, sessionRpe)) {
                                val previous = sessionRpe
                                sessionRpe = picked
                                rpeSaved = false
                                if (FtCompleteModel.shouldPersistRpe(picked, previous, latestSessionId)) {
                                    val targetId = latestSessionId
                                    scope.launch {
                                        val current = WorkoutRepository
                                            .getSessions(store)
                                            .firstOrNull { it.sessionId == targetId }
                                        rpeSaved = current != null && WorkoutRepository.updateSession(
                                            store,
                                            current.copy(sessionRpe = picked),
                                        )
                                    }
                                }
                            }
                        },
                        modifier = Modifier.padding(top = 14.dp),
                    )
                }
            }

            Dock(onClick = { onNavigate("review") })
        }

        if (confettiVisible) {
            ConfettiLayer(pieces = pieces, layerAlpha = layerAlpha.value)
        }
    }
}

/**
 * `.cf-hero` L205-232：完成徽章（`cf-pop .5s .05s`）+ 标题（`cf-rise .45s .16s`）
 * + 副标题（`cf-rise .45s .26s`）。
 */
@Composable
private fun Hero() {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .popIn(delayMs = 50, durationMs = FtMotion.DURATION_CF_POP)
                .requiredSize(102.dp) // `.cf-badge { width/height: 102px; border-radius: 51px }`
                .clip(FtShape.pill)
                .background(FtColor.completeCircle)
                .border(1.dp, FtColor.completeCircleBorder, FtShape.pill),
            contentAlignment = Alignment.Center,
        ) {
            MedalIcon(modifier = Modifier.requiredSize(80.dp)) // `.cf-badge-icon { 80×80 }`
        }
        Text(
            text = stringResource(FtCompleteModel.TITLE_RES),
            modifier = Modifier
                .padding(top = 26.dp)
                .riseIn(delayMs = 160, durationMs = FtMotion.DURATION_CF_RISE_FAST),
            color = FtColor.txtHi,
            fontSize = 36.sp,
            lineHeight = 44.sp, // 原型显式声明
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )
        Text(
            text = stringResource(FtCompleteModel.SUBTITLE_RES),
            modifier = Modifier
                .padding(top = 10.dp)
                .riseIn(delayMs = 260, durationMs = FtMotion.DURATION_CF_RISE_FAST),
            color = FtColor.completeSub,
            fontSize = 18.sp,
            lineHeight = 24.sp, // 原型显式声明
            fontWeight = FontWeight.Normal,
            textAlign = TextAlign.Center,
        )
    }
}

/**
 * `.cf-streak` L234-260：连续记录卡（`cf-rise .5s .36s`）。
 * 底色与描边取样式表末尾的「Card Surface v1」（L356）。
 */
@Composable
private fun StreakCard(
    streakCount: Int,
    days: List<FtStreakDay>,
    modifier: Modifier = Modifier,
) {
    val streakA11y = stringResource(FtCompleteModel.STREAK_A11Y_RES)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .riseIn(delayMs = 360, durationMs = FtMotion.DURATION_CF_RISE_BASE)
            .clip(RoundedCornerShape(28.dp))
            .background(StreakFill)
            .border(1.dp, FtColor.line10, RoundedCornerShape(28.dp))
            .padding(18.dp), // `.cf-streak { padding: 18px }`
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 12.dp), // `.streak-head { margin-bottom: 12px }`
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = stringResource(FtCompleteModel.STREAK_TITLE_RES),
                color = FtColor.txtHi,
                fontSize = 18.sp,
                lineHeight = 21.6.sp, // 1.2 × 18px（原型显式声明）
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = stringResource(R.string.complete_streak_count, streakCount),
                style = FtType.natural(13f, 700, FtType.num),
                color = FtColor.accent,
            )
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .semantics { contentDescription = streakA11y }, // 原型 `role="img"` 的 aria-label
            horizontalArrangement = Arrangement.spacedBy(8.dp), // `.streak-days { gap: 8px }`
        ) {
            days.forEach { day ->
                StreakDayColumn(day = day, modifier = Modifier.weight(1f))
            }
        }
    }
}

/**
 * 整体 RPE 采集卡（逐字对齐鸿蒙 `WorkoutCompletePage.ets` 的 `rpeCard`）。
 *
 * 外卡：`padding 16` / `bg #08FFFFFF` / `radius 22` / `border #1AFFFFFF`——鸿蒙用
 * `WHITE_A03`(#08FFFFFF) + `WHITE_A10`(#1AFFFFFF)，Android 侧由 [StreakFill] 与
 * [FtColor.line10] 承载同名色值。
 *
 * 档位格子：10 个 `weight(1f)` 等宽，`height 34` / `radius 10` / 13sp Bold；
 * 选中 `accent` 底 + `onAccent` 字，未选 `glass8`(#14FFFFFF = 鸿蒙 WHITE_A08) 底 + `white70` 字。
 */
@Composable
private fun RpeCard(
    value: Int,
    saved: Boolean,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(RpeFill)
            .border(1.dp, FtColor.line10, RoundedCornerShape(22.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = stringResource(FtCompleteModel.RPE_TITLE_RES),
                color = FtColor.txtHi,
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
            )
            // 未评价走 RPE_UNRATED_RES，否则 RPE_VALUE_RES（`RPE n` + 可选「 · 已保存」）
            val statusRes = FtCompleteModel.rpeStatusRes(value, saved)
            Text(
                text = if (value <= 0) {
                    stringResource(statusRes)
                } else {
                    val suffix = if (saved) stringResource(FtCompleteModel.RPE_SAVED_RES) else ""
                    stringResource(statusRes, value, suffix)
                },
                color = FtColor.accent,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
            )
        }
        Text(
            text = stringResource(FtCompleteModel.RPE_HINT_RES),
            color = FtColor.white54,
            fontSize = 11.sp,
        )
        // 逐项 a11y 在 composable 作用域预先算好（`stringResource` 不能进非 composable lambda）
        val rpeA11y = FtCompleteModel.RPE_OPTIONS.map { option ->
            stringResource(
                FtCompleteModel.RPE_A11Y_OPTION_RES,
                option,
                stringResource(
                    if (value == option) FtCompleteModel.RPE_A11Y_SELECTED_RES
                    else FtCompleteModel.RPE_A11Y_UNSELECTED_RES,
                ),
            )
        }
        FtSegmentedPill(
            labels = FtCompleteModel.RPE_OPTIONS.map { it.toString() },
            // 未评价（value = 0）时 indexOf 返回 -1 → 滑块整体不渲染，不会误高亮第 1 档。
            selectedIndex = FtCompleteModel.RPE_OPTIONS.indexOf(value),
            onSelect = { index -> onSelect(FtCompleteModel.RPE_OPTIONS[index]) },
            fillWidth = true,
            buttonHeight = 34.dp,
            buttonFontSize = 13.sp,
            buttonFontWeight = FontWeight.Bold,
            itemGap = 4.dp,
            itemRadius = 10.dp,
            trackRadius = 10.dp,
            itemBackground = FtColor.glass8,
            itemContentDescription = { index -> rpeA11y[index] },
            inactiveColor = FtColor.white70,
            container = SegContainer.None,
        )
    }
}

/** `.streak-day` L254-259：28px 圆点 + 11px 星期字，`.on` 走翡翠、`.off` 走淡白。 */
@Composable
private fun StreakDayColumn(day: FtStreakDay, modifier: Modifier = Modifier) {    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp), // `.streak-day { gap: 6px }`
    ) {
        Box(
            modifier = Modifier
                .requiredSize(28.dp)
                .clip(FtShape.pill)
                .background(if (day.active) FtColor.streakDayOn else FtColor.streakDayOff),
        )
        Text(
            text = day.label,
            color = if (day.active) FtColor.accent else FtColor.white54,
            fontSize = 11.sp,
            lineHeight = 11.sp, // 1 × 11px（原型显式声明）
        )
    }
}

/** `.cf-dock` / `.cf-btn-primary` L262-289：12/20/20 内边距、顶部分隔线、52 高的主按钮。 */
@Composable
private fun Dock(onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .riseIn(delayMs = 600, durationMs = FtMotion.DURATION_CF_RISE_BASE)
            .background(FtColor.completeBg)
            .drawBehind {
                // `border-top: 1px solid var(--hairline)`：只画顶边（不是整圈描边）
                drawRect(
                    color = FtColor.hairline,
                    topLeft = Offset.Zero,
                    size = Size(size.width, 1.dp.toPx()),
                )
            }
            .padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 20.dp),
    ) {
        ContinueButton(onClick = onClick)
    }
}

/**
 * `.cf-btn.cf-btn-primary`：100% 宽、52 高、圆角 18、翡翠底、`:active` 缩到 .985。
 *
 * `aria-label="继续查看训练总结"`（原型 L436）逐字取自源码，按钮可见文案仍是「继续」。
 */
@Composable
private fun ContinueButton(onClick: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    // 裸值直送 graphicsLayer 是硬切（视觉上没有按压反馈），走 animateFloatAsState
    val scale by animateFloatAsState(
        targetValue = if (pressed) FtMotion.PRESS_SCALE_CTA else 1f,
        animationSpec = tween(FtMotion.DURATION_PRESS, easing = FtMotion.EASE_MOTION),
        label = "complete-continue-press-scale",
    )
    val continueA11y = stringResource(R.string.complete_a11y_continue)

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(shape)
            .background(FtColor.accent)
            .semantics { contentDescription = continueA11y }
            .clickable(
                interactionSource = interaction,
                indication = null,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = stringResource(FtCompleteModel.CONTINUE_LABEL_RES),
            style = FtType.natural(16f, 700),
            color = FtColor.onAccent,
        )
    }
}

/**
 * `.cf-badge-icon` L401-409：100×100 viewBox 的奖牌线稿，
 * `<g transform="translate(16 15) scale(2.85)">` 内是 24 单位空间里的六笔，
 * 描边 `var(--complete-check)`、宽 2、圆头圆角。
 */
@Composable
private fun MedalIcon(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / 100f
        val s = 2.85f * k
        val ox = 16f * k
        val oy = 15f * k
        fun x(v: Float) = ox + v * s
        fun y(v: Float) = oy + v * s
        val stroke = Stroke(width = 2f * s, cap = StrokeCap.Round, join = StrokeJoin.Round)

        val ribbon = Path().apply {
            moveTo(x(7f), y(4f)); lineTo(x(17f), y(4f)); lineTo(x(18f), y(9f))
            // `c0 3-2 5-6 5s-6-2-6-5z`（s 反射控制点）→ 两条三次贝塞尔
            cubicTo(x(18f), y(12f), x(16f), y(14f), x(12f), y(14f))
            cubicTo(x(8f), y(14f), x(6f), y(12f), x(6f), y(9f))
            close()
        }
        drawPath(ribbon, FtColor.completeCheck, style = stroke)
        drawPath(
            Path().apply { moveTo(x(5f), y(4f)); lineTo(x(19f), y(4f)) },
            FtColor.completeCheck, style = stroke,
        )
        drawPath(
            Path().apply { moveTo(x(8f), y(21f)); lineTo(x(16f), y(21f)) },
            FtColor.completeCheck, style = stroke,
        )
        drawPath(
            Path().apply { moveTo(x(12f), y(17f)); lineTo(x(12f), y(21f)) },
            FtColor.completeCheck, style = stroke,
        )
        // `M5 9H3a2 2 0 0 0 2 2`：左挂环（圆心 (5,9) 的四分之一圆，
        // 用切线交点 (3,11) 作控制点的二次贝塞尔逼近——该弧在本屏只约 5px）
        drawPath(
            Path().apply {
                moveTo(x(5f), y(9f)); lineTo(x(3f), y(9f))
                quadraticTo(x(3f), y(11f), x(5f), y(11f))
            },
            FtColor.completeCheck, style = stroke,
        )
        // `M19 9h2a2 2 0 0 1-2 2`：右挂环（圆心 (19,9)，控制点 (21,11)）
        drawPath(
            Path().apply {
                moveTo(x(19f), y(9f)); lineTo(x(21f), y(9f))
                quadraticTo(x(21f), y(11f), x(19f), y(11f))
            },
            FtColor.completeCheck, style = stroke,
        )
    }
}

/**
 * `.confetti-layer` / `.confetti-piece` L291-312 + `@keyframes cf-fall` L336-341。
 *
 * 38 片各自按 `--dur` / `--delay` / `--rot` 下落：`translateY 0 → 960px`、`rotate 0 → rot`、
 * `opacity 0 →(10%) 1 →(80%) 1 →(100%) 0`。以一条线性时钟统一驱动、逐片切片实现。
 */
@Composable
private fun ConfettiLayer(pieces: List<FtConfettiPiece>, layerAlpha: Float) {
    val totalMs = remember(pieces) {
        pieces.maxOf { it.delaySeconds + it.durationSeconds } * 1000f
    }
    val clock = remember { Animatable(0f) }
    LaunchedEffect(pieces) {
        clock.snapTo(0f)
        clock.animateTo(totalMs, tween(totalMs.toInt(), easing = LinearEasing))
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .graphicsLayer { alpha = layerAlpha }, // `.confetti-layer { transition: opacity .5s }`
    ) {
        pieces.forEach { piece ->
            val delayMs = piece.delaySeconds * 1000f
            val durMs = piece.durationSeconds * 1000f
            val local = ((clock.value - delayMs) / durMs).coerceIn(0f, 1f)
            val eased = FtMotion.EASE_FALL.transform(local)
            // cf-fall 的关键帧：0%→opacity 0，10%→1，80%→1，100%→0
            val alpha = when {
                local <= 0.1f -> local / 0.1f
                local <= 0.8f -> 1f
                else -> (1f - local) / 0.2f
            }

            Box(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    // `.confetti-piece { top: -24px; left: <rnd>% }`，设计空间 430 宽
                    .offset(
                        x = (piece.leftPercent / 100f * 430f).dp,
                        y = (-24f + eased * 960f).dp,
                    )
                    .size(width = piece.width.dp, height = piece.height.dp) // `.size` 而非 requiredSize：需被外层约束
                    .graphicsLayer {
                        this.alpha = alpha
                        rotationZ = eased * piece.rotationDeg
                    }
                    .clip(RoundedCornerShape(2.dp))
                    .background(ConfettiColors[piece.colorIndex]),
            )
        }
    }
}

// ── 入场动画（原型 `@keyframes` 的屏内复刻） ──────────────────────

/**
 * `@keyframes cf-rise`（L347-350）：`opacity 0 + translateY(14px)` → `opacity 1 + 位移 0`。
 */
@Composable
private fun Modifier.riseIn(delayMs: Int, durationMs: Int): Modifier {
    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        delay(delayMs.toLong())
        progress.animateTo(1f, tween(durationMs, easing = FtMotion.EASE_MOTION))
    }
    return this.graphicsLayer {
        alpha = progress.value
        translationY = (1f - progress.value) * 14.dp.toPx()
    }
}

/**
 * `@keyframes cf-pop`（L342-346）：`scale .82 / opacity 0` →(60%) `scale 1.04 / opacity 1`
 * →(100%) `scale 1`。
 */
@Composable
private fun Modifier.popIn(delayMs: Int, durationMs: Int): Modifier {
    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        delay(delayMs.toLong())
        progress.animateTo(1f, tween(durationMs, easing = FtMotion.EASE_MOTION))
    }
    return this.graphicsLayer {
        val t = progress.value
        val scale = if (t < 0.6f) {
            0.82f + (1.04f - 0.82f) * (t / 0.6f)
        } else {
            1.04f + (1f - 1.04f) * ((t - 0.6f) / 0.4f)
        }
        scaleX = scale
        scaleY = scale
        alpha = if (t < 0.6f) t / 0.6f else 1f
    }
}

// ── 屏内色值（原型 `:root` 无对应令牌，按 FtColorUtil 规则就地换算） ──
//
// 换算规则 AA = round(alpha × 255)

/** 末尾覆盖层 `.cf-streak` 底 `rgba(255,255,255,.031)` → round(7.905) = 8 = 0x08 */
private val StreakFill = Color(0x08FFFFFF)

/**
 * RPE 卡外卡底——鸿蒙 `PrototypeTokens.WHITE_A03`(`#08FFFFFF`)。
 * 与 [StreakFill] 色值同源（`rgba(255,255,255,.031)`），因语义不同而独立声明。
 */
private val RpeFill = Color(0x08FFFFFF)
/** 彩带五色（原型 `.confetti-piece.c0..c4`，L300-304）。 */
private val ConfettiColors = listOf(
    FtColor.accent,      // c0 var(--accent)
    FtColor.accentSoft,  // c1 var(--accent-soft)
    FtColor.accentDeep,  // c2 var(--accent-deep)
    FtColor.completeCheck, // c3 var(--complete-check)
    FtColor.white90,     // c4 var(--white-90)
)

// ── 训练域接线的屏内辅助 ─────────────────────────────────────────

/**
 * 连续训练天数：从「今天（若今天已练）或昨天」起向前逐日回溯命中数。
 * 今天尚未训练时不立刻归零（保持「连续记录」语义）。
 */
private fun currentStreak(trainingDates: Set<String>): Int {
    val calendar = Calendar.getInstance()
    if (!trainingDates.contains(WorkoutSessionService.formatDate(calendar.timeInMillis))) {
        calendar.add(Calendar.DAY_OF_MONTH, -1)
    }
    var streak = 0
    while (trainingDates.contains(WorkoutSessionService.formatDate(calendar.timeInMillis))) {
        streak++
        calendar.add(Calendar.DAY_OF_MONTH, -1)
    }
    return streak
}

/**
 * 本周（周首由 [weekStart] 决定、共 7 天）各天的打卡状态，与连续记录卡的 `.streak-day` 槽位
 * 一一对应。窗口起点与标签序统一由 [WeekWindow] 给出（周一 → 「一」…「日」；周日 → 「日」…「六」）。
 */
private fun weekActivity(trainingDates: Set<String>, weekStart: WeekStart): List<FtStreakDay> {
    val (weekStartMillis, _) = WeekWindow.weekRange(System.currentTimeMillis(), weekStart)
    val labels = WeekWindow.dayLabels(weekStart, currentLanguageTag())
    return (0 until 7).map { offset ->
        val day = Calendar.getInstance().apply {
            timeInMillis = weekStartMillis
            add(Calendar.DAY_OF_MONTH, offset)
        }
        FtStreakDay(
            label = labels[offset],
            active = trainingDates.contains(WorkoutSessionService.formatDate(day.timeInMillis)),
        )
    }
}
