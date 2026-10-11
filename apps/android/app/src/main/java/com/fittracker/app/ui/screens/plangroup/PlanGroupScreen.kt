package com.fittracker.app.ui.screens.plangroup

import androidx.annotation.StringRes
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import kotlinx.coroutines.delay

/**
 * 计划组详细页（原型 `fittracker-plan-group-detail.html` 的 `screen-plan-group-detail` 帧，
 * OD 最新版 L381-428）。
 *
 * 画布 390×844 直绘。无底栏（非 Tab 一级路由）。
 *
 * 版式来源（OD 最新版 CSS 行号）：
 * `.pgd-top` L137-144 · `.pgd-scroll` L163-165 · `.pgd-content` L169 ·
 * `.pgd-summary*` L172-193 · `.pgd-rhythm*` L196-219 · `.pgd-days` L222 ·
 * `.pgd-day-tab*` L224-248 · `.pgd-day-panel`/`.pgd-ex*` L251-296 ·
 * `.pgd-cta-bar`/`.pgd-cta` L299-321 · `.pgd-toast` L324-342。
 *
 * 交互（OD 最新版 L493-593）：天页签切换是**纯前端状态**（不跳路由，L564）；
 * 动作行点击弹浮层（L575）；「使用此计划」置灰 1600ms 后复原（L585-591）；
 * 返回键被 `window.FT_APP.routes`（L611）改写成导航到 `plans`；Android 侧走 [onBack]
 * （优先出栈，直达无栈可退时按 PARENT 表回退 `plans`）。
 */
@Composable
fun PlanGroupScreen(
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val resources = LocalResources.current
    var currentDay by remember { mutableIntStateOf(0) }
    var useDisabled by remember { mutableStateOf(false) }
    var toast by remember { mutableStateOf<String?>(null) }

    // 原型 `showToast` 的 `setTimeout(…, 1800)`（L452）
    LaunchedEffect(toast) {
        if (toast != null) {
            delay(1800)
            toast = null
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(FtColor.ink0) // `.appshell` 底 var(--ink-0)
            // 环境光（OD L129-133）：为液态玻璃提供可折射/透出的明暗与色相变化。
            // 原型为三束椭圆 radial-gradient，此处以正圆近似（半径取两轴均值），
            // 颜色自中心 alpha 渐隐至透明。
            .drawBehind {
                val w = size.width
                val h = size.height
                drawRect(
                    brush = Brush.radialGradient(
                        colors = listOf(AmbientGlow0, Color.Transparent),
                        center = Offset(w * 0.16f, h * 0.06f),
                        radius = (w * 0.58f + h * 0.38f) / 2f,
                    ),
                )
                drawRect(
                    brush = Brush.radialGradient(
                        colors = listOf(AmbientGlow1, Color.Transparent),
                        center = Offset(w * 0.88f, h * 0.78f),
                        radius = (w * 0.52f + h * 0.34f) / 2f,
                    ),
                )
                drawRect(
                    brush = Brush.radialGradient(
                        colors = listOf(AmbientGlow2, Color.Transparent),
                        center = Offset(w * 0.94f, h * 0.16f),
                        radius = (w * 0.44f + h * 0.30f) / 2f,
                    ),
                )
            },
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            TopBar(onBack = onBack)

            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()), // `.pgd-scroll`
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp), // `.pgd-content` gap: 16px
                ) {
                    SummaryCard()
                    RhythmSection()
                    DayTabs(currentDay = currentDay, onSelect = { currentDay = it })
                    DayPanel(
                        day = FtPlanGroupDetail.days[currentDay],
                        onExercise = { name ->
                            toast = resources.getString(R.string.plangroup_toast_exercise, name)
                        },
                    )
                }
            }

            CtaBar(
                disabled = useDisabled,
                onClick = {
                    useDisabled = true
                    toast = resources.getString(
                        R.string.plangroup_toast_switched,
                        resources.getString(FtPlanGroupDetail.NAME_RES),
                    )
                },
            )
        }

        // `.pgd-toast` 定位在 `.appshell` 内（bottom 88），与本屏同坐标系，故屏内实现
        ScreenToast(
            message = toast,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 88.dp),
        )
    }

    // 原型「使用此计划」的 1600ms 复原（L579）
    LaunchedEffect(useDisabled) {
        if (useDisabled) {
            delay(1600)
            useDisabled = false
        }
    }
}

/** `.pgd-top` L137-144：52/12/10 内边距、44px 返回键、居中标题、右侧同宽占位。 */
@Composable
private fun TopBar(onBack: () -> Unit) {
    // `stringResource` 只能在 @Composable 上下文调用，`.semantics {}` lambda 不是——先解析再闭包捕获
    val backA11y = stringResource(R.string.plangroup_a11y_back)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(TopBarFill)
            .padding(start = 12.dp, end = 12.dp, top = 52.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(14.dp))
                // 无障碍标签逐字取自原型 `.pgd-back` 的 aria-label（OD 新版 L390）
                .semantics { contentDescription = backA11y }
                .clickableNoRipple(onClick = onBack),
            contentAlignment = Alignment.Center,
        ) {
            ChevronLeftIcon(modifier = Modifier.size(22.dp), color = FtColor.white70)
        }
        Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
            Text(
                text = stringResource(FtPlanGroupDetail.NAME_RES),
                style = FtType.natural(16f, 700),
                color = FtColor.txtHi,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Box(modifier = Modifier.size(44.dp)) // `.pgd-top-spacer`
    }
}

/** `.pgd-summary` L172-193（OD 新版）：中性灰阶——石墨底 + 中性描边 + 顶部内高光，不参与强调色预算。 */
@Composable
private fun SummaryCard() {
    val shape = RoundedCornerShape(22.dp)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            // 原型卡阴影 `0 14px 30px rgba(0,0,0,.36)` 在深色底剖面上不可辨（参照渲染无暗带）；
            // elevation 阴影会产生可测暗带（home 判例）——按原型剖面移除
            .clip(shape)
            .background(SummaryFill) // #1A1D20
            .drawBehind { topHighlight(0.11f) } // `inset 0 1px 0 rgba(255,255,255,.11)`
            .border(1.dp, SummaryBorder, shape)
            .padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 15.dp),
    ) {
        Column {
            Text(
                text = stringResource(R.string.plangroup_summary_label),
                style = FtType.natural(11f, 700).copy(letterSpacing = 0.66.sp), // .06em × 11px（OD L182）
                color = FtColor.white54,
            )
            Text(
                text = stringResource(FtPlanGroupDetail.NAME_RES),
                modifier = Modifier
                    .padding(top = 8.dp, end = 8.dp)
                    .fillMaxWidth(),
                color = FtColor.txtHi,
                fontSize = 22.sp,
                lineHeight = 26.sp, // 1.18 × 22px（原型显式声明）
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = stringResource(FtPlanGroupDetail.DESC_RES),
                modifier = Modifier.padding(top = 8.dp),
                color = FtColor.white62,
                fontSize = 13.sp,
                lineHeight = 20.8.sp, // 1.6 × 13px（原型显式声明）
            )
            Row(
                modifier = Modifier.padding(top = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(7.dp), // `.pgd-summary-meta` gap: 7px
            ) {
                FtPlanGroupDetail.TAGS.forEach { tagRes ->
                    Box(
                        modifier = Modifier
                            .clip(FtShape.pill)
                            .background(TagFill) // rgba(255,255,255,.07)
                            .border(1.dp, TagBorder, FtShape.pill)
                            .padding(horizontal = 11.dp, vertical = 4.dp),
                    ) {
                        Text(
                            text = stringResource(tagRes),
                            style = FtType.natural(11f, 600),
                            color = TagText, // rgba(255,255,255,.74)
                        )
                    }
                }
            }
        }
    }
}

/** `.pgd-rhythm` L196-219：7 列等宽格 + 星期一~日标签。 */
@Composable
private fun RhythmSection() {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp), // `.pgd-rhythm` gap: 10px
    ) {
        Text(
            text = stringResource(R.string.plangroup_rhythm_title),
            style = FtType.natural(12f, 700).copy(letterSpacing = 0.24.sp), // .02em × 12px
            color = FtColor.white54,
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(5.dp), // `.pgd-rhythm-grid` gap: 5px
        ) {
            FtPlanGroupDetail.WEEK.forEachIndexed { index, labelRes ->
                RhythmDay(
                    dow = stringResource(FtPlanGroupDetail.DOW[index]),
                    label = stringResource(labelRes),
                    rest = index == FtPlanGroupDetail.REST_INDEX,
                    modifier = Modifier.weight(1f), // grid-template-columns: repeat(7, 1fr)
                )
            }
        }
    }
}

@Composable
private fun RhythmDay(
    dow: String,
    label: String,
    rest: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = dow,
            style = FtType.natural(11f, 600),
            color = FtColor.white40,
        )
        val cellShape = RoundedCornerShape(11.dp)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(34.dp)
                .then(
                    if (rest) {
                        // `.pgd-rhythm-cell.rest`（OD L214-219）：#151D1B + 中性描边、无发光
                        Modifier
                            .clip(cellShape)
                            .background(CellRestFill)
                            .border(1.dp, CellRestBorder, cellShape)
                    } else {
                        // `.pgd-rhythm-cell`（OD L201-213）：纯色强调 + 发光 + 顶部内高光
                        Modifier
                            .shadow(
                                4.dp,
                                cellShape,
                                ambientColor = GlowAccent20, // `0 4px 12px rgba(80,236,167,.20)`
                                spotColor = GlowAccent20,
                            )
                            .clip(cellShape)
                            .background(FtColor.accent)
                            .drawBehind { topHighlight(0.34f) }
                            .border(1.dp, Color.Transparent, cellShape)
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = label,
                style = FtType.natural(12f, 700),
                color = if (rest) FtColor.white40 else FtColor.onAccent, // #07100B
            )
        }
    }
}

/** `.pgd-days` L222-248：横向滚动的天页签，选中态为纯色强调 + 发光（OD 新版）。 */
@Composable
private fun DayTabs(
    currentDay: Int,
    onSelect: (Int) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp), // `.pgd-days` gap: 8px
    ) {
        FtPlanGroupDetail.days.forEachIndexed { index, day ->
            val active = index == currentDay
            val tabShape = RoundedCornerShape(16.dp)
            Column(
                modifier = Modifier
                    .widthIn(min = 96.dp) // `.pgd-day-tab` min-width: 96px
                    .then(
                        if (active) {
                            // `.pgd-day-tab.active`（OD L238-244）：纯色强调 + 发光 + 顶部内高光
                            Modifier
                                .shadow(
                                    8.dp,
                                    tabShape,
                                    ambientColor = GlowAccent24, // `0 8px 20px rgba(80,236,167,.24)`
                                    spotColor = GlowAccent24,
                                )
                                .clip(tabShape)
                                .background(FtColor.accent)
                                .drawBehind { topHighlight(0.34f) }
                                .border(1.dp, Color.Transparent, tabShape) // border: transparent
                        } else {
                            // `.pgd-day-tab`（OD L224-235）：#141B1A + 中性描边
                            Modifier
                                .clip(tabShape)
                                .background(TabFill)
                                .border(1.dp, TabBorder, tabShape)
                        },
                    )
                    .clickableNoRipple { onSelect(index) }
                    .padding(horizontal = 12.dp, vertical = 10.dp),
            ) {
                Text(
                    text = stringResource(R.string.plangroup_day_tab, index + 1),
                    style = FtType.natural(11f, 600, FtType.num),
                    color = if (active) OnAccent64 else FtColor.white54, // `.active .n`：rgba(7,16,11,.64)
                )
                Text(
                    text = stringResource(day.titleRes),
                    modifier = Modifier.padding(top = 3.dp),
                    style = FtType.natural(14f, 700),
                    color = if (active) FtColor.onAccent else FtColor.txtHi, // `.active .t`：#07100B
                )
            }
        }
    }
}

/** `.pgd-day-panel` + `.pgd-ex*` L251-296：当日动作清单。 */
@Composable
private fun DayPanel(
    day: FtGroupDay,
    onExercise: (String) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp), // `.pgd-day-panel` gap: 12px
    ) {
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(8.dp), // `.pgd-day-head` gap: 8px
        ) {
            Text(
                text = stringResource(day.titleRes),
                style = FtType.natural(16f, 700),
                color = FtColor.txtHi,
            )
            Text(
                text = stringResource(day.focusRes),
                style = FtType.natural(12f),
                color = FtColor.white54,
            )
        }
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(9.dp), // `.pgd-ex-list` gap: 9px
        ) {
            day.exercises.forEachIndexed { index, exercise ->
                // `stringResource` 不能在点击回调里调用——先解析再闭包捕获
                val exerciseName = stringResource(exercise.nameRes)
                GroupExerciseRow(
                    index = index,
                    exercise = exercise,
                    onClick = { onExercise(exerciseName) },
                )
            }
        }
    }
}

@Composable
private fun GroupExerciseRow(
    index: Int,
    exercise: FtGroupExercise,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(15.dp))
            .background(ExFill) // `#151B20`
            .border(1.dp, FtColor.line14, RoundedCornerShape(15.dp))
            .clickableNoRipple(onClick = onClick)
            .padding(horizontal = 13.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        val idxShape = RoundedCornerShape(10.dp)
        Box(
            modifier = Modifier
                .size(28.dp)
                // `.pgd-ex-idx`（OD L269-283）：纯色强调 + 发光 + 顶部内高光
                .shadow(
                    3.dp,
                    idxShape,
                    ambientColor = GlowAccent20, // `0 3px 10px rgba(80,236,167,.20)`
                    spotColor = GlowAccent20,
                )
                .clip(idxShape)
                .background(FtColor.accent)
                .drawBehind { topHighlight(0.34f) }
                .border(1.dp, Color.Transparent, idxShape),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "${index + 1}",
                style = FtType.natural(13f, 700, FtType.num),
                color = FtColor.onAccent, // #07100B
            )
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(7.dp),
            ) {
                Text(
                    text = stringResource(exercise.nameRes),
                    modifier = Modifier.weight(1f, fill = false),
                    style = FtType.natural(14f, 700),
                    color = FtColor.txtHi,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Box(
                    modifier = Modifier
                        .clip(FtShape.pill)
                        .background(FtColor.glass6)
                        .border(1.dp, FtColor.hairline, FtShape.pill)
                        .padding(horizontal = 7.dp, vertical = 2.dp),
                ) {
                    Text(
                        text = stringResource(exercise.equipmentRes),
                        style = FtType.natural(10f, 600),
                        color = FtColor.white54,
                        maxLines = 1,
                    )
                }
            }
            Text(
                text = stringResource(exercise.noteRes),
                style = FtType.natural(11.5f),
                color = FtColor.white54,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Text(
            text = stringResource(R.string.plangroup_sets_reps, exercise.sets, exercise.reps),
            style = FtType.natural(13f, 700, FtType.num),
            color = FtColor.accentSoft,
            maxLines = 1,
        )
    }
}

/** `.pgd-cta-bar` L299-321：底部固定主按钮，「使用中」置灰并换文案。 */
@Composable
private fun CtaBar(
    disabled: Boolean,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(CtaBarFill)
            .padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 20.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(FtColor.accent)
                .clickableNoRipple(enabled = !disabled, onClick = onClick),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            CheckIcon(modifier = Modifier.size(16.dp), color = FtColor.onAccent)
            Text(
                text = stringResource(if (disabled) R.string.plangroup_cta_used else R.string.plangroup_cta_use),
                modifier = Modifier.padding(start = 7.dp),
                style = FtType.natural(15f, 700).copy(letterSpacing = 0.15.sp), // .01em × 15px
                color = FtColor.onAccent,
            )
        }
    }
}

/**
 * 浮层（原型 `.pgd-toast` L324-342）。
 *
 * 它挂在 `.appshell` 内（`bottom: 88px`），与本屏同坐标系——**不**像登录屏那样
 * 位于缩放画布之外，故屏内直接实现，不必提到 `FtScreen` 的宿主层。
 */
@Composable
private fun ScreenToast(
    message: String?,
    modifier: Modifier = Modifier,
) {
    var shown by remember { mutableStateOf("") }
    if (message != null && message != shown) {
        shown = message
    }
    // 原型 `translateY(10px)`：入出场位移固定 10px，须在 Density 作用域内换算为 px
    val slideOffset = with(LocalDensity.current) { 10.dp.roundToPx() }
    androidx.compose.animation.AnimatedVisibility(
        visible = message != null,
        modifier = modifier,
        enter = androidx.compose.animation.fadeIn(
            androidx.compose.animation.core.tween(180),
        ) + androidx.compose.animation.slideInVertically(
            androidx.compose.animation.core.tween(180),
        ) { slideOffset },
        exit = androidx.compose.animation.fadeOut(
            androidx.compose.animation.core.tween(180),
        ) + androidx.compose.animation.slideOutVertically(
            androidx.compose.animation.core.tween(180),
        ) { slideOffset },
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 320.dp)
                .clip(FtShape.pill)
                .background(ToastFill)
                .border(1.dp, FtColor.line10, FtShape.pill)
                .padding(horizontal = 16.dp, vertical = 10.dp),
        ) {
            Text(
                text = shown,
                color = FtColor.txtHi,
                fontSize = 13.sp,
                lineHeight = 18.2.sp, // 1.4 × 13px（原型显式声明）
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
        }
    }
}

// ── 图标 ────────────────────────────────────────────────────────────────────
//
// 路径逐字取自本文件的 `<symbol>`（OD 新版 L361-366）。与 `PlansScreen` 的同名图标路径相同，
// 但按「同一抽象第三次出现才提取」的纪律，此处仍为屏内私有实现
// （`PlansScreen` 是第二次；若后续屏再用，应提到 `ui/components/FtIcons.kt`）。

private const val ICON_VIEW = 24f

/** 返回（原型 `#i-chevron-left`，OD 新版 L361-363）：`M15 5l-7 7 7 7`，描边 2、圆头圆角。 */
@Composable
private fun ChevronLeftIcon(modifier: Modifier = Modifier, color: Color = Color.Unspecified) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val p = Path().apply {
            moveTo(15f * k, 5f * k)
            lineTo(8f * k, 12f * k)
            lineTo(15f * k, 19f * k)
        }
        drawPath(p, color, style = Stroke(2f * k, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

/** CTA 前的对勾（原型 `#i-check`，OD 新版 L364-366）：`M5 12.5l4.5 4.5L19 7`。 */
@Composable
private fun CheckIcon(modifier: Modifier = Modifier, color: Color = Color.Unspecified) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val p = Path().apply {
            moveTo(5f * k, 12.5f * k)
            lineTo(9.5f * k, 17f * k)
            lineTo(19f * k, 7f * k)
        }
        drawPath(p, color, style = Stroke(2f * k, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

// ── 数据（原型 `PLAN`，OD 新版 L437-477，逐字移植） ────────────────────────

data class FtGroupExercise(
    val id: String,
    @StringRes val nameRes: Int,
    val sets: Int,
    val reps: String,
    @StringRes val equipmentRes: Int,
    @StringRes val noteRes: Int,
)

data class FtGroupDay(
    @StringRes val titleRes: Int,
    @StringRes val focusRes: Int,
    val exercises: List<FtGroupExercise>,
)

object FtPlanGroupDetail {

    /** 计划名（原型 `PLAN.name`，OD 新版 L438）。 */
    @StringRes
    val NAME_RES = R.string.plangroup_name

    /** 计划描述（原型 `PLAN.desc`）。 */
    @StringRes
    val DESC_RES = R.string.plangroup_desc

    /** 概要卡的三个标签（原型同级字段 `audience`/`freq`/`totalDays` 拼装，OD 新版 L443）。 */
    val TAGS: List<Int> = listOf(
        R.string.plangroup_tag_audience,
        R.string.plangroup_tag_freq,
        R.string.plangroup_tag_days,
    )

    /** 每周节奏（原型 `week`，OD 新版 L444）：'休' 走 `.rest` 样式（见 [REST_INDEX]）。 */
    val WEEK: List<Int> = listOf(
        R.string.plangroup_rhythm_push,
        R.string.plangroup_rhythm_pull,
        R.string.plangroup_rhythm_legs,
        R.string.plangroup_rhythm_push,
        R.string.plangroup_rhythm_pull,
        R.string.plangroup_rhythm_legs,
        R.string.plangroup_rhythm_rest,
    )

    /** [WEEK] 中「休」的下标——原型以 `label === '休'` 判定 `.rest`，此处等价为下标判定。 */
    const val REST_INDEX = 6

    /** 星期标签（原型 `DOW`，OD 新版 L512）。 */
    val DOW: List<Int> = listOf(
        R.string.plangroup_dow_mon,
        R.string.plangroup_dow_tue,
        R.string.plangroup_dow_wed,
        R.string.plangroup_dow_thu,
        R.string.plangroup_dow_fri,
        R.string.plangroup_dow_sat,
        R.string.plangroup_dow_sun,
    )

    val days: List<FtGroupDay> = listOf(
        FtGroupDay(
            titleRes = R.string.plangroup_rhythm_push,
            focusRes = R.string.plangroup_focus_push,
            exercises = listOf(
                FtGroupExercise(
                    id = "barbell-bench-press",
                    nameRes = R.string.plangroup_ex_bench_press,
                    sets = 4,
                    reps = "8",
                    equipmentRes = R.string.plangroup_equip_barbell,
                    noteRes = R.string.plangroup_ex_bench_press_note,
                ),
                FtGroupExercise(
                    id = "overhead-press",
                    nameRes = R.string.plangroup_ex_overhead_press,
                    sets = 3,
                    reps = "10",
                    equipmentRes = R.string.plangroup_equip_dumbbell,
                    noteRes = R.string.plangroup_ex_overhead_press_note,
                ),
                FtGroupExercise(
                    id = "lateral-raise",
                    nameRes = R.string.plangroup_ex_lateral_raise,
                    sets = 3,
                    reps = "12",
                    equipmentRes = R.string.plangroup_equip_dumbbell,
                    noteRes = R.string.plangroup_ex_lateral_raise_note,
                ),
                FtGroupExercise(
                    id = "triceps-pushdown",
                    nameRes = R.string.plangroup_ex_triceps_pushdown,
                    sets = 3,
                    reps = "12",
                    equipmentRes = R.string.plangroup_equip_machine,
                    noteRes = R.string.plangroup_ex_triceps_pushdown_note,
                ),
            ),
        ),
        FtGroupDay(
            titleRes = R.string.plangroup_rhythm_pull,
            focusRes = R.string.plangroup_focus_pull,
            exercises = listOf(
                FtGroupExercise(
                    id = "pull-up",
                    nameRes = R.string.plangroup_ex_pull_up,
                    sets = 4,
                    reps = "8",
                    equipmentRes = R.string.plangroup_equip_bodyweight,
                    noteRes = R.string.plangroup_ex_pull_up_note,
                ),
                FtGroupExercise(
                    id = "barbell-row",
                    nameRes = R.string.plangroup_ex_barbell_row,
                    sets = 4,
                    reps = "10",
                    equipmentRes = R.string.plangroup_equip_barbell,
                    noteRes = R.string.plangroup_ex_barbell_row_note,
                ),
                FtGroupExercise(
                    id = "lat-pulldown",
                    nameRes = R.string.plangroup_ex_lat_pulldown,
                    sets = 3,
                    reps = "12",
                    equipmentRes = R.string.plangroup_equip_machine,
                    noteRes = R.string.plangroup_ex_lat_pulldown_note,
                ),
                FtGroupExercise(
                    id = "biceps-curl",
                    nameRes = R.string.plangroup_ex_biceps_curl,
                    sets = 3,
                    reps = "12",
                    equipmentRes = R.string.plangroup_equip_dumbbell,
                    noteRes = R.string.plangroup_ex_biceps_curl_note,
                ),
            ),
        ),
        FtGroupDay(
            titleRes = R.string.plangroup_rhythm_legs,
            focusRes = R.string.plangroup_focus_legs,
            exercises = listOf(
                FtGroupExercise(
                    id = "squat",
                    nameRes = R.string.plangroup_ex_squat,
                    sets = 4,
                    reps = "8",
                    equipmentRes = R.string.plangroup_equip_barbell,
                    noteRes = R.string.plangroup_ex_squat_note,
                ),
                FtGroupExercise(
                    id = "leg-press",
                    nameRes = R.string.plangroup_ex_leg_press,
                    sets = 3,
                    reps = "12",
                    equipmentRes = R.string.plangroup_equip_machine,
                    noteRes = R.string.plangroup_ex_leg_press_note,
                ),
                FtGroupExercise(
                    id = "leg-curl",
                    nameRes = R.string.plangroup_ex_leg_curl,
                    sets = 3,
                    reps = "12",
                    equipmentRes = R.string.plangroup_equip_machine,
                    noteRes = R.string.plangroup_ex_leg_curl_note,
                ),
                FtGroupExercise(
                    id = "lunge",
                    nameRes = R.string.plangroup_ex_lunge,
                    sets = 3,
                    reps = "12",
                    equipmentRes = R.string.plangroup_equip_dumbbell,
                    noteRes = R.string.plangroup_ex_lunge_note,
                ),
            ),
        ),
    )
}

// ── 屏内色值（原型 `:root` 无对应令牌，按 FtColorUtil 规则就地换算） ──
//
// 换算规则 AA = round(alpha × 255)

/** `.pgd-top` 底 `rgba(10,13,18,.82)` → round(209.1) = 209 = 0xD1 */
private val TopBarFill = Color(0xD10A0D12)

/** `.pgd-cta-bar` 底 `rgba(10,13,18,.92)` → round(234.6) = 235 = 0xEB */
private val CtaBarFill = Color(0xEB0A0D12)

/** `.pgd-toast` 底 `rgba(13,17,23,.94)` → round(239.7) = 240 = 0xF0 */
private val ToastFill = Color(0xF00D1117)

/** `.appshell` 环境光三束（OD L131-133）：`rgba(80,236,167,.12)` / `rgba(69,201,161,.085)` / `rgba(140,235,204,.055)` */
private val AmbientGlow0 = Color(0x1F50ECA7)
private val AmbientGlow1 = Color(0x1645C9A1)
private val AmbientGlow2 = Color(0x0E8CEBCC)

/** `.pgd-summary` 底 `#1A1D20`（OD 新版：中性灰阶，不参与强调色预算） */
private val SummaryFill = Color(0xFF1A1D20)

/** `.pgd-summary` 描边 `rgba(255,255,255,.12)` → round(30.6) = 31 = 0x1F（OD L175） */
private val SummaryBorder = Color(0x1FFFFFFF)

/** `.pgd-tag` 底 `rgba(255,255,255,.07)` → round(17.85) = 18 = 0x12；描边 `.12` → 0x1F；文字 `.74` → round(188.7) = 189 = 0xBD（OD L186-191） */
private val TagFill = Color(0x12FFFFFF)
private val TagBorder = Color(0x1FFFFFFF)
private val TagText = Color(0xBDFFFFFF)

/** `.pgd-rhythm-cell.rest` 底 `#151D1B`；描边 `rgba(255,255,255,.08)` → round(20.4) = 20 = 0x14（OD L214-219） */
private val CellRestFill = Color(0xFF151D1B)
private val CellRestBorder = Color(0x14FFFFFF)

/** `.pgd-day-tab` 未选中底 `#141B1A`；描边 `rgba(255,255,255,.08)` → 0x14（OD L224-235） */
private val TabFill = Color(0xFF141B1A)
private val TabBorder = Color(0x14FFFFFF)

/** `.pgd-day-tab.active .n`：`rgba(7,16,11,.64)` → round(163.2) = 163 = 0xA3（OD L247） */
private val OnAccent64 = Color(0xA307100B)

/** 强调块发光（`rgba(80,236,167,.20)` → 51 = 0x33 / `.24` → 61 = 0x3D；OD L209/L242/L276） */
private val GlowAccent20 = Color(0x3350ECA7)
private val GlowAccent24 = Color(0x3D50ECA7)

/** `.pgd-ex` 底 `#151B20` */
private val ExFill = Color(0xFF151B20)

/** `inset 0 1px 0 rgba(255,255,255,α)` 顶部内高光（概要卡 / 节奏格 / 天页签 / 序号块共用，OD 新版）。 */
private fun DrawScope.topHighlight(alpha: Float) {
    drawLine(
        color = Color.White.copy(alpha = alpha),
        start = Offset.Zero,
        end = Offset(size.width, 0f),
        strokeWidth = 1.dp.toPx(),
    )
}
