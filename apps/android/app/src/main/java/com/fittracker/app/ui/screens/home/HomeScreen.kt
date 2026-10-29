package com.fittracker.app.ui.screens.home

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
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.TrainingPlanRepository
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.WeekWindow
import com.fittracker.app.data.service.currentLanguageTag
import com.fittracker.app.data.service.WorkoutRepository
import com.fittracker.app.data.service.WorkoutSessionService
import com.fittracker.app.data.service.stats.HomePlanService
import com.fittracker.app.ui.components.FtClockIcon
import com.fittracker.app.ui.components.FtDumbbellIcon
import com.fittracker.app.ui.components.FtTargetIcon
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.screens.plan.dayFocusMuscles
import com.fittracker.app.ui.theme.DuTokens
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import kotlin.math.roundToInt

/**
 * 首页（原型 `fittracker-welcome-home.html` 的 `screen-home` 帧）。
 *
 * 画布 390×844 直绘，由 `FtCanvas` 施加；本文件内所有 px 值 1:1 映射为 dp。
 * 底部 tabbar 由壳层 `FtApp` 提供，不属于本屏。
 *
 * 版式来源（原型 CSS 行号）：
 * `.home-content` L351-356 · `.home-head` L358-370 · `.today` L373-380 ·
 * `.today-top` L382-385 · `.today-id` L387-420 · `.today-ring` L422-453 ·
 * `.today-divider` L455-459 · `.today-metrics` L462-490 · 卡内按钮 L493-520 ·
 * `.week` L528-581。
 */
@Composable
fun HomeScreen(
    onNavigate: (String) -> Unit,
    modifier: Modifier = Modifier,
    vm: HomeViewModel = viewModel(),
) {
    // 状态与装载由 [HomeViewModel] 持有——`viewModel()` 取 NavBackStackEntry 作用域实例，
    // tab 切换（`saveState=true`）取回同一实例：首帧即真数据、装载只跑一次
    // （`LaunchedEffect(Unit)` 只在组件首次组合触发）。
    LaunchedEffect(Unit) { vm.load() }

    val dateText = vm.dateText
    val greetingText = vm.greetingText
    val weeklyProgressPercent = vm.weeklyProgressPercent
    val todayTitle = vm.todayTitle
    val todayMuscleText = vm.todayMuscleText
    val todayStatusText = vm.todayStatusText
    val todayExerciseCount = vm.todayExerciseCount
    val todayDurationMinutes = vm.todayDurationMinutes
    val todayMuscleGroupCount = vm.todayMuscleGroupCount
    val weeklyPlannedDays = vm.weeklyPlannedDays
    val weeklyTrainedCount = vm.weeklyTrainedCount
    val weekDays = vm.weekDays

    // 入场：头部 → 今日卡 → 周卡 逐层落位（错峰 40ms），落位后不再重播。
    var entered by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { entered = true }
    val headIn by animateFloatAsState(
        targetValue = if (entered) 1f else 0f,
        animationSpec = tween(FtMotion.DURATION_ENTER, easing = FtMotion.EASE_ENTER),
        label = "home-head-in",
    )
    val todayIn by animateFloatAsState(
        targetValue = if (entered) 1f else 0f,
        animationSpec = tween(
            FtMotion.DURATION_ENTER,
            delayMillis = FtMotion.DURATION_STAGGER,
            easing = FtMotion.EASE_ENTER,
        ),
        label = "home-today-in",
    )
    val weekIn by animateFloatAsState(
        targetValue = if (entered) 1f else 0f,
        animationSpec = tween(
            FtMotion.DURATION_ENTER,
            delayMillis = FtMotion.DURATION_STAGGER * 2,
            easing = FtMotion.EASE_ENTER,
        ),
        label = "home-week-in",
    )

    Column(
        modifier = modifier
            .fillMaxSize()
            // 内容自适应 + 可滚动（内容不足一屏时无滚动行为）：卡片按内容定高，
            // 富余高度留在页面底部，不再用 weight 把空白塞进卡片内部。
            .verticalScroll(rememberScrollState())
            .background(FtColor.ink0) // 原型 .appshell 背景 var(--ink-0)（L174/L177）
            // 与鸿蒙 HomeContent.ets 对齐：顶部 53、底部 36。
            // 安卓是 edge-to-edge（FtApp 的 contentWindowInsets = WindowInsets(0)），内容从屏幕物理
            // 顶端起算，故直接写 53；鸿蒙窗口非全屏、页面区已在状态栏下，那边用的是 53 - topInset。
            .padding(start = 16.dp, end = 16.dp, top = 53.dp, bottom = 36.dp),
        // 块间距两端不同（head→今日 19、今日→周卡 16），已下沉到各块自身的 top padding，
        // 不能用统一的 Arrangement.spacedBy 表达。
    ) {
        HomeHead(
            dateText = dateText,
            greeting = greetingText,
            modifier = Modifier.enterFromBelow(headIn),
        )
        TodayCard(
            todayTitle = todayTitle,
            muscleText = todayMuscleText,
            statusText = todayStatusText,
            exerciseCount = todayExerciseCount,
            durationMinutes = todayDurationMinutes,
            muscleGroupCount = todayMuscleGroupCount,
            progressPercent = weeklyProgressPercent,
            onStart = { onNavigate("start-workout") },
            onPreview = { onNavigate("workout") },
            modifier = Modifier.padding(top = 19.dp).enterFromBelow(todayIn),
        )
        WeekCard(
            days = weekDays,
            trainedCount = weeklyTrainedCount,
            plannedDays = weeklyPlannedDays,
            modifier = Modifier.padding(top = 16.dp).enterFromBelow(weekIn),
        )
    }
}

/** `.home-head` L358-370：日期 12.7px/500，问候 36.3px/700，两者间隔 5.4px。 */
@Composable
private fun HomeHead(dateText: String, greeting: String, modifier: Modifier = Modifier) {
    // 与今日卡的 19dp 间距由 TodayCard 的 top padding 提供，此处不再叠加。
    Column(modifier = modifier) {
        Text(
            text = dateText,
            color = FtColor.white70,
            fontSize = 12.7.sp,
            fontWeight = FontWeight.Medium,
            letterSpacing = 0.127.sp, // .01em × 12.7px
        )
        Text(
            text = greeting,
            modifier = Modifier.padding(top = 5.4.dp),
            color = FtColor.txtHi,
            fontSize = 36.3.sp,
            lineHeight = 43.56.sp, // 1.2 × 36.3px
            fontWeight = FontWeight.Bold,
        )
    }
}

/** 入场效果：透明度 0→1 叠加 8dp 上移落位。 */
private fun Modifier.enterFromBelow(progress: Float): Modifier = this.graphicsLayer {
    alpha = progress
    translationY = 8.dp.toPx() * (1f - progress)
}

/** `.today` L373-380：圆角 26、1px `--line-10` 描边、底 `rgba(255,255,255,.031)`。 */
@Composable
private fun TodayCard(
    todayTitle: String,
    muscleText: String,
    statusText: String,
    exerciseCount: Int,
    durationMinutes: Int,
    muscleGroupCount: Int,
    progressPercent: Int,
    onStart: () -> Unit,
    onPreview: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            // 原型卡阴影 `0 22px 44px rgba(0,0,0,.24)` 在深色底剖面上不可辨（参照渲染卡下平坦、无暗带）；
            // 而 Compose elevation 阴影会在卡下产生可测暗带（真机剖面 (9,13,16) vs 背景 (11,15,19)）——按原型剖面移除
            .clip(FtShape.panelLg)
            .background(CardFill)
            .border(1.dp, FtColor.line10, FtShape.panelLg)
            .padding(start = 18.dp, end = 18.dp, top = 19.dp, bottom = 18.dp), // 与鸿蒙 HomeContent.ets 对齐：19/18
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.Top,
        ) {
            TodayIdentity(
                title = todayTitle,
                muscleText = muscleText,
                statusText = statusText,
                modifier = Modifier.weight(1f),
            )
            TodayRing(
                percent = progressPercent / 100f,
                capText = stringResource(R.string.home_ring_caption),
                modifier = Modifier.padding(top = 4.dp), // 与鸿蒙对齐：环上距 4
            )
        }

        // `.today-divider` L455-459
        Box(
            modifier = Modifier
                .padding(top = 18.dp, bottom = 16.dp) // 与鸿蒙对齐：18/16
                .fillMaxWidth()
                .height(1.dp)
                .drawBehind {
                    drawRect(
                        brush = Brush.horizontalGradient(
                            0f to Color.Transparent,
                            0.5f to DividerLine,
                            1f to Color.Transparent,
                        ),
                    )
                },
        )

        TodayMetrics(
            exerciseCount = exerciseCount,
            durationMinutes = durationMinutes,
            muscleGroupCount = muscleGroupCount,
        )

        CtaButton(
            text = stringResource(R.string.home_action_start),
            onClick = onStart,
            modifier = Modifier.padding(top = 16.dp), // 与鸿蒙对齐：16
            bg = FtColor.accent,
            fg = FtColor.onAccent2,
            weight = 700,
        )
        CtaButton(
            text = stringResource(R.string.home_action_preview),
            onClick = onPreview,
            modifier = Modifier.padding(top = 8.dp),
            bg = GhostFill,
            fg = FtColor.txtHi,
            weight = 500,
            borderColor = FtColor.line10,
        )
    }
}

/** `.today-id` L387-420：训练名 / 推荐胶囊 / 肌群 / 训练日。 */
@Composable
private fun TodayIdentity(title: String, muscleText: String, statusText: String, modifier: Modifier = Modifier) {
    Column(modifier = modifier) {
        Text(
            text = stringResource(R.string.home_today_label),
            color = FtColor.accent,
            fontSize = 12.7.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 0.762.sp, // .06em × 12.7px
        )
        Row(
            modifier = Modifier.padding(top = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = title,
                color = FtColor.txtHi,
                fontSize = 22.sp,
                lineHeight = 24.64.sp, // 1.12 × 22px
                fontWeight = FontWeight.Bold,
            )
            RecommendChip()
        }
        Text(
            text = muscleText,
            modifier = Modifier.padding(top = 8.dp),
            color = FtColor.white62,
            fontSize = 12.7.sp,
        )
        Row(
            modifier = Modifier.padding(top = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(7.dp),
        ) {
            // 与鸿蒙对齐：12dp 容器内是 6dp 实心点 + 3dp 光环（外径 12）。
            // 原实现是 6dp 盒内画 3dp 内描边，外径只有 6dp。
            Box(
                modifier = Modifier
                    .size(12.dp)
                    .clip(CircleShape)
                    .background(FtColor.accent12),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .clip(CircleShape)
                        .background(FtColor.accent),
                )
            }
            Text(
                text = statusText,
                color = FtColor.white54,
                fontSize = 10.9.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

/**
 * 原型 `.today-id .rec` L398-405：
 * 9px/700、`accent-12` 底、`accent-17` 描边、圆角 999、内边距 3×8。
 * 与共享件 `FtChip` 不等价（字号/字重/描边均不同），故屏内自绘。
 */
@Composable
private fun RecommendChip() {
    Box(
        modifier = Modifier
            .clip(FtShape.pill)
            .background(FtColor.accent12)
            .border(1.dp, FtColor.accent17, FtShape.pill)
            .padding(horizontal = 8.dp, vertical = 3.dp),
    ) {
        Text(
            text = stringResource(R.string.home_recommend),
            color = FtColor.accent,
            fontSize = 9.sp,
            lineHeight = 10.8.sp, // 1.2 × 9px
            fontWeight = FontWeight.Bold,
            letterSpacing = 0.18.sp, // .02em × 9px
        )
    }
}

/**
 * `.today-ring` L422-453：96×96。
 *
 * 外环在原型里是 `conic-gradient(accent 0→50.4deg, rgba(255,255,255,.12) 50.4deg→360deg)`
 * 经径向遮罩抠成的 7px 环带。这里改用分层 `drawArc`：玻璃包边 → 轨道 → 远晕 → 近晕 → 主弧。
 * 原实现用 [Brush.sweepGradient] 给整圈着色，而端帽属 `Stroke` 参数、与 Brush 路径互斥，
 * 弧端只能平切；分层 drawArc + [StrokeCap.Round] 才拿得到圆头（鸿蒙侧同样因此改为自绘）。
 * CSS conic 从 12 点起算、Compose 弧从 3 点起算，故整体 rotate(-90°)。
 * 原型另有 `drop-shadow(0 0 9px rgba(80,236,167,.28))`，以双层半透明弧衰减近似。
 */
@Composable
private fun TodayRing(
    percent: Float,
    capText: String,
    modifier: Modifier = Modifier,
) {
    // 环与中心数字的同一个驱动值：曲线（EASE_ENTER）、时长（DURATION_RING_FILL）、
    // 错峰（DURATION_STAGGER）均与鸿蒙 HomeContent.playRingFill 同值。
    // 数字由 fill 求得，不再接受调用方传入的静态文案——否则两条动画各走各的曲线。
    var fillStarted by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { fillStarted = true }
    val fill by animateFloatAsState(
        targetValue = if (fillStarted) percent else 0f,
        animationSpec = tween(
            durationMillis = FtMotion.DURATION_RING_FILL,
            delayMillis = FtMotion.DURATION_STAGGER,
            easing = FtMotion.EASE_ENTER,
        ),
        label = "home-ring-fill",
    )
    val pct = (fill * 100f).roundToInt()
    // 读数拆成「整数 + %」两个 Text，TalkBack 需要整句；资源键因此保留给无障碍文案
    val ringA11y = stringResource(R.string.home_ring_percent, pct)
    Box(modifier = modifier.size(RingTokens.SIZE.dp).semantics { contentDescription = ringA11y }) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val strokeW = RingTokens.STROKE.dp.toPx()
            val radius = (size.minDimension - strokeW) / 2f
            val center = Offset(size.width / 2f, size.height / 2f)
            val done = fill >= RingTokens.DONE_ARC
            rotate(-90f, pivot = center) {
                // 玻璃包边：环带内外各 1dp 极淡轮廓，制造「玻璃管」观感
                drawArc(
                    color = FtColor.ringGlass,
                    startAngle = 0f,
                    sweepAngle = 360f,
                    useCenter = false,
                    style = Stroke(RingTokens.GLASS_WIDTH.dp.toPx(), cap = StrokeCap.Round),
                )
                // 未完成轨道；达成后淡出，让闭环本身更亮
                drawArc(
                    color = if (done) FtColor.ringTrackDone else FtColor.ringTrack,
                    startAngle = 0f,
                    sweepAngle = 360f,
                    useCenter = false,
                    style = Stroke(strokeW, cap = StrokeCap.Round),
                )
                if (fill >= RingTokens.MIN_ARC) {
                    val sweep = 360f * fill
                    // 远晕 / 近晕：两层更宽的半透明弧衰减，替代 blur（两端同构、无 GPU 滤镜依赖）
                    drawArc(
                        color = if (done) FtColor.ringGlowFarDone else FtColor.ringGlowFar,
                        startAngle = 0f,
                        sweepAngle = sweep,
                        useCenter = false,
                        style = Stroke(RingTokens.GLOW_FAR_WIDTH.dp.toPx(), cap = StrokeCap.Round),
                    )
                    drawArc(
                        color = if (done) FtColor.ringGlowNearDone else FtColor.ringGlowNear,
                        startAngle = 0f,
                        sweepAngle = sweep,
                        useCenter = false,
                        style = Stroke(RingTokens.GLOW_NEAR_WIDTH.dp.toPx(), cap = StrokeCap.Round),
                    )
                    drawArc(
                        color = FtColor.accent,
                        startAngle = 0f,
                        sweepAngle = sweep,
                        useCenter = false,
                        style = Stroke(strokeW, cap = StrokeCap.Round),
                    )
                }
            }
        }
        Box(
            modifier = Modifier
                .padding(9.dp)
                .fillMaxSize()
                .clip(CircleShape)
                // 内圈顶部受光：与鸿蒙同口径，用纵向渐变近似原型的径向顶光
                .background(
                    Brush.verticalGradient(
                        0f to Color(0x0FFFFFFF),
                        0.52f to Color(0x000D1117),
                        1f to FtColor.ringInner,
                    )
                )
                .border(1.dp, FtColor.ringInnerBorder, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        text = "$pct",
                        color = FtColor.txtHi,
                        fontFamily = FtType.num,
                        fontSize = 19.sp,
                        lineHeight = 19.sp, // line-height 1
                        fontWeight = FontWeight.Bold,
                        letterSpacing = (-0.38).sp, // -.02em × 19px
                    )
                    Text(
                        text = "%",
                        modifier = Modifier.padding(start = 1.dp, bottom = 1.5.dp),
                        color = FtColor.txtHi.copy(alpha = 0.72f),
                        fontFamily = FtType.num,
                        fontSize = 11.sp,
                        lineHeight = 11.sp,
                        fontWeight = FontWeight.Medium,
                    )
                }
                Text(
                    text = capText,
                    color = FtColor.white54,
                    fontSize = 9.5.sp,
                    letterSpacing = 0.19.sp, // .02em × 9.5px
                )
            }
        }
    }
}

/** `.today-metrics` L462-490：三格，图标底 38×38、值 26px/700、注 8.8px。 */
@Composable
private fun TodayMetrics(exerciseCount: Int, durationMinutes: Int, muscleGroupCount: Int) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        MetricCell(
            modifier = Modifier.weight(1f),
            label = stringResource(R.string.home_metric_exercises),
            value = exerciseCount.toString(),
            note = stringResource(R.string.home_metric_exercises_unit),
        ) { FtDumbbellIcon(modifier = Modifier.size(20.dp), color = FtColor.accent) }
        MetricCell(
            modifier = Modifier.weight(1f),
            label = stringResource(R.string.home_metric_duration),
            value = durationMinutes.toString(),
            note = stringResource(R.string.home_metric_duration_unit),
        ) { FtClockIcon(modifier = Modifier.size(20.dp), color = FtColor.accent) }
        MetricCell(
            modifier = Modifier.weight(1f),
            label = stringResource(R.string.home_metric_muscles),
            value = muscleGroupCount.toString(),
            note = stringResource(R.string.home_metric_muscles_unit),
        ) { FtTargetIcon(modifier = Modifier.size(20.dp), color = FtColor.accent) }
    }
}

@Composable
private fun MetricCell(
    label: String,
    value: String,
    note: String,
    modifier: Modifier = Modifier,
    icon: @Composable () -> Unit,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(38.dp)
                .clip(FtShape.md)
                .background(FtColor.accent07)
                .border(1.dp, FtColor.accent12, FtShape.md),
            contentAlignment = Alignment.Center,
        ) {
            icon()
        }
        Text(
            text = label,
            modifier = Modifier.padding(top = 8.dp),
            color = FtColor.white62,
            fontSize = 9.8.sp,
            textAlign = TextAlign.Center,
        )
        Text(
            text = value,
            color = FtColor.txtHi,
            fontFamily = FtType.num,
            fontSize = 26.sp,
            lineHeight = 26.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = (-0.52).sp, // -.02em × 26px
        )
        Text(
            text = note,
            color = FtColor.white54,
            fontSize = 8.8.sp,
            textAlign = TextAlign.Center,
        )
    }
}

/** 卡内 40px 高小按钮（原型 `.today .btn-primary` / `.btn-ghost` L493-520）。 */
@Composable
private fun CtaButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    bg: Color,
    fg: Color,
    weight: Int,
    borderColor: Color? = null,
) {
    val shape = RoundedCornerShape(20.dp)
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    // 只有无描边的实心主按钮用 Duolingo 硬边厚底；次要/ghost 保留原型的 scale 按压
    val usesPressDepth = borderColor == null
    val scale by animateFloatAsState(
        targetValue = if (!usesPressDepth && pressed) FtMotion.PRESS_SCALE_CTA else 1f,
        animationSpec = tween(FtMotion.DURATION_PRESS, easing = FtMotion.EASE_MOTION),
        label = "home-cta-press-scale",
    )
    val depth = if (usesPressDepth && !pressed) DuTokens.PRESS_DEPTH else 0.dp
    val shift = if (usesPressDepth && pressed) DuTokens.PRESS_SHIFT else 0.dp
    Box(
        modifier = modifier
            .fillMaxWidth()
            // 自适应：用 minHeight 而非 height —— 系统字号放大（≤1.3×）时按钮需能随之长高，
            // 定高会把文字裁掉。参考态下两者等价（单行文字高度小于 40dp）。
            .defaultMinSize(minHeight = 40.dp)
            // 按压反馈：主按钮走厚底收平 + 下沉，次要按钮走 `scale(.985)`
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
                translationY = shift.toPx()
            }
            .clip(shape)
            .background(bg)
            // 硬边厚底（零模糊）：画在按钮面之上，由 clip 收进圆角
            .drawBehind {
                if (depth.value > 0f) {
                    val thickness = depth.toPx()
                    drawRect(
                        color = FtColor.accentDeep,
                        topLeft = Offset(0f, size.height - thickness),
                        size = Size(size.width, thickness),
                    )
                }
            }
            // 内容避让厚底，按钮总高不变
            .padding(bottom = depth)
            .then(if (borderColor != null) Modifier.border(1.dp, borderColor, shape) else Modifier)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            color = fg,
            fontSize = 13.6.sp,
            fontWeight = FontWeight(weight),
        )
    }
}

/** `.week` L528-581：圆角 27.2、1px `--line-10` 描边、底 `rgba(255,255,255,.031)`。 */
@Composable
private fun WeekCard(
    days: List<HomeWeekDay>,
    trainedCount: Int,
    plannedDays: Int,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .height(168.dp) // 与鸿蒙对齐：固定 168（16 上下内边距 + 40 标题行 + 18 间距 + 78 日点行）
            .clip(WeekShape)
            .background(CardFill)
            .border(1.dp, FtColor.line10, WeekShape)
            .padding(16.dp), // 与鸿蒙对齐：16
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(40.dp), // 与鸿蒙对齐：标题行定高 40
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = stringResource(R.string.home_week_title),
                    color = FtColor.txtHi,
                    fontSize = 14.5.sp,
                    lineHeight = 22.sp,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = weekRangeSubtitle(days),
                    color = FtColor.white40,
                    fontSize = 10.sp,
                    lineHeight = 16.sp,
                )
            }
            Text(
                text = stringResource(R.string.home_week_count, trainedCount, plannedDays),
                color = FtColor.accent,
                fontSize = 10.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.Bold,
            )
        }

        // 与鸿蒙对齐：标题行与周视图之间 18（标题行已定高 40）。
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 18.dp),
            horizontalArrangement = Arrangement.spacedBy(7.dp),
        ) {
            days.forEach { day ->
                WeekDay(
                    modifier = Modifier.weight(1f),
                    label = day.label,
                    date = day.date,
                    active = day.active,
                )
            }
        }
    }
}

@Composable
private fun WeekDay(
    label: String,
    date: Int,
    active: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.height(78.dp), // 与鸿蒙对齐：14 + 8 + 34 + 8 + 14
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = label,
            color = FtColor.white62,
            fontSize = 10.sp,
            lineHeight = 14.sp, // 与鸿蒙对齐：显式行高，避免字体默认行高把列撑高
            fontWeight = FontWeight.SemiBold,
        )
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(if (active) FtColor.accent else DayDotFill)
                .border(
                    4.dp.takeIf { active } ?: 1.dp,
                    if (active) FtColor.accent12 else FtColor.line14,
                    CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (active) {
                CheckMark()
            }
        }
        Text(
            text = date.toString(),
            color = FtColor.white54,
            fontSize = 10.sp,
            lineHeight = 14.sp, // 与鸿蒙对齐：显式行高
            fontWeight = FontWeight.SemiBold,
        )
    }
}

/** 原型 `.week-day.active .dot::after`：旋转 45° 的 L 形勾。 */
@Composable
private fun CheckMark() {
    Box(
        modifier = Modifier
            .size(9.dp)
            .drawBehind {
                val w = 2.dp.toPx()
                val p = androidx.compose.ui.graphics.Path().apply {
                    moveTo(size.width * 0.15f, size.height * 0.5f)
                    lineTo(size.width * 0.42f, size.height * 0.78f)
                    lineTo(size.width * 0.9f, size.height * 0.18f)
                }
                drawPath(
                    p,
                    FtColor.onAccent,
                    style = Stroke(w, cap = androidx.compose.ui.graphics.StrokeCap.Round),
                )
            },
    )
}

// ── 周节奏数据（对齐鸿蒙 `HomeContent.HomeWeekDayItem` / `createWeekDayItems`） ──
//
// `HomeWeekDay` / `buildHomeWeekDays` / `weekDateKey` 已随状态迁入 HomeViewModel.kt；
// 此处只留 `weekRangeSubtitle`（依赖 `stringResource`，是 @Composable，必须留在屏内）。

/**
 * 「本周节奏」副标题「周X—周Y」——随设置周首联动（周首标签序的唯一真源是
 * [buildHomeWeekDays] 里的 [WeekWindow.dayLabels]，此处直接取首尾标签，不另算一遍周窗口）。
 */
@Composable
private fun weekRangeSubtitle(days: List<HomeWeekDay>): String {
    val labels: List<String> = if (days.isEmpty()) {
        WeekWindow.dayLabels(WeekStart.MONDAY, currentLanguageTag())
    } else {
        listOf(days.first().label, days.last().label)
    }
    return stringResource(R.string.home_week_range, labels.first(), labels.last())
}

// ── 屏内色值（原型 `:root` 无对应令牌，按 FtColorUtil 规则就地定义） ──
//
// 换算规则 AA = round(alpha × 255)

/** `rgba(255,255,255,.031)` → round(7.905) = 8 = 0x08（`.today` / `.week` 底色） */
private val CardFill = Color(0x08FFFFFF)

/** `rgba(255,255,255,.031)` 的幽灵按钮底（`.today .btn-ghost`） */
private val GhostFill = Color(0x08FFFFFF)

// ── 进度环尺寸（与鸿蒙 `RingTokens` 逐值同源） ──
// 颜色在 `FtColor.ring*`；这里只放绘制几何，避免屏内出现裸数字。
private object RingTokens {
    const val SIZE = 96
    const val STROKE = 7
    const val GLASS_WIDTH = 9
    const val GLOW_NEAR_WIDTH = 11
    const val GLOW_FAR_WIDTH = 16
    /** 低于该进度不画弧与光晕：圆头端帽在 0 附近会留下一个孤立圆点 */
    const val MIN_ARC = 0.004f
    /** 达成态阈值 */
    const val DONE_ARC = 0.999f
}

/** `rgba(255,255,255,.13)` → round(33.15) = 33 = 0x21（分隔线中段） */
private val DividerLine = Color(0x21FFFFFF)

/** `rgba(255,255,255,.06)` → round(15.3) = 15 = 0x0F（未激活日格底） */
private val DayDotFill = Color(0x0FFFFFFF)

/** 原型 `.week` 的 `border-radius: 27.2px` */
private val WeekShape = RoundedCornerShape(27.2.dp)
