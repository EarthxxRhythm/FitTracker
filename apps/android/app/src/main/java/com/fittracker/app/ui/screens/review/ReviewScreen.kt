package com.fittracker.app.ui.screens.review

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import com.fittracker.app.R
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.BodyRecordService
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.WeeklyStats
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.WeekWindow
import com.fittracker.app.data.service.currentLanguageTag
import com.fittracker.app.data.service.WorkoutRepository
import com.fittracker.app.data.service.WorkoutSessionService
import com.fittracker.app.data.service.stats.PersonalRecordService
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType

/** 时间尺度（原型 `data-scale`）。 */
private enum class ReviewScale { WEEK, MONTH }

/**
 * 训练回顾屏（原型 `fittracker-review.html` 的 `screen-review` 帧，L1162-1467）。
 *
 * 画布 390×844 直绘（`.review-shell { position:absolute; inset:0 }`）。**是 Tab 一级路由**，
 * 底栏由 `FtApp` 渲染、本屏不画（与 home / plan 同口径）。
 *
 * 版式来源（原型 CSS 行号）：
 * `.review-shell`/`.viewport`/`.pane` L217 前段 · `.review-content` L221-223 ·
 * `.review-stats` L239-243 · `.seg`/`.seg-btn` L252-282 · `.overview`/`.ov-*` L434-475 ·
 * `.stats`/`.stat`/`.s-*` L476-503 · `.weekly`/`.wk-*`/`.bar-*` L505-543 ·
 * 月历 `.month-cal` L335-433 · `.openstats` 作用域 L905-940 · `.card`/`.card-title` L941-957 ·
 * `.bodymap`/`.bm-*`/`.hm-*` L958-1020 · `.chart`/`.wg-foot` L1040-1055 · `.rm-*` L1085-1105 ·
 * `.effort-*` L1195-1210 · `.goal-btn`/`.goal-modal` L1110-1190 · Card Surface v1 覆盖 L1110 后。
 *
 * 三处**以源码为准**的取舍：
 * 1. 样式表末尾「Card Surface v1」把 `.overview`/`.stat`/`.weekly`/`.openstats .card`
 *    的底色与描边统一改写为 `rgba(255,255,255,.031)` / `--line-10`——按**末尾**规则实现，
 *    故 `.stat` 声明的 `--surface-stat` 实际不生效。
 * 2. 目标弹窗的 `backdrop-filter: blur(5px)` **未复刻**（Compose 无「模糊下层」原语），
 *    只保留 `rgba(4,6,8,.62)` 遮罩——与同仓 active / planGroup 的既有取舍一致。
 * 3. 月历图例五个方块在原型里是同一个浅白色（层叠特异性所致，见 [FtReviewColors]），
 *    如实还原而非「修正」。
 *
 * 路由：原型本文件 `FT_APP.routes` 是空表（L1838），底栏跳转由壳层负责；本屏不放路由。
 */
@Composable
fun ReviewScreen(
    onNavigate: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var scale by remember { mutableStateOf(ReviewScale.WEEK) }
    var muscleMode by remember { mutableStateOf(MuscleMode.BALANCE) }
    var selectedMuscle by remember { mutableStateOf<String?>(null) }
    var effortMetric by remember { mutableStateOf(EffortMetric.RIR) }
    var goal by remember { mutableStateOf(FtReviewModel.initialGoal()) }
    var goalLineY by remember { mutableFloatStateOf(FtReviewModel.INITIAL_GOAL_LINE_Y) }
    var goalModalOpen by remember { mutableStateOf(false) }

    // Wave 4 / W3-2b 资料域接线：复盘派生数据取自本地会话仓储与体重记录服务。空库时保持样例
    // （既有视觉），有数据时用服务实算「训练 / 时长」统计、1RM 列表、训练节奏（周柱 / 月历）
    // 与体重变化（数值 / 曲线 / 「较上周」脚注）；体态图（肌肉地图）本轮仍为样例——
    // V2：需肌群聚合服务（WorkoutSet.exerciseId × ContentRepository 肌肉映射）。
    val context = LocalContext.current
    val resources = LocalResources.current
    // 空库降级样例：1RM 四行文案走资源（真实路径由 PersonalRecordService 填充）。
    val sampleOneRmRows = remember(context) {
        FtReviewModel.ONE_RM_SAMPLES.map { sample ->
            OneRmRow(
                name = resources.getString(sample.nameRes),
                src = resources.getString(sample.srcRes),
                value = sample.value,
                unit = resources.getString(R.string.review_unit_kg),
            )
        }
    }
    var oneRmRows by remember { mutableStateOf(sampleOneRmRows) }
    var weekStats by remember { mutableStateOf<WeeklyStats?>(null) }
    var weekBars by remember { mutableStateOf(FtReviewModel.WEEK_BARS) }
    var monthCells by remember { mutableStateOf(FtReviewModel.MONTH_CELLS) }
    var monthLabel by remember { mutableStateOf(resources.getString(FtReviewModel.MONTH_LABEL_RES)) }
    var monthMeta by remember { mutableStateOf(resources.getString(FtReviewModel.MONTH_META_RES)) }
    var weekHeadText by remember { mutableStateOf(resources.getString(FtReviewModel.WEEK.weekRes)) }
    var monthHeadText by remember { mutableStateOf(resources.getString(FtReviewModel.MONTH.weekRes)) }
    var monthHead by remember { mutableStateOf(WeekWindow.dayLabels(WeekStart.MONDAY)) }
    var weightCurrent by remember { mutableStateOf(FtReviewModel.WEIGHT_CURRENT) }
    var weightDelta by remember { mutableStateOf(resources.getString(FtReviewModel.WEIGHT_DELTA_RES)) }
    var weightPoints by remember { mutableStateOf(FtReviewModel.WEIGHT_POINTS) }
    var hasWeightRecords by remember { mutableStateOf(false) }
    var weightDeltaValue by remember { mutableStateOf("") }
    LaunchedEffect(Unit) {
        val store = JsonStore(context.appDataStore)
        val now = System.currentTimeMillis()
        val weekStart = SettingsService.loadSettings(store).weekStart
        // 周/月尺度抬头与月历表头：纯日期计算（与数据有无无关）
        weekHeadText = resources.getString(R.string.review_head_week, WeekWindow.weekRangeText(now, weekStart, currentLanguageTag()))
        val monthCal = java.util.Calendar.getInstance().apply { timeInMillis = now }
        monthHeadText = resources.getString(R.string.review_head_month, monthCal.get(java.util.Calendar.MONTH) + 1)
        monthHead = WeekWindow.dayLabels(weekStart, currentLanguageTag())
        val sessions = WorkoutRepository.getSessions(store)
        if (sessions.isNotEmpty()) {
            weekStats = WorkoutSessionService.weeklyStats(sessions, now, weekStart)
            weekBars = FtReviewModel.weeklyBars(sessions, now, weekStart)
            monthCells = FtReviewModel.monthGrid(sessions, now, weekStart)
            val monthLabelArgs = FtReviewModel.monthLabel(now)
            monthLabel = resources.getString(R.string.review_month_label, monthLabelArgs.year, monthLabelArgs.month)
            val monthMetaArgs = FtReviewModel.monthMeta(sessions, now)
            monthMeta = resources.getString(R.string.review_month_meta, monthMetaArgs.days, monthMetaArgs.minutes)
            val details = PersonalRecordService.createRecordDetails(sessions)
            if (details.isNotEmpty()) {
                oneRmRows = details.take(4).map { detail ->
                    OneRmRow(
                        name = detail.exerciseName,
                        src = detail.bestDateText,
                        value = detail.bestOneRepMax.toString(),
                        unit = resources.getString(R.string.review_unit_kg),
                    )
                }
            }
        }
        // W3-1 体重记录服务：有记录用真实值，无记录回落原型样例（与 BodyScreen 的 hasRecords/回落同口径）。
        val records = BodyRecordService.loadRecords(store)
        if (records.isNotEmpty()) {
            val deltaKg = BodyRecordService.weekDeltaKg(records, now)
            weightCurrent = FtReviewModel.weightCurrentText(records.last().kg)
            weightDelta = resources.getString(R.string.review_weight_delta_week, FtReviewModel.weightDeltaValue(deltaKg))
            weightDeltaValue = FtReviewModel.weightDeltaValue(deltaKg)
            hasWeightRecords = true
            val trend = BodyRecordService.weekTrend(records, now, weekStart, currentLanguageTag())
            if (trend != null) weightPoints = FtReviewModel.weightPoints(trend.values)
        }
    }

    val baseData = if (scale == ReviewScale.WEEK) FtReviewModel.WEEK else FtReviewModel.MONTH
    val weekData = weekStats
    val data = run {
        val stats = baseData.stats.toMutableList()
        if (scale == ReviewScale.WEEK && weekData != null) {
            stats[0] = ReviewStat(R.string.review_stat_workouts, weekData.count.toString(), R.string.review_unit_times)
            stats[1] = ReviewStat(R.string.review_stat_duration, (weekData.duration / 60).toString(), R.string.review_unit_minutes)
        }
        if (hasWeightRecords) {
            stats[2] = ReviewStat(R.string.review_stat_weight_change, weightDeltaValue, R.string.review_unit_kg)
        }
        baseData.copy(stats = stats)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(FtColor.ink0), // `.review-shell` 底 var(--ink-0)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState()), // `.pane-scroll`
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.3.dp, end = 16.3.dp, top = 52.6.dp, bottom = 36.3.dp),
                verticalArrangement = Arrangement.spacedBy(16.3.dp), // `.review-stats` / `.openstats` gap
            ) {
                ScaleToolbar(scale = scale, onScale = { scale = it })
                OverviewCard(data = data, headText = if (scale == ReviewScale.WEEK) weekHeadText else monthHeadText)
                StatsRow(stats = data.stats)
                ActivityCard(
                    scale = scale,
                    data = data,
                    weekBars = weekBars,
                    monthCells = monthCells,
                    monthLabel = monthLabel,
                    monthMeta = monthMeta,
                    monthHead = monthHead,
                )

                // .openstats 作用域的四张卡（外层 gap 与 .review-stats 同为 16.3，故并列即可）
                MuscleMapCard(
                    mode = muscleMode,
                    selected = selectedMuscle,
                    onMode = { muscleMode = it; selectedMuscle = null },
                    onSelect = { selectedMuscle = it },
                )
                WeightGoalCard(
                    goal = goal,
                    goalLineY = goalLineY,
                    points = weightPoints,
                    currentText = weightCurrent,
                    deltaText = weightDelta,
                    onOpenGoal = { goalModalOpen = true },
                )
                EffortCard(metric = effortMetric, onMetric = { effortMetric = it })
                OneRmCard(rows = oneRmRows)
            }
        }

        if (goalModalOpen) {
            GoalModal(
                initial = goal,
                onDismiss = { goalModalOpen = false },
                onSave = { value ->
                    goal = value
                    goalLineY = FtReviewModel.goalLineY(value)
                    goalModalOpen = false
                },
            )
        }
    }
}

// ── 时间尺度工具条 ───────────────────────────────────────────────

/** `.review-toolbar` + `.seg`（L249-282）：胶囊分段控件，工具栏里靠左、按内容宽。 */
@Composable
private fun ScaleToolbar(scale: ReviewScale, onScale: (ReviewScale) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(), // `.review-toolbar`,space-between（仅一个子元素 → 靠左）
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SegmentedPill(
            labels = listOf(stringResource(R.string.review_scale_week), stringResource(R.string.review_scale_month)),
            selectedIndex = if (scale == ReviewScale.WEEK) 0 else 1,
            onSelect = { onScale(if (it == 0) ReviewScale.WEEK else ReviewScale.MONTH) },
        )
    }
}

/**
 * `.seg` / `.seg-btn`（L252-282 与 `.openstats .seg` L962-982）。
 *
 * 两个变体：工具栏里是 `inline-flex`（按内容宽、按钮 44 高 20 内边距），
 * openstats 里是 `width:100%` + 按钮 `flex:1`（36 高 12 内边距）。
 */
@Composable
private fun SegmentedPill(
    labels: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
    fillWidth: Boolean = false,
    buttonHeight: Dp = 44.dp,
    buttonPadH: Dp = 20.dp,
    inactiveColor: Color = FtColor.white62,
    contentDescription: String? = null,
) {
    Row(
        modifier = modifier
            .then(if (fillWidth) Modifier.fillMaxWidth() else Modifier)
            .then(
                if (contentDescription != null) {
                    Modifier.semantics { this.contentDescription = contentDescription }
                } else {
                    Modifier
                },
            )
            .clip(FtShape.pill) // radius 999 + padding 3
            .background(SegFill)
            .border(1.dp, FtColor.line10, FtShape.pill)
            .padding(3.dp),
    ) {
        labels.forEachIndexed { index, label ->
            val active = index == selectedIndex
            Box(
                modifier = Modifier
                    .then(if (fillWidth) Modifier.weight(1f) else Modifier)
                    .height(buttonHeight)
                    .clip(FtShape.pill)
                    .background(if (active) FtColor.accent else Color.Transparent)
                    .clickableNoRipple { onSelect(index) }
                    .padding(horizontal = buttonPadH),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = label,
                    fontSize = 13.sp,
                    fontWeight = if (active) FontWeight.SemiBold else FontWeight.Medium, // 600 / 500
                    color = if (active) FtColor.onAccent else inactiveColor,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                )
            }
        }
    }
}

// ── 概览卡 / 统计行 ──────────────────────────────────────────────

/** `.overview`（L434-475）：本周概览，`min-height: 145.1px`。 */
@Composable
private fun OverviewCard(data: ReviewScaleData, headText: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 145.1.dp)
            .clip(RoundedCornerShape(25.4.dp))
            .background(CardFill)
            .border(1.dp, FtColor.line10, RoundedCornerShape(25.4.dp))
            .padding(16.3.dp),
        verticalArrangement = Arrangement.spacedBy(12.7.dp), // `.overview { gap: 12.7px }`
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = headText,
                style = FtType.natural(12.7f, 600),
                color = FtColor.white70,
            )
            Text(
                text = data.badge,
                modifier = Modifier
                    .clip(FtShape.pill)
                    .background(FtColor.accent10) // rgba(80,236,167,.102)
                    .padding(horizontal = 9.1.dp, vertical = 5.4.dp),
                style = FtType.natural(10.9f, 600, FtType.num).copy(lineHeight = 10.9.sp), // line-height: 1
                color = FtColor.accent,
            )
        }
        Text(
            text = stringResource(data.headlineRes),
            style = FtType.natural(20f, 700).copy(
                lineHeight = 22.sp, // 1.1 × 20px
                letterSpacing = (-0.2).sp, // -.01em × 20px
            ),
            color = FtColor.txtHi,
        )
        Text(
            text = stringResource(data.descRes),
            style = FtType.natural(11.8f).copy(lineHeight = 15.9.sp),
            color = FtColor.white48,
        )
    }
}

/** `.stats` / `.stat`（L476-503）：三张等高数据卡，高 73.5。 */
@Composable
private fun StatsRow(stats: List<ReviewStat>) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(73.5.dp),
        horizontalArrangement = Arrangement.spacedBy(9.1.dp),
    ) {
        stats.forEach { stat ->
            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(18.1.dp))
                    .background(CardFill) // Card Surface v1 覆盖掉 --surface-stat
                    .border(1.dp, FtColor.line10, RoundedCornerShape(18.1.dp))
                    .padding(12.7.dp),
                verticalArrangement = Arrangement.spacedBy(4.5.dp), // `.stat { gap: 4.5px }`
            ) {
                Text(
                    text = stringResource(stat.labelRes),
                    style = FtType.natural(10.9f),
                    color = FtColor.white48,
                )
                Row(
                    verticalAlignment = Alignment.Bottom, // `align-items: flex-end`
                    horizontalArrangement = Arrangement.spacedBy(3.6.dp),
                ) {
                    Text(
                        text = stat.value,
                        style = FtType.natural(21.8f, 700, FtType.mono).copy(lineHeight = 21.8.sp),
                        color = FtColor.txtHi,
                    )
                    Text(
                        text = stringResource(stat.unitRes),
                        style = FtType.natural(10.9f).copy(lineHeight = 12.5.sp), // 1.15 × 10.9px
                        color = FtColor.accent,
                    )
                }
            }
        }
    }
}

// ── 训练节奏（周柱状 / 月日历） ──────────────────────────────────

/** `.weekly`（L505-543）+ 月历（L335-433）：按尺度在柱状图与日历之间切换。 */
@Composable
private fun ActivityCard(
    scale: ReviewScale,
    data: ReviewScaleData,
    weekBars: List<WeekBar>,
    monthCells: List<MonthCell>,
    monthLabel: String,
    monthMeta: String,
    monthHead: List<String>,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(25.4.dp))
            .background(CardFill)
            .border(1.dp, FtColor.line10, RoundedCornerShape(25.4.dp))
            .padding(16.3.dp),
        verticalArrangement = Arrangement.spacedBy(12.7.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                // 原型 `wk-title` 恒为「训练节奏」，`wk-sub` 随尺度变
                text = stringResource(R.string.review_activity_title),
                style = FtType.natural(14.5f, 700),
                color = FtColor.txtHi,
            )
            Text(
                text = stringResource(data.subRes),
                style = FtType.natural(10.9f),
                color = FtColor.white48,
            )
        }

        if (scale == ReviewScale.WEEK) {
            WeekBars(bars = weekBars)
        } else {
            MonthCalendar(cells = monthCells, label = monthLabel, meta = monthMeta, head = monthHead)
        }
    }
}

/** `.wk-bars` / `.bar-col` / `.bar`（L521-543）：七根柱，高 136.1。 */
@Composable
private fun WeekBars(bars: List<WeekBar>) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(136.1.dp),
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(9.1.dp),
    ) {
        bars.forEach { bar ->
            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight(),
                verticalArrangement = Arrangement.Bottom, // justify-content: flex-end
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(bar.height.dp)
                        .clip(RoundedCornerShape(9.1.dp))
                        .background(if (bar.on) FtColor.accent else FtColor.accent20),
                )
                Text(
                    text = bar.label,
                    modifier = Modifier.padding(top = 7.3.dp), // `.bar-col { gap: 7.3px }`
                    style = FtType.natural(10f).copy(lineHeight = 10.sp), // line-height: 1
                    color = if (bar.on) FtColor.accent else FtColor.white54,
                )
            }
        }
    }
}

/** `.month-cal`（L335-433）：训练日历，7 列网格。 */
@Composable
private fun MonthCalendar(cells: List<MonthCell>, label: String, meta: String, head: List<String>) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp), // `.month-cal { gap: 10px }`
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = label,
                style = FtType.natural(15f, 700),
                color = FtColor.txtHi,
            )
            Text(
                text = meta,
                style = FtType.natural(10.9f),
                color = FtColor.white48,
            )
        }
        Text(
            text = stringResource(FtReviewModel.MONTH_TIP_RES),
            style = FtType.natural(11f).copy(lineHeight = 17.05.sp), // 1.55 × 11px
            color = FtColor.white48,
        )

        // `.mcal-head`：7 列等宽网格
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            head.forEach { headLabel ->
                Text(
                    text = headLabel,
                    modifier = Modifier.weight(1f),
                    style = FtType.natural(10f).copy(lineHeight = 20.sp),
                    color = FtColor.white40,
                    textAlign = TextAlign.Center,
                )
            }
        }

        // `.mcal-grid`：35 格（30 天 + 5 个空位），每 7 格一行
        Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
            cells.chunked(7).forEach { week ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    week.forEach { cell ->
                        MonthCellView(cell = cell, modifier = Modifier.weight(1f))
                    }
                }
            }
        }

        // `.month-legend`：五个方块 + 文案（原型的方块是同一浅白色，见 FtReviewColors）
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            FtReviewModel.MONTH_LEGEND_RES.forEach { labelRes ->
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .requiredSize(14.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(FtReviewColors.monthLegendSwatch),
                    )
                    Text(
                        text = stringResource(labelRes),
                        style = FtType.natural(9f),
                        color = FtColor.white48,
                    )
                }
            }
        }
    }
}

/** `.mcal-cell`（L372-407）：高 34、圆角 9 的日期格。 */
@Composable
private fun MonthCellView(cell: MonthCell, modifier: Modifier = Modifier) {
    if (cell.day == 0) {
        // `.mcal-space { background: transparent; border: 0 }`
        Box(modifier = modifier.height(34.dp))
        return
    }
    Box(
        modifier = modifier
            .height(34.dp)
            .clip(RoundedCornerShape(9.dp))
            .background(if (cell.level == 0) FtReviewColors.mcalBg else FtReviewColors.mcalFill(cell.level))
            .border(
                width = 1.dp,
                color = if (cell.level == 0) FtReviewColors.mcalBorder else Color.Transparent,
                shape = RoundedCornerShape(9.dp),
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = cell.day.toString(),
            style = FtType.natural(12f, if (cell.level == 4) 700 else 500, FtType.num),
            color = if (cell.level >= 3) FtReviewColors.mcalTextOn else FtReviewColors.mcalText,
        )
        if (cell.today) {
            // `.today { box-shadow: 0 0 0 1.5px var(--txt-hi) }` —— 不占布局的外环
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .border(1.5.dp, FtColor.txtHi, RoundedCornerShape(9.dp)),
            )
        }
    }
}

// ── 肌肉地图 ────────────────────────────────────────────────────

/** `.openstats .card` + 肌肉地图（L958-1020）。 */
@Composable
private fun MuscleMapCard(
    mode: MuscleMode,
    selected: String?,
    onMode: (MuscleMode) -> Unit,
    onSelect: (String) -> Unit,
) {
    Card {
        CardTitle(title = stringResource(R.string.review_muscle_title), meta = stringResource(FtReviewModel.mmMetaRes(mode)))
        SegmentedPill(
            labels = MuscleMode.entries.map { stringResource(FtReviewModel.mmLabelRes(it)) },
            selectedIndex = MuscleMode.entries.indexOf(mode),
            onSelect = { onMode(MuscleMode.entries[it]) },
            fillWidth = true,
            buttonHeight = 36.dp,
            buttonPadH = 12.dp,
            inactiveColor = FtReviewColors.label2,
            contentDescription = stringResource(R.string.review_muscle_a11y_mode), // 原型 `aria-label`（L1287）
        )
        BodyMapView(
            mode = mode,
            selected = selected,
            onSelect = onSelect,
            modifier = Modifier.padding(top = 14.dp), // `.bodymap { margin-top: 14px }`
        )
        MuscleLegend(mode = mode, modifier = Modifier.padding(top = 12.dp))
        if (selected != null) {
            MuscleDetailRow(mode = mode, id = selected)
        }
        Text(
            text = stringResource(FtReviewModel.mmNoteRes(mode)),
            modifier = Modifier.padding(top = 10.dp),
            style = FtType.natural(12f).copy(lineHeight = 17.4.sp), // 1.45 × 12px
            color = FtReviewColors.label3,
        )
    }
}

/** `.hm-legend`（L1007-1015，图例方块为 `--surface-2` 底 + 等级色）。 */
@Composable
private fun MuscleLegend(mode: MuscleMode, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        // 靠右对齐（`justify-content: flex-end`）：用前置 spacer 顶开
        Box(modifier = Modifier.weight(1f))
        Text(
            text = stringResource(FtReviewModel.LEGEND_LOW_RES),
            style = FtType.natural(11f),
            color = FtReviewColors.label3,
        )
        (1..4).forEach { level ->
            Box(
                modifier = Modifier
                    .requiredSize(10.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(FtReviewColors.legendFill(mode, level)),
            )
        }
        Text(
            text = stringResource(FtReviewModel.LEGEND_HIGH_RES),
            style = FtType.natural(11f),
            color = FtReviewColors.label3,
        )
    }
}

/** `.mrow`（L1021-1032）：点选后的名称 + 进度条 + 取值。 */
@Composable
private fun MuscleDetailRow(mode: MuscleMode, id: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 6.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(9.dp),
    ) {
        val labelRes = FtReviewModel.muscleLabelRes(id)
        Text(
            text = if (labelRes != null) stringResource(labelRes) else id,
            modifier = Modifier.weight(1f),
            style = FtType.natural(14f),
            color = FtReviewColors.label,
            maxLines = 1,
        )
        Box(
            modifier = Modifier
                .size(width = 74.dp, height = 5.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(FtReviewColors.surface2),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(FtReviewModel.muscleDetailPercent(mode, id) / 100f)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(3.dp))
                    .background(FtReviewColors.acc),
            )
        }
        val detail = FtReviewModel.muscleDetail(mode, id)
        Text(
            text = detail.arg?.let { stringResource(detail.textRes, it) } ?: stringResource(detail.textRes),
            modifier = Modifier.widthIn(min = 52.dp),
            style = FtType.natural(12f),
            color = FtReviewColors.label2,
            textAlign = TextAlign.End,
        )
    }
}

// ── 体重与目标 ──────────────────────────────────────────────────

/** `.openstats .card` + 体重曲线 + 目标按钮（L1305-1341）。 */
@Composable
private fun WeightGoalCard(
    goal: Double,
    goalLineY: Float,
    points: List<Pair<Float, Float>>,
    currentText: String,
    deltaText: String,
    onOpenGoal: () -> Unit,
) {
    val goalA11y = stringResource(R.string.review_weight_goal_a11y_open)
    Card {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = stringResource(R.string.review_weight_title),
                style = FtType.natural(14.5f, 700).copy(lineHeight = 15.95.sp), // 1.1 × 14.5px
                color = FtReviewColors.label,
            )
            Box(
                modifier = Modifier
                    .height(36.dp)
                    .clip(FtShape.pill)
                    .background(GoalBtnFill)
                    .border(1.dp, GoalBtnBorder, FtShape.pill)
                    .semantics { contentDescription = goalA11y } // 原型 `aria-haspopup="dialog"`
                    .clickableNoRipple(onClick = onOpenGoal)
                    .padding(horizontal = 14.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    // 文案由**当前目标值**给出（原型 `saveGoal` 直接改写按钮 textContent）
                    text = stringResource(R.string.review_weight_goal_label, FtReviewModel.goalValueText(goal)),
                    style = FtType.natural(13f, 600, FtType.num).copy(letterSpacing = 0.13.sp), // .01em
                    color = FtColor.accent,
                )
            }
        }

        WeightChart(
            goalLineY = goalLineY,
            points = points,
            modifier = Modifier.padding(top = 6.dp), // `.chart { margin-top: 6px }`
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp), // `.wg-foot { margin-top: 8px }`
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = stringResource(FtReviewModel.WEIGHT_FOOT_LEFT_RES) + " ",
                    style = FtType.natural(12f),
                    color = FtReviewColors.label3,
                )
                Text(
                    text = currentText,
                    style = FtType.natural(17f, 600).copy(letterSpacing = (-0.17).sp), // -.01em
                    color = FtReviewColors.label,
                )
            }
            Text(
                text = deltaText,
                style = FtType.natural(12f),
                color = FtReviewColors.label3,
            )
        }
    }
}

/**
 * `.chart`（L1040-1043）+ 内联 SVG（L1311-1330）：342×132 viewBox 的体重曲线。
 *
 * 四层，自下而上与原型 markup 顺序一致：网格线 → 目标线（虚线）→ 面积多边形 →
 * 折线 + 八个数据点。`svg { width:100%; height:auto }` 即等比铺满卡宽。
 */
@Composable
private fun WeightChart(
    goalLineY: Float,
    points: List<Pair<Float, Float>>,
    modifier: Modifier = Modifier,
) {
    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(FtReviewModel.WEIGHT_VIEW_W / FtReviewModel.WEIGHT_VIEW_H),
    ) {
        val k = size.width / FtReviewModel.WEIGHT_VIEW_W
        fun px(v: Float) = v * k

        // 四条网格线：x 12→330，stroke rgba(255,255,255,.06)，宽 1
        FtReviewModel.WEIGHT_GRID_YS.forEach { y ->
            drawLine(
                color = FtColor.hairline,
                start = Offset(px(12f), px(y)),
                end = Offset(px(330f), px(y)),
                strokeWidth = px(1f),
            )
        }

        // 目标线：虚线 4 4、rgba(255,255,255,.32)
        drawLine(
            color = FtColor.white32,
            start = Offset(px(12f), px(goalLineY)),
            end = Offset(px(330f), px(goalLineY)),
            strokeWidth = px(1f),
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(px(4f), px(4f))),
        )

        // 面积：折线点 + 右下角 + 左下角闭合，fill rgba(80,236,167,.12)
        val area = Path().apply {
            points.forEachIndexed { i, (x, y) ->
                if (i == 0) moveTo(px(x), px(y)) else lineTo(px(x), px(y))
            }
            lineTo(px(330f), px(FtReviewModel.WEIGHT_AREA_BASE_Y))
            lineTo(px(12f), px(FtReviewModel.WEIGHT_AREA_BASE_Y))
            close()
        }
        drawPath(area, FtColor.accent12)

        // 折线：stroke #50ECA7、宽 2.5、圆头圆角
        val line = Path().apply {
            points.forEachIndexed { i, (x, y) ->
                if (i == 0) moveTo(px(x), px(y)) else lineTo(px(x), px(y))
            }
        }
        drawPath(
            line,
            FtColor.accent,
            style = Stroke(width = px(2.5f), cap = StrokeCap.Round, join = StrokeJoin.Round),
        )

        // 数据点：r 3 实心
        points.forEach { (x, y) ->
            drawCircle(FtColor.accent, radius = px(3f), center = Offset(px(x), px(y)))
        }
    }
}

// ── 努力程度 ────────────────────────────────────────────────────

/** `.openstats .card` + 努力程度（L1195-1210）。 */
@Composable
private fun EffortCard(metric: EffortMetric, onMetric: (EffortMetric) -> Unit) {
    val view = remember(metric) { FtReviewModel.effort(metric) }
    Card {
        CardTitle(title = stringResource(R.string.review_effort_title), meta = stringResource(R.string.review_effort_meta))
        SegmentedPill(
            labels = EffortMetric.entries.map { it.display },
            selectedIndex = EffortMetric.entries.indexOf(metric),
            onSelect = { onMetric(EffortMetric.entries[it]) },
            fillWidth = true,
            buttonHeight = 36.dp,
            buttonPadH = 12.dp,
            inactiveColor = FtReviewColors.label2,
            contentDescription = stringResource(R.string.review_effort_a11y_scale), // 原型 `aria-label`（L1340）
        )
        Text(
            text = stringResource(R.string.review_effort_note),
            modifier = Modifier.padding(top = 12.dp),
            style = FtType.natural(11f).copy(lineHeight = 16.5.sp), // 1.5 × 11px
            color = FtReviewColors.label3,
        )
        Row(
            modifier = Modifier.padding(top = 14.dp),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = view.average,
                style = FtType.natural(30f, 700, FtType.num).copy(letterSpacing = (-0.6).sp), // -.02em
                color = FtReviewColors.label,
            )
            Text(
                text = stringResource(FtReviewModel.EFFORT_UNIT_RES, view.metric.display),
                style = FtType.natural(12f),
                color = FtReviewColors.label3,
            )
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 14.dp)
                .height(96.dp),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            view.barPercents.forEachIndexed { index, percent ->
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                    verticalArrangement = Arrangement.Bottom,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .fillMaxHeight(percent / 100f) // `.bar { height: N% }`
                            .clip(RoundedCornerShape(6.dp))
                            .background(FtReviewColors.acc),
                    )
                    Text(
                        text = view.barLabels[index],
                        modifier = Modifier.padding(top = 6.dp), // `.effort-bar { gap: 6px }`
                        style = FtType.natural(9f).copy(lineHeight = 9.sp),
                        color = FtReviewColors.label3,
                    )
                }
            }
        }
    }
}

// ── 估算 1RM ────────────────────────────────────────────────────

/** `.openstats .card` + 估算 1RM（L1352-1375）。 */
@Composable
private fun OneRmCard(rows: List<OneRmRow>) {
    Card {
        CardTitle(title = stringResource(R.string.review_1rm_title), meta = stringResource(R.string.review_1rm_meta))
        rows.forEachIndexed { index, row ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    text = row.name,
                    modifier = Modifier.weight(1f),
                    style = FtType.natural(15f),
                    color = FtReviewColors.label,
                    maxLines = 1,
                )
                Text(
                    text = row.src,
                    style = FtType.natural(11f),
                    color = FtReviewColors.label3,
                )
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        text = row.value,
                        style = FtType.natural(17f, 700, FtType.num).copy(letterSpacing = (-0.34).sp),
                        color = FtReviewColors.label,
                    )
                    Text(
                        text = row.unit,
                        modifier = Modifier.padding(start = 2.dp),
                        style = FtType.natural(11f, 500),
                        color = FtReviewColors.acc,
                    )
                }
            }
            if (index < rows.lastIndex) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(FtColor.hairline), // `--sep-op: rgba(255,255,255,.06)`
                )
            }
        }
    }
}

// ── 目标弹窗 ────────────────────────────────────────────────────

/** `.goal-modal`（L1120-1190）：遮罩 + 居中面板，输入目标体重。 */
@Composable
private fun GoalModal(initial: Double, onDismiss: () -> Unit, onSave: (Double) -> Unit) {
    val targetWeightA11y = stringResource(R.string.review_goal_modal_a11y_input)
    var text by remember {
        mutableStateOf(if (initial % 1.0 == 0.0) initial.toLong().toString() else initial.toString())
    }

    fun commit() {
        onSave(FtReviewModel.clampGoal(text.toDoubleOrNull() ?: FtReviewModel.initialGoal()))
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(ModalBackdrop)
            .clickableNoRipple(onClick = onDismiss),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .widthIn(max = 320.dp)
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                // 面板吞掉点击，避免透传到遮罩（原型只在 `e.target` 带 data-close 时关闭）
                .clickableNoRipple(onClick = {})
                .clip(RoundedCornerShape(22.dp))
                .background(FtColor.surface) // #10171B
                .border(1.dp, FtColor.line10, RoundedCornerShape(22.dp))
                .padding(20.dp),
        ) {
            Text(
                text = stringResource(R.string.review_goal_modal_title),
                style = FtType.natural(16f, 700),
                color = FtColor.txtHi,
            )
            Text(
                text = stringResource(R.string.review_goal_modal_desc),
                modifier = Modifier.padding(top = 6.dp),
                style = FtType.natural(12f),
                color = FtColor.white54,
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(FtColor.surfaceStat) // #171D24
                    .border(1.dp, FtColor.line10, RoundedCornerShape(14.dp))
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                BasicTextField(
                    value = text,
                    onValueChange = { text = it },
                    modifier = Modifier
                        .weight(1f)
                        .semantics { contentDescription = targetWeightA11y },
                    singleLine = true,
                    textStyle = TextStyle(
                        fontFamily = FtType.num,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = FtColor.txtHi,
                    ),
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Decimal,
                        imeAction = ImeAction.Done,
                    ),
                    // 原型 review.html:1769-1773：输入框 `keydown` 命中 Enter 即 `saveGoal()`。
                    keyboardActions = KeyboardActions(onDone = { commit() }),
                )
                Text(
                    text = stringResource(R.string.review_goal_modal_unit),
                    style = FtType.natural(13f),
                    color = FtColor.white54,
                )
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 18.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.End),
            ) {
                ModalButton(label = stringResource(R.string.review_goal_modal_cancel), primary = false, onClick = onDismiss)
                ModalButton(label = stringResource(R.string.review_goal_modal_save), primary = true, onClick = { commit() })
            }
        }
    }
}

/** `.goal-actions button`（L1180-1190）：高 40 的胶囊，取消灰底、保存翡翠底。 */
@Composable
private fun ModalButton(label: String, primary: Boolean, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier = Modifier
            .height(40.dp)
            .clip(FtShape.pill)
            .background(if (primary) FtColor.accent else FtColor.glass6)
            .clickableNoRipple(onClick = onClick)
            .padding(horizontal = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = FtType.natural(13f, 600),
            color = if (primary) FtColor.onAccent else FtColor.white70,
        )
    }
}

// ── 共用卡片外壳 ────────────────────────────────────────────────

/** `.openstats .card`（L941-947）+ Card Surface v1 覆盖：底 `rgba(255,255,255,.031)`、描边 `--line-10`、圆角 25.4。 */
@Composable
private fun Card(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(25.4.dp))
            .background(CardFill)
            .border(1.dp, FtColor.line10, RoundedCornerShape(25.4.dp))
            .padding(16.3.dp),
    ) {
        content()
    }
}

/** `.card-title`（L948-957）：标题 + 右侧 meta，`margin-bottom: 14px`。 */
@Composable
private fun CardTitle(title: String, meta: String? = null) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = title,
            style = FtType.natural(14.5f, 700).copy(lineHeight = 15.95.sp), // 1.1 × 14.5px
            color = FtReviewColors.label,
        )
        if (meta != null) {
            Text(
                text = meta,
                style = FtType.natural(10.9f),
                color = FtReviewColors.label3,
            )
        }
    }
}

// ── 屏内常量与色值 ──────────────────────────────────────────────

// 卡标题与注记文案见 `values/strings_review.xml`（`review_activity_title` / `review_effort_note`）。

// 换算规则 AA = round(alpha × 255)

/** Card Surface v1 覆盖后的卡底 `rgba(255,255,255,.031)` → round(7.905) = 8 = 0x08 */
private val CardFill = Color(0x08FFFFFF)

/** `.seg` 底 `rgba(255,255,255,.047)` → round(11.985) = 12 = 0x0C */
private val SegFill = Color(0x0CFFFFFF)

/** `.goal-btn` 底 `rgba(80,236,167,.10)` → 0x1A */
private val GoalBtnFill = Color(0x1A50ECA7)

/** `.goal-btn` 描边 `rgba(80,236,167,.38)` → round(96.9) = 97 = 0x61 */
private val GoalBtnBorder = Color(0x6150ECA7)

/** `.goal-backdrop` 底 `rgba(4,6,8,.62)` → round(158.1) = 158 = 0x9E */
private val ModalBackdrop = Color(0x9E040608)
