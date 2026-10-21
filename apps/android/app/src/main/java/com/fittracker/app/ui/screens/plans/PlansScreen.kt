package com.fittracker.app.ui.screens.plans

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.PresetPlans
import com.fittracker.app.data.service.TrainingPlanRepository
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import kotlinx.coroutines.delay

/**
 * 计划组屏（原型 `fittracker-plan-detail.html` 的 `screen-plan-detail` 帧，L358-397）。
 *
 * 画布 390×844 直绘，由 `FtCanvas` 施加；本文件 px 值 1:1 映射为 dp。
 * 无底栏（非 Tab 一级路由）——原型此帧的 `.appshell` 内不含 `.tabbar`。
 *
 * 版式来源（原型 CSS 行号）：
 * `.pd-top` L172-186 · `.pd-scroll` L185-190 · `.pd-content` L191 ·
 * `.pg-current*` L193-217 · `.pd-sec-label` L220 · `.pg-card` L222-237 ·
 * `.pg-cover` L239-246 · `.pg-body`/`.pg-name`/`.pg-meta` L247-262 ·
 * `.pg-examples` L263-268 · `.pg-chevron` L269-270 · `.pd-toast` L273-289。
 *
 * 交互：卡片与返回键在原型里被 `ft-stage.js` 的捕获监听改写成**真实导航**
 * （`window.FT_APP.routes`，L474：`.pg-card` → `planGroup`、`#btn-back` → `plan`），
 * 内联的 toast 文案因此不会显示——Android 侧同样按导航实现。
 */
@Composable
fun PlansScreen(
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    vm: PlansViewModel = viewModel(),
) {
    // 状态与装载由 [PlansViewModel] 持有（`viewModel()` 取 NavBackStackEntry 作用域实例）。
    LaunchedEffect(Unit) { vm.load() }

    val currentName = vm.currentName
    val currentMeta = vm.currentMeta

    // 计划组列表（`PlansContent.buildGroupCards`）：预置计划常量映射，无需 IO
    val groups = remember { ftPlanGroupsFromPresets() }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(FtColor.ink0), // `.appshell` 底 var(--ink-0)
    ) {
        PlansTopBar(onBack = onBack)

        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState()), // `.pd-scroll`
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp), // `.pd-content` gap: 20px
            ) {
                CurrentPlanCard(name = currentName, meta = currentMeta)
                PlanGroupListSection(
                    groups = groups,
                    // 携带 planId 查询参数——详情页据此取真实预设计划数据
                    // （对齐鸿蒙 `PlansContent.ets:317-321` 的 `pushUrl(params:{planId})`）。
                    // 复用同仓 `LegalDocScreen` 的查询串约定（`legal?kind=...`）。
                    onOpen = { planId -> onNavigate("planGroup?planId=$planId") },
                )
            }
        }
    }
}

/** `.pd-top` L172-186：52/12/10 内边距、40px 返回键、居中标题、右侧同宽占位。 */
@Composable
private fun PlansTopBar(onBack: () -> Unit) {
    // `stringResource` 只能在 @Composable 上下文调用，`.semantics {}` lambda 不是——先解析再闭包捕获
    val backA11y = stringResource(R.string.plans_a11y_back)
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
                .size(40.dp)
                .clip(RoundedCornerShape(12.dp))
                // 无障碍标签逐字取自原型 `.pd-back` 的 aria-label（L367）
                .semantics { contentDescription = backA11y }
                .clickableNoRipple(onClick = onBack),
            contentAlignment = Alignment.Center,
        ) {
            ChevronLeftIcon(modifier = Modifier.size(22.dp), color = FtColor.white70)
        }
        Box(
            modifier = Modifier.weight(1f),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = stringResource(R.string.plans_title),
                style = natural(16f, 700),
                color = FtColor.txtHi,
            )
        }
        Box(modifier = Modifier.size(40.dp)) // `.pd-top-spacer`
    }
}

/** `.pg-current` L193-217：当前使用中的计划摘要卡，右上角带「当前使用」胶囊（空态对齐鸿蒙 `PlansContent.currentCard`）。 */
@Composable
private fun CurrentPlanCard(name: String?, meta: String?) {
    val hasPlan = name != null
    val shape = RoundedCornerShape(20.dp)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            // 原型卡阴影 `0 14px 28px rgba(0,0,0,.2)` 在深色底剖面上不可辨（参照渲染无暗带）；
            // elevation 阴影会产生可测暗带（home 判例）——按原型剖面移除
            .clip(shape)
            .background(CurrentFill)
            .border(1.dp, FtColor.accent40, shape)
            .padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 15.dp),
    ) {
        Column {
            Text(
                text = stringResource(R.string.plans_current_label),
                style = natural(11f, 700).copy(letterSpacing = 0.33.sp), // .03em × 11px
                color = FtColor.accent,
            )
            Text(
                text = name ?: stringResource(R.string.plans_current_empty_name),
                modifier = Modifier
                    .padding(top = 9.dp, end = 76.dp) // `.pg-current-name` padding-right: 76px
                    .fillMaxWidth(),
                color = FtColor.txtHi,
                fontSize = 20.sp,
                lineHeight = 23.sp, // 1.15 × 20px（原型显式声明）
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = meta ?: stringResource(R.string.plans_current_empty_meta),
                modifier = Modifier.padding(top = 6.dp),
                style = natural(12f),
                color = FtColor.white62,
            )
        }
        // 「当前使用」胶囊仅在有当前计划时显示（对齐 `PlansContent.currentCard` 的 hasCurrentPlan 分支）
        if (hasPlan) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 14.dp, end = 14.dp)
                    .clip(FtShape.pill)
                    .background(FtColor.accent)
                    .padding(horizontal = 10.dp, vertical = 4.dp),
            ) {
                Text(
                    text = stringResource(R.string.plans_current_badge),
                    style = natural(10f, 700),
                    color = FtColor.onAccent,
                )
            }
        }
    }
}

/** 计划组清单区（原型 `section[data-od-id=plan-groups-list]` L385-390）。 */
@Composable
private fun PlanGroupListSection(groups: List<FtPlanGroup>, onOpen: (String) -> Unit) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            // 顶栏标题与本小节标题在原型中逐字同为「计划组」——复用同一资源
            text = stringResource(R.string.plans_title),
            style = natural(16f, 700).copy(letterSpacing = 0.32.sp), // .02em × 16px
            color = FtColor.white54,
        )
        Column(
            modifier = Modifier.padding(top = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp), // `.pg-list` gap: 10px
        ) {
            groups.forEach { group ->
                PlanGroupCard(group = group, onClick = { onOpen(group.planId) })
            }
        }
    }
}

/** `.pg-card` L222-270：52 图标底 + 名称/元信息/示例 + 右箭头。 */
@Composable
private fun PlanGroupCard(
    group: FtPlanGroup,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(18.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 92.dp)
            .clip(shape)
            .background(GroupCardFill)
            .border(1.dp, FtColor.line14, shape)
            .clickableNoRipple(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(13.dp),
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(FtColor.accent10)
                .border(1.dp, CoverBorder, RoundedCornerShape(14.dp)),
            contentAlignment = Alignment.Center,
        ) {
            GroupIcon(kind = group.icon, modifier = Modifier.size(24.dp), color = FtColor.accent)
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(5.dp), // `.pg-body` gap: 5px
        ) {
            Text(
                text = group.name,
                style = natural(16f, 700),
                color = FtColor.txtHi,
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp), // `.pg-meta` gap: 4px 8px
            ) {
                Box(
                    modifier = Modifier
                        .clip(FtShape.pill)
                        .background(FtColor.glass6)
                        .border(1.dp, FtColor.hairline, FtShape.pill)
                        .padding(horizontal = 9.dp, vertical = 3.dp),
                ) {
                    Text(
                        text = group.audience,
                        style = natural(11f),
                        color = FtColor.white62,
                    )
                }
                Text(
                    text = group.freq,
                    style = natural(11f),
                    color = FtColor.white54,
                )
                Text(
                    text = stringResource(R.string.plans_group_days, group.days),
                    style = natural(11f, 400, FtType.num),
                    color = FtColor.white54,
                )
            }
            Text(
                text = stringResource(R.string.plans_group_examples, group.examples),
                style = natural(11f),
                color = FtColor.white54,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        ChevronRightIcon(modifier = Modifier.size(20.dp), color = FtColor.white40)
    }
}

// ── 数据 ────────────────────────────────────────────────────────────────────

/** 计划组图标种类（原型 `GROUPS[].icon` 指向的 `<symbol>`）。 */
enum class FtPlanGroupIcon { Layers, Activity, Target, Dumbbell }

/**
 * 一条计划组（原型 `GROUPS`，L404-409）。
 *
 * 文案字段为**已解析字符串**：屏内实际数据由 [ftPlanGroupsFromPresets] 从 `PresetPlans` 取
 * （运行期数据，同 `FtSettingTrailing.Value` 的策略——数据层文案不在本域提取）；
 * 原型静态基线 [FtPlanGroups.all] 先经 `stringResource` 解析再落入本类型。
 */
data class FtPlanGroup(
    /**
     * 预设计划 id（`PresetPlan.id`，如 `preset_ppl`）——详情页据此取真实数据。
     * 静态基线 [FtPlanGroups.all] 无 id（占位空串），屏内实际数据由
     * [ftPlanGroupsFromPresets] 填充，故运行时恒非空。
     */
    val planId: String,
    val name: String,
    val audience: String,
    val freq: String,
    val days: Int,
    val icon: FtPlanGroupIcon,
    val examples: String,
)

/**
 * 原型 `GROUPS` 四条，逐字移植（静态基线，**当前未被引用**——屏内实际取 [ftPlanGroupsFromPresets]）。
 *
 * 文案不落模型层：中文真源在 `values/strings_plans.xml`（前缀 `plans_baseline_`），
 * 由 [all] 在 @Composable 上下文用 `stringResource` 解析。
 */
object FtPlanGroups {
    @Composable
    fun all(): List<FtPlanGroup> = listOf(
        FtPlanGroup(
            planId = "preset_upper_lower",
            name = stringResource(R.string.plans_baseline_upper_lower_name),
            audience = stringResource(R.string.plans_baseline_audience_beginner),
            freq = stringResource(R.string.plans_baseline_freq_4days),
            days = 4,
            icon = FtPlanGroupIcon.Layers,
            examples = stringResource(R.string.plans_baseline_upper_lower_examples),
        ),
        FtPlanGroup(
            planId = "preset_ppl",
            name = stringResource(R.string.plans_baseline_ppl_name),
            audience = stringResource(R.string.plans_baseline_audience_all_levels),
            freq = stringResource(R.string.plans_baseline_freq_3to6days),
            days = 3,
            icon = FtPlanGroupIcon.Activity,
            examples = stringResource(R.string.plans_baseline_ppl_examples),
        ),
        FtPlanGroup(
            planId = "preset_split_4",
            name = stringResource(R.string.plans_baseline_split4_name),
            audience = stringResource(R.string.plans_baseline_audience_advanced),
            freq = stringResource(R.string.plans_baseline_freq_4days),
            days = 4,
            icon = FtPlanGroupIcon.Target,
            examples = stringResource(R.string.plans_baseline_split4_examples),
        ),
        FtPlanGroup(
            planId = "preset_bro_split",
            name = stringResource(R.string.plans_baseline_split5_name),
            audience = stringResource(R.string.plans_baseline_audience_advanced),
            freq = stringResource(R.string.plans_baseline_freq_5days),
            days = 5,
            icon = FtPlanGroupIcon.Dumbbell,
            examples = stringResource(R.string.plans_baseline_split5_examples),
        ),
    )
}

/**
 * 预置计划 → 计划组卡（对齐鸿蒙 `PlansContent.buildGroupCards` / `iconForPlan` / `buildExamples`
 * ——示例取首日前 3 个动作名）。
 */
fun ftPlanGroupsFromPresets(): List<FtPlanGroup> = PresetPlans.ALL.map { plan ->
    FtPlanGroup(
        planId = plan.id,
        name = plan.name,
        audience = plan.targetAudience,
        freq = plan.weeklyFrequency,
        days = plan.days.size,
        icon = when (plan.id) {
            "preset_upper_lower" -> FtPlanGroupIcon.Layers
            "preset_ppl" -> FtPlanGroupIcon.Activity
            "preset_split_4" -> FtPlanGroupIcon.Target
            "preset_bro_split" -> FtPlanGroupIcon.Dumbbell
            else -> FtPlanGroupIcon.Layers
        },
        examples = plan.days.firstOrNull()
            ?.exercises
            ?.take(3)
            ?.joinToString(" · ") { it.name }
            ?: "",
    )
}

// ── 图标 ────────────────────────────────────────────────────────────────────
//
// 全部由 Canvas 手绘，路径逐字取自本文件的 `<symbol>` 定义（L300-341）。
//
// ⚠️ 这几个**不能复用** `ui/components/FtIcons.kt` 的同名图标：原型的 `<symbol>`
// 是**逐文件定义**的，同名不同形——例如本文件的 `#i-activity` 是单笔脉冲线
// `M3 12h4l2.5-7 4 14 2.5-7H21`，而 `fittracker-welcome-home.html` 的 `#i-activity`
// 是「折线柱 + 脉冲」两笔（共享件实现的是后者）；`#i-dumbbell` 同理
// （本文件 `M7 7v10M17 7v10M7 12h10M3.5 9v6M20.5 9v6`，描边 2，与共享件的坐标/线宽均不同）。

private const val ICON_VIEW = 24f

private fun DrawScope.strokeLine(
    color: Color,
    x1: Float, y1: Float, x2: Float, y2: Float,
    width: Float,
) {
    drawLine(color, Offset(x1, y1), Offset(x2, y2), strokeWidth = width, cap = StrokeCap.Round)
}

/** 返回（原型 `#i-chevron-left`，L300-302）：`M15 5l-7 7 7 7`，描边 2、圆头圆角。 */
@Composable
fun ChevronLeftIcon(modifier: Modifier = Modifier, color: Color = FtColor.white70) {
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

/** 卡片右箭头（原型 `#i-chevron-right`，L303-305）：`M9 5l7 7-7 7`。 */
@Composable
private fun ChevronRightIcon(modifier: Modifier = Modifier, color: Color = Color.Unspecified) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val p = Path().apply {
            moveTo(9f * k, 5f * k)
            lineTo(16f * k, 12f * k)
            lineTo(9f * k, 19f * k)
        }
        drawPath(p, color, style = Stroke(2f * k, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

/** 按种类绘制计划组封面图标。 */
@Composable
private fun GroupIcon(kind: FtPlanGroupIcon, modifier: Modifier = Modifier, color: Color) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        when (kind) {
            // `#i-layers` L309-313：三层，描边 1.8、圆角 join
            FtPlanGroupIcon.Layers -> {
                val stroke = Stroke(1.8f * k, join = StrokeJoin.Round)
                val top = Path().apply {
                    moveTo(12f * k, 3f * k)
                    lineTo(3f * k, 8f * k)
                    lineTo(12f * k, 13f * k)
                    lineTo(21f * k, 8f * k)
                    close()
                }
                drawPath(top, color, style = stroke)
                listOf(12f, 16f).forEach { y ->
                    val line = Path().apply {
                        moveTo(3f * k, y * k)
                        lineTo(12f * k, (y + 5f) * k)
                        lineTo(21f * k, y * k)
                    }
                    drawPath(line, color, style = stroke)
                }
            }
            // `#i-activity` L317-319：单笔脉冲线
            FtPlanGroupIcon.Activity -> {
                val p = Path().apply {
                    moveTo(3f * k, 12f * k)
                    lineTo(7f * k, 12f * k)
                    lineTo(9.5f * k, 5f * k)
                    lineTo(13.5f * k, 19f * k)
                    lineTo(16f * k, 12f * k)
                    lineTo(21f * k, 12f * k)
                }
                drawPath(p, color, style = Stroke(2f * k, cap = StrokeCap.Round, join = StrokeJoin.Round))
            }
            // `#i-target` L330-334：双环 r8 / r3 + 实心 r0.6
            FtPlanGroupIcon.Target -> {
                val c = Offset(12f * k, 12f * k)
                drawCircle(color, radius = 8f * k, center = c, style = Stroke(1.8f * k))
                drawCircle(color, radius = 3f * k, center = c, style = Stroke(1.8f * k))
                drawCircle(color, radius = 0.6f * k, center = c)
            }
            // `#i-dumbbell` L306-308：五笔，描边 2
            FtPlanGroupIcon.Dumbbell -> {
                val w = 2f * k
                strokeLine(color, 7f * k, 7f * k, 7f * k, 17f * k, w)
                strokeLine(color, 17f * k, 7f * k, 17f * k, 17f * k, w)
                strokeLine(color, 7f * k, 12f * k, 17f * k, 12f * k, w)
                strokeLine(color, 3.5f * k, 9f * k, 3.5f * k, 15f * k, w)
                strokeLine(color, 20.5f * k, 9f * k, 20.5f * k, 15f * k, w)
            }
        }
    }
}

// ── 屏内工具 ────────────────────────────────────────────────────────────────

/**
 * 原型**未声明** `line-height` 的文本样式，即 CSS 的 `normal`（字体自然行高）。
 *
 * 不能套用 [FtType.ft] 的缺省 `1.4 × size`——那个刻度化默认值会让每行多出 2–4px，
 * 十余处叠加即累积成整屏下移（登录屏实测曾达 29px）。原型显式声明行高处
 * （`.pg-current-name` 1.15）仍按字面值给定。
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

// ── 屏内色值（原型 `:root` 无对应令牌，按 FtColorUtil 规则就地换算） ──
//
// 换算规则 AA = round(alpha × 255)

/** `.pd-top` 底 `rgba(10,13,18,.96)` → round(244.8) = 245 = 0xF5 */
private val TopBarFill = Color(0xF50A0D12)

/** `.pg-current` 底 `rgba(80,236,167,.08)` → round(20.4) = 20 = 0x14 */
private val CurrentFill = Color(0x1450ECA7)

/** `.pg-card` 底 `#151B20` */
private val GroupCardFill = Color(0xFF151B20)

/** `.pg-cover` 描边 `rgba(80,236,167,.22)` → round(56.1) = 56 = 0x38 */
private val CoverBorder = Color(0x3850ECA7)
