package com.fittracker.app.ui.components

import android.app.Application
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
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
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.data.model.WeightRecord
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.BodyRecordService
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.WeightUnit
import com.fittracker.app.ui.screens.body.FtBodyModel
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtType
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/**
 * 首页「开始训练」前置的体重记录底部面板（对齐鸿蒙 `WeightRecordDialog.ets`）。
 *
 * 入场：面板自屏幕下方升起 0.5s（`cubic-bezier(.2,.7,.2,1)` = [FtMotion.EASE_MOTION]），
 * 遮罩同步淡入到 40% 黑；面板内的平滑曲线 1.2s 从原点画到末点，
 * 末端数值随曲线尖端从 0 滚到最新体重。
 *
 * 图表语言与回顾页同源（342×132 逻辑视口、绘图区 x 12–330 / y 16–100、
 * 4 条 0.06 白网格、面积基线 y=120）：同一份数据不该因容器不同而变形。
 *
 * 大数字区域是**空输入条**（不预填历史值、不参与动画）。
 * 关闭出口只有两个——点遮罩空白处、点「取消」；**没有 × 按钮**。
 */
@Composable
fun WeightGateDialog(
    onCancel: () -> Unit,
    onConfirmed: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val app = LocalContext.current.applicationContext as Application
    val store = remember(app) { JsonStore(app.appDataStore) }
    val scope = rememberCoroutineScope()

    var unit by remember { mutableStateOf(WeightUnit.KG) }
    var latestKg by remember { mutableStateOf(0.0) }
    var hasRecords by remember { mutableStateOf(false) }
    var goalKg by remember { mutableStateOf(0.0) }
    var segments by remember { mutableStateOf<List<QuadSegment>>(emptyList()) }
    var chartLo by remember { mutableStateOf(0.0) }
    var chartHi by remember { mutableStateOf(0.0) }
    var text by remember { mutableStateOf("") }
    var hint by remember { mutableStateOf("") }
    var saving by remember { mutableStateOf(false) }
    val invalidHint = stringResource(R.string.body_invalid_hint)
    // 键盘是否可见：弹起时 ime insets 已含手势条，面板不必再让出 36dp
    val imeVisible = WindowInsets.ime.getBottom(LocalDensity.current) > 0

    // 曲线与末端数字共用的入场进度
    val progress = remember { Animatable(0f) }
    LaunchedEffect(store) {
        unit = UserProfileService.loadProfile(store).weightUnit
        val settings = SettingsService.loadSettings(store)
        goalKg = settings.weightGoalKg
        val records = BodyRecordService.loadRecords(store)
        hasRecords = records.isNotEmpty()
        latestKg = records.lastOrNull()?.kg ?: 0.0
        // 用真实记录序列（最近 CHART_POINTS 条）：周趋势会前向填充，
        // 记录少时整条曲线被铺成一条平线，看不出历史走势
        val values = records.takeLast(CHART_POINTS).map { it.kg }
        if (values.isNotEmpty()) {
            var lo = values[0].toDouble()
            var hi = values[0].toDouble()
            for (value in values) {
                if (value < lo) lo = value.toDouble()
                if (value > hi) hi = value.toDouble()
            }
            // 目标参与量程：保证目标虚线始终落在图内（否则未达标/已达标时线会被丢掉）
            if (goalKg > 0.0) {
                if (goalKg < lo) lo = goalKg
                if (goalKg > hi) hi = goalKg
            }
            chartLo = lo
            chartHi = hi
            // 与回顾页同一条归一：全等时 span 取 1，避免除零
            val span = if (hi - lo == 0.0) 1.0 else hi - lo
            segments = if (values.size == 1) {
                // 只有一条记录：从原点画到该点，否则 toSmoothSegments 返回空、曲线不画
                toSmoothSegments(
                    listOf(
                        NormPoint(0f, 0.92f),
                        NormPoint(1f, ((hi - values[0]) / span).toFloat()),
                    ),
                )
            } else {
                toSmoothSegments(
                    values.mapIndexed { index, kg ->
                        NormPoint(
                            x = index.toFloat() / (values.size - 1),
                            y = ((hi - kg) / span).toFloat(),
                        )
                    },
                )
            }
        }
        progress.animateTo(
            targetValue = 1f,
            animationSpec = tween(FtMotion.DURATION_CHART_DRAW, easing = FtMotion.EASE_MOTION),
        )
    }

    val panelState = remember { MutableTransitionState(false) }
    LaunchedEffect(Unit) { panelState.targetState = true }
    val scrim = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        scrim.animateTo(0.4f, tween(FtMotion.DURATION_PANEL_RAISE, easing = FtMotion.EASE_MOTION))
    }

    fun commit() {
        // 连点保护：addRecord 是异步落盘，没有这道闸时双击会写入两条同日记录
        if (saving) return
        val parsed = FtBodyModel.parseWeight(text)
        if (!FtBodyModel.isWeightValid(parsed)) {
            hint = invalidHint
            return
        }
        hint = ""
        val kg = FtBodyModel.toKilograms(parsed!!, unit)
        saving = true
        scope.launch {
            BodyRecordService.addRecord(
                store,
                WeightRecord(dateMillis = System.currentTimeMillis(), kg = kg),
            )
            onConfirmed()
        }
    }

    // imePadding：Activity 已 enableEdgeToEdge()、Manifest 未声明 windowSoftInputMode，
    // 窗口不会为输入法让位。不消费 ime insets 时面板被键盘整块压住——输入框卡在键盘上缘、
    // 图表和按钮全部看不见。加上它，整个 sheet 抬到键盘上方。
    Box(
        modifier = modifier
            .fillMaxSize()
            .imePadding(),
    ) {
        // 遮罩：压暗到 40%，点空白处关闭
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = scrim.value))
                .clickableNoRipple(onClick = onCancel),
        )

        AnimatedVisibility(
            visibleState = panelState,
            enter = slideInVertically(
                animationSpec = tween(FtMotion.DURATION_PANEL_RAISE, easing = FtMotion.EASE_MOTION),
            ) { it },
            modifier = Modifier.align(Alignment.BottomCenter),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    // 键盘弹起时手势条已被键盘覆盖，36dp 会变成面板与键盘之间一段空档
                    .padding(bottom = if (imeVisible) 12.dp else 36.dp),
            ) {
                // 正文卡片：两个按钮不在里面
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(28.dp))
                        .background(GATE_CARD_FILL)
                        .border(1.dp, FtColor.line10, RoundedCornerShape(28.dp))
                        .pointerInput(Unit) { detectTapGestures { } }
                        .padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 16.dp),
                ) {
                GateGrabber()

                GateHeader(latestKg = latestKg, hasRecords = hasRecords, goalKg = goalKg, unit = unit)

                GateInputRow(
                    text = text,
                    onTextChange = {
                        text = it
                        hint = ""
                    },
                    unit = unit,
                )

                BoxWithConstraints(
                    modifier = Modifier
                        .fillMaxWidth()
                        // 等比约束：宽高比锁定回顾页视口，曲线不被容器高度拉伸
                        .aspectRatio(VIEW_W / VIEW_H),
                ) {
                    val chartWidth = maxWidth
                    val chartHeight = maxHeight
                    val drawn = truncateSegments(segments, progress.value)
                    val goalRatio = goalFraction(goalKg, chartLo, chartHi)

                    Canvas(modifier = Modifier.fillMaxSize()) {
                        val sx = size.width / VIEW_W
                        val sy = size.height / VIEW_H

                        // 网格：与回顾页同 4 条，且与有无数据无关——空态保留坐标系，
                        // 否则整块区域是纯空白，看起来像渲染失败
                        for (row in GRID_ROWS) {
                            drawLine(
                                color = Color.White.copy(alpha = 0.06f),
                                start = Offset(PLOT_X0 * sx, row * sy),
                                end = Offset(PLOT_X1 * sx, row * sy),
                                strokeWidth = 1.dp.toPx(),
                            )
                        }

                        // 目标水平虚线（虚线本身即目标值）
                        if (goalRatio != null) {
                            drawLine(
                                color = Color.White.copy(alpha = 0.32f),
                                start = Offset(PLOT_X0 * sx, plotY(goalRatio) * sy),
                                end = Offset(PLOT_X1 * sx, plotY(goalRatio) * sy),
                                strokeWidth = 1.dp.toPx(),
                                pathEffect = PathEffect.dashPathEffect(
                                    floatArrayOf(4.dp.toPx(), 4.dp.toPx()),
                                ),
                            )
                        }
                        if (drawn.isNotEmpty()) {
                            val path = Path().apply {
                                moveTo(plotX(drawn[0].from.x) * sx, plotY(drawn[0].from.y) * sy)
                                drawn.forEach { segment ->
                                    quadraticBezierTo(
                                        plotX(segment.control.x) * sx,
                                        plotY(segment.control.y) * sy,
                                        plotX(segment.to.x) * sx,
                                        plotY(segment.to.y) * sy,
                                    )
                                }
                            }
                            // 渐变面积：折线到面积基线（回顾页同款）
                            val area = Path().apply {
                                addPath(path)
                                lineTo(plotX(drawn.last().to.x) * sx, AREA_BASE_Y * sy)
                                lineTo(plotX(drawn.first().from.x) * sx, AREA_BASE_Y * sy)
                                close()
                            }
                            drawPath(
                                path = area,
                                brush = Brush.verticalGradient(
                                    colors = listOf(
                                        FtColor.accent.copy(alpha = 0.12f),
                                        Color.Transparent,
                                    ),
                                    startY = PLOT_Y_TOP * sy,
                                    endY = AREA_BASE_Y * sy,
                                ),
                            )
                            drawPath(
                                path = path,
                                color = FtColor.accent,
                                style = Stroke(
                                    width = 2.5.dp.toPx(),
                                    cap = StrokeCap.Round,
                                    join = StrokeJoin.Round,
                                ),
                            )
                            tipOf(drawn)?.let { tip ->
                                val cx = plotX(tip.x) * sx
                                val cy = plotY(tip.y) * sy
                                // 光晕 → 实心点：3dp 的点在小图上太弱，加一圈低透明度底色把它点亮
                                drawCircle(
                                    color = FtColor.accent.copy(alpha = 0.22f),
                                    radius = 7.dp.toPx(),
                                    center = Offset(cx, cy),
                                )
                                drawCircle(
                                    color = FtColor.accent,
                                    radius = 3.dp.toPx(),
                                    center = Offset(cx, cy),
                                )
                            }
                        }
                    }

                    if (goalRatio != null) {
                        // 右对齐到绘图区右缘：不压曲线、不越出画布
                        Text(
                            text = goalText(goalKg, unit),
                            modifier = Modifier
                                .offset(
                                    x = chartWidth * (PLOT_X1 / VIEW_W) - LABEL_WIDTH,
                                    y = chartHeight * (plotY(goalRatio) / VIEW_H) - 20.dp,
                                )
                                .width(LABEL_WIDTH),
                            color = FtColor.white70,
                            fontSize = 13.sp,
                            textAlign = TextAlign.End,
                        )
                    }

                    val tip = tipOf(drawn)
                    if (hasRecords && tip != null) {
                        val tipX = chartWidth * (plotX(tip.x) / VIEW_W)
                        val tipY = chartHeight * (plotY(tip.y) / VIEW_H)
                        // 尖端是「最新一条」，几乎总落在最右侧：数值必须摆在内侧，
                        // 否则会被容器右缘裁掉一半（原实现无条件 ±62dp，靠左时反被压到 0）
                        val onLeft = tip.x > 0.55f
                        val labelX = if (onLeft) {
                            (tipX - LABEL_WIDTH - 8.dp).coerceAtLeast(0.dp)
                        } else {
                            tipX + 8.dp
                        }
                        // 尖端贴近下界时把数值翻到上方，避免压住曲线或越出图表区
                        val labelY = if (tip.y > 0.6f) tipY - 26.dp else tipY + 6.dp
                        Text(
                            text = FtBodyModel.formatWeight(
                                FtBodyModel.toDisplay(latestKg * progress.value, unit),
                            ),
                            modifier = Modifier
                                .offset(x = labelX, y = labelY)
                                .width(LABEL_WIDTH),
                            color = FtColor.accent,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                            textAlign = if (onLeft) TextAlign.End else TextAlign.Start,
                        )
                    }
                }

                Text(
                    text = hint,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(16.dp),
                    color = FtColor.accent,
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center,
                )
                }

                Spacer(modifier = Modifier.height(16.dp))

                Row(
                    // 必须显式 fillMaxWidth：Row wrap-content 时两个 weight(1f) 子项没有稳定基准
                    // clipToBounds：裁掉子项可能的绘制溢出（按钮左侧曾出现一条被拉伸的色带）
                    modifier = Modifier
                        .fillMaxWidth()
                        .clipToBounds(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    FtButton(
                        text = stringResource(R.string.body_sheet_cancel),
                        onClick = onCancel,
                        modifier = Modifier.weight(1f),
                        variant = FtButtonVariant.Secondary,
                        enabled = !saving,
                        height = 48.dp,
                    )
                    FtButton(
                        text = if (saving) {
                            stringResource(R.string.body_gate_saving)
                        } else {
                            stringResource(R.string.body_gate_confirm)
                        },
                        onClick = { commit() },
                        modifier = Modifier.weight(1f),
                        enabled = !saving,
                        height = 48.dp,
                    )
                }
            }
        }
    }
}

/** 顶部抓手：底部面板的惯例 affordance，说明这块是可升起的表层而不是浮在页面中间的卡片。 */
@Composable
private fun GateGrabber() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 14.dp),
        horizontalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .width(40.dp)
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(FtColor.line10),
        )
    }
}

@Composable
private fun GateHeader(latestKg: Double, hasRecords: Boolean, goalKg: Double, unit: WeightUnit) {
    // 信息层级：标签弱（12sp / white40），数值强（13sp / white87 或 accent）
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = stringResource(R.string.body_gate_last), color = FtColor.white40, fontSize = 12.sp)
            Text(
                text = if (hasRecords) {
                    FtBodyModel.formatWeight(FtBodyModel.toDisplay(latestKg, unit)) +
                        FtBodyModel.unitLabel(unit)
                } else {
                    stringResource(R.string.body_gate_no_records)
                },
                color = if (hasRecords) FtColor.white87 else FtColor.white40,
                fontSize = 13.sp,
                fontWeight = if (hasRecords) FontWeight.Medium else FontWeight.Normal,
            )
        }
        Spacer(modifier = Modifier.weight(1f))
        if (goalKg > 0.0) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(text = stringResource(R.string.body_gate_goal), color = FtColor.white40, fontSize = 12.sp)
                Text(
                    text = FtBodyModel.toDisplay(goalKg, unit).roundToInt().toString() +
                        FtBodyModel.unitLabel(unit).uppercase(),
                    color = FtColor.accent,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }
    }
}

@Composable
private fun GateInputRow(text: String, onTextChange: (String) -> Unit, unit: WeightUnit) {
    // BasicTextField 在 Row 里总会吃满可用宽度（weight/fill=false 都压不住），
    // 于是单位被推到屏幕最右。这里按实际字形宽度测出输入框宽度，让「数字 + 单位」成为一组。
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val focusRequester = remember { FocusRequester() }
    var focused by remember { mutableStateOf(false) }
    // 聚焦即展开 76→96 并提亮：移动端没有 hover，焦点是唯一现成的「在场」通道
    val lineWidth by animateDpAsState(
        targetValue = if (focused) 96.dp else 76.dp,
        animationSpec = tween(FtMotion.DURATION_PRESS, easing = FtMotion.EASE_MOTION),
        label = "gate-input-line-width",
    )
    val lineAlpha by animateFloatAsState(
        targetValue = if (focused) 1f else 0.5f,
        animationSpec = tween(FtMotion.DURATION_PRESS, easing = FtMotion.EASE_MOTION),
        label = "gate-input-line-alpha",
    )
    // 空态宽度归零：只剩单位单独居中；有输入时按字形宽度展开，数字与单位紧邻
    val fieldWidth = if (text.isEmpty()) {
        0.dp
    } else {
        val widthPx = remember(text) {
            measurer.measure(
                text = text,
                style = FtType.natural(56f, 700, FtType.num),
            ).size.width
        }
        with(density) { widthPx.toDp() } + 8.dp
    }

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 10.dp)
                .height(72.dp)
                // 空态输入框宽度为 0，点整块也能聚焦
                .clickableNoRipple { focusRequester.requestFocus() },
            contentAlignment = Alignment.Center,
        ) {
            // 数字独立居中；单位不参与居中计算，挂在数字右侧
            BasicTextField(
                value = text,
                onValueChange = onTextChange,
                modifier = Modifier
                    .width(fieldWidth)
                    .height(64.dp)
                    .focusRequester(focusRequester)
                    .onFocusChanged { focused = it.isFocused },
                textStyle = FtType.natural(56f, 700, FtType.num).copy(
                    color = FtColor.txtHi,
                    textAlign = TextAlign.Center,
                ),
                singleLine = true,
                cursorBrush = SolidColor(FtColor.accent),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            )
            Text(
                text = FtBodyModel.unitLabel(unit).uppercase(),
                // 单位是次级信息：字号压到主数字的约 0.32 倍，间距收到 10dp，右下微沉
                modifier = Modifier.offset(x = fieldWidth / 2 + 10.dp, y = 6.dp),
                color = FtColor.white65,
                fontSize = 18.sp,
                letterSpacing = 0.5.sp,
            )
        }
        Box(
            modifier = Modifier
                .width(lineWidth)
                .height(2.dp)
                .background(FtColor.accent.copy(alpha = lineAlpha)),
        )
    }
}

/** 目标线在图表内的 y 比例；无目标 / 量程非法 / 越界返回 null（不画）。 */
private fun goalFraction(goalKg: Double, lo: Double, hi: Double): Float? {
    if (goalKg <= 0.0 || hi <= lo) return null
    if (goalKg < lo || goalKg > hi) return null
    return ((hi - goalKg) / (hi - lo)).toFloat()
}

/** 目标标签：按显示单位取整（与回顾页口径一致）+ 单位，与 header 同一口径。 */
private fun goalText(goalKg: Double, unit: WeightUnit): String =
    FtBodyModel.toDisplay(goalKg, unit).roundToInt().toString() +
        FtBodyModel.unitLabel(unit).uppercase()

/** 逻辑视口尺寸（与回顾页 342×132 同基准）。 */
private const val VIEW_W = 342f
private const val VIEW_H = 132f

/** 绘图区边界与上下界（回顾页同值：x 12–330、y 16–100）。 */
private const val PLOT_X0 = 12f
private const val PLOT_X1 = 330f
private const val PLOT_Y_TOP = 16f
private const val PLOT_Y_BOTTOM = 100f

/** 渐变面积下延基线（回顾页同值）。 */
private const val AREA_BASE_Y = 120f

/** 网格横线（回顾页同 4 条）。 */
private val GRID_ROWS = listOf(16f, 44f, 72f, 100f)

/** 归一化 x（0..1）→ 逻辑视口 x。 */
private fun plotX(nx: Float): Float = PLOT_X0 + nx * (PLOT_X1 - PLOT_X0)

/** 归一化 y（0..1，0 = 量程上界）→ 逻辑视口 y。 */
private fun plotY(ny: Float): Float = PLOT_Y_TOP + ny * (PLOT_Y_BOTTOM - PLOT_Y_TOP)

/** 图表取最近多少条真实记录。 */
private const val CHART_POINTS = 14

/** 图表标签固定宽度（够 "999.9LBS"）：右对齐取数时不会因文本宽度漂移。 */
private val LABEL_WIDTH = 56.dp

/** 面板不透明中性玻璃面：蒙层之下用半透明白会把首页内容透进面板。 */
private val GATE_CARD_FILL = Color(0xFF13161A)
