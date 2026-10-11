package com.fittracker.app.ui.screens.body

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
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
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
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
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.data.model.WeightRecord
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.BodyRecordService
import com.fittracker.app.data.service.BodyTrend
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.currentLanguageTag
import com.fittracker.app.data.service.WeightUnit
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import kotlinx.coroutines.launch
import kotlin.math.min

/**
 * 身体数据屏（原型 `fittracker-body-data.html` 的 `screen-body-data` 帧，L293-444）。
 *
 * 画布 390×844 **直绘**（`.appshell { position: absolute; inset: 0 }`，L106），
 * 屏内不施加任何缩放。无底栏（非 Tab 一级路由，路由表 `FtRoutes` 的 `body` 为 Direct）。
 *
 * 版式来源（原型 CSS 行号）：
 * `.appshell` L106 · `.bd-top`/`.bd-back`/`.bd-title`/`.bd-date` L108-123 ·
 * `.bd-scroll`/`.bd-content` L125-127 · `.card`/`.card.focus`/`.card-head`/`.card-title`/`.card-meta` L129-140 ·
 * 体重概览 `.weight-*`/`.goal*` L143-157 · 身体成分 `.fat-*`/`.metric-*` L160-175 ·
 * 体重趋势 `.seg`/`.trend-*` L178-184 · 围度 `.measure-*`/`.ms-*` L187-194 ·
 * 主操作 `.bd-cta`/`.foot-note` L197-207 · 记录面板 `.sheet-*` L210-239 ·
 * 「Card Surface v1」覆盖 L258-261。图表几何与交互见脚本 L474-560。
 *
 * 三处**以源码为准**的取舍：
 * 1. 样式表末尾「Card Surface v1」（L258-261）把 `.card`/`.metric-tile`/`.card.focus` 的底色
 *    统一改写为 `rgba(255,255,255,.031)`、描边统一为 `--line-10`——**按末尾规则实现**，
 *    故焦点卡那层翡翠底（L135）实际不生效，焦点卡只保留圆角 26、内边距 18 与投影。
 * 2. 原型六处 `align-items: baseline` 用 `Modifier.alignByBaseline()` 复刻（仓内首次出现；
 *    此前各屏以 `CenterVertically` / `Bottom` 近似）。凡是左右同为文本的行都走真基线对齐；
 *    左为容器（如趋势卡的标题栏）时退回 `CenterVertically`，此处在对应处标注。
 * 3. 记录面板的进场 `translateY(102%)` 用 `slideInVertically { it }` 复刻（位移量=自身高度），
 *    投影 `0 -24px 60px rgba(0,0,0,.45)` 以 `Modifier.shadow` 近似（Compose 无「偏移+模糊」原语）。
 *
 * 交互（原型脚本 L499-563）：周/月/年切换重绘折线（L501-508）；「记录今日体重」开启面板（L541）；
 * 保存时校验 0 < v ≤ 500，非法给提示（L546-550），合法则改写主数值、把 delta 换成
 * 「今日已记录 · 刚刚」并刷新目标进度（L551-554）；取消/遮罩/Escape 关闭（L538-540、L557-560）。
 * 原型 `FT_APP.routes`（L564）把返回键指向 `profile`。
 */
@Composable
fun BodyScreen(
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var period by remember { mutableStateOf(TrendPeriod.WEEK) }
    var saved by remember { mutableStateOf(false) }
    var sheetOpen by remember { mutableStateOf(false) }

    // 设置项「体重单位」的消费：与设置屏同一持久化口径（[UserProfileService]）。
    val context = LocalContext.current
    val store = remember { JsonStore(context.appDataStore) }
    val scope = rememberCoroutineScope()
    var weightUnit by remember { mutableStateOf(WeightUnit.KG) }
    var records by remember { mutableStateOf<List<WeightRecord>>(emptyList()) }
    var weekStart by remember { mutableStateOf(WeekStart.MONDAY) }
    LaunchedEffect(Unit) {
        weightUnit = UserProfileService.loadProfile(store).weightUnit
        records = BodyRecordService.loadRecords(store)
        weekStart = SettingsService.loadSettings(store).weekStart
    }

    // 有记录 → 主数值 / 趋势 / 「较上周」取真实值；**无记录 → 空态占位**（不再回落到原型样例数值——
    // 2026-10-09 真机验收点名「都还没录入数据就有数据了」）。
    val hasRecords = records.isNotEmpty()
    val now = System.currentTimeMillis()
    val weight: Double? = if (hasRecords) records.last().kg else null
    val deltaLabel: FtBodyLabel? = when {
        saved -> FtBodyLabel(FtBodyModel.DELTA_SAVED_RES) // 保存即时反馈（原型 L552）
        hasRecords -> FtBodyModel.deltaText(BodyRecordService.weekDeltaKg(records, now), weightUnit)
        else -> null // 「较上周」：无记录时不显示
    }
    // 顶部日期取真实今天（原型 `.bd-date` 的「21 / 8月」是样例常量）；
    // 月份随区域格式化（zh → `8月`、en → `Aug`），故不落文案资源。
    val today = remember {
        val cal = java.util.Calendar.getInstance()
        cal.get(java.util.Calendar.DAY_OF_MONTH).toString() to
            java.text.SimpleDateFormat("LLL", java.util.Locale.getDefault())
                .format(java.util.Date())
    }
    // 「今日 · 更新于 …」：有记录 → 真实更新时间；无记录 → 不显示
    // （locale 读取包进 remember：Compose lint 要求不在组合体内以非可观察方式读 locale）
    val updatedText: String? = remember(records) {
        if (records.isNotEmpty()) {
            java.text.SimpleDateFormat("M-d HH:mm", java.util.Locale.getDefault())
                .format(java.util.Date(records.last().dateMillis))
        } else {
            null
        }
    }
    val trend: BodyTrend? = if (!hasRecords) {
        null
    } else {
        when (period) {
            TrendPeriod.WEEK -> BodyRecordService.weekTrend(records, now, weekStart, currentLanguageTag())
            TrendPeriod.MONTH -> BodyRecordService.monthTrend(records, now)
            TrendPeriod.YEAR -> BodyRecordService.yearTrend(records, now)
        }
    }
    // 无记录 → 趋势空态（不再回落原型样例序列；空态的图形区在 TrendCard 内占位）
    val trendSeries = trend?.let { FtBodyModel.series(it, weightUnit) }
    val trendCaptionLabel: FtBodyLabel = if (hasRecords) {
        trend?.let { FtBodyModel.trendCaption(it, weightUnit) }
            ?: FtBodyModel.trendCaption(period, weightUnit)
    } else {
        FtBodyLabel(FtBodyModel.TREND_EMPTY_RES)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(FtColor.ink0), // `.appshell` 底 var(--ink-0)（L106）
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            TopBar(onBack = onBack, day = today.first, month = today.second) // 原型 FT_APP.routes（L564）：父屏 profile；日期取真实今天

            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()), // `.bd-scroll`（L125-126）
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        // `.bd-content { padding: 6px 16px 30px }`（L127）
                        .padding(start = 16.dp, end = 16.dp, top = 6.dp, bottom = 30.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp), // `.bd-content { gap: 14px }`
                ) {
                    WeightSummaryCard(weight = weight, saved = saved, unit = weightUnit, delta = deltaLabel, updated = updatedText)
                    CompositionCard(unit = weightUnit)
                    TrendCard(period = period, onPeriod = { period = it }, series = trendSeries, caption = trendCaptionLabel.text())
                    MeasurementsCard()
                    RecordButton(onClick = { sheetOpen = true }) // `#btn-record-weight`（L421）
                    Text(
                        text = stringResource(FtBodyModel.footNote(weightUnit)), // 承诺随当前单位改写（L422）
                        modifier = Modifier.padding(horizontal = 4.dp), // `.foot-note { padding: 0 4px }`（L207）
                        style = FtType.natural(11f).copy(lineHeight = 18.15.sp), // 1.65 × 11px
                        color = FtColor.white40,
                    )
                }
            }
        }

        // ── 记录体重底部面板（`.sheet-layer`，L210-239）────────────────
        AnimatedVisibility(
            visible = sheetOpen,
            enter = fadeIn(tween(FtMotion.DURATION_OVERLAY)),
            exit = fadeOut(tween(FtMotion.DURATION_OVERLAY)),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Scrim) // `.sheet-backdrop { background: rgba(0,0,0,.5) }`（L211）
                    .clickableNoRipple { sheetOpen = false }, // data-close-sheet（L429）
            )
        }
        AnimatedVisibility(
            visible = sheetOpen,
            modifier = Modifier.align(Alignment.BottomCenter),
            // `.sheet { transform: translateY(102%) }` + `cubic-bezier(.32,.72,.3,1) .3s`（L214-215）
            enter = slideInVertically(tween(FtMotion.DURATION_PANEL, easing = FtMotion.EASE_PANEL)) { it },
            exit = slideOutVertically(tween(FtMotion.DURATION_PANEL, easing = FtMotion.EASE_PANEL)) { it },
        ) {
            WeightSheet(
                initial = weight ?: FtBodyModel.INITIAL_WEIGHT, // 输入框预填（可编辑；非数据展示）
                unit = weightUnit,
                onDismiss = { sheetOpen = false },
                onSave = { value ->
                    sheetOpen = false
                    // 落盘实际记录（kg 基准）后即时重读 → 主数值 / 趋势 / 「较上周」刷新。
                    scope.launch {
                        BodyRecordService.addRecord(
                            store,
                            WeightRecord(dateMillis = System.currentTimeMillis(), kg = value),
                        )
                        records = BodyRecordService.loadRecords(store)
                        saved = true
                    }
                },
            )
        }
    }
}

/** 解析 [FtBodyLabel] 为当前区域文案（模型层只持资源 ID，插值在 UI 层完成）。 */
@Composable
private fun FtBodyLabel.text(): String = stringResource(res, *args.toTypedArray())

// ── 顶栏 ────────────────────────────────────────────────────────

/** `.bd-top` / `.bd-back` / `.bd-title` / `.bd-date`（L108-123）。 */
@Composable
private fun TopBar(onBack: () -> Unit, day: String, month: String) {
    // `stringResource` 不能在 `semantics { }`（非 @Composable lambda）内调用——先取值。
    val backDesc = stringResource(FtBodyModel.BACK_A11Y_RES)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 16.dp, top = 52.dp, bottom = 12.dp), // `.bd-top`（L110）
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp), // `.bd-top { gap: 10px }`
    ) {
        Box(
            modifier = Modifier
                .size(44.dp) // `.bd-back { width/height: 44px }`（L113）
                .clip(FtShape.pill)
                .background(BackFill) // rgba(255,255,255,.047)
                .border(1.dp, BackBorder, FtShape.pill) // rgba(255,255,255,.08)
                // aria-label 逐字取自原型 `.bd-back`（L301）
                .semantics { contentDescription = backDesc }
                .clickableNoRipple(onClick = onBack),
            contentAlignment = Alignment.Center,
        ) {
            BackChevronIcon(modifier = Modifier.size(20.dp), color = FtColor.white70) // `.bd-back svg` 20×20（L118）
        }
        Text(
            text = stringResource(FtBodyModel.TITLE_RES),
            modifier = Modifier.weight(1f), // `.bd-title { flex: 1 1 auto }`（L121）
            style = FtType.natural(18f, 700),
            color = FtColor.txtHi,
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
        Column(
            modifier = Modifier.width(44.dp), // `.bd-date { width: 44px }`（L122）
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = day, // `.bd-date b` 13/600 white70（L123）——真实现日（原为样例常量 21）
                style = FtType.natural(13f, 600, FtType.num),
                color = FtColor.white70,
            )
            Text(
                text = month, // `.bd-date` 11px white54（L122）——真实现月（原为样例常量 8月）
                style = FtType.natural(11f, 400, FtType.num),
                color = FtColor.white54,
            )
        }
    }
}

// ── 体重概览（焦点卡） ──────────────────────────────────────────

/**
 * `.card.focus` + 体重概览（L133-157）。
 *
 * 焦点卡的翡翠底与翡翠描边被 L261 覆盖为普通卡底色，见类注释取舍 1；
 * 保留的差异只有圆角 26、内边距 18 与 `0 20px 40px rgba(0,0,0,.22)` 投影。
 */
@Composable
private fun WeightSummaryCard(weight: Double?, saved: Boolean, unit: WeightUnit, delta: FtBodyLabel?, updated: String?) {
    val shape = RoundedCornerShape(26.dp) // `.card.focus { border-radius: 26px }`（L134）
    // `.goal-fill { transition: width .35s var(--ease) }`（L157）→ FtMotion.DURATION_PROGRESS
    val goalFraction by animateFloatAsState(
        targetValue = (weight?.let { FtBodyModel.goalPercent(it) } ?: 0) / 100f,
        animationSpec = tween(FtMotion.DURATION_PROGRESS, easing = FtMotion.EASE_PANEL),
        label = "goal-fill",
    )
    Column(
        modifier = Modifier
            .fillMaxWidth()
            // 原型卡阴影 `0 20px 40px rgba(0,0,0,.22)` 在深色底剖面上不可辨（参照渲染无暗带）；
            // elevation 阴影会产生可测暗带（home 判例）——按原型剖面移除
            .clip(shape)
            .background(CardFill) // Card Surface v1（L259-261）
            .border(1.dp, FtColor.line10, shape)
            .padding(18.dp), // `.card.focus { padding: 18px }`（L136）
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween, // `.weight-head`（L143）
        ) {
            Text(
                text = stringResource(FtBodyModel.WEIGHT_LABEL_RES),
                modifier = Modifier.alignByBaseline(), // align-items: baseline
                style = FtType.natural(12f),
                color = FtColor.white62,
            )
            if (updated != null) { // 有记录才显示更新时间（原样例如「今日 · 更新于 07:40」已去）
                Text(
                    text = stringResource(FtBodyModel.UPDATED_RES, updated),
                    modifier = Modifier.alignByBaseline(),
                    style = FtType.natural(11f, 400, FtType.num),
                    color = FtColor.white54,
                )
            }
        }

        Row(
            modifier = Modifier.padding(top = 10.dp), // `.weight-value { margin-top: 10px }`（L146）
            horizontalArrangement = Arrangement.spacedBy(7.dp), // gap: 7px
        ) {
            Text(
                text = weight?.let { FtBodyModel.formatDisplay(it, unit) } ?: "--", // 无记录 → 占位（原回落样例 72.5）
                modifier = Modifier.alignByBaseline(),
                style = FtType.natural(56f, 700, FtType.num).copy(
                    lineHeight = 56.sp, // line-height: 1
                    letterSpacing = (-1.12).sp, // -.02em × 56px
                ),
                color = FtColor.txtHi,
            )
            if (weight != null) { // 无记录时单位也隐藏（与「--」占位配套）
                Text(
                    text = FtBodyModel.unitLabel(unit),
                    modifier = Modifier.alignByBaseline(),
                    style = FtType.natural(16f),
                    color = FtColor.white62,
                )
            }
        }

        // `.weight-delta`：accent10 胶囊，12/600 翡翠字（L149-150）——无记录时不显示
        if (delta != null) {
            Row(
                modifier = Modifier
                    .padding(top = 12.dp)
                    .clip(FtShape.pill)
                    .background(FtColor.accent10)
                    .padding(horizontal = 11.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                if (saved) {
                    CheckIcon(modifier = Modifier.size(13.dp), color = FtColor.accent) // `#i-check`（L276-278）
                } else {
                    DownArrowIcon(modifier = Modifier.size(13.dp), color = FtColor.accent) // `#i-down`（L270-272）
                }
                Text(
                    text = delta.text(), // 保存态 `今日已记录 · 刚刚`（L552）/ 真实差值（样例态已去）
                    style = FtType.natural(12f, 600),
                    color = FtColor.accent,
                )
            }
        }

        // `.goal { margin-top: 16px; padding-top: 15px; border-top: 1px solid var(--hairline) }`（L152）
        Box(
            modifier = Modifier
                .padding(top = 16.dp)
                .fillMaxWidth()
                .height(1.dp)
                .background(FtColor.hairline),
        )
        Column(modifier = Modifier.fillMaxWidth().padding(top = 15.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween, // `.goal-head`（L153）
            ) {
                Text(
                    text = FtBodyModel.goalLabel(unit).text(),
                    modifier = Modifier.alignByBaseline(),
                    style = FtType.natural(12f),
                    color = FtColor.white62,
                )
                Text(
                    text = weight?.let { FtBodyModel.goalGap(it, unit).text() } ?: "--", // `#goal-gap`（L325）；无记录 → 占位
                    modifier = Modifier.alignByBaseline(),
                    style = FtType.natural(12f, 600, FtType.num), // `.goal-value`（L155）
                    color = FtColor.txtHi,
                )
            }
            // `.goal-track`：高 7、glass8 底；`.goal-fill` 翡翠按百分比填充（L156-157）
            Box(
                modifier = Modifier
                    .padding(top = 10.dp)
                    .fillMaxWidth()
                    .height(7.dp)
                    .clip(FtShape.pill)
                    .background(FtColor.glass8),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(goalFraction)
                        .fillMaxHeight()
                        .background(FtColor.accent),
                )
            }
        }
    }
}

// ── 身体成分 ────────────────────────────────────────────────────

/** `.card` + 身体成分（L160-175）。 */
@Composable
private fun CompositionCard(unit: WeightUnit) {
    Card {
        CardHead(
            title = stringResource(FtBodyModel.COMPOSITION_TITLE_RES),
            meta = stringResource(FtBodyModel.COMPOSITION_META_RES),
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween, // `.fat-head`（L160）
        ) {
            // 体脂率：App 暂无体成分录入渠道 → 占位显示（不再展示原型样例 16.2%——2026-10-09 真机验收点名）
            Text(
                text = "--",
                modifier = Modifier.alignByBaseline(),
                style = FtType.natural(24f, 700, FtType.num).copy(lineHeight = 24.sp), // `.fat-value`（L161）
                color = FtColor.accent,
            )
            Text(
                text = stringResource(FtBodyModel.FAT_LABEL_RES),
                modifier = Modifier.alignByBaseline(),
                style = FtType.natural(11f), // L339 内联 font-size: 11px
                color = FtColor.white62,
            )
        }

        FatRange()

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            FtBodyModel.FAT_SCALE_RES.forEach { labelRes ->
                Text( // `.fat-scale`：10px white40（L167）
                    text = stringResource(labelRes),
                    style = FtType.natural(10f, 400, FtType.num),
                    color = FtColor.white40,
                )
            }
        }

        // `.metric-grid { grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 16px }`（L169）
        Column(
            modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // 各指标 App 暂无录入渠道 → 值占位置灰（保留 tile 布局；不再展示原型样例值——2026-10-09 验收点名）
            FtBodyModel.metrics(unit).chunked(2).forEach { row ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    row.forEach { metric ->
                        MetricTile(
                            metric = metric.copy(value = "--", unit = null, noteRes = null, muted = true),
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }
    }
}

/**
 * `.fat-range` / `.fat-track` / `.fat-zone` / `.fat-marker`（L163-166）。
 *
 * 三层绝对定位：轨道（top 11、高 8）、健康区间（top 11、left 25%、宽 50%）、
 * 标记点（top 6、18×18 圆、translateX(-50%) 定位在 left 56%）。
 */
@Composable
private fun FatRange() {
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 4.dp) // `.fat-range { margin: 8px 0 4px }`（L163）
            .height(30.dp), // `.fat-range { height: 30px }`
    ) {
        val w = maxWidth
        Box(
            modifier = Modifier // `.fat-track`（L164）
                .offset(y = 11.dp)
                .fillMaxWidth()
                .height(8.dp)
                .clip(FtShape.pill)
                .background(FtColor.glass8),
        )
        Box(
            modifier = Modifier // `.fat-zone`（L165 + 内联 left/width，L343）
                .offset(x = w * FtBodyModel.FAT_ZONE_LEFT, y = 11.dp)
                .width(w * FtBodyModel.FAT_ZONE_WIDTH)
                .height(8.dp)
                .clip(FtShape.pill)
                .background(FtColor.accent20),
        )
        // `.fat-marker`（原型的 16.2% 指针）不再显示——无体成分数据可标（保留 FatMarker 定义备用）
    }
}

/** `.fat-marker` 的同心三层：外发光环 → `--ink-0` 边 → 翡翠心。 */
@Composable
private fun FatMarker(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(18.dp)) { // `width/height: 18px`
        val r = size.minDimension / 2f // 半径 9px
        val u = size.minDimension / 18f // 1px（`border: 3px` / `box-shadow: 0 0 0 1px`）
        drawCircle(
            color = MarkerRing, // rgba(80,236,167,.5)
            radius = r + 0.5f * u,
            center = center,
            style = Stroke(width = 1f * u),
        )
        drawCircle(color = FtColor.ink0, radius = r, center = center) // 3px 边框（border-box 内缩）
        drawCircle(color = FtColor.accent, radius = r - 3f * u, center = center)
    }
}

/** `.metric-tile`（L170）——Card Surface v1 覆盖后底 `rgba(255,255,255,.031)`、描边 `--line-10`（L260）。 */
@Composable
private fun MetricTile(metric: BodyMetric, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier = modifier
            .clip(shape)
            .background(CardFill)
            .border(1.dp, FtColor.line10, shape)
            .padding(horizontal = 14.dp, vertical = 13.dp), // `.metric-tile { padding: 13px 14px }`
    ) {
        Text(
            text = stringResource(metric.labelRes), // `.mt-label`：11.5px white62（L171）
            style = FtType.natural(11.5f),
            color = FtColor.white62,
        )
        Text(
            text = buildAnnotatedString { // `.mt-value`：21/700 行高 1（L172）
                append(metric.value)
                if (metric.unit != null) {
                    append(" ")
                    withStyle(
                        SpanStyle( // `.mt-value .unit`：12/600 white62（L173）
                            fontFamily = FtType.num,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = FtColor.white62,
                        ),
                    ) { append(metric.unit) }
                }
            },
            modifier = Modifier.padding(top = 7.dp), // `.mt-value { margin-top: 7px }`
            style = FtType.natural(21f, 700, FtType.num).copy(lineHeight = 21.sp),
            color = FtColor.txtHi,
        )
        metric.noteRes?.let { noteRes ->
            Text(
                text = stringResource(noteRes), // `.mt-note`：10.5px（L174-175）
                modifier = Modifier.padding(top = 6.dp), // `.mt-note { margin-top: 6px }`
                style = FtType.natural(10.5f),
                color = if (metric.muted) FtColor.white40 else FtColor.accent,
            )
        }
    }
}

// ── 体重趋势 ────────────────────────────────────────────────────

/**
 * `.card` + 体重趋势（L178-184）。
 *
 * 标题栏左侧是一个「标题 + 副题」的块容器，不是纯文本——`align-items: baseline`
 * 对它退化为「块首行基线」，此处以 `CenterVertically` 近似（取舍 2）。
 */
@Composable
private fun TrendCard(period: TrendPeriod, onPeriod: (TrendPeriod) -> Unit, series: TrendSeries?, caption: String) {
    Card {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 14.dp), // `.card-head { margin-bottom: 14px }`（L138）
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column {
                Text(
                    text = stringResource(FtBodyModel.TREND_TITLE_RES), // `.card-title`：16/700 行高 1.2（L139）
                    style = FtType.natural(16f, 700).copy(lineHeight = 19.2.sp),
                    color = FtColor.txtHi,
                )
                Text(
                    text = caption, // `.trend-cap`：11px white54（L182）——样例态取原型 caption，有记录取真实区间文案
                    modifier = Modifier.padding(top = 3.dp), // `.trend-cap { margin-top: 3px }`
                    style = FtType.natural(11f),
                    color = FtColor.white54,
                )
            }
            PeriodSeg(period = period, onPeriod = onPeriod)
        }
        if (series != null) {
            TrendChart(series = series, modifier = Modifier.padding(top = 4.dp)) // `.trend-chart { margin-top: 4px }`（L183）
        } else {
            // 无记录空态：保留图表区高度、不绘制任何假曲线（样例序列已去）
            Box(modifier = Modifier.fillMaxWidth().height(150.dp)) // 与 TrendChart Canvas 高一致
        }
    }
}

/** `.seg`（L178-181）：圆角 12 的分段控件，选中项翡翠底。 */
@Composable
private fun PeriodSeg(period: TrendPeriod, onPeriod: (TrendPeriod) -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    // `stringResource` 不能在 `semantics { }`（非 @Composable lambda）内调用——先取值。
    val rangeDesc = stringResource(FtBodyModel.A11Y_TREND_RANGE_RES)
    Row(
        modifier = Modifier
            // 原型 `.seg` 的 aria-label（L380）
            .semantics { contentDescription = rangeDesc }
            .clip(shape)
            .background(SegFill) // rgba(255,255,255,.06)
            .border(1.dp, FtColor.line10, shape)
            .padding(3.dp), // `.seg { padding: 3px }`
        horizontalArrangement = Arrangement.spacedBy(2.dp), // `.seg { gap: 2px }`
    ) {
        TrendPeriod.entries.forEach { item ->
            val active = item == period
            Box(
                modifier = Modifier
                    .height(30.dp) // `.seg button { height: 30px }`（L179）
                    .clip(RoundedCornerShape(9.dp)) // border-radius: 9px
                    .background(if (active) FtColor.accent else Color.Transparent)
                    .clickableNoRipple { onPeriod(item) }
                    .padding(horizontal = 14.dp), // `.seg button { padding: 0 14px }`
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = stringResource(item.labelRes),
                    style = FtType.natural(12.5f, 600), // 12.5px / 600（L179）
                    color = if (active) FtColor.onAccent else FtColor.white62,
                    maxLines = 1,
                )
            }
        }
    }
}

/**
 * `.trend-chart` + 内联 SVG（L186-388）：`viewBox="0 0 326 140"`、
 * `preserveAspectRatio="xMidYMid meet"`、容器 `width:100%; height:150px`。
 *
 * 故绘制区按 `min(w/326, h/140)` 等比缩放、并在容器内**垂直居中**（参考态下即上下各留 5px）。
 * 四层自下而上与原型 markup 顺序一致：网格线 → 面积 → 折线 → 数据点 + 轴标签。
 */
@Composable
private fun TrendChart(series: TrendSeries, modifier: Modifier = Modifier) {
    val points = remember(series) { FtBodyModel.chartPoints(series) }
    val measurer = rememberTextMeasurer()
    val labelStyle = remember {
        TextStyle(fontFamily = FtType.cn, fontSize = 9.sp, color = ChartLabel) // font-size: 9（L494）
    }
    Canvas(modifier = modifier.fillMaxWidth().height(150.dp)) {
        val k = min(size.width / FtBodyModel.CHART_W, size.height / FtBodyModel.CHART_H)
        val ox = (size.width - FtBodyModel.CHART_W * k) / 2f
        val oy = (size.height - FtBodyModel.CHART_H * k) / 2f
        fun cx(v: Float) = ox + v * k
        fun cy(v: Float) = oy + v * k

        // 两条网格线（原型 L486-487）
        drawLine(
            color = FtColor.hairline, // rgba(255,255,255,.06)
            start = Offset(cx(20f), cy(FtBodyModel.GRID_FAINT_Y)),
            end = Offset(cx(305f), cy(FtBodyModel.GRID_FAINT_Y)),
            strokeWidth = 1f * k,
        )
        drawLine(
            color = FtColor.line10, // rgba(255,255,255,.10)
            start = Offset(cx(20f), cy(FtBodyModel.GRID_STRONG_Y)),
            end = Offset(cx(305f), cy(FtBodyModel.GRID_STRONG_Y)),
            strokeWidth = 1f * k,
        )

        // 面积多边形：折线点 + 右下角 + 左下角闭合（原型 `area`，L481）
        val area = Path().apply {
            points.forEachIndexed { i, (x, y) ->
                if (i == 0) moveTo(cx(x), cy(y)) else lineTo(cx(x), cy(y))
            }
            lineTo(cx(FtBodyModel.CHART_X.last()), cy(FtBodyModel.CHART_BASE))
            lineTo(cx(FtBodyModel.CHART_X.first()), cy(FtBodyModel.CHART_BASE))
            close()
        }
        // `#trendFill`：objectBoundingBox 的纵向渐变，accent .18 → 0（L485）
        drawPath(
            path = area,
            brush = Brush.verticalGradient(
                colors = listOf(AreaTop, AreaBottom),
                startY = cy(points.minOf { it.second }),
                endY = cy(FtBodyModel.CHART_BASE),
            ),
        )

        // 折线：翡翠、宽 2、圆头圆角（L490）
        val line = Path().apply {
            points.forEachIndexed { i, (x, y) ->
                if (i == 0) moveTo(cx(x), cy(y)) else lineTo(cx(x), cy(y))
            }
        }
        drawPath(
            path = line,
            color = FtColor.accent,
            style = Stroke(width = 2f * k, cap = StrokeCap.Round, join = StrokeJoin.Round),
        )

        // 数据点（原型 L482-486）：末点 r 4.5 实心翡翠，其余 r 3 黑心翡翠描边
        points.forEachIndexed { i, (x, y) ->
            val c = Offset(cx(x), cy(y))
            if (i == points.lastIndex) {
                drawCircle(color = FtColor.accent, radius = 4.5f * k, center = c)
            } else {
                drawCircle(color = FtColor.ink0, radius = 3f * k, center = c) // fill #0B0F13
                drawCircle(
                    color = FtColor.accent,
                    radius = 3f * k,
                    center = c,
                    style = Stroke(width = 1.5f * k),
                )
            }
        }

        // 轴标签（原型 L492-495）：`text-anchor: middle`、y 为基线
        series.labels.forEachIndexed { i, label ->
            if (label.isEmpty()) return@forEachIndexed
            val layout = measurer.measure(label, labelStyle)
            drawText(
                textLayoutResult = layout,
                topLeft = Offset(
                    cx(FtBodyModel.CHART_X[i]) - layout.size.width / 2f,
                    cy(FtBodyModel.CHART_LABEL_Y) - layout.firstBaseline,
                ),
            )
        }
    }
}

// ── 围度记录 ────────────────────────────────────────────────────

/** `.card` + 围度记录（L187-194）。 */
@Composable
private fun MeasurementsCard() {
    Card {
        CardHead(
            title = stringResource(FtBodyModel.MEASURE_TITLE_RES),
            meta = stringResource(FtBodyModel.MEASURE_META_RES),
        )
        Column(modifier = Modifier.fillMaxWidth()) {
            FtBodyModel.MEASURES.forEachIndexed { index, measure ->
                // `.measure-row + .measure-row { border-top: 1px solid var(--hairline) }`（L189）
                if (index > 0) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(1.dp)
                            .background(FtColor.hairline),
                    )
                }
                MeasureRow(measure = measure)
            }
        }
    }
}

/** `.measure-row` / `.ms-label` / `.ms-value`（L188-194）。 */
@Composable
private fun MeasureRow(measure: BodyMeasure) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 13.dp), // `.measure-row { padding: 13px 0 }`（L188）
        verticalAlignment = Alignment.CenterVertically, // align-items: center
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = stringResource(measure.labelRes), // `.ms-label`：13.5px white70（L190）
            style = FtType.natural(13.5f),
            color = FtColor.white70,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) { // `.ms-value { gap: 9px }`（L191）
            Text(
                text = measure.value, // `.ms-num`：14/600 txtHi（L192）
                modifier = Modifier.alignByBaseline(),
                style = FtType.natural(14f, 600, FtType.num),
                color = FtColor.txtHi,
            )
            Text(
                text = measure.delta, // `.ms-delta`：11.5px 翡翠；`.down` 变 white54（L193-194）
                modifier = Modifier.alignByBaseline(),
                style = FtType.natural(11.5f, 400, FtType.num),
                color = if (measure.down) FtColor.white54 else FtColor.accent,
            )
        }
    }
}

// ── 主操作 ──────────────────────────────────────────────────────

/**
 * `.bd-cta`（L197-205）：100% 宽、54 高、圆角 17、翡翠底，
 * `:active { transform: scale(.98) }`（L205）。
 */
@Composable
private fun RecordButton(onClick: () -> Unit) {
    val shape = RoundedCornerShape(17.dp)
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale = if (pressed) 0.98f else 1f

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(shape)
            .background(FtColor.accent)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = stringResource(FtBodyModel.CTA_LABEL_RES),
            style = FtType.natural(15f, 700).copy(letterSpacing = 0.15.sp), // `.01em × 15px`（L201）
            color = FtColor.onAccent,
        )
    }
}

// ── 记录体重底部面板 ────────────────────────────────────────────

/**
 * `.sheet-layer > .sheet`（L212-239）。
 *
 * 面板贴底、全宽，仅上两角圆角 28；`padding: 12px 20px 30px`。
 * 保存逻辑逐字对齐原型 `save-weight` 处理器（L544-554）。
 */
@Composable
private fun WeightSheet(
    initial: Double,
    unit: WeightUnit,
    onDismiss: () -> Unit,
    onSave: (Double) -> Unit,
) {
    var text by remember { mutableStateOf(FtBodyModel.formatDisplay(initial, unit)) }
    var hintRes by remember { mutableStateOf<Int?>(null) }
    // `stringResource` 不能在 `semantics { }`（非 @Composable lambda）内调用——先取值。
    val inputDesc = stringResource(FtBodyModel.SHEET_INPUT_A11Y_RES)

    fun commit() {
        val value = FtBodyModel.parseWeight(text)
        if (!FtBodyModel.isWeightValid(value)) {
            hintRes = FtBodyModel.INVALID_HINT_RES // L548
            return
        }
        onSave(FtBodyModel.toKilograms(value!!, unit))
    }

    val shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp) // `border-radius: 28px 28px 0 0`（L214）
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(24.dp, shape) // 原型 `0 -24px 60px rgba(0,0,0,.45)` 的近似
            .clip(shape)
            .background(FtColor.ink1) // `var(--ink-1)`
            .drawBehind {
                // `border-top: 1px solid var(--line-10)`（L213）：只画顶边
                drawLine(
                    color = FtColor.line10,
                    start = Offset.Zero,
                    end = Offset(size.width, 0f),
                    strokeWidth = 1.dp.toPx(),
                )
            }
            .padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 30.dp), // L214
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .padding(bottom = 18.dp) // `.sheet-grip { margin: 0 auto 18px }`（L221）
                .width(40.dp)
                .height(4.dp)
                .clip(FtShape.pill)
                .background(FtColor.white32),
        )
        Text(
            text = stringResource(FtBodyModel.SHEET_TITLE_RES), // `.sheet-title`：17/700 居中（L222）
            modifier = Modifier.fillMaxWidth(),
            style = FtType.natural(17f, 700),
            color = FtColor.txtHi,
            textAlign = TextAlign.Center,
        )
        Text(
            text = stringResource(FtBodyModel.SHEET_SUB_RES), // `.sheet-sub`：12px white54 居中（L223）
            modifier = Modifier.fillMaxWidth().padding(top = 5.dp),
            style = FtType.natural(12f),
            color = FtColor.white54,
            textAlign = TextAlign.Center,
        )

        // `.sheet-input-wrap { margin-top: 20px; gap: 8px }`（L224）
        Row(
            modifier = Modifier.fillMaxWidth().padding(top = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .width(140.dp) // `.sheet-input { width: 140px }`（L226）
                    .clip(RoundedCornerShape(18.dp))
                    .background(FtColor.glass6)
                    .border(1.dp, FtColor.line14, RoundedCornerShape(18.dp))
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                BasicTextField(
                    value = text,
                    onValueChange = { text = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .semantics { contentDescription = inputDesc }, // aria-label（L435）
                    singleLine = true,
                    // `text-align: center` 由 textStyle 承载（BasicTextField 无 textAlign 形参）
                    textStyle = TextStyle( // `.sheet-input`：40/700 txtHi（L226）
                        fontFamily = FtType.num,
                        fontSize = 40.sp,
                        fontWeight = FontWeight.Bold,
                        color = FtColor.txtHi,
                        textAlign = TextAlign.Center,
                    ),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                )
            }
            Text(
                text = FtBodyModel.unitLabel(unit), // `.sheet-unit`：16px white62（L232）
                style = FtType.natural(16f),
                color = FtColor.white62,
            )
        }

        Text(
            text = hintRes?.let { stringResource(it) } ?: "", // `.sheet-hint`：11.5px 翡翠、min-height 16（L233）
            modifier = Modifier.fillMaxWidth().padding(top = 14.dp).heightIn(min = 16.dp),
            style = FtType.natural(11.5f),
            color = FtColor.accent,
            textAlign = TextAlign.Center,
        )

        // `.sheet-actions { margin-top: 20px; gap: 10px }`（L234）
        Row(
            modifier = Modifier.fillMaxWidth().padding(top = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            SheetButton(
                label = stringResource(FtBodyModel.SHEET_CANCEL_RES),
                primary = false,
                onClick = onDismiss,
                modifier = Modifier.weight(1f),
            )
            SheetButton(
                label = stringResource(FtBodyModel.SHEET_SAVE_RES),
                primary = true,
                onClick = { commit() },
                modifier = Modifier.weight(1f),
            )
        }
    }
}

/** `.sheet-cancel` / `.sheet-save`（L235-238）：各 flex:1、高 50、圆角 16、14.5/600。 */
@Composable
private fun SheetButton(
    label: String,
    primary: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(16.dp)
    Box(
        modifier = modifier
            .height(50.dp) // `.sheet-save, .sheet-cancel { height: 50px }`（L235）
            .clip(shape)
            .background(if (primary) FtColor.accent else FtColor.glass6)
            .then(
                if (primary) Modifier else Modifier.border(1.dp, FtColor.line14, shape),
            )
            .clickableNoRipple(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = FtType.natural(14.5f, 600), // 14.5px / 600（L235）
            color = if (primary) FtColor.onAccent else FtColor.white70,
        )
    }
}

// ── 共用外壳 ────────────────────────────────────────────────────

/** `.card`（L129-132）：圆角 22、内边距 16；底/描边取「Card Surface v1」（L259-260）。 */
@Composable
private fun Card(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(FtShape.panel) // radius 22px
            .background(CardFill) // rgba(255,255,255,.031)
            .border(1.dp, FtColor.line10, FtShape.panel)
            .padding(16.dp),
        content = content,
    )
}

/** `.card-head` / `.card-title` / `.card-meta`（L138-140）：底对齐、两侧分布、下留 14。 */
@Composable
private fun CardHead(title: String, meta: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 14.dp), // `.card-head { margin-bottom: 14px }`
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = title,
            modifier = Modifier.alignByBaseline(),
            style = FtType.natural(16f, 700).copy(lineHeight = 19.2.sp), // `.card-title`：16/700 行高 1.2（L139）
            color = FtColor.txtHi,
        )
        Text(
            text = meta,
            modifier = Modifier.alignByBaseline(),
            style = FtType.natural(11f), // `.card-meta`：11px white62（L140）
            color = FtColor.white62,
        )
    }
}

// ── 图标 ────────────────────────────────────────────────────────
//
// 路径逐字取自本 HTML 的 `<symbol>`（L266-278），viewBox 均为 24×24。
// 屏内自绘、不引 `ui/components/FtIcons.kt`——纪律要求图标只取自本 HTML 的 symbol。

private const val ICON_VIEW = 24f

/** `#i-back`（L267-269）：`m15 18-6-6 6-6`，描边 2、圆头圆角。 */
@Composable
private fun BackChevronIcon(modifier: Modifier = Modifier, color: Color = FtColor.white70) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val path = Path().apply {
            moveTo(15f * k, 18f * k)
            lineTo(9f * k, 12f * k)
            lineTo(15f * k, 6f * k)
        }
        drawPath(
            path = path,
            color = color,
            style = Stroke(width = 2f * k, cap = StrokeCap.Round, join = StrokeJoin.Round),
        )
    }
}

/** `#i-down`（L270-272）：`M12 5v14M6 13l6 6 6-6`，描边 2。 */
@Composable
private fun DownArrowIcon(modifier: Modifier = Modifier, color: Color = FtColor.accent) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val path = Path().apply {
            moveTo(12f * k, 5f * k)
            lineTo(12f * k, 19f * k)
            moveTo(6f * k, 13f * k)
            lineTo(12f * k, 19f * k)
            lineTo(18f * k, 13f * k)
        }
        drawPath(
            path = path,
            color = color,
            style = Stroke(width = 2f * k, cap = StrokeCap.Round, join = StrokeJoin.Round),
        )
    }
}

/** `#i-check`（L276-278）：`m5 12.5 4.5 4.5L19 7.5`，描边 2.2。 */
@Composable
private fun CheckIcon(modifier: Modifier = Modifier, color: Color = FtColor.accent) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val path = Path().apply {
            moveTo(5f * k, 12.5f * k)
            lineTo(9.5f * k, 17f * k)
            lineTo(19f * k, 7.5f * k)
        }
        drawPath(
            path = path,
            color = color,
            style = Stroke(width = 2.2f * k, cap = StrokeCap.Round, join = StrokeJoin.Round),
        )
    }
}

// ── 屏内常量与色值 ──────────────────────────────────────────────
// 换算规则 AA = round(alpha × 255)

/** Card Surface v1 覆盖后的卡底 `rgba(255,255,255,.031)` → round(7.905) = 8 = 0x08 */
private val CardFill = Color(0x08FFFFFF)

/** `.seg` 底 `rgba(255,255,255,.06)` → round(15.3) = 15 = 0x0F */
private val SegFill = Color(0x0FFFFFFF)

/** `.bd-back` 底 `rgba(255,255,255,.047)` → round(11.985) = 12 = 0x0C */
private val BackFill = Color(0x0CFFFFFF)

/** `.bd-back` 描边 `rgba(255,255,255,.08)` → round(20.4) = 20 = 0x14 */
private val BackBorder = Color(0x14FFFFFF)

/** `.fat-marker` 外发光 `rgba(80,236,167,.5)` → round(127.5) = 128 = 0x80 */
private val MarkerRing = Color(0x8050ECA7)

/** `.sheet-backdrop` 底 `rgba(0,0,0,.5)` → round(127.5) = 128 = 0x80 */
private val Scrim = Color(0x80000000)

/** 趋势面积渐变顶色：`#50ECA7` opacity `.18`（L485） */
private val AreaTop = FtColor.accent.copy(alpha = 0.18f)

/** 趋势面积渐变底色：`#50ECA7` opacity `0`（L485） */
private val AreaBottom = FtColor.accent.copy(alpha = 0f)

/** 趋势轴标签 `rgba(255,255,255,.5)` → round(127.5) = 128 = 0x80（L494） */
private val ChartLabel = Color(0x80FFFFFF)
