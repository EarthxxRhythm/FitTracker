package com.fittracker.app.ui.screens.home

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.res.stringResource
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
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType

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

    Column(
        modifier = modifier
            .fillMaxSize()
            // 用户要求：首页不可滑动（内容配合单屏，移除滚动容器）
            .background(FtColor.ink0) // 原型 .appshell 背景 var(--ink-0)（L174/L177）
            .padding(start = 16.dp, end = 16.dp, top = 44.dp, bottom = 20.dp), // 压缩进单屏：53/36 → 44/20
    ) {
        HomeHead(dateText = dateText, greeting = greetingText)
        // 弹性撑满（同计划页 2f:8f 的做法）：抬头保持自然高，两张卡按**自然高度比**
        // （实测 469 : 136 ≈ 3.4 : 1）分配剩余高度——真机内容区比设计画布高，多出的高度
        // 按此比例分给两张卡，卡片等比变高，底部不再留空档。
        TodayCard(
            todayTitle = todayTitle,
            muscleText = todayMuscleText,
            statusText = todayStatusText,
            exerciseCount = todayExerciseCount,
            durationMinutes = todayDurationMinutes,
            muscleGroupCount = todayMuscleGroupCount,
            progressPercent = weeklyProgressPercent,
            onStart = { onNavigate("active") },
            onPreview = { onNavigate("workout") },
            modifier = Modifier.weight(3.4f),
        )
        WeekCard(
            days = weekDays,
            trainedCount = weeklyTrainedCount,
            plannedDays = weeklyPlannedDays,
            modifier = Modifier.weight(1f),
        )
    }
}

/** `.home-head` L358-370：日期 12.7px/500，问候 36.3px/700，两者间隔 5.4px。 */
@Composable
private fun HomeHead(dateText: String, greeting: String) {
    Column(modifier = Modifier.padding(bottom = 12.dp)) { // 压缩：19 → 12
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
            .padding(start = 18.dp, end = 18.dp, top = 14.dp, bottom = 12.dp), // 压缩：20/18 → 14/12
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
                valueText = stringResource(R.string.home_ring_percent, progressPercent),
                capText = stringResource(R.string.home_ring_caption),
            )
        }

        // `.today-divider` L455-459
        Box(
            modifier = Modifier
                .padding(top = 12.dp, bottom = 10.dp) // 压缩：18/16 → 12/10
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

        // 弹性间隔：卡片被拉伸时多出的高度落在这一处——下方操作按钮组因此贴住卡片底缘，
        // 空白不会堆在卡片末尾（未拉伸时该间隔为 0，与原布局等价）。
        Box(modifier = Modifier.weight(1f))

        CtaButton(
            text = stringResource(R.string.home_action_start),
            onClick = onStart,
            modifier = Modifier.padding(top = 10.dp), // 压缩：16 → 10
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
            // 原型 `.day::before`：6px 圆点 + 3px accent-12 光环
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(FtColor.accent)
                    .border(3.dp, FtColor.accent12, CircleShape),
            )
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
 * 外环是 `conic-gradient(accent 0→50.4deg, rgba(255,255,255,.12) 50.4deg→360deg)`
 * 经径向遮罩抠成的 7px 环带。Compose 用 [Brush.sweepGradient] 等价表达：
 * 50.4/360 = 0.14；CSS conic 从 12 点起算，Compose sweep 从 3 点起算，故整体 rotate(-90°)。
 * 原型另有 `drop-shadow(0 0 9px rgba(80,236,167,.28))`，此处以较宽的半透明描边近似。
 */
@Composable
private fun TodayRing(
    percent: Float,
    valueText: String,
    capText: String,
) {
    Box(modifier = Modifier.size(96.dp)) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val strokeW = 7.dp.toPx()
            val radius = (size.minDimension - strokeW) / 2f
            val center = Offset(size.width / 2f, size.height / 2f)
            rotate(-90f, pivot = center) {
                // 光晕近似
                drawCircle(
                    color = RingGlow,
                    radius = radius,
                    center = center,
                    style = Stroke(strokeW * 2.4f),
                )
                drawCircle(
                    brush = Brush.sweepGradient(
                        0f to FtColor.accent,
                        percent to FtColor.accent,
                        percent to RingTrack,
                        1f to RingTrack,
                    ),
                    radius = radius,
                    center = center,
                    style = Stroke(strokeW),
                )
            }
        }
        Box(
            modifier = Modifier
                .padding(9.dp)
                .fillMaxSize()
                .clip(CircleShape)
                .background(FtColor.ringInner)
                .border(1.dp, InnerRingBorder, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = valueText,
                    color = FtColor.txtHi,
                    fontFamily = FtType.num,
                    fontSize = 19.sp,
                    lineHeight = 19.sp, // line-height 1
                    fontWeight = FontWeight.Bold,
                    letterSpacing = (-0.38).sp, // -.02em × 19px
                )
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
    Box(
        modifier = modifier
            .fillMaxWidth()
            // 自适应：用 minHeight 而非 height —— 系统字号放大（≤1.3×）时按钮需能随之长高，
            // 定高会把文字裁掉。参考态下两者等价（单行文字高度小于 40dp）。
            .defaultMinSize(minHeight = 40.dp)
            .clip(shape)
            .background(bg)
            .then(if (borderColor != null) Modifier.border(1.dp, borderColor, shape) else Modifier)
            .clickableNoRipple(onClick = onClick),
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
            .padding(top = 10.dp)
            .fillMaxWidth()
            .clip(WeekShape)
            .background(CardFill)
            .border(1.dp, FtColor.line10, WeekShape)
            .padding(12.dp), // 压缩：top 16→10、内 16→12
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 12.dp), // 压缩：18 → 12
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

        // 弹性间隔：卡片被拉伸时多出的高度落在标题行与周视图之间，周视图贴住卡片底缘。
        Box(modifier = Modifier.weight(1f))

        Row(
            modifier = Modifier.fillMaxWidth(),
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
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = label,
            color = FtColor.white62,
            fontSize = 10.sp,
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

/** `rgba(255,255,255,.12)` → round(30.6) = 31 = 0x1F（进度环未完成段） */
private val RingTrack = Color(0x1FFFFFFF)

/** `rgba(80,236,167,.28)` → round(71.4) = 71 = 0x47（进度环 drop-shadow） */
private val RingGlow = Color(0x4750ECA7)

/** `rgba(255,255,255,.09)` → round(22.95) = 23 = 0x17（进度环内圈描边） */
private val InnerRingBorder = Color(0x17FFFFFF)

/** `rgba(255,255,255,.13)` → round(33.15) = 33 = 0x21（分隔线中段） */
private val DividerLine = Color(0x21FFFFFF)

/** `rgba(255,255,255,.06)` → round(15.3) = 15 = 0x0F（未激活日格底） */
private val DayDotFill = Color(0x0FFFFFFF)

/** 原型 `.week` 的 `border-radius: 27.2px` */
private val WeekShape = RoundedCornerShape(27.2.dp)
