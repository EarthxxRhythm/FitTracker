package com.fittracker.app.ui.screens.plan

import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.fittracker.app.R
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.TrainingPlanRepository
import com.fittracker.app.data.service.WorkoutRepository
import com.fittracker.app.data.service.WorkoutSessionService
import com.fittracker.app.ui.components.FtDumbbellIcon
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import kotlin.math.abs
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/**
 * 计划页（原型 `fittracker-plan.html` 的 `screen-plan` 帧，L547-583）。
 *
 * 画布 390×844 直绘，由 `FtCanvas` 施加；本文件所有 px 值 1:1 映射为 dp。
 * 底部 tabbar 由壳层 `FtApp` 提供，不属于本屏。
 *
 * 版式来源（原型 CSS 行号）：
 * `.plan-content` L186-191 · `.current-plan` L193-196 · `.master-card` L197-205 ·
 * `.mc-*` L206-243 · `.today-plan` L245-250 · `.deck-stage` L251-256 · `.deck` L257-263 ·
 * `.deck-card` L270-280 · `.dc-*` L306-342 · `.ex-*` L352-379。
 *
 * 卡片堆的摆放由 [FtDeckArc] 计算（对齐原型的 `applyArc`），本文件只负责把
 * [FtDeckSlot] 落到 `graphicsLayer`——**屏内不得散落几何公式**。
 */
@Composable
fun PlanScreen(
    onNavigate: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val resources = LocalResources.current
    val store = remember { JsonStore(context.appDataStore) }

    // 数据源（对齐鸿蒙 `PlanContent.loadPlanData`）：当前计划（用户启用的预置计划）→ 空态。
    // 鸿蒙的三级（含 GoalRepository + PlanEngine 生成路径）在 Android 暂为两级——GoalSetupPage
    // 已随产品变更移除（`AppState.ets` 注释），生成路径无输入源；随目标设置能力引入再补。
    var planName by remember { mutableStateOf(resources.getString(FtPlanDefaults.NAME_RES)) }
    var planMeta by remember { mutableStateOf(resources.getString(FtPlanDefaults.META_RES)) }
    var weeklyProgress by remember { mutableStateOf(resources.getString(FtPlanDefaults.WEEK_PROGRESS_RES)) }
    var progressFraction by remember { mutableStateOf(FtPlanDefaults.PROGRESS_FRACTION) }
    var days by remember { mutableStateOf(FtPlanDefaults.days) }
    var activeIndex by remember { mutableIntStateOf(0) }
    var planId by remember { mutableStateOf("") }
    var restored by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        val weekStart = SettingsService.loadSettings(store).weekStart
        val current = TrainingPlanRepository.getCurrentPlan(store)
        if (current != null) {
            planId = current.id
            days = ftPlanDaysFromUserPlan(current)
            planName = current.name.ifEmpty { resources.getString(R.string.plan_fallback_name) }
            planMeta = resources.getString(
                R.string.plan_meta_format,
                current.targetAudience,
                current.days.size,
                current.weeklyFrequency,
            )
            val stats = WorkoutSessionService.weeklyStats(
                WorkoutRepository.getSessions(store),
                System.currentTimeMillis(),
                weekStart,
            )
            val total = current.days.size
            weeklyProgress = resources.getString(R.string.plan_week_progress, stats.count, total)
            progressFraction = if (total > 0) (stats.count.toFloat() / total).coerceIn(0f, 1f) else 0f
        } else {
            // 空态（`PlanContent.applyEmptyState`）
            days = emptyList()
            planName = resources.getString(R.string.plan_fallback_name)
            planMeta = resources.getString(R.string.plan_empty_meta)
            weeklyProgress = resources.getString(R.string.plan_week_progress, 0, 0)
            progressFraction = 0f
        }
        // 恢复上次浏览的卡片位置（原型 plan.html:743-746：localStorage 'fittracker-plan-state'
        // 的 `card` 字段）。原型不做边界校验，本侧补 clamp——天数变化后旧索引会落到空位。
        val saved = PlanStateWire.decode(store.readString(StoreNames.PLAN_STATE))?.card
        activeIndex = if (saved != null && saved in days.indices) saved else 0
        restored = true
    }

    // 卡片位置变更后回写（原型 `syncActive`，plan.html:820-824）
    LaunchedEffect(activeIndex, restored) {
        if (!restored) return@LaunchedEffect
        store.writeString(StoreNames.PLAN_STATE, PlanStateWire.encode(planId, activeIndex))
    }

    // 进度条右侧文案（`PlanContent.activeDayCaption`）：随卡片堆索引联动
    val caption = days.getOrNull(activeIndex)
        ?.let { stringResource(R.string.plan_caption_active, activeIndex + 1, it.tag) }
        ?: stringResource(R.string.plan_caption_none)

    Column(
        modifier = modifier
            .fillMaxSize()
            // 原型 `.appshell` 底为 var(--ink-0)（#0B0F13），不是 FtCanvas 默认的 --bg（#07090B）
            .background(FtColor.ink0)
            .padding(start = 16.dp, end = 16.dp, top = 53.dp, bottom = 24.dp),
    ) {
        // `.current-plan { flex: 2 }` / `.today-plan { flex: 8 }`——按 2:8 分配剩余高度
        MasterPlanCard(
            name = planName,
            meta = planMeta,
            weekProgress = weeklyProgress,
            progressFraction = progressFraction,
            caption = caption,
            onClick = { onNavigate("plans") },
            modifier = Modifier
                .fillMaxWidth()
                .weight(2f),
        )
        TodayPlanDeck(
            days = days,
            activeIndex = activeIndex,
            onActiveIndexChange = { activeIndex = it },
            modifier = Modifier
                .fillMaxWidth()
                .weight(8f)
                .padding(top = 16.dp), // `.today-plan` margin-top: 16px
        )
    }
}

/**
 * 卡片位置的落盘形态——逐字段对齐原型 `localStorage['fittracker-plan-state']`
 * （`{ plan: activePlan, card: activeCard }`，plan.html:822）。
 *
 * Android 侧暂无计划选择器（原型 `plan` 字段对应多计划切换），故 `plan` 只作记录；
 * 恢复语义只消费 `card`。
 */
@Serializable
private data class PlanStateWire(val plan: String = "", val card: Int = 0) {

    companion object {

        fun encode(planId: String, card: Int): String =
            JsonCodec.json.encodeToString(PlanStateWire.serializer(), PlanStateWire(planId, card))

        /** 宽容解析：无存档 / 坏 JSON → `null`，由调用方回落默认位置。 */
        fun decode(raw: String?): PlanStateWire? = if (raw.isNullOrEmpty()) {
            null
        } else {
            runCatching { JsonCodec.json.decodeFromString(PlanStateWire.serializer(), raw) }.getOrNull()
        }
    }
}

/**
 * 当前计划摘要卡（原型 `.master-card`，L197-243；整卡是进入计划组的路由入口，
 * 见 `window.FT_APP.routes`，L968）。
 */
@Composable
private fun MasterPlanCard(
    name: String,
    meta: String,
    weekProgress: String,
    progressFraction: Float,
    caption: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(24.dp)
    Column(
        modifier = modifier
            // 原型卡阴影 `0 14px 28px rgba(0,0,0,.2)` 在深色底剖面上不可辨（参照渲染无暗带）；
            // elevation 阴影会产生可测暗带（home 判例）——按原型剖面移除
            .clip(shape)
            .background(MasterFill)
            .border(1.dp, MasterBorder, shape)
            .clickableNoRipple(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = stringResource(R.string.plan_current_title),
                style = natural(12f, 700),
                color = FtColor.accent,
            )
            Text(
                text = weekProgress,
                style = natural(11f, 700, FtType.num),
                color = FtColor.accent,
            )
        }
        Text(
            text = name,
            modifier = Modifier.padding(top = 8.dp),
            color = FtColor.txtHi,
            fontSize = 22.sp,
            lineHeight = 23.1.sp, // 1.05 × 22px（原型显式声明）
            fontWeight = FontWeight.Bold,
            letterSpacing = (-0.22).sp, // -.01em × 22px
        )
        Text(
            text = meta,
            modifier = Modifier.padding(top = 5.dp),
            style = natural(11.5f),
            color = FtColor.white62,
        )
        // `.mc-progress { margin-top: auto }`——用等权占位把进度行推到底部
        Box(modifier = Modifier.weight(1f))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(6.dp)
                    .clip(FtShape.pill)
                    .background(TrackFill),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .fillMaxWidth(progressFraction)
                        .clip(FtShape.pill)
                        .background(FtColor.accent),
                )
            }
            Text(
                text = caption,
                style = natural(11f, 600, FtType.num),
                color = FtColor.white62,
                maxLines = 1,
            )
        }
    }
}

/**
 * 今日计划卡片堆（原型 `.deck` + `renderDeck`/`paint`/`applyArc`，L734-793）。
 *
 * 三态合一：静止时 `dragOffset = 0`、拖拽中实时跟随、释放后由 `animateOffset`
 * 缓动到位——与原型同一套公式（`u = 索引 − 当前索引 − dragOffset`）。
 * 支持左右拖拽与方向键（原型 L891-894）。
 */
@Composable
internal fun TodayPlanDeck(
    days: List<FtPlanDay>,
    activeIndex: Int,
    onActiveIndexChange: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    var dragOffset by remember { mutableFloatStateOf(0f) }
    // 落定动画句柄：新落定/拖拽接管时取消旧动画，防止旧协程把 dragOffset 归零并重复落定索引（快速连拖竞态）
    var animJob by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
    val scope = rememberCoroutineScope()
    // 手势闭包（pointerInput）只在 key 变化时重启，被捕获的普通参数会**冻结**在首次组合的值上；
    // 经 rememberUpdatedState 读取，闭包内每次都能拿到最新索引/天数——否则第二次滑动会把目标
    // 索引算回旧值，表现为「卡片滑出去又弹回原来那张」（PlanDeckSwipeTest 覆盖此回归）。
    val currentActiveIndex by rememberUpdatedState(activeIndex)
    val currentDays by rememberUpdatedState(days)

    /** 原型 `animateOffset(target, dur)`：先缓动到 target，再落定索引并归零偏移。 */
    fun animateOffset(target: Float, durationMs: Int) {
        if (currentDays.isEmpty()) return // 空列表防护（空态时无卡可动）
        animJob?.cancel() // 顶替未完成的旧落定
        val from = dragOffset
        animJob = scope.launch {
            animate(
                initialValue = from,
                targetValue = target,
                animationSpec = tween(durationMs, easing = EaseOutCubic),
            ) { value, _ -> dragOffset = value }
            dragOffset = 0f
            onActiveIndexChange(
                (currentActiveIndex + target.toInt().coerceIn(-1, 1))
                    .coerceIn(0, (currentDays.size - 1).coerceAtLeast(0)),
            )
        }
    }

    /** 原型 `advance(dir)`（L846-851）：越界直接返回，不启动动画。 */
    fun advance(dir: Int) {
        val to = currentActiveIndex + dir
        if (to < 0 || to >= currentDays.size) return
        animateOffset(dir.toFloat(), COMMIT_DURATION_MS)
    }

    BoxWithConstraints(
        modifier = modifier
            .focusable()
            .onKeyEvent { event ->
                if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                when (event.key) {
                    Key.DirectionRight, Key.DirectionDown -> { advance(1); true }
                    Key.DirectionLeft, Key.DirectionUp -> { advance(-1); true }
                    else -> false
                }
            },
    ) {
        val deckWidth = maxWidth.value
        val density = LocalDensity.current
        val stepPx = with(density) { FtDeckArc.stepPx(deckWidth).dp.toPx() }
        val moveThreshold = with(density) { 6.dp.toPx() } // 原型 `Math.abs(dx) > 6`

        Box(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(days.size, deckWidth) {
                    var startOffset = 0f
                    var totalDx = 0f
                    var moved = false

                    detectDragGestures(
                        onDragStart = {
                            // 原型 L851-860：记录起点、清判别标志（并中止进行中的缓动）
                            animJob?.cancel() // 中止进行中的缓动（原型语义；此前遗漏导致快速连拖竞态）
                            startOffset = dragOffset
                            totalDx = 0f
                            moved = false
                        },
                        onDragEnd = {
                            // 原型 `endDrag`（L875-886）
                            val settle = FtDeckArc.settle(
                                dragOffset = dragOffset,
                                moved = moved,
                                activeIndex = currentActiveIndex,
                                cardCount = currentDays.size,
                            )
                            when (settle) {
                                is FtDeckSettle.Advance ->
                                    animateOffset(settle.dir.toFloat(), COMMIT_DURATION_MS)
                                FtDeckSettle.SnapBack ->
                                    animateOffset(0f, SNAPBACK_DURATION_MS)
                            }
                        },
                        onDragCancel = { animateOffset(0f, SNAPBACK_DURATION_MS) },
                        onDrag = { change, amount ->
                            change.consume()
                            totalDx += amount.x
                            if (abs(totalDx) > moveThreshold) moved = true
                            dragOffset = FtDeckArc.clampDrag(startOffset - totalDx / stepPx)
                        },
                    )
                },
        ) {
            days.forEachIndexed { index, day ->
                val slot = FtDeckArc.slot(
                    u = (index - activeIndex) - dragOffset,
                    deckWidth = deckWidth,
                )
                if (slot.alpha > 0f) {
                    DeckCard(
                        day = day,
                        dayIndex = index,
                        modifier = Modifier
                            .fillMaxSize()
                            // `.deck-card { left: 24px; right: 24px }`——卡片比 deck 窄 48
                            .padding(horizontal = FtDeckArc.CARD_INSET.dp)
                            .zIndex(slot.zIndex.toFloat())
                            .graphicsLayer {
                                translationX = slot.offsetX.dp.toPx()
                                translationY = slot.offsetY.dp.toPx()
                                rotationZ = slot.rotationDeg
                                scaleX = slot.scale
                                scaleY = slot.scale
                                alpha = slot.alpha
                            },
                    )
                }
            }
        }
    }
}

/** 单张日期卡（原型 `.deck-card` 的 `.dc-main` + `.dc-detail`，L270-379）。 */
@Composable
private fun DeckCard(
    day: FtPlanDay,
    dayIndex: Int,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(24.dp)
    Column(
        modifier = modifier
            // 原型卡阴影 `0 18px 36px rgba(0,0,0,.32)` 在深色底剖面上不可辨（参照渲染无暗带）；
            // elevation 阴影会产生可测暗带（home 判例）——按原型剖面移除
            .clip(shape)
            // 卡片堆里相邻卡会在水平方向被当前卡压住约 15px（stepPx 0.86 的余量 + 旋转角）；
            // 原型的「卡片统一」把卡底设为 rgba(255,255,255,.031) 半透明，堆叠时便会**透出**
            // 上下相邻卡的边角。先垫一层与页面同色的不透明底，再叠同一层半透明表面——
            // 观感（页面底 + 3.1% 白）不变，下层卡片不再可见。
            .background(FtColor.ink0)
            .background(DeckCardFill)
            .border(1.dp, DeckCardBorder, shape)
            .padding(18.dp),
        // `justify-content: space-between`
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Column {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    text = stringResource(R.string.plan_deck_index, dayIndex + 1, day.tag),
                    style = natural(11f, 600, FtType.mono).copy(letterSpacing = 0.44.sp), // .04em × 11px
                    color = FtColor.white62,
                )
                DayBadge(badge = day.badge, isToday = day.isToday)
                Box(modifier = Modifier.weight(1f)) // `.dc-icon { margin-left: auto }`
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(FtColor.accent10)
                        .border(1.dp, IconBorder, RoundedCornerShape(12.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    FtDumbbellIcon(modifier = Modifier.size(20.dp), color = FtColor.accent)
                }
            }
            Text(
                text = day.title,
                modifier = Modifier.padding(top = 16.dp),
                color = FtColor.txtHi,
                fontSize = 34.sp,
                lineHeight = 38.08.sp, // 1.12 × 34px（原型显式声明）
                fontWeight = FontWeight.Bold,
            )
            Text(
                // `PlanTabModel.daySubtitle`：duration 为空时不追加尾段（预置计划无单次时长）
                text = if (day.duration.isEmpty()) {
                    stringResource(R.string.plan_day_subtitle, day.focus, day.exercises.size)
                } else {
                    stringResource(R.string.plan_day_subtitle_with_duration, day.focus, day.exercises.size, day.duration)
                },
                modifier = Modifier.padding(top = 9.dp),
                style = natural(14f),
                color = FtColor.white62,
            )
        }

        Column {
            Text(
                text = stringResource(R.string.plan_exercise_list),
                style = natural(11f, 700).copy(letterSpacing = 0.22.sp), // .02em × 11px
                color = FtColor.white54,
            )
            Column(
                modifier = Modifier.padding(top = 10.dp),
                verticalArrangement = Arrangement.spacedBy(5.dp), // `.dc-list` gap: 5px
            ) {
                day.exercises.forEachIndexed { index, exercise ->
                    ExerciseRow(index = index, exercise = exercise)
                }
            }
        }
    }
}

/** 角标（原型 `.dc-type` / `.dc-type.is-today`，L314-325）。文案由 [FtPlanBadge] 资源解析。 */
@Composable
private fun DayBadge(
    badge: FtPlanBadge,
    isToday: Boolean,
) {
    Box(
        modifier = Modifier
            .clip(FtShape.pill)
            .background(if (isToday) FtColor.accent else FtColor.glass6)
            .then(
                if (isToday) {
                    Modifier
                } else {
                    Modifier.border(1.dp, FtColor.hairline, FtShape.pill)
                },
            )
            .padding(horizontal = 9.dp, vertical = 4.dp),
    ) {
        Text(
            text = if (badge.dayNumber > 0) {
                stringResource(badge.labelRes, badge.dayNumber)
            } else {
                stringResource(badge.labelRes)
            },
            style = natural(10f, if (isToday) 700 else 400),
            color = if (isToday) FtColor.onAccent else FtColor.white62,
        )
    }
}

/** 动作行（原型 `.ex-item`，L352-379）。 */
@Composable
private fun ExerciseRow(
    index: Int,
    exercise: FtPlanExercise,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 44.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(FtColor.glass6)
            .padding(horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            text = FtPlanDefaults.exerciseNumber(index),
            modifier = Modifier.width(24.dp),
            style = natural(11f, 600, FtType.mono),
            color = FtColor.accent,
        )
        Text(
            text = exercise.name,
            style = natural(13.5f, 600),
            color = FtColor.txtHi,
            maxLines = 1,
        )
        Text(
            text = exercise.muscle,
            modifier = Modifier.weight(1f),
            style = natural(11f),
            color = FtColor.white54,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = exercise.dose,
            style = natural(12f, 600, FtType.num),
            color = FtColor.white62,
            maxLines = 1,
        )
    }
}

// ── 屏内工具 ────────────────────────────────────────────────────────────────

/**
 * 原型**未声明** `line-height` 的文本样式，即 CSS 的 `normal`（字体自然行高）。
 *
 * 与 [FtType.ft] 的缺省 `1.4 × size` 不同——那个刻度化默认值会让每行多出 2–4px，
 * 叠加后累积成整屏下移（登录屏实测曾达 29px）。原型显式声明了行高的地方
 * （`.mc-name` 1.05、`.dc-name` 1.12）仍按字面值给定。
 */
private fun natural(
    size: Float,
    weight: Int = 400,
    family: FontFamily = FtType.cn,
): TextStyle = TextStyle(
    fontFamily = family,
    fontSize = size.sp,
    fontWeight = FontWeight(weight),
    lineHeight = TextUnit.Unspecified,
)

/** 原型 `easeOut(p) = 1 - (1-p)^3`（`fittracker-plan.html:810`）。 */
private val EaseOutCubic = Easing { p -> 1f - (1f - p) * (1f - p) * (1f - p) }

/** 原型切卡时长 `animateOffset(dir, 320)`。 */
private const val COMMIT_DURATION_MS = 320

/** 原型回弹时长 `animateOffset(0, 260)`。 */
private const val SNAPBACK_DURATION_MS = 260

// ── 屏内色值（原型 `:root` 无对应令牌，按 FtColorUtil 规则就地换算） ──
//
// 换算规则 AA = round(alpha × 255)

/** `.master-card` 底：OD 新版「卡片统一（Card Surface v1）」末尾覆盖为 `rgba(255,255,255,.031)` → round(7.9) = 8 = 0x08（主定义 `.06` 翡翠已被覆盖替换）。 */
private val MasterFill = Color(0x08FFFFFF)

/** `.master-card` 描边：OD 新版「卡片统一」覆盖为 `var(--line-10)` → round(25.5) = 26 = 0x1A（主定义 `.22` 翡翠已被覆盖替换）。 */
private val MasterBorder = Color(0x1AFFFFFF)

/** `.mc-track` 底 `rgba(80,236,167,.14)` → round(35.7) = 36 = 0x24 */
private val TrackFill = Color(0x2450ECA7)

/** `.dc-icon` 描边 `rgba(80,236,167,.25)` → round(63.75) = 64 = 0x40 */
private val IconBorder = Color(0x4050ECA7)

/** `.deck-card` 底：OD 新版「卡片统一」覆盖为 `rgba(255,255,255,.031)` → 0x08（主定义 `#151B20` 已被覆盖替换）。 */
private val DeckCardFill = Color(0x08FFFFFF)

/** `.deck-card` 描边：OD 新版「卡片统一」覆盖为 `var(--line-10)` → round(25.5) = 26 = 0x1A（主定义 `.09` 已被覆盖替换）。 */
private val DeckCardBorder = Color(0x1AFFFFFF)
