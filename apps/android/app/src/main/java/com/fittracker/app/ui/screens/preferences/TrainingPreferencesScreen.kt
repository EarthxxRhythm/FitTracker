package com.fittracker.app.ui.screens.preferences

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.FtTrainingPreferences
import com.fittracker.app.data.service.PlanAdapter
import com.fittracker.app.data.service.TrainingPreferencesService
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 训练偏好屏（规格源：`design/06_prototype_redraw/src/fittracker-training-preferences.html`，
 * frame `screen-training-preferences`——设计侧新增页，原型 footer（L448）明示入口在个人页）。
 *
 * 390×844 **直绘**（路由 `trainingPreferences` 的 `canvas` = `Direct`），画布由 `FtCanvas` 施加；
 * 本文件 px 值 1:1 映射为 dp。无底栏（非 Tab 一级路由）。
 *
 * 版式来源（原型 CSS 行号，实读）：`.st-top` L177-183 · `.st-back` L184-199 · `.st-title` L200 ·
 * `.st-scroll-inner` L205-210 · `.sub-card` L212-217 · `.sub-sec-head/title/meta` L218-220 ·
 * `.pref-group/eyebrow/title/note` L222-226 · `.chip-row/.chip` L227-246 ·
 * 保存钮 `.save-wrap/.save-btn` L248-263 · `.st-foot-note` L265 · `.st-toast` L267-285。
 *
 * 数据与交互（计划 B1/B4）：
 * - 加载：`LaunchedEffect` 读 [TrainingPreferencesService.loadPreferences] → 初始化六组 chip 选中态；
 * - 保存：`scope.launch { PlanAdapter.generateAndEnablePlan(store, prefs) }` → toast
 *   「偏好已保存，本周训练计划已重新生成」/ 失败「保存失败，请重试」；
 * - 返回：顶栏返回键与系统返回一并汇入 [onBack]（直达无栈可退时的兜底在 `FtNavTransitions`）。
 *
 * 背景取 [FtColor.ink0]（同 `SettingsScreen` 口径：原型 `.st-frame` 的径向/线性渐变在工程内统一
 * 去色相为单一深底，见 `FtColor` 头注）。
 */
@Composable
fun TrainingPreferencesScreen(
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val resources = LocalResources.current
    val store = remember { JsonStore(context.appDataStore) }
    val scope = rememberCoroutineScope()

    // 六组 chip 的选中态：键 = 组 key，单选组恒为 0..1 元素集。
    // 首帧用落库模型（`data.service`）的默认值占位，加载后由真源替换。
    var selection by remember {
        mutableStateOf(FtTrainingPreferencesModel.initialSelection(FtTrainingPreferences()))
    }
    var saving by remember { mutableStateOf(false) }
    var toast by remember { mutableStateOf<PrefToastState?>(null) }

    // 原型 `showToast` 的 `setTimeout(…, 1900)`（脚本 L461）
    LaunchedEffect(toast) {
        if (toast != null) {
            delay(1900)
            toast = null
        }
    }

    // 首帧读回上次偏好 → 初始化 chip 选中态（计划 B1「加载」）
    LaunchedEffect(Unit) {
        selection = FtTrainingPreferencesModel.initialSelection(
            TrainingPreferencesService.loadPreferences(store),
        )
    }

    // 系统返回与顶栏返回一致（同 `AccountSyncScreen` 先例）
    BackHandler(enabled = true, onBack = onBack)

    // 保存：偏好落库 + 重新生成并启用本周计划（计划 B4 的编排入口）
    fun save() {
        if (saving) return
        scope.launch {
            saving = true
            val ok = runCatching {
                PlanAdapter.generateAndEnablePlan(
                    context,
                    store,
                    FtTrainingPreferencesModel.toPreferences(selection),
                )
            }.getOrDefault(false)
            saving = false
            toast = PrefToastState.next(
                toast,
                resources.getString(
                    if (ok) FtTrainingPreferencesModel.TOAST_SAVED else FtTrainingPreferencesModel.TOAST_FAILED,
                ),
            )
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(FtColor.ink0),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            PrefTopBar(onBack = onBack)

            // `.st-scroll` L203 → LazyColumn；`.st-scroll-inner { padding: 8px 16px 30px; gap: 14px }`（L205-210）
            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 30.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                items(FtTrainingPreferencesModel.CARDS, key = { it.title }) { card ->
                    PrefCardView(
                        card = card,
                        selection = selection,
                        onChipClick = { group, chipId ->
                            selection = selection + (
                                group.key to FtTrainingPreferencesModel.toggleSelection(
                                    group,
                                    selection[group.key].orEmpty(),
                                    chipId,
                                )
                                )
                        },
                    )
                }
                item { SaveButton(onClick = { save() }) }
                item { FootNote() }
            }
        }

        // `.st-toast { left: 50%; bottom: 30px }`（L267-285）
        PrefToast(
            message = toast?.text,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 30.dp),
        )
    }
}

// ── 顶栏 ──────────────────────────────────────────────────────────────────

/**
 * `.st-top` L177-183：`padding: 50px 16px 12px`、`gap: 10px`；44px 圆形返回键
 * （底 `rgba(255,255,255,.047)` L188 + 描边 `rgba(255,255,255,.08)` L189）+ 居中标题（18px/700 L200）
 * + 44px 对称占位（L201）。
 */
@Composable
private fun PrefTopBar(onBack: () -> Unit) {
    val backA11y = stringResource(FtTrainingPreferencesModel.BACK_A11Y)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            // 直绘画布自屏幕顶起算，故顶距取满 50（同 `SettingsScreen` / `AccountSyncScreen` 口径）
            .padding(start = 16.dp, end = 16.dp, top = 50.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            modifier = Modifier
                .size(44.dp) // `.st-back { width/height: 44px }`（L185-186）
                .clip(FtShape.pill) // `border-radius: 50%`（L187）
                .background(BackBtnFill) // `background: rgba(255,255,255,.047)`（L188）
                .border(1.dp, FtColor.line14, FtShape.pill) // `border: 1px solid rgba(255,255,255,.08)`（L189）
                .semantics { contentDescription = backA11y }
                .clickableNoRipple(onClick = onBack),
            contentAlignment = Alignment.Center,
        ) {
            BackIcon(modifier = Modifier.size(20.dp)) // `.st-back svg { width/height: 20px }`（L197）
        }

        Text(
            text = stringResource(FtTrainingPreferencesModel.TITLE),
            modifier = Modifier.weight(1f), // `.st-title { flex: 1 1 auto }`（L200）
            style = FtType.natural(18f, 700), // 18px / 700（L200）
            color = FtColor.txtHi,
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.width(44.dp)) // `.st-top-spacer { width: 44px }`（L201）
    }
}

// ── 卡片与 chip ───────────────────────────────────────────────────────────

/** `.sub-card` L212-217：圆角 22（L213）、描边 `--line-10`（L214）、底 `rgba(255,255,255,.031)`（L215）、`padding: 16px`（L216）。 */
@Composable
private fun PrefCardView(
    card: FtPrefCard,
    selection: Map<String, Set<String>>,
    onChipClick: (FtPrefGroup, String) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(FtShape.panel) // `border-radius: 22px`（L213）
            .background(CardFill) // `background: rgba(255,255,255,.031)`（L215）
            .border(1.dp, FtColor.line10, FtShape.panel) // `border: 1px solid var(--line-10)`（L214）
            .padding(16.dp), // `padding: 16px`（L216）
    ) {
        // `.sub-sec-head`（L218）：`justify-content: space-between; gap: 12px; margin-bottom: 6px; align-items: baseline`
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 6.dp), // `margin-bottom: 6px`（L218）
            // baseline 在 Compose 无直接等价，取底对齐近似（15px 与 11px 两段文字的基线差 ≤2px）
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = stringResource(card.title),
                modifier = Modifier.weight(1f),
                style = FtType.natural(15f, 700), // `.sub-sec-title` 15px/700（L219）
                color = FtColor.txtHi,
            )
            Text(
                text = stringResource(card.meta),
                style = FtType.natural(11f), // `.sub-sec-meta` 11px（L220）
                color = FtColor.white62,
            )
        }

        card.groups.forEachIndexed { index, group ->
            PrefGroupView(
                group = group,
                selected = selection[group.key].orEmpty(),
                // `.pref-group { margin-top: 16px }`（L222）/ `.pref-group:first-child { margin-top: 0 }`（L223）
                topPadding = if (index == 0) 0.dp else 16.dp,
                onChipClick = onChipClick,
            )
        }
    }
}

/** 一组：`.pref-eyebrow` L224 · `.pref-title` L225 · `.pref-note` L226 · `.chip-row` L227。 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun PrefGroupView(
    group: FtPrefGroup,
    selected: Set<String>,
    topPadding: Dp,
    onChipClick: (FtPrefGroup, String) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = topPadding),
    ) {
        Text(
            text = stringResource(group.eyebrow),
            style = FtType.natural(10.5f, 600), // 10.5px / 600（L224）
            color = FtColor.accent,
        )
        Text(
            text = stringResource(group.title),
            modifier = Modifier.padding(top = 4.dp), // `.pref-title { margin-top: 4px }`（L225）
            style = FtType.natural(14f, 700), // 14px / 700（L225）
            color = FtColor.txtHi,
        )
        group.note?.let { note ->
            Text(
                text = stringResource(note),
                modifier = Modifier.padding(top = 3.dp), // `.pref-note { margin-top: 3px }`（L226）
                style = FtType.natural(11f).copy(lineHeight = 16.5.sp), // 11px / 行高 1.5（L226）
                color = FtColor.white54,
            )
        }
        // `.chip-row { margin-top: 11px; flex-wrap: wrap; gap: 8px }`（L227）——换行语义用 FlowRow 映射
        FlowRow(
            modifier = Modifier.padding(top = 11.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            group.options.forEach { option ->
                PrefChip(
                    label = stringResource(option.label),
                    selected = option.id in selected,
                    onClick = { onChipClick(group, option.id) },
                )
            }
        }
    }
}

/**
 * `.chip` L228-246：圆角 12（L230）、`padding: 9px 14px`（L229）、底 `rgba(255,255,255,.04)`（L231）、
 * 描边 `--line-10`（L232）、色 `--white-70`（L233）、13px/500（L234-235）；
 * `.selected` 底 `rgba(80,236,167,.15)`（L242）/ 描边 `rgba(80,236,167,.45)`（L243）/ 色 `--accent`（L244）/ 600（L245）。
 */
@Composable
private fun PrefChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(FtShape.md) // `border-radius: 12px`（L230）
            .background(if (selected) ChipActiveFill else ChipFill) // 未选 L231 / 选中 L242
            .border(1.dp, if (selected) ChipActiveBorder else FtColor.line10, FtShape.md) // 未选 L232 / 选中 L243
            .clickableNoRipple(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 9.dp), // `padding: 9px 14px`（L229）
    ) {
        Text(
            text = label,
            // `.chip:active { transform: scale(.97) }`（L240）——与同仓筛选 chip（`LibraryScreen.CategoryRow`）
            // 一致，未做按压缩放，保持两处 chip 的交互反馈统一
            style = FtType.natural(13f, if (selected) 600 else 500), // 13px/500（L234-235），选中 600（L245）
            color = if (selected) FtColor.accent else FtColor.white70, // 未选 L233 / 选中 L244
            maxLines = 1,
        )
    }
}

// ── 保存钮与页脚 ──────────────────────────────────────────────────────────

/** `.save-wrap` L248 / `.save-btn` L249-263：全宽、52 高（L251）、圆角 16（L252）、180deg 渐变 `#53E7A5 → #47D994`（L254）、字 15px/700（L256-257）。 */
@Composable
private fun SaveButton(onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale = if (pressed) FtMotion.PRESS_SCALE_CTA else 1f // `.save-btn:active { transform: scale(.985) }`（L263）

    Box(
        modifier = Modifier
            .fillMaxWidth() // `width: 100%`（L250）
            .padding(top = 4.dp) // `.save-wrap { padding-top: 4px }`（L248）
            .height(52.dp) // `height: 52px`（L251）
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(FtShape.xl) // `border-radius: 16px`（L252）
            // `background: linear-gradient(180deg, var(--cta-b), var(--cta-a))`（L254）
            .background(Brush.verticalGradient(listOf(FtColor.ctaB, FtColor.ctaA)))
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = stringResource(FtTrainingPreferencesModel.SAVE_LABEL),
            style = FtType.natural(15f, 700), // `font-size: 15px; font-weight: 700`（L256-257）
            color = FtColor.onAccent, // `color: var(--on-accent)`（L255）
        )
    }
}

/** `.st-foot-note` L265：11px `--white-54`、行高 1.6、居中、`padding: 2px 6px 0`。 */
@Composable
private fun FootNote() {
    Text(
        text = stringResource(FtTrainingPreferencesModel.FOOT_NOTE),
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 6.dp, end = 6.dp, top = 2.dp), // `padding: 2px 6px 0`（L265）
        style = FtType.natural(11f).copy(lineHeight = 17.6.sp), // 11px / 行高 1.6（L265）
        color = FtColor.white54,
        textAlign = TextAlign.Center,
    )
}

// ── 图标 ──────────────────────────────────────────────────────────────────

/** 顶栏返回键的 `#i-back`（symbol L309-311）：`M15.5 5 8.5 12l7 7`，描边 1.8、圆头圆角。 */
@Composable
private fun BackIcon(modifier: Modifier, color: Color = FtColor.white70) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val path = Path().apply {
            moveTo(15.5f * k, 5f * k)
            lineTo(8.5f * k, 12f * k)
            lineTo(15.5f * k, 19f * k)
        }
        drawPath(
            path = path,
            color = color,
            style = Stroke(1.8f * k, cap = StrokeCap.Round, join = StrokeJoin.Round),
        )
    }
}

// ── 浮层提示（形态对齐同仓 `SettingsScreen` / `LibraryScreen` 的 `ScreenToast`） ──

/** `.st-toast` L267-285：底部居中胶囊，180ms 淡入 + 上移 10px；文本 13px（L278）/ `line-height: 1.4`（L279）。 */
@Composable
private fun PrefToast(message: String?, modifier: Modifier = Modifier) {
    var shown by remember { mutableStateOf("") }
    if (message != null && message != shown) {
        shown = message
    }
    // 原型 `translateY(10px)`（L271）：入出场位移固定 10px，须在 Density 作用域内换算为 px
    val slideOffset = with(LocalDensity.current) { 10.dp.roundToPx() }
    AnimatedVisibility(
        visible = message != null,
        modifier = modifier,
        enter = fadeIn(tween(180)) + slideInVertically(tween(180)) { slideOffset },
        exit = fadeOut(tween(180)) + slideOutVertically(tween(180)) { slideOffset },
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 320.dp) // `max-width: 320px`（L272）
                .clip(FtShape.pill) // `border-radius: 999px`（L274）
                .background(ToastFill) // `background: rgba(13,17,23,.94)`（L276）
                .border(1.dp, FtColor.line10, FtShape.pill) // `border: 1px solid rgba(255,255,255,.10)`（L275）
                .padding(horizontal = 16.dp, vertical = 10.dp), // `padding: 10px 16px`（L273）
        ) {
            Text(
                text = shown,
                style = FtType.natural(13f).copy(lineHeight = 18.2.sp), // 13px / 行高 1.4（L278-279）
                color = FtColor.txtHi,
                textAlign = TextAlign.Center,
            )
        }
    }
}

/**
 * 浮层消息的携带序号（对齐 `FtScreens.kt` 的 `AuthToastState` / `SettingsScreen` 的 `SettingsToastState`）。
 *
 * `LaunchedEffect(toast)` 以**实例**为键：同文案连发时若沿用等值实例，键未变则协程不重启、
 * 浮层续不足 1.9 秒。以自增 [seq] 区分每次触发。
 */
private data class PrefToastState(val seq: Int, val text: String) {
    companion object {
        fun next(current: PrefToastState?, text: String): PrefToastState =
            PrefToastState((current?.seq ?: -1) + 1, text)
    }
}

// ── 局部常量 ──────────────────────────────────────────────────────────────

/** 图标 viewBox 边长；按 `size.minDimension / 24` 等比换算（与同仓 `ProfileScreen` 同口径）。 */
private const val ICON_VIEW = 24f

/** `.sub-card` 底 `rgba(255,255,255,.031)`（L215）：AA = round(7.905) = 8 = 0x08 → `0x08FFFFFF`。 */
private val CardFill = Color(0x08FFFFFF)

/** `.st-back` 底 `rgba(255,255,255,.047)`（L188）：AA = round(11.985) = 12 = 0x0C → `0x0CFFFFFF`。 */
private val BackBtnFill = Color(0x0CFFFFFF)

/** `.chip` 底 `rgba(255,255,255,.04)`（L231）：AA = round(10.2) = 10 = 0x0A → `0x0AFFFFFF`。 */
private val ChipFill = Color(0x0AFFFFFF)

/** `.chip.selected` 底 `rgba(80,236,167,.15)`（L242）：AA = round(38.25) = 38 = 0x26 → `0x2650ECA7`。 */
private val ChipActiveFill = Color(0x2650ECA7)

/** `.chip.selected` 描边 `rgba(80,236,167,.45)`（L243）：AA = round(114.75) = 115 = 0x73 → `0x7350ECA7`。 */
private val ChipActiveBorder = Color(0x7350ECA7)

/** `.st-toast` 底 `rgba(13,17,23,.94)`（L276）：AA = round(239.7) = 240 = 0xF0 → `0xF00D1117`。 */
private val ToastFill = Color(0xF00D1117)
