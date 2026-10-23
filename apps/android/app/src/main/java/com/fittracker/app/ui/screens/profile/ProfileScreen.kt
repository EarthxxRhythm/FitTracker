package com.fittracker.app.ui.screens.profile

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
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.WeightUnit
import com.fittracker.app.data.service.WeightUtils
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.WeekWindow
import com.fittracker.app.data.service.currentLanguageTag
import com.fittracker.app.data.service.WorkoutRepository
import com.fittracker.app.data.service.WorkoutSessionService
import com.fittracker.app.data.service.stats.PersonalRecordService
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import java.util.Calendar

/**
 * 个人页（「我的」）——原型 `design/06_prototype_redraw/src/fittracker-personal.html`
 * 的 `screen-personal` 帧内 `pane-profile`（L1366-1455）。
 *
 * 画布 390×844 **直绘**（`FtRoutes` 中 profile 条目的 `canvas = FtCanvasKind.Direct`），
 * 由 `FtCanvas` 施加；本文件内所有 px 值 1:1 映射为 dp，屏内不做任何手写缩放。
 * 底部 tabbar 由壳层 `FtApp` 提供（`fittracker-personal.html:1458-1474` 的 `.tabbar`），**不属于本屏**。
 *
 * 版式来源（原型 CSS 行号）：
 * `.appshell` L203-207 · `.viewport` L209-215 · `.pane-scroll` L223-224 · `.profile-content` L227-232 ·
 * `.p-head` L234-238 · `.avatar` L240-253 · `.p-id`/`.p-name`/`.p-sub` L255-257 · `.p-settings` L259-278 ·
 * `.card` L280-285 · `.card.focus` L286-292 · `.card-head`/`.card-title`/`.card-meta` L294-314 ·
 * `.focus-*` L315-342 · `.focus-meta*` L343-359 · `.streak-*` L361-389 ·
 * `.achievement*` L390-421 · `.shortcuts`/`.shortcut`/`.sc-*` L423-446 ·
 * 末尾覆盖层「Card Surface v1」L1229-1232。
 *
 * 两处**以源码末尾规则为准**的取舍：
 * 1. 样式表末尾「Card Surface v1」（L1229-1232）把 `.card` 与 `.card.focus` 的底色统一改写为
 *    `rgba(255,255,255,.031)`、描边统一为 `--line-10`——覆盖了 L286-291 里 `.card.focus` 的翡翠
 *    强调底（`rgba(80,236,167,.06)`）与 `rgba(80,236,167,.22)` 描边。本实现按**末尾**规则。
 *    （`.card.focus` 的 `box-shadow`（L290）未被覆盖，保留。）
 * 2. `.profile-content` 的 `gap: 16px`（L231）直接映射为 `verticalArrangement = Arrangement.spacedBy(16.dp)`，
 *    与 `contentPadding` 的四边内边距（L228）叠加后，与原型「四块之间各 16、四周 53/16/30」完全一致。
 *
 * 滚动：原型的滚动容器 `.pane-scroll { overflow-y: auto }`（L223）转为 `LazyColumn`。
 *
 * 交互（原型脚本 L1767-1769）：设置钮 → `settings`、身体数据 → `body`、动作库 → `library`。
 * 三者一律只发导航语义，屏内不驻留子页——子页（`subpage-body` / `subpage-library` /
 * `subpage-settings`，L1478-1659）在原型里是 `.subpage-layer` 上的独立整屏，属别的路由。
 */
@Composable
fun ProfileScreen(
    onNavigate: (String) -> Unit,
    modifier: Modifier = Modifier,
    vm: ProfileViewModel = viewModel(),
) {
    // 状态与装载由 [ProfileViewModel] 持有——`viewModel()` 取 NavBackStackEntry 作用域实例，
    // tab 切换（`saveState=true`）取回同一实例：首帧即真数据、装载只跑一次。
    // 首帧不用原型样例（「林默」/「增肌第 42 天」）——68e797f 已把初值收口为空态占位，
    // 迁移后由 VM 保有同样语义（见 ProfileViewModel 状态字段注释）。
    LaunchedEffect(Unit) { vm.load() }

    val name = vm.name
    val avatarInitial = vm.avatarInitial
    val avatarKey = vm.avatarKey
    val weekValue = vm.weekValue
    val weekSessions = vm.weekSessions
    val achievements = vm.achievements
    val weekRangeText = vm.weekRangeText
    val weightUnit = vm.weightUnit

    // 入场：头部 → 本周概览 → 最近成就 → 快捷入口 逐层落位（错峰 40ms）。
    var entered by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { entered = true }
    val headIn by animateFloatAsState(
        targetValue = if (entered) 1f else 0f,
        animationSpec = tween(FtMotion.DURATION_ENTER, easing = FtMotion.EASE_ENTER),
        label = "profile-head-in",
    )
    val weekIn by animateFloatAsState(
        targetValue = if (entered) 1f else 0f,
        animationSpec = tween(
            FtMotion.DURATION_ENTER,
            delayMillis = FtMotion.DURATION_STAGGER,
            easing = FtMotion.EASE_ENTER,
        ),
        label = "profile-week-in",
    )
    val achIn by animateFloatAsState(
        targetValue = if (entered) 1f else 0f,
        animationSpec = tween(
            FtMotion.DURATION_ENTER,
            delayMillis = FtMotion.DURATION_STAGGER * 2,
            easing = FtMotion.EASE_ENTER,
        ),
        label = "profile-ach-in",
    )
    val shortcutIn by animateFloatAsState(
        targetValue = if (entered) 1f else 0f,
        animationSpec = tween(
            FtMotion.DURATION_ENTER,
            delayMillis = FtMotion.DURATION_STAGGER * 3,
            easing = FtMotion.EASE_ENTER,
        ),
        label = "profile-shortcut-in",
    )

    // 内容自适应 + 可滚动（内容不足一屏时无滚动行为）：卡片按内容定高，
    // 富余高度留在页面底部，不再用 weight 把空白塞进卡片内部。
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .background(FtColor.ink0) // `.appshell` 底 var(--ink-0) = #0B0F13（L206）
            // `.profile-content { padding: 53px 16px 30px }`（L228）
            .padding(start = 16.dp, end = 16.dp, top = 44.dp, bottom = 14.dp), // 压缩进单屏：53/30 → 44/14
        // `.profile-content { gap: 16px }`（L231）
        verticalArrangement = Arrangement.spacedBy(10.dp), // 压缩：16 → 10
    ) {
        ProfileHead(
            name = name,
            avatarInitial = avatarInitial,
            avatarKey = avatarKey,
            onNavigate = onNavigate,
            modifier = Modifier.enterFromBelow(headIn),
        )
        WeekOverviewCard(
            value = weekValue,
            sessions = weekSessions,
            rangeText = weekRangeText,
            modifier = Modifier.enterFromBelow(weekIn),
        )
        // 「训练连续记录」卡已按需求移除——连续天数仍由成就卡的「稳定输出」派生消费。
        AchievementsCard(
            achievements = achievements,
            weightUnit = weightUnit,
            modifier = Modifier.enterFromBelow(achIn),
        )
        Shortcuts(onNavigate = onNavigate, modifier = Modifier.enterFromBelow(shortcutIn))
    }
}

// ── 头部 ─────────────────────────────────────────────────────────────────

/** 入场效果：透明度 0→1 叠加 8dp 上移落位。 */
private fun Modifier.enterFromBelow(progress: Float): Modifier = this.graphicsLayer {
    alpha = progress
    translationY = 8.dp.toPx() * (1f - progress)
}

/**
 * `.p-head` L234-238：`display:flex; align-items:center; gap:12px`。
 * 头像（L240-253）+ 身份块（L255-257）+ 设置钮（L259-278）。
 */
@Composable
private fun ProfileHead(
    name: String,
    avatarInitial: String,
    avatarKey: String,
    onNavigate: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val tint = avatarTintOf(avatarKey)
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically, // align-items: center（L236）
        horizontalArrangement = Arrangement.spacedBy(12.dp), // gap: 12px（L237）
    ) {
        // 头像 + 身份块整体可点击 → 资料编辑页（只点小头像不好发现）。
        Row(
            modifier = Modifier
                .weight(1f)
                .clip(ProfileHeadShape)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = { onNavigate(FtProfileModel.EDIT_ROUTE) },
                ),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // `.avatar` L240-253：52×52、50% 圆、色键底色 + 同色系描边、前景同色系高亮
            Box(
                modifier = Modifier
                    .requiredSize(52.dp)
                    .clip(CircleShape)
                    .background(tint.bg)
                    .border(1.dp, tint.border, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = avatarInitial,
                    style = FtType.natural(22f, 700, FtType.num), // 原型 font-num 22px/700（L248-250）
                    color = tint.fg,
                )
            }

            Column(modifier = Modifier.weight(1f)) { // `.p-id { flex: 1 1 auto }`（L255）
                Text(
                    text = name,
                    color = FtColor.txtHi,
                    fontSize = 21.sp,
                    lineHeight = 25.2.sp, // line-height: 1.2（L256）
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = stringResource(FtProfileModel.SUB_NONE_RES),
                    modifier = Modifier.padding(top = 4.dp), // `.p-sub { margin-top: 4px }`（L257）
                    style = FtType.natural(12.5f), // 12.5px，原型未声明 line-height
                    color = FtColor.white62,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        EditChip(onClick = { onNavigate(FtProfileModel.EDIT_ROUTE) })
        SettingsButton(onClick = { onNavigate(FtProfileModel.SETTINGS_ROUTE) })
    }
}

/** 资料编辑入口（设计侧新增）：32dp 文字胶囊，按压 `scale(.96)` 与设置钮同语汇。 */
@Composable
private fun EditChip(onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale = if (pressed) PRESS_SCALE_SETTINGS else 1f
    Box(
        modifier = Modifier
            .height(32.dp)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(FtShape.pill)
            .background(EditChipFill)
            .border(1.dp, FtColor.line10, FtShape.pill)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .padding(horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = stringResource(R.string.profile_edit_entry),
            style = FtType.natural(12f, 600),
            color = FtColor.white70,
        )
    }
}

/**
 * `.p-settings` L259-278：44×44 圆形（L260-261）、底 `rgba(255,255,255,.047)`（L263）、
 * 1px `rgba(255,255,255,.08)` 描边（L264）、图标 20×20（L272）、按压 `scale(.96)`（L278）。
 */
@Composable
private fun SettingsButton(onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale = if (pressed) PRESS_SCALE_SETTINGS else 1f // `.p-settings:active { transform: scale(.96) }`（L278）
    // `.p-settings` 的 `aria-label`——`.semantics` 非 Composable 作用域，先在屏内取用
    val a11yLabel = stringResource(FtProfileModel.SETTINGS_A11Y_RES)

    Box(
        modifier = Modifier
            .requiredSize(44.dp)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(CircleShape)
            .background(IconButtonFill)
            .border(1.dp, FtColor.glass8, CircleShape)
            .semantics { contentDescription = a11yLabel }
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        SettingsIcon(modifier = Modifier.size(20.dp), color = FtColor.white70) // svg 20×20（L272）
    }
}

// ── 本周概览 ──────────────────────────────────────────────────────────────

/**
 * `.card.focus` L286-292 + 末尾覆盖层 L1232：圆角 28（L287）、底 `rgba(255,255,255,.031)`、
 * 描边 `--line-10`、`padding: 18px`（L291）、`box-shadow: 0 20px 40px rgba(0,0,0,.22)`（L290）。
 */
@Composable
private fun WeekOverviewCard(
    value: String,
    sessions: String,
    rangeText: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            // 原型卡阴影 `0 20px 40px rgba(0,0,0,.22)`（L290）在深色底剖面上不可辨（参照渲染无暗带）；
            // elevation 阴影会产生可测暗带（home 判例）——按原型剖面移除
            .clip(FocusShape)
            .background(CardFill) // 末尾覆盖层 L1229-1232：rgba(255,255,255,.031)
            .border(1.dp, FtColor.line10, FocusShape)
            .padding(14.dp), // `.card.focus { padding: 18px }`（L291）——压缩 18 → 14
        // 弹性撑满：卡片被拉伸时多出的高度摊到内部各组之间，而不是堆在卡片末尾。
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        // `.card-head` L294-300：baseline 对齐（L296）、两端分布（L297）、下间距 14（L299）
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 10.dp), // `margin-bottom: 14px`（L299）——压缩 14 → 10
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = stringResource(FtProfileModel.WEEK_TITLE_RES),
                modifier = Modifier.alignByBaseline(),
                color = FtColor.txtHi,
                fontSize = 17.sp,
                lineHeight = 20.4.sp, // `.card-title` line-height: 1.2（L306）
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = rangeText,
                modifier = Modifier.alignByBaseline(),
                style = FtType.natural(11f), // `.card-meta` 11px，未声明 line-height（L310）
                color = FtColor.white62,
            )
        }

        // `.focus-hero` L315-320：baseline 对齐（L317）、gap 8（L318）、上间距 2（L319）
        Row(
            modifier = Modifier.padding(top = 2.dp), // `margin-top: 2px`（L319）
            horizontalArrangement = Arrangement.spacedBy(8.dp), // gap: 8px（L318）
        ) {
            Text(
                text = value,
                modifier = Modifier.alignByBaseline(),
                color = FtColor.accent,
                fontFamily = FtType.num, // 原型 font-num（L322）
                fontSize = 48.sp,
                lineHeight = 48.sp, // line-height: 1（L325）
                fontWeight = FontWeight.Bold,
                letterSpacing = (-0.96).sp, // letter-spacing: -.02em × 48px（L326）
            )
            Text(
                text = stringResource(FtProfileModel.WEEK_UNIT_RES),
                modifier = Modifier.alignByBaseline(),
                style = FtType.natural(16f), // `.focus-hero-unit` 16px，未声明 line-height（L329-331）
                color = FtColor.white62,
            )
        }

        Text(
            text = stringResource(FtProfileModel.WEEK_LABEL_RES),
            modifier = Modifier.padding(top = 8.dp), // `margin-top: 8px`（L334）
            style = FtType.natural(12f), // `.focus-hero-label` 12px，未声明 line-height（L335）
            color = FtColor.white54,
        )

        // `.focus-divider { height:1px; background:var(--hairline); margin:15px 0 13px }`（L338-342）
        Box(
            modifier = Modifier
                .padding(top = 10.dp, bottom = 9.dp) // `margin: 15px 0 13px`（L341）——压缩 15/13 → 10/9
                .fillMaxWidth()
                .height(1.dp) // `height: 1px`（L339）
                .background(FtColor.hairline),
        )

        // `.focus-meta-row { display:flex; gap:12px }`（L343）
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val metrics = listOf(
                FtProfileModel.WEEK_METRICS[0].copy(value = sessions),
            )
            metrics.forEach { metric ->
                FocusMetric(metric = metric, modifier = Modifier.weight(1f)) // `.focus-meta { flex:1 1 0 }`（L345）
            }
        }
    }
}

/** `.focus-meta` L344-350 + `.fm-label`/`.fm-value`/`.fm-unit` L351-359：纵向 gap 4（L349）。 */
@Composable
private fun FocusMetric(metric: FtProfileMetric, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(4.dp), // gap: 4px（L349）
    ) {
        Text(
            text = stringResource(metric.labelRes),
            style = FtType.natural(10.5f), // `.fm-label` 10.5px，未声明 line-height（L351）
            color = FtColor.white62,
        )
        Text(
            text = metric.value,
            color = FtColor.txtHi,
            fontFamily = FtType.num, // 原型 font-num（L353）
            fontSize = 20.sp,
            lineHeight = 20.sp, // line-height: 1（L356）
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = stringResource(metric.unitRes),
            style = FtType.natural(10.5f), // `.fm-unit` 10.5px，未声明 line-height（L359）
            color = FtColor.white62,
        )
    }
}

// ── 最近成就 ──────────────────────────────────────────────────────────────

/** `.card` L280-285（同 [StreakCard] 的底/描边）+ `.achievements-title`（L390）`.card-title` 字号。 */
@Composable
private fun AchievementsCard(
    achievements: List<FtProfileAchievement>,
    weightUnit: WeightUnit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(FtShape.panel)
            .background(CardFill)
            .border(1.dp, FtColor.line10, FtShape.panel)
            .padding(12.dp), // 压缩：16 → 12
        // 弹性撑满：多出的高度摊到标题与各成就行之间。
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = stringResource(FtProfileModel.ACHIEVEMENTS_TITLE_RES),
            modifier = Modifier.padding(bottom = 8.dp), // `.achievements-title { margin-bottom: 12px }`（L390）——压缩 12 → 8
            color = FtColor.txtHi,
            fontSize = 17.sp,
            lineHeight = 20.4.sp, // `.card-title` line-height: 1.2（L306）
            fontWeight = FontWeight.Bold,
        )

        if (achievements.isEmpty()) {
            Text(
                text = stringResource(R.string.profile_achievements_empty), // 无数据空态（不再显示原型样例）
                modifier = Modifier.padding(top = 5.dp, bottom = 5.dp),
                style = FtType.natural(12f),
                color = FtColor.white62,
            )
        }
        achievements.forEachIndexed { index, achievement ->
            if (index > 0) {
                // `.achievement + .achievement { border-top:1px solid var(--hairline)(L398); margin-top:2px(L399) }`
                Box(
                    modifier = Modifier
                        .padding(top = 2.dp)
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(FtColor.hairline),
                )
            }
            AchievementRow(
                achievement = achievement,
                weightUnit = weightUnit,
                // `.achievement { padding: 7px 0 }`（L395）；后继项 `padding-top: 11px`（L400）
                modifier = Modifier.padding(top = if (index == 0) 5.dp else 8.dp, bottom = 5.dp), // 压缩：7/11/7 → 5/8/5
            )
        }
    }
}

/** `.achievement` L391-421：图标底 40×40 圆角 13 + 标题/注 + 右对齐数值，行距 12（L394）、居中对齐（L393）。 */
@Composable
private fun AchievementRow(
    achievement: FtProfileAchievement,
    weightUnit: WeightUnit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically, // align-items: center（L393）
        horizontalArrangement = Arrangement.spacedBy(12.dp), // gap: 12px（L394）
    ) {
        // `.ach-ic` L402-412：40×40、圆角 13、accent-10 底 / accent 字；`.gold` 走 gold-12 / gold（L417-421）
        Box(
            modifier = Modifier
                .requiredSize(40.dp)
                .clip(RoundedCornerShape(13.dp))
                .background(if (achievement.gold) FtColor.gold12 else FtColor.accent10),
            contentAlignment = Alignment.Center,
        ) {
            ProfileIcon(
                kind = achievement.icon,
                modifier = Modifier.size(20.dp), // `.ach-ic svg { 20×20 }`（L412）
                color = if (achievement.gold) FtColor.gold else FtColor.accent,
            )
        }

        Column(modifier = Modifier.weight(1f)) { // `.ach-id { flex: 1 1 auto }`（L413）
            Text(
                text = achievement.titleText ?: stringResource(achievement.titleRes),
                style = FtType.natural(14f, 700), // `.ach-title` 14px/700，未声明 line-height（L414）
                color = FtColor.txtHi,
            )
            Text(
                text = achievement.noteText ?: achievement.weightKgParam?.let { kg ->
                    stringResource(
                        achievement.noteRes,
                        WeightUtils.formatWeight(kg.toDouble(), weightUnit) + " " + WeightUtils.unitLabel(weightUnit),
                    )
                } ?: achievement.streakDaysParam?.let { days ->
                    stringResource(achievement.noteRes, days)
                } ?: stringResource(achievement.noteRes),
                modifier = Modifier.padding(top = 3.dp), // `.ach-note { margin-top: 3px }`（L415）
                style = FtType.natural(12f), // 12px，未声明 line-height（L415）
                color = FtColor.white62,
            )
        }

        Text(
            text = achievement.valueText ?: achievement.weekSessionsParam?.let { count ->
                stringResource(achievement.valueRes, count)
            } ?: stringResource(achievement.valueRes),
            style = FtType.natural(11f), // `.ach-value` 11px，未声明 line-height（L416）
            color = if (achievement.gold) FtColor.gold else FtColor.accent, // L416 / L421
            textAlign = TextAlign.End, // `text-align: right`（L416）
        )
    }
}

// ── 快捷入口 ──────────────────────────────────────────────────────────────

/** `.shortcuts { display:flex; gap:8px }`（L423）。 */
@Composable
private fun Shortcuts(onNavigate: (String) -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        FtProfileModel.SHORTCUTS.forEach { shortcut ->
            ShortcutButton(
                shortcut = shortcut,
                // 弹性撑满：卡片被拉伸时按钮一起长高（fillMaxHeight），空白不落在卡片内。
                modifier = Modifier.weight(1f).fillMaxHeight(), // `.shortcut { flex:1 1 0 }`（L425）
                onClick = { onNavigate(shortcut.route) },
            )
        }
    }
}

/**
 * `.shortcut` L424-435：高 46（L427）、圆角 16（L433）、`rgba(255,255,255,.047)` 底（L431）、
 * 1px `--line-10` 描边（L432）、左右内边距 12（L434）、`color: var(--white-70)`（L435）、
 * 按压 `scale(.98)`（L443）。图标/文字/箭头尺寸见 L444-446。
 */
@Composable
private fun ShortcutButton(
    shortcut: FtProfileShortcut,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale = if (pressed) PRESS_SCALE_SHORTCUT else 1f // `.shortcut:active { transform: scale(.98) }`（L443）

    Row(
        modifier = modifier
            .height(46.dp) // `height: 46px`（L427）
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(ShortcutShape) // `border-radius: 16px`（L433）
            .background(ShortcutFill) // `background: rgba(255,255,255,.047)`（L431）
            .border(1.dp, FtColor.line10, ShortcutShape) // `border: 1px solid var(--line-10)`（L432）
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .padding(horizontal = 12.dp), // `padding: 0 12px`（L434）
        verticalAlignment = Alignment.CenterVertically, // align-items: center（L429）
        horizontalArrangement = Arrangement.spacedBy(8.dp), // gap: 8px（L430）
    ) {
        ProfileIcon(
            kind = shortcut.icon,
            modifier = Modifier.size(18.dp), // `.sc-ic { 18×18 }`（L444）
            color = FtColor.white70, // 继承 `.shortcut { color: var(--white-70) }`（L435）
        )
        Text(
            text = stringResource(shortcut.labelRes),
            modifier = Modifier.weight(1f), // `.sc-label { flex: 1 1 auto }`（L445）
            style = FtType.natural(13f), // 13px，未声明 line-height（L445）
            color = FtColor.white70,
            textAlign = TextAlign.Start, // `text-align: left`（L445）
        )
        ChevronIcon(modifier = Modifier.size(18.dp), color = FtColor.white62) // `.sc-chev` 18×18 white-62（L446）
    }
}

// ── 图标（均取自本 HTML 的 <symbol>，viewBox 0 0 24 24） ─────────────────────
//
// `currentStreakDays` / `weekActiveDays` / `pad2` 已随状态迁入 ProfileViewModel.kt。

/** 图标 viewBox 边长；一律按 `size.minDimension / 24` 等比换算（与 `FtIcons.kt` 同口径）。 */
private const val VIEW = 24f

/** 图标描边默认宽度（原型各 symbol 的 `stroke-width` 多为 1.8，箭头类为 2）。 */
private const val STROKE_ICON = 1.8f

@Composable
private fun ProfileIcon(kind: FtProfileIcon, modifier: Modifier, color: Color) {
    when (kind) {
        FtProfileIcon.FLAME -> FlameIcon(modifier = modifier, color = color)
        FtProfileIcon.TROPHY -> TrophyIcon(modifier = modifier, color = color)
        FtProfileIcon.SCALE -> ScaleIcon(modifier = modifier, color = color)
        FtProfileIcon.LIBRARY -> LibraryIcon(modifier = modifier, color = color)
        FtProfileIcon.SLIDERS -> SlidersIcon(modifier = modifier, color = color)
    }
}

/** `#i-settings`（L1255-1258）：圆心 r3 + 八根辐条，描边 1.8，圆头。 */
@Composable
private fun SettingsIcon(modifier: Modifier, color: Color) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val w = STROKE_ICON * k
        drawCircle(color, radius = 3f * k, center = Offset(12f * k, 12f * k), style = Stroke(w))
        val spokes = Path().apply {
            moveTo(12f * k, 2.8f * k); lineTo(12f * k, 5.2f * k)
            moveTo(12f * k, 18.8f * k); lineTo(12f * k, 21.2f * k)
            moveTo(4.9f * k, 4.9f * k); lineTo(6.6f * k, 6.6f * k)
            moveTo(17.4f * k, 17.4f * k); lineTo(19.1f * k, 19.1f * k)
            moveTo(2.8f * k, 12f * k); lineTo(5.2f * k, 12f * k)
            moveTo(18.8f * k, 12f * k); lineTo(21.2f * k, 12f * k)
            moveTo(4.9f * k, 19.1f * k); lineTo(6.6f * k, 17.4f * k)
            moveTo(17.4f * k, 6.6f * k); lineTo(19.1f * k, 4.9f * k)
        }
        drawPath(spokes, color, style = Stroke(w, cap = StrokeCap.Round))
    }
}

/**
 * `#i-flame`（L1259-1261）：单段闭合轮廓，描边 1.8、圆头圆角。
 *
 * 原路径混用 cubic 与两支 SVG 圆弧。两处圆弧已按椭圆几何**精确换算**为 `arcTo`（非近似）：
 * - 起始弧 `A2.5 2.5 0 0 0 11 12`：弦 (8.5,14.5)→(11,12) 的中垂解出圆心 (8.5,12)、r=2.5，
 *   sweep-flag=0 即逆角向，对应 Compose `arcTo` 的负扫角（90° → 0°，-90°）。
 * - 底部大弧 `a7 7 0 1 1-14 0`：弦长 14 恰为 2r，是半圆，圆心 (12,15)；sweep-flag=1 为正方
 *   向扫角，0° → 180° 经过正下方（y=22），即火苗的圆底。
 * - 收尾弧 `a2.5 2.5 0 0 0 2.5 2.5`：圆心 (8.5,12)，180° → 90°（-90°），与首弧同心。
 */
@Composable
private fun FlameIcon(modifier: Modifier, color: Color) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val w = STROKE_ICON * k
        val path = Path().apply {
            moveTo(8.5f * k, 14.5f * k)
            arcTo(Rect(6f * k, 9.5f * k, 11f * k, 14.5f * k), 90f, -90f, false) // → (11,12)
            cubicTo(11f * k, 10.62f * k, 10.5f * k, 10f * k, 10f * k, 9f * k)
            cubicTo(8.928f * k, 6.857f * k, 9.776f * k, 4.946f * k, 12f * k, 3f * k)
            cubicTo(12.5f * k, 5.5f * k, 14f * k, 7.9f * k, 16f * k, 9.5f * k)
            cubicTo(18f * k, 11.1f * k, 19f * k, 13f * k, 19f * k, 15f * k)
            arcTo(Rect(5f * k, 8f * k, 19f * k, 22f * k), 0f, 180f, false) // 半圆底 → (5,15)
            cubicTo(5f * k, 13.847f * k, 5.433f * k, 12.706f * k, 6f * k, 12f * k)
            arcTo(Rect(6f * k, 9.5f * k, 11f * k, 14.5f * k), 180f, -90f, false) // → (8.5,14.5)
            close()
        }
        drawPath(path, color, style = Stroke(w, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

/**
 * `#i-trophy`（L1262-1265）：两支子路径——杯体（含底部半圆）与耳/座。
 *
 * 圆弧换算：杯体 `a8 8 0 0 1-16 0` 弦长 16 = 2r，是半圆，圆心 (12,9)，0° → 180° 经过正下方；
 * 双耳 `a2.5 2.5 0 0 1 0-5`（左，90° → 270°，经过左侧 x=2）与 `a2.5 2.5 0 0 0 0-5`（右，90° → -90°，
 * 经过右侧 x=22）。均按椭圆几何精确换算，非近似。
 */
@Composable
private fun TrophyIcon(modifier: Modifier, color: Color) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val w = STROKE_ICON * k
        val style = Stroke(w, cap = StrokeCap.Round, join = StrokeJoin.Round)

        // `M4 5h16v4a8 8 0 0 1-16 0z`：杯体
        val cup = Path().apply {
            moveTo(4f * k, 5f * k)
            lineTo(20f * k, 5f * k)
            lineTo(20f * k, 9f * k)
            arcTo(Rect(4f * k, 1f * k, 20f * k, 17f * k), 0f, 180f, false) // → (4,9)
            close()
        }
        drawPath(cup, color, style = style)

        // 耳 / 座：`M6 9H4.5a…M18 9h1.5a…M12 13v9M4 22h16`
        val frame = Path().apply {
            moveTo(6f * k, 9f * k)
            lineTo(4.5f * k, 9f * k)
            arcTo(Rect(2f * k, 4f * k, 7f * k, 9f * k), 90f, 180f, false) // → (4.5,4)
            lineTo(6f * k, 4f * k)
            moveTo(18f * k, 9f * k)
            lineTo(19.5f * k, 9f * k)
            arcTo(Rect(17f * k, 4f * k, 22f * k, 9f * k), 90f, -180f, false) // → (19.5,4)
            lineTo(18f * k, 4f * k)
            moveTo(12f * k, 13f * k); lineTo(12f * k, 22f * k)
            moveTo(4f * k, 22f * k); lineTo(20f * k, 22f * k)
        }
        drawPath(frame, color, style = style)
    }
}

/** `#i-scale`（L1266-1271）：立柱 + 横梁 + 两枚三角托盘，描边 1.8、圆头圆角。 */
@Composable
private fun ScaleIcon(modifier: Modifier, color: Color) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val w = STROKE_ICON * k
        val path = Path().apply {
            moveTo(12f * k, 3f * k); lineTo(12f * k, 21f * k)
            moveTo(8f * k, 21f * k); lineTo(16f * k, 21f * k)
            moveTo(3f * k, 7f * k); lineTo(21f * k, 7f * k)
            moveTo(3f * k, 7f * k); lineTo(0.5f * k, 14f * k); lineTo(5.5f * k, 14f * k); close()
            moveTo(21f * k, 7f * k); lineTo(18.5f * k, 14f * k); lineTo(23.5f * k, 14f * k); close()
        }
        drawPath(path, color, style = Stroke(w, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

/** `#i-library`（L1302-1305）：四个 7×7、rx2 圆角矩形，描边 1.8。 */
@Composable
private fun LibraryIcon(modifier: Modifier, color: Color) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val w = STROKE_ICON * k
        val corner = CornerRadius(2f * k, 2f * k)
        val side = 7f * k
        listOf(4f to 4f, 13f to 4f, 4f to 13f, 13f to 13f).forEach { (x, y) ->
            drawRoundRect(
                color = color,
                topLeft = Offset(x * k, y * k),
                size = Size(side, side),
                cornerRadius = corner,
                style = Stroke(w),
            )
        }
    }
}

/**
 * `FtProfileIcon.SLIDERS` 的绘制（**设计侧新增**，原型 `fittracker-personal.html` 无对应 `<symbol>`，
 * 出处见 `FtProfileModel` 的 [FtProfileIcon] 尾注）：三条横线 + 三枚实心调节圆点，
 * 24 viewBox 风格对齐本文件其余图标（描边 1.8、圆头）。
 */
@Composable
private fun SlidersIcon(modifier: Modifier, color: Color) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val w = STROKE_ICON * k
        val path = Path().apply {
            moveTo(4f * k, 6f * k); lineTo(20f * k, 6f * k)
            moveTo(4f * k, 12f * k); lineTo(20f * k, 12f * k)
            moveTo(4f * k, 18f * k); lineTo(20f * k, 18f * k)
        }
        drawPath(path, color, style = Stroke(w, cap = StrokeCap.Round))
        listOf(9f to 6f, 15f to 12f, 9f to 18f).forEach { (x, y) ->
            drawCircle(color, radius = 1.8f * k, center = Offset(x * k, y * k))
        }
    }
}

/** `#i-chevron`（L1283-1285）：`m9 18 6-6-6-6`，描边 2（L1284）、圆头圆角。 */
@Composable
private fun ChevronIcon(modifier: Modifier, color: Color) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / VIEW
        val path = Path().apply {
            moveTo(9f * k, 18f * k)
            lineTo(15f * k, 12f * k)
            lineTo(9f * k, 6f * k)
        }
        drawPath(
            path = path,
            color = color,
            style = Stroke(2f * k, cap = StrokeCap.Round, join = StrokeJoin.Round), // stroke-width: 2（L1284）
        )
    }
}

// ── 局部常量（原型值无对应全局令牌或需按末尾规则覆盖） ──────────────────────

/**
 * `.card` / `.card.focus` 的统一底色（末尾覆盖层 L1229-1232）：`rgba(255,255,255,.031)`。
 * AA = round(.031 × 255) = round(7.905) = 8 = 0x08 → `0x08FFFFFF`。
 */
private val CardFill = Color(0x08FFFFFF)

/** `.p-settings` 底 `rgba(255,255,255,.047)`（L263）：AA = round(11.985) = 12 = 0x0C → `0x0CFFFFFF`。 */
private val IconButtonFill = Color(0x0CFFFFFF)

/** `.shortcut` 底 `rgba(255,255,255,.047)`（L431）：同上 → `0x0CFFFFFF`。 */
private val ShortcutFill = Color(0x0CFFFFFF)

/** `.avatar` 描边 `rgba(80,236,167,.30)`（L245）：AA = round(76.5) = 77 = 0x4D → `0x4D50ECA7`。 */
private val AvatarBorder = Color(0x4D50ECA7)

/** `.card.focus` 圆角 28px（L287）；`FtShape` 无 28 档，故局部定义。 */
private val FocusShape = RoundedCornerShape(28.dp)

/** `.shortcut` 圆角 16px（L433）。 */
private val ShortcutShape = RoundedCornerShape(16.dp)

/** `.p-settings:active { transform: scale(.96) }`（L278）；`FtMotion` 无同名档位。 */
private const val PRESS_SCALE_SETTINGS = 0.96f

/** `.shortcut:active { transform: scale(.98) }`（L443）＝ `FtMotion.PRESS_SCALE_CARD`。 */
private const val PRESS_SCALE_SHORTCUT = 0.98f

/** 资料编辑入口底 `rgba(255,255,255,.047)`（同快捷入口语汇）→ `0x0CFFFFFF`。 */
private val EditChipFill = Color(0x0CFFFFFF)

/** 头部「头像 + 身份」可点击区域的圆角（与卡片语汇一致）。 */
private val ProfileHeadShape = RoundedCornerShape(16.dp)

/** 头像配色组：`UserProfile.avatar` 存色键，空/未知键回落翡翠。编辑页复用同一映射。 */
internal data class AvatarTint(val bg: Color, val fg: Color, val border: Color)

internal fun avatarTintOf(key: String): AvatarTint = when (key) {
    "gold" -> AvatarTint(Color(0x1AD3B487), Color(0xFFD3B487), Color(0x4DD3B487))
    "sky" -> AvatarTint(Color(0x1A5AC8FA), Color(0xFF8CD1FF), Color(0x4D5AC8FA))
    "rose" -> AvatarTint(Color(0x1AFF8A9B), Color(0xFFFF9FB0), Color(0x4DFF8A9B))
    "violet" -> AvatarTint(Color(0x1AA78BFA), Color(0xFFC4B5FD), Color(0x4DA78BFA))
    "amber" -> AvatarTint(Color(0x1AFFC46B), Color(0xFFFFD08A), Color(0x4DFFC46B))
    else -> AvatarTint(FtColor.accent10, FtColor.accent, AvatarBorder)
}
