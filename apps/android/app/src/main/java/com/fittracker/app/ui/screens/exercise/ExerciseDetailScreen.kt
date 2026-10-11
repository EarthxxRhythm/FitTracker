package com.fittracker.app.ui.screens.exercise

import androidx.activity.compose.BackHandler
import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.data.model.ExerciseContent
import com.fittracker.app.data.service.ContentRepository
import com.fittracker.app.ui.screens.library.ExerciseGif
import com.fittracker.app.ui.screens.library.FtLibraryModel
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtColorUtil
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType

/**
 * 动作详情屏（规格源：鸿蒙 `features/exercise/pages/ExerciseDetailPage.ets`，885 行——无原型 HTML 帧，逐值移植）。
 *
 * 390×844 直绘，画布由 `FtCanvas` 施加；本文件 px 值 1:1 映射为 dp
 * （源页数值均取自鸿蒙 `common/styles/DesignTokens.ets`，非 CSS px）。
 *
 * 数据：`ContentRepository.getExercise(exerciseId)`（先 `load(context)` 装载
 * `assets/exercise-content.json`）+ 各字段反查。源页取数走
 * `ContentRepository.ets:224` 的 `getExerciseDetailViewModel`，本屏以
 * [ExerciseDetailUiState.toUiState] 内联等价派生（名称反查 `getMuscleName` /
 * `getEquipmentName`、难度文案 `ContentRepository.ets:592` 的 `getDifficultyText`、
 * 替代动作名 `ContentRepository.ets:574` 的 `getAlternativeExerciseNames`、
 * 视频占位文案 `ContentRepository.ets:585` 的 `getVideoPlaceholder`）。
 *
 * 版式来源（源文件行号）：
 * `build()` L409-452 · `buildKnowledgeHeroSection()` L276-408 · `buildMediaSection()` L454-516 ·
 * `buildTechniqueSection()` L518-536 · `buildAlternativeSection()` L538-587 · `buildMetadataSection()` L589-610 ·
 * `buildTag()` L612-626 · `buildDetailLaneHeader()` L628-644 · `buildMetricTile()` L646-668 ·
 * `buildInfoRow()` L670-687 · `buildMediaPreview()` L689-739 · `buildMediaAssetBlock()` L741-793 ·
 * `buildNumberedSection()` L795-833 · `buildStatusPanel()` L835-876 · `buildDivider()` L878-885。
 * 卡片容器口径取自鸿蒙 `components/AppCard.ets`（`panel` = SURFACE_STRONG + BORDER_STRONG +
 * radius 16 + padding 24 + shadow MD；`outlined` = SURFACE_PRIMARY + BORDER_SUBTLE + radius 12 + padding 16）。
 *
 * 三处**以源码为准**的取舍：
 * 1. **不绘制顶栏**——源页 `build()`（L409-452）内**确无**页头，内容从滚动区顶部开始；
 *    返回由鸿蒙 NavigationStack 承担。Android 侧同样不绘顶栏（保持源坐标不位移），
 *    改为把系统返回接线到 [onBack]（`BackHandler`）。
 * 2. 媒体预览区接动作 GIF（W2-2）：命中 `assets/exercise-gifs/<file>.gif` 素材时
 *    （[FtLibraryModel.gifAssetFor] 按 `exerciseId` / 动作名反查），以原型
 *    `TouchTokens.HERO_HEIGHT`(200) 的盒播放动图——复用同仓
 *    [com.fittracker.app.ui.screens.library.ExerciseGif] 的 Coil GIF 用法（依赖已随
 *    `coil-compose` / `coil-gif` 引入，`app/build.gradle.kts` 仍**未接** Media3）。
 *    未命中素材时保持原取舍：`canRenderInline` 为真走同尺寸空盒 + 叠加角标，
 *    否则走居中的媒体状态块。
 * 3. 源页定义但**全文件未调用**的 `getAssetAvailabilityColor()`（L209-218）未移植（死代码）；
 *    其余辅助函数逐条对齐。
 */
/**
 * 一条用户可见文案的载体：`res != 0` 时走字符串资源（`args` 为嵌套文案参数），
 * 否则用 [raw]（来自内容数据的原始字符串，非本域文案）。
 *
 * 模型 / 解析层（[ExerciseDetailUiState] / [MediaResolver]）无 `Context`，
 * 故只持资源 ID 与参数，由 UI 层 [text] 以 `stringResource` 解析（Wave 8 i18n）。
 */
private data class FtLabel(
    @StringRes val res: Int = 0,
    val args: List<FtLabel> = emptyList(),
    val raw: String = "",
) {
    /** 是否含文案（资源或原始字符串任一非空）。 */
    val isPresent: Boolean get() = res != 0 || raw.isNotEmpty()
}

/** 资源文案（可带嵌套参数）。 */
private fun resLabel(@StringRes id: Int, vararg args: FtLabel): FtLabel =
    FtLabel(res = id, args = args.toList())

/** 原始数据文案（来自内容库）。 */
private fun rawLabel(value: String): FtLabel = FtLabel(raw = value)

/** 解析为当前区域文案。 */
@Composable
private fun FtLabel.text(): String =
    if (res != 0) stringResource(res, *args.map { it.text() }.toTypedArray()) else raw

@Composable
fun ExerciseDetailScreen(
    exerciseId: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    var detail by remember(exerciseId) { mutableStateOf<ExerciseDetailUiState?>(null) }
    var resolved by remember(exerciseId) { mutableStateOf(false) }

    LaunchedEffect(exerciseId) {
        val id = exerciseId.trim()
        if (id.isNotEmpty()) {
            try {
                if (!ContentRepository.isLoaded) {
                    ContentRepository.load(context)
                }
            } catch (_: Exception) {
                // 资产缺失 / schema 不符时 `ContentRepository` 保持原状态（load 的契约），
                // 下面 getExercise 返回 null → 渲染源页的「未找到动作」空态。
            }
            detail = ContentRepository.getExercise(id)?.toUiState()
        }
        resolved = true
    }

    // 源页无顶栏、无返回键（返回由鸿蒙 NavigationStack 提供）；Android 侧把系统返回接给 onBack。
    BackHandler(enabled = true, onBack = onBack)

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(BgPrimary) // 源 `ColorTokens.BG_PRIMARY`（L452）
            .verticalScroll(rememberScrollState())
            .padding(24.dp), // 源 `Scroll > Column().padding(SpacingTokens.LG)`（L445）
        verticalArrangement = Arrangement.spacedBy(24.dp), // 源 `Column({ space: SpacingTokens.LG })`（L411）
    ) {
        if (resolved && detail == null) {
            NotFoundCard()
        }
        detail?.let { ui ->
            HeroCard(ui)
            LaneHeader(
                title = stringResource(R.string.exercise_lane_media_title),
                description = stringResource(R.string.exercise_lane_media_desc),
            )
            MediaSection(ui)
            LaneHeader(
                title = stringResource(R.string.exercise_lane_technique_title),
                description = stringResource(R.string.exercise_lane_technique_desc),
            )
            TechniqueSection(ui)
            AlternativeSection(ui)
            LaneHeader(
                title = stringResource(R.string.exercise_lane_meta_title),
                description = stringResource(R.string.exercise_lane_meta_desc),
            )
            MetadataSection(ui)
        }
    }
}

// ── 首屏空态 ────────────────────────────────────────────────────────────────

/** 源 `build()` 的 `!hasExercise` 分支（L415-437）：panel 卡内三段文案。 */
@Composable
private fun NotFoundCard() {
    PanelCard {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp), // `Column({ space: SpacingTokens.MD })`
            horizontalAlignment = Alignment.Start,
        ) {
            Text(stringResource(R.string.exercise_not_found_eyebrow), style = FtType.natural(11f), color = TextTertiary)
            Text(stringResource(R.string.exercise_not_found_title), style = FtType.natural(28f, 700), color = FtColor.txtBody)
            Text(
                text = stringResource(R.string.exercise_not_found_desc),
                style = FtType.natural(16f).copy(lineHeight = 22.sp), // BODY_LINE_HEIGHT 22
                color = TextSecondary,
            )
        }
    }
}

// ── 知识英雄卡 ──────────────────────────────────────────────────────────────

/** 源 `buildKnowledgeHeroSection()`（L276-408）：标题块 + 媒体角标 + 三枚指标瓦片 + 训练焦点块。 */
@Composable
private fun HeroCard(ui: ExerciseDetailUiState) {
    PanelCard {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.Start,
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top, // `.alignItems(VerticalAlign.Top)`
            ) {
                Column(
                    modifier = Modifier.weight(1f), // `.layoutWeight(1)`
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    horizontalAlignment = Alignment.Start,
                ) {
                    Text(ui.heroEyebrow.text(), style = FtType.natural(11f), color = TextTertiary)
                    Text(
                        text = ui.name,
                        style = FtType.natural(28f, 700), // DISPLAY_SIZE / DISPLAY_WEIGHT
                        color = FtColor.txtBody,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = ui.metaSummary.text(),
                        style = FtType.natural(14f), // CAPTION_SIZE
                        color = TextSecondary,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                ToneBadge(text = ui.media.badgeText.text(), tone = ui.media.tone, outlined = true)
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                MetricTile(
                    label = stringResource(R.string.exercise_metric_steps_label),
                    value = ui.steps.size.toString(),
                    note = stringResource(R.string.exercise_metric_steps_note),
                    modifier = Modifier.weight(1f),
                )
                MetricTile(
                    label = stringResource(R.string.exercise_metric_cues_label),
                    value = ui.cues.size.toString(),
                    note = stringResource(R.string.exercise_metric_cues_note),
                    modifier = Modifier.weight(1f),
                )
                MetricTile(
                    label = stringResource(R.string.exercise_metric_alternatives_label),
                    value = ui.alternativeNames.size.toString(),
                    note = stringResource(R.string.exercise_metric_alternatives_note),
                    modifier = Modifier.weight(1f),
                )
            }

            // 训练焦点块（源 L338-405）：内嵌 SURFACE_SECONDARY 块，含焦点文案、媒体预览标签、
            // 执行要点、难度/肌群/器械标签与安全提示带
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(FtShape.xl) // RadiusTokens.LG = 16
                    .background(SurfaceSecondary)
                    .border(1.dp, BorderStrong, FtShape.xl)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                horizontalAlignment = Alignment.Start,
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Top,
                ) {
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                        horizontalAlignment = Alignment.Start,
                    ) {
                        Text(stringResource(R.string.exercise_focus_label), style = FtType.natural(13f, 500), color = TextTertiary)
                        Text(
                            text = ui.heroSummary.text(),
                            style = FtType.natural(20f, 700), // HEADLINE
                            color = FtColor.txtBody,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                    // 无描边变体（源此处 badge 无 `.border`）
                    ToneBadge(
                        text = mediaPreviewLabel(ui.media).text(),
                        tone = ui.media.tone,
                        outlined = false,
                    )
                }

                Text(
                    text = ui.executionFocusText.text(),
                    style = FtType.natural(16f).copy(lineHeight = 22.sp), // BODY_LINE_HEIGHT
                    color = TextSecondary,
                    modifier = Modifier.fillMaxWidth(),
                )

                // 源 `Flex({ wrap: FlexWrap.Wrap })`：难度 → 主肌群 → 器械，逐个带右下 8 边距
                TagFlow(ui)

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(FtShape.md) // RadiusTokens.MD = 12
                        .background(WarningBg)
                        .border(1.dp, AccentGold, FtShape.md)
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    horizontalAlignment = Alignment.Start,
                ) {
                    Text(stringResource(R.string.exercise_safety_label), style = FtType.natural(11f), color = AccentGold)
                    Text(
                        text = ui.safetyFocusText.text(),
                        style = FtType.natural(14f).copy(lineHeight = 18.sp), // CAPTION_LINE_HEIGHT
                        color = TextSecondary,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}

/** 源 `Flex` 标签流（L373-386）：难度（OVERLAY_ACCENT/ACCENT_GOLD）→ 肌群（OVERLAY_PRIMARY/PRIMARY）→ 器械（SURFACE_ELEVATED/TEXT_SECONDARY）。 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TagFlow(ui: ExerciseDetailUiState) {
    FlowRow(modifier = Modifier.fillMaxWidth()) {
        // `buildTag()` 的 `.margin({ right: SM, bottom: SM })`
        val tagGap = Modifier.padding(end = 8.dp, bottom = 8.dp)
        ToneTag(
            text = ui.difficultyText.text(),
            background = OverlayAccent,
            textColor = AccentGold,
            modifier = tagGap,
        )
        ui.primaryMuscleNames.forEach { muscleName ->
            ToneTag(
                text = muscleName,
                background = OverlayPrimary,
                textColor = FtColor.accent,
                modifier = tagGap,
            )
        }
        ui.equipmentNames.forEach { equipmentName ->
            ToneTag(
                text = equipmentName,
                background = SurfaceElevated,
                textColor = TextSecondary,
                modifier = tagGap,
            )
        }
    }
}

// ── 媒体与演示 ──────────────────────────────────────────────────────────────

/** 源 `buildMediaSection()`（L454-516）：媒体状态 + 封面/视频可用性 + 预览块 + 两个资源块。 */
@Composable
private fun MediaSection(ui: ExerciseDetailUiState) {
    val media = ui.media
    PanelCard {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.Start,
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically, // `.alignItems(VerticalAlign.Center)`
            ) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    horizontalAlignment = Alignment.Start,
                ) {
                    Text(stringResource(R.string.exercise_media_title), style = FtType.natural(18f, 500), color = FtColor.txtBody)
                    Text(media.statusText.text(), style = FtType.natural(14f), color = TextSecondary)
                }
                ToneBadge(text = mediaPreviewLabel(media).text(), tone = media.tone, outlined = false)
            }

            // 源顺序：标题行（L456-483）→ 预览块（L486）→ 封面/视频瓦片（L488-491）
            // W2-2：按 exerciseId / 动作名反查动作 GIF 素材（真实内容 id 为 `ex_*`，与素材名不同）
            MediaPreview(media, FtLibraryModel.gifAssetFor(ui.exerciseId, ui.name), ui.name)

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                MetricTile(
                    label = stringResource(R.string.exercise_media_cover_label),
                    value = assetAvailabilityLabel(media.cover).text(),
                    note = stringResource(R.string.exercise_media_cover_note),
                    modifier = Modifier.weight(1f),
                )
                MetricTile(
                    label = stringResource(R.string.exercise_media_video_label),
                    value = assetAvailabilityLabel(media.video).text(),
                    note = stringResource(R.string.exercise_media_video_note),
                    modifier = Modifier.weight(1f),
                )
            }

            Text(
                text = media.summaryText.text(),
                // 源 `.fontWeight(FontTokens.BODY_BOLD_WEIGHT)` = Medium
                style = FtType.natural(16f, 500),
                color = FtColor.txtBody,
                modifier = Modifier.fillMaxWidth(),
            )
            Text(
                text = media.detailText.text(),
                style = FtType.natural(14f).copy(lineHeight = 18.sp),
                color = TextSecondary,
                modifier = Modifier.fillMaxWidth(),
            )

            InfoRow(label = stringResource(R.string.exercise_media_source_row), value = media.sourceNote.text())
            InfoRow(label = stringResource(R.string.exercise_media_license_row), value = media.licenseNote.text())

            MediaAssetBlock(title = stringResource(R.string.exercise_media_cover_block), asset = media.cover)
            MediaAssetBlock(title = stringResource(R.string.exercise_media_video_block), asset = media.video)
        }
    }
}

/**
 * 源 `buildMediaPreview()`（L689-739）：可内联时走 200 高预览盒，否则居中的媒体状态块。
 *
 * W2-2：[gifAsset] 非空（命中动作 GIF 素材）时**优先**于源页的封面分支，以同一 200 高盒
 * 播放动图；加载中 / 失败由 [ExerciseGif] 内部回落同尺寸占位块（见文件头取舍 2）。
 */
@Composable
private fun MediaPreview(media: MediaPresentation, gifAsset: String?, exerciseName: String) {
    if (gifAsset != null) {
        // 源盒高 `TouchTokens.HERO_HEIGHT`(200)。不绘源页叠加角标——它描述的是封面资源
        // 可用性，与「GIF 已在播放」相冲突（真实内容 coverUrl 为空时该角标恒为「未提供」）。
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .clip(FtShape.md)
                .background(BgElevated),
        ) {
            ExerciseGif(
                gifAsset = gifAsset,
                iconSize = 30.dp,
                fill = BgElevated,
                contentDescription = stringResource(R.string.exercise_a11y_demo, exerciseName),
            )
        }
        return
    }
    if (media.cover.canRenderInline) {
        // 无 GIF 素材、封面可内联 → 同尺寸空盒 + 源页的叠加角标（见文件头取舍 2）
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp) // `TouchTokens.HERO_HEIGHT`
                .clip(FtShape.md)
                .background(BgElevated),
        ) {
            Column(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(16.dp) // `.margin(SpacingTokens.MD)`
                    .clip(RoundedCornerShape(8.dp)) // `RadiusTokens.SM`
                    .background(OverlayPrimary)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
                horizontalAlignment = Alignment.Start,
            ) {
                Text(stringResource(R.string.exercise_media_preview_overlay), style = FtType.natural(14f, 500), color = FtColor.txtBody)
                Text(
                    text = media.cover.stateText.text(),
                    style = FtType.natural(13f),
                    color = FtColor.txtBody,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    } else {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .clip(FtShape.md)
                .background(BgElevated)
                .border(1.dp, BorderSubtle, FtShape.md)
                .padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = mediaPreviewLabel(media).text(),
                style = FtType.natural(18f, 500),
                color = FtColor.txtBody,
            )
            Text(
                text = media.statusText.text(),
                style = FtType.natural(14f),
                color = TextSecondary,
                textAlign = TextAlign.Center,
            )
        }
    }
}

/** 源 `buildMediaAssetBlock()`（L741-793）：outlined 卡（单资源状态 / 主副文案 / 引用·来源·授权三行）。 */
@Composable
private fun MediaAssetBlock(title: String, asset: MediaAssetInfo) {
    OutlinedCard {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalAlignment = Alignment.Start,
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    horizontalAlignment = Alignment.Start,
                ) {
                    Text(title, style = FtType.natural(16f, 500), color = FtColor.txtBody)
                    Text(asset.stateText.text(), style = FtType.natural(13f), color = TextSecondary)
                }
                ToneBadge(
                    text = assetAvailabilityLabel(asset).text(),
                    tone = when {
                        asset.canRenderInline -> "primary"
                        asset.hasReference -> "accent"
                        else -> "default"
                    },
                    outlined = false,
                )
            }

            Text(
                text = asset.primaryText.text(),
                style = FtType.natural(14f),
                color = FtColor.txtBody,
                modifier = Modifier.fillMaxWidth(),
            )
            Text(
                text = asset.secondaryText.text(),
                style = FtType.natural(13f),
                color = TextSecondary,
                modifier = Modifier.fillMaxWidth(),
            )

            if (asset.originalUrl.isNotEmpty()) {
                InfoRow(label = stringResource(R.string.exercise_asset_ref_row), value = asset.originalUrl)
            }
            InfoRow(label = stringResource(R.string.exercise_asset_source_row), value = asset.sourceLabel.text())
            InfoRow(label = stringResource(R.string.exercise_asset_license_row), value = asset.licenseLabel.text())
        }
    }
}

// ── 执行要点 / 替代 / 元信息 ────────────────────────────────────────────────

/** 源 `buildTechniqueSection()`（L518-536）：编号步骤 + 分隔线 + 三块状态面板。 */
@Composable
private fun TechniqueSection(ui: ExerciseDetailUiState) {
    PanelCard {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.Start,
        ) {
            Text(stringResource(R.string.exercise_technique_title), style = FtType.natural(18f, 500), color = FtColor.txtBody)
            NumberedSection(
                title = stringResource(R.string.exercise_steps_title),
                values = ui.steps,
                emptyText = stringResource(R.string.exercise_steps_empty),
            )
            HairlineDivider()
            StatusPanel(title = stringResource(R.string.exercise_cues_title), values = ui.cues, tone = "info")
            StatusPanel(title = stringResource(R.string.exercise_mistakes_title), values = ui.commonMistakes, tone = "error")
            StatusPanel(title = stringResource(R.string.exercise_safety_title), values = ui.safetyNotes, tone = "warning")
        }
    }
}

/** 源 `buildNumberedSection()`（L795-833）：翡翠序号圆 + 正文。 */
@Composable
private fun NumberedSection(title: String, values: List<String>, emptyText: String) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        horizontalAlignment = Alignment.Start,
    ) {
        Text(title, style = FtType.natural(16f, 500), color = FtColor.txtBody)

        if (values.isEmpty()) {
            Text(
                text = emptyText,
                style = FtType.natural(16f),
                color = TextSecondary,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        values.forEachIndexed { index, value ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                IndexBubble(text = (index + 1).toString(), background = FtColor.accent)
                Text(
                    text = value,
                    style = FtType.natural(16f).copy(lineHeight = 22.sp),
                    color = FtColor.txtBody,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

/** 源 `buildStatusPanel()`（L835-876）：info / error / warning 三色调的条目面板。 */
@Composable
private fun StatusPanel(title: String, values: List<String>, tone: String) {
    val panelColor = statusToneColor(tone)
    val panelFill = statusToneBackground(tone)
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        horizontalAlignment = Alignment.Start,
    ) {
        Text(title, style = FtType.natural(16f, 500), color = FtColor.txtBody)

        if (values.isEmpty()) {
            Text(
                text = statusEmptyText(tone).text(),
                style = FtType.natural(16f),
                color = TextSecondary,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        values.forEach { value ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(FtShape.md)
                    .background(panelFill)
                    .border(1.dp, panelColor, FtShape.md)
                    .padding(16.dp),
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = "·",
                    style = FtType.natural(16f),
                    color = panelColor,
                    modifier = Modifier.padding(top = 4.dp), // `.margin({ top: SpacingTokens.XS })`
                )
                Text(
                    text = value,
                    style = FtType.natural(16f).copy(lineHeight = 22.sp),
                    color = FtColor.txtBody,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

/** 源 `buildAlternativeSection()`（L538-587）：说明 + 空态文案 + 替代动作条目。 */
@Composable
private fun AlternativeSection(ui: ExerciseDetailUiState) {
    PanelCard {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.Start,
        ) {
            Text(stringResource(R.string.exercise_alternative_title), style = FtType.natural(18f, 500), color = FtColor.txtBody)
            Text(
                text = stringResource(R.string.exercise_alternative_desc),
                style = FtType.natural(14f).copy(lineHeight = 18.sp),
                color = TextSecondary,
            )

            if (ui.alternativeNames.isEmpty()) {
                Text(
                    text = stringResource(R.string.exercise_alternative_empty),
                    style = FtType.natural(16f),
                    color = TextSecondary,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            ui.alternativeNames.forEachIndexed { index, name ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(FtShape.md)
                        .background(BgElevated)
                        .border(1.dp, BorderSubtle, FtShape.md)
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    IndexBubble(text = (index + 1).toString(), background = SurfaceElevated)
                    Text(
                        text = name,
                        style = FtType.natural(16f),
                        color = FtColor.txtBody,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

/** 源 `buildMetadataSection()`（L589-610）：panel + compact（内边距 16）的键值清单。 */
@Composable
private fun MetadataSection(ui: ExerciseDetailUiState) {
    PanelCard(padding = 16.dp) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalAlignment = Alignment.Start,
        ) {
            Text(stringResource(R.string.exercise_metadata_title), style = FtType.natural(14f, 500), color = FtColor.txtBody)
            InfoRow(label = stringResource(R.string.exercise_meta_id_row), value = ui.exerciseId)
            if (ui.nameEn.isNotEmpty()) {
                InfoRow(label = stringResource(R.string.exercise_meta_name_en_row), value = ui.nameEn)
            }
            InfoRow(label = stringResource(R.string.exercise_meta_muscle_row), value = ui.muscleSummary.text())
            InfoRow(label = stringResource(R.string.exercise_meta_equipment_row), value = ui.equipmentSummary.text())
        }
    }
}

// ── 通用小组件 ──────────────────────────────────────────────────────────────

/** 源 `buildDetailLaneHeader()`（L628-644）：分段标题 + 说明。 */
@Composable
private fun LaneHeader(title: String, description: String) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(4.dp),
        horizontalAlignment = Alignment.Start,
    ) {
        Text(title, style = FtType.natural(20f, 700), color = FtColor.txtBody)
        Text(
            text = description,
            style = FtType.natural(14f).copy(lineHeight = 18.sp),
            color = TextTertiary,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/** 源 `buildMetricTile()`（L646-668）：BG_ELEVATED 瓦片，标签 / 数值 / 注解三段。 */
@Composable
private fun MetricTile(label: String, value: String, note: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(FtShape.md)
            .background(BgElevated)
            .border(1.dp, BorderSubtle, FtShape.md)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
        horizontalAlignment = Alignment.Start,
    ) {
        Text(label, style = FtType.natural(13f), color = TextTertiary)
        Text(value, style = FtType.natural(20f, 700), color = FtColor.txtBody)
        Text(note, style = FtType.natural(14f), color = TextSecondary)
    }
}

/** 源 `buildInfoRow()`（L670-687）：键宽 68 的左键右值行。 */
@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            text = label,
            style = FtType.natural(13f),
            color = TextTertiary,
            modifier = Modifier.width(68.dp),
        )
        Text(
            text = value,
            style = FtType.natural(16f),
            color = TextSecondary,
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
    }
}

/** 源 `buildTag()`（L612-626）的胶囊标签。 */
@Composable
private fun ToneTag(
    text: String,
    background: Color,
    textColor: Color,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        style = FtType.natural(14f),
        color = textColor,
        modifier = modifier
            .clip(FtShape.pill)
            .background(background)
            .padding(horizontal = 8.dp, vertical = 4.dp),
    )
}

/**
 * 状态胶囊（源页三处 badge 的合并实现）。
 *
 * [outlined] = 源 `buildKnowledgeHeroSection` 里带 `border(1, tone 色)` 的那一处；
 * 其余两处（训练焦点角标、媒体卡角标、资源块角标）**无描边**。
 */
@Composable
private fun ToneBadge(text: String, tone: String, outlined: Boolean) {
    val filled = Modifier
        .clip(FtShape.pill)
        .background(mediaToneBackground(tone))
    val shaped = if (outlined) filled.border(1.dp, mediaToneColor(tone), FtShape.pill) else filled
    Text(
        text = text,
        style = FtType.natural(13f),
        color = FtColor.txtBody,
        maxLines = 1,
        modifier = shaped.padding(horizontal = 8.dp, vertical = 4.dp),
    )
}

/** 序号圆（编号步骤 = PRIMARY 底；替代动作 = SURFACE_ELEVATED 底），字号 SMALL_SIZE 13。 */
@Composable
private fun IndexBubble(text: String, background: Color) {
    Box(
        modifier = Modifier
            .size(24.dp)
            .clip(FtShape.pill)
            .background(background),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            style = FtType.natural(13f),
            color = FtColor.txtBody,
            textAlign = TextAlign.Center,
        )
    }
}

/** 源 `buildDivider()`（L878-885）：1px DIVIDER 分隔线。 */
@Composable
private fun HairlineDivider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(DividerColor),
    )
}

/**
 * 鸿蒙 `AppCard({ variant: 'panel', cardPadding: 'default' })`
 * （`AppCard.ets`：SURFACE_STRONG / BORDER_STRONG / radius 16 / padding 24 / shadow MD）。
 *
 * Compose 阴影无 blur+offset 双参数，取 `elevation = 12.dp` + 色值近似
 * ShadowTokens.MD（radius 20 / offsetY 8 / rgba(3,8,8,.34)），与同仓 `PlansScreen` 既有做法一致。
 */
@Composable
private fun PanelCard(padding: Dp = 24.dp, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            // 原型卡阴影（深色 rgba(3,8,8,.34)）在深色底剖面上不可辨；
            // elevation 阴影会产生可测暗带（home 判例）——按原型剖面移除
            .clip(FtShape.xl)
            .background(SurfaceStrong)
            .border(1.dp, BorderStrong, FtShape.xl)
            .padding(padding),
        content = content,
    )
}

/**
 * 鸿蒙 `AppCard({ variant: 'outlined', cardPadding: 'compact' })`
 * （`AppCard.ets`：SURFACE_PRIMARY / BORDER_SUBTLE / radius 12 / padding 16 / 无阴影）。
 */
@Composable
private fun OutlinedCard(padding: Dp = 16.dp, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(FtShape.md)
            .background(SurfacePrimary)
            .border(1.dp, BorderSubtle, FtShape.md)
            .padding(padding),
        content = content,
    )
}

// ── 数据 ────────────────────────────────────────────────────────────────────

/**
 * 源 `ExerciseDetailViewModel`（`ContentRepository.ets:30-48`）+ 页面派生文案
 * （源 `getMuscleSummary` L123 · `getEquipmentSummary` L130 · `getHeroSummary` L137 ·
 * `getHeroEyebrow` L149 · `getMetaSummary` L159 · `getExecutionFocusText` L259 ·
 * `getSafetyFocusText` L269）。
 */
private data class ExerciseDetailUiState(
    val exerciseId: String,
    val name: String,
    val nameEn: String,
    val difficultyText: FtLabel,
    val primaryMuscleNames: List<String>,
    val equipmentNames: List<String>,
    val steps: List<String>,
    val cues: List<String>,
    val commonMistakes: List<String>,
    val safetyNotes: List<String>,
    val alternativeNames: List<String>,
    val media: MediaPresentation,
) {
    val muscleSummary: FtLabel
        get() = if (primaryMuscleNames.isEmpty()) {
            resLabel(R.string.exercise_muscle_pending)
        } else {
            rawLabel(primaryMuscleNames.joinToString(" / "))
        }

    val equipmentSummary: FtLabel
        get() = if (equipmentNames.isEmpty()) {
            resLabel(R.string.exercise_equipment_pending)
        } else {
            rawLabel(equipmentNames.joinToString(" / "))
        }

    val heroSummary: FtLabel
        get() {
            val focusText = muscleSummary
            val equipmentText = equipmentSummary
            if (cues.isNotEmpty()) {
                return resLabel(R.string.exercise_hero_summary, focusText, equipmentText, rawLabel(cues[0]))
            }
            if (safetyNotes.isNotEmpty()) {
                return resLabel(R.string.exercise_hero_summary, focusText, equipmentText, rawLabel(safetyNotes[0]))
            }
            return resLabel(
                R.string.exercise_hero_summary,
                focusText,
                equipmentText,
                resLabel(R.string.exercise_hero_focus_default),
            )
        }

    val heroEyebrow: FtLabel
        get() = when {
            media.cover.canRenderInline || media.video.canRenderInline -> resLabel(R.string.exercise_eyebrow_learning)
            media.cover.hasReference || media.video.hasReference -> resLabel(R.string.exercise_eyebrow_reference)
            else -> resLabel(R.string.exercise_eyebrow_detail)
        }

    val metaSummary: FtLabel
        get() = if (nameEn.isNotEmpty()) rawLabel(nameEn) else resLabel(R.string.exercise_meta_id, rawLabel(exerciseId))

    val executionFocusText: FtLabel
        get() = cues.firstOrNull()?.let { rawLabel(it) }
            ?: safetyNotes.firstOrNull()?.let { rawLabel(it) }
            ?: resLabel(R.string.exercise_execution_focus_default)

    val safetyFocusText: FtLabel
        get() = safetyNotes.firstOrNull()?.let { rawLabel(it) }
            ?: resLabel(R.string.exercise_safety_focus_default)
}

/**
 * 源 `ContentRepository.ets:224` 的 `getExerciseDetailViewModel` 的安卓等价派生：
 * 名称反查接 [ContentRepository]（L558/L566/L574 的三个 `get*Names`），
 * 难度文案对齐 L592 的 `getDifficultyText`。
 */
private fun ExerciseContent.toUiState(): ExerciseDetailUiState {
    val videoPlaceholder = if (videoUrl.trim().isNotEmpty()) {
        // 源 `getVideoPlaceholder`（L585-591）
        resLabel(R.string.exercise_video_placeholder_ready)
    } else {
        resLabel(R.string.exercise_video_placeholder_soon)
    }
    val media = MediaResolver.resolve(
        coverUrl = coverUrl,
        videoUrl = videoUrl,
        videoPlaceholder = videoPlaceholder,
        metadata = MediaMetadata(
            coverSourceLabel = coverSourceLabel,
            videoSourceLabel = videoSourceLabel,
            mediaLicenseText = mediaLicenseText,
        ),
    )
    return ExerciseDetailUiState(
        exerciseId = exerciseId,
        name = nameZh,
        nameEn = nameEn,
        difficultyText = difficultyLabel(difficulty),
        primaryMuscleNames = primaryMuscleIds.map { ContentRepository.getMuscleName(it) },
        equipmentNames = equipmentIds.map { ContentRepository.getEquipmentName(it) },
        steps = steps,
        cues = cues,
        commonMistakes = commonMistakes,
        safetyNotes = safetyNotes,
        alternativeNames = alternativeExerciseIds.mapNotNull { ContentRepository.getExercise(it)?.nameZh },
        media = media,
    )
}

/** 源 `getDifficultyText`（`ContentRepository.ets:592-604`）：未知取值回退原字符串。 */
private fun difficultyLabel(difficulty: String): FtLabel = when (difficulty) {
    "beginner" -> resLabel(R.string.exercise_difficulty_beginner)
    "intermediate" -> resLabel(R.string.exercise_difficulty_intermediate)
    "advanced" -> resLabel(R.string.exercise_difficulty_advanced)
    else -> rawLabel(difficulty)
}

// ── 媒体解析（逐函数移植 `shared/services/ExerciseMediaResolverService.ets`） ──
//
// 源：`ExerciseMediaResolverServiceImpl`（`resolve` / `resolveAsset` / `fillPresentationCopy` /
// `getOverallState` / `getAssetState` / `getAssetStateText` / `getAssetPrimaryText` /
// `getAssetSecondaryText` / `getSourceLabel` / `getLicenseLabel` / `buildSourceNote` /
// `buildLicenseNote` / `canRenderInline` / `isAbsoluteFilePath` / `isAsciiLetter` / `getScheme`）。
// 源用可变对象分步填充，此处以返回不可变 [MediaPresentationCopy] 等价表达。

/** 源 `ExerciseMediaMetadata`。 */
private data class MediaMetadata(
    val coverSourceLabel: String,
    val videoSourceLabel: String,
    val mediaLicenseText: String,
)

/** 源 `ExerciseMediaAssetInfo`。文案字段为 [FtLabel]（静态走资源，来源/授权可为数据原始串）。 */
private data class MediaAssetInfo(
    val originalUrl: String,
    val resolvedUrl: String,
    val scheme: String,
    val state: String,
    val stateText: FtLabel,
    val primaryText: FtLabel,
    val secondaryText: FtLabel,
    val sourceLabel: FtLabel,
    val licenseLabel: FtLabel,
    val hasReference: Boolean,
    val canRenderInline: Boolean,
)

/** 源 `ExerciseMediaPresentation`。文案字段为 [FtLabel]。 */
private data class MediaPresentation(
    val overallState: String,
    val badgeText: FtLabel,
    val tone: String,
    val statusText: FtLabel,
    val summaryText: FtLabel,
    val detailText: FtLabel,
    val sourceNote: FtLabel,
    val licenseNote: FtLabel,
    val cover: MediaAssetInfo,
    val video: MediaAssetInfo,
)

/** 源 `fillPresentationCopy` 写入的五个字段。 */
private data class MediaPresentationCopy(
    val badgeText: FtLabel,
    val tone: String,
    val statusText: FtLabel,
    val summaryText: FtLabel,
    val detailText: FtLabel,
)

private object MediaResolver {

    fun resolve(
        coverUrl: String,
        videoUrl: String,
        videoPlaceholder: FtLabel,
        metadata: MediaMetadata,
    ): MediaPresentation {
        val placeholder = videoPlaceholder
        val cover = resolveAsset("cover", coverUrl, placeholder, metadata)
        val video = resolveAsset("video", videoUrl, placeholder, metadata)
        val overallState = overallState(cover, video, placeholder)
        val copy = presentationCopy(overallState, placeholder)
        return MediaPresentation(
            overallState = overallState,
            badgeText = copy.badgeText,
            tone = copy.tone,
            statusText = copy.statusText,
            summaryText = copy.summaryText,
            detailText = copy.detailText,
            sourceNote = sourceNote(cover, video),
            licenseNote = licenseNote(cover, video),
            cover = cover,
            video = video,
        )
    }

    private fun resolveAsset(
        kind: String,
        url: String,
        videoPlaceholder: FtLabel,
        metadata: MediaMetadata,
    ): MediaAssetInfo {
        val normalizedUrl = url.trim()
        val scheme = schemeOf(normalizedUrl)
        val hasReference = normalizedUrl.isNotEmpty()
        val canRenderInline = canRenderInline(kind, normalizedUrl, scheme)
        val state = assetState(hasReference, canRenderInline)
        val explicitSourceLabel = if (kind == "cover") {
            metadata.coverSourceLabel.trim()
        } else {
            metadata.videoSourceLabel.trim()
        }
        val explicitLicenseLabel = metadata.mediaLicenseText.trim()
        return MediaAssetInfo(
            originalUrl = normalizedUrl,
            resolvedUrl = if (canRenderInline) normalizedUrl else "",
            scheme = scheme,
            state = state,
            stateText = assetStateText(kind, state),
            primaryText = assetPrimaryText(kind, state),
            secondaryText = assetSecondaryText(kind, state, scheme, videoPlaceholder),
            sourceLabel = sourceLabel(explicitSourceLabel, normalizedUrl, scheme),
            licenseLabel = licenseLabel(explicitLicenseLabel, normalizedUrl, scheme),
            hasReference = hasReference,
            canRenderInline = canRenderInline,
        )
    }

    private fun presentationCopy(
        overallState: String,
        videoPlaceholder: FtLabel,
    ): MediaPresentationCopy = when (overallState) {
        "playable" -> MediaPresentationCopy(
            badgeText = resLabel(R.string.exercise_media_badge_playable),
            tone = "primary",
            statusText = resLabel(R.string.exercise_media_status_playable),
            summaryText = resLabel(R.string.exercise_media_summary_playable),
            detailText = resLabel(R.string.exercise_media_detail_playable),
        )

        "declared" -> MediaPresentationCopy(
            badgeText = resLabel(R.string.exercise_media_badge_declared),
            tone = "accent",
            statusText = resLabel(R.string.exercise_media_status_declared),
            summaryText = resLabel(R.string.exercise_media_summary_declared),
            detailText = resLabel(R.string.exercise_media_detail_declared),
        )

        else -> if (videoPlaceholder.isPresent) {
            MediaPresentationCopy(
                badgeText = resLabel(R.string.exercise_media_badge_placeholder),
                tone = "accent",
                statusText = resLabel(R.string.exercise_media_status_placeholder),
                summaryText = videoPlaceholder,
                detailText = resLabel(R.string.exercise_media_detail_placeholder),
            )
        } else {
            MediaPresentationCopy(
                badgeText = resLabel(R.string.exercise_media_badge_missing),
                tone = "muted",
                statusText = resLabel(R.string.exercise_media_status_missing),
                summaryText = resLabel(R.string.exercise_media_summary_missing),
                detailText = resLabel(R.string.exercise_media_detail_missing),
            )
        }
    }

    private fun overallState(
        cover: MediaAssetInfo,
        video: MediaAssetInfo,
        videoPlaceholder: FtLabel,
    ): String = when {
        video.canRenderInline -> "playable"
        cover.canRenderInline || cover.hasReference || video.hasReference -> "declared"
        videoPlaceholder.isPresent -> "placeholder"
        else -> "missing"
    }

    private fun assetState(hasReference: Boolean, canRenderInline: Boolean): String = when {
        canRenderInline -> "ready"
        hasReference -> "declared"
        else -> "missing"
    }

    private fun assetStateText(kind: String, state: String): FtLabel = when {
        kind == "cover" && state == "ready" -> resLabel(R.string.exercise_asset_cover_ready)
        kind == "cover" && state == "declared" -> resLabel(R.string.exercise_asset_cover_declared)
        kind == "cover" -> resLabel(R.string.exercise_asset_cover_missing)
        state == "ready" -> resLabel(R.string.exercise_asset_video_ready)
        state == "declared" -> resLabel(R.string.exercise_asset_video_declared)
        else -> resLabel(R.string.exercise_asset_video_missing)
    }

    private fun assetPrimaryText(kind: String, state: String): FtLabel = when {
        kind == "cover" && state == "ready" -> resLabel(R.string.exercise_asset_cover_primary_ready)
        kind == "cover" && state == "declared" -> resLabel(R.string.exercise_asset_cover_primary_declared)
        kind == "cover" -> resLabel(R.string.exercise_asset_cover_primary_missing)
        state == "ready" -> resLabel(R.string.exercise_asset_video_primary_ready)
        state == "declared" -> resLabel(R.string.exercise_asset_video_primary_declared)
        else -> resLabel(R.string.exercise_asset_video_primary_missing)
    }

    private fun assetSecondaryText(
        kind: String,
        state: String,
        scheme: String,
        videoPlaceholder: FtLabel,
    ): FtLabel = when {
        state == "ready" -> if (kind == "cover") {
            resLabel(R.string.exercise_asset_cover_secondary_ready)
        } else {
            resLabel(R.string.exercise_asset_video_secondary_ready)
        }

        state == "declared" && scheme == "local" -> if (kind == "cover") {
            resLabel(R.string.exercise_asset_cover_secondary_local)
        } else {
            resLabel(R.string.exercise_asset_video_secondary_local)
        }

        state == "declared" -> resLabel(R.string.exercise_asset_secondary_declared)
        kind == "video" && videoPlaceholder.isPresent -> videoPlaceholder
        else -> resLabel(R.string.exercise_asset_secondary_tail)
    }

    private fun sourceLabel(explicitLabel: String, url: String, scheme: String): FtLabel = when {
        explicitLabel.isNotEmpty() -> rawLabel(explicitLabel)
        url.isEmpty() -> resLabel(R.string.exercise_source_missing)
        scheme == "local" -> resLabel(R.string.exercise_source_local)
        scheme == "http" || scheme == "https" -> resLabel(R.string.exercise_source_remote)
        scheme == "file" -> resLabel(R.string.exercise_source_file)
        else -> resLabel(R.string.exercise_source_custom)
    }

    private fun licenseLabel(explicitLabel: String, url: String, scheme: String): FtLabel = when {
        explicitLabel.isNotEmpty() -> rawLabel(explicitLabel)
        url.isEmpty() -> resLabel(R.string.exercise_license_missing)
        scheme == "local" -> resLabel(R.string.exercise_license_local)
        scheme == "http" || scheme == "https" -> resLabel(R.string.exercise_license_remote)
        scheme == "file" -> resLabel(R.string.exercise_license_file)
        else -> resLabel(R.string.exercise_license_custom)
    }

    private fun sourceNote(cover: MediaAssetInfo, video: MediaAssetInfo): FtLabel = when {
        cover.hasReference && video.hasReference -> if (cover.sourceLabel == video.sourceLabel) {
            cover.sourceLabel
        } else {
            resLabel(R.string.exercise_note_source_both, cover.sourceLabel, video.sourceLabel)
        }

        video.hasReference -> resLabel(R.string.exercise_note_source_video, video.sourceLabel)
        cover.hasReference -> resLabel(R.string.exercise_note_source_cover, cover.sourceLabel)
        else -> resLabel(R.string.exercise_note_source_none)
    }

    private fun licenseNote(cover: MediaAssetInfo, video: MediaAssetInfo): FtLabel = when {
        cover.hasReference && video.hasReference -> if (cover.licenseLabel == video.licenseLabel) {
            cover.licenseLabel
        } else {
            resLabel(R.string.exercise_note_license_both, cover.licenseLabel, video.licenseLabel)
        }

        video.hasReference -> resLabel(R.string.exercise_note_license_video, video.licenseLabel)
        cover.hasReference -> resLabel(R.string.exercise_note_license_cover, cover.licenseLabel)
        else -> resLabel(R.string.exercise_note_license_none)
    }

    private fun canRenderInline(kind: String, url: String, scheme: String): Boolean {
        if (url.isEmpty()) {
            return false
        }
        if (scheme == "http" || scheme == "https" || scheme == "file") {
            return true
        }
        if (kind == "cover" && isAbsoluteFilePath(url)) {
            return true
        }
        return false
    }

    private fun isAbsoluteFilePath(url: String): Boolean {
        if (url.length < 3) {
            return false
        }
        val driveLetter = url.substring(0, 1)
        val separatorText = url.substring(1, 3)
        return isAsciiLetter(driveLetter) && separatorText == ":\\"
    }

    private fun isAsciiLetter(value: String): Boolean {
        if (value.length != 1) {
            return false
        }
        val code = value[0].code
        return (code in 65..90) || (code in 97..122)
    }

    private fun schemeOf(url: String): String {
        val index = url.indexOf("://")
        if (index <= 0) {
            return ""
        }
        return url.substring(0, index).lowercase()
    }
}

// ── 屏内文案 helper ─────────────────────────────────────────────────────────
//
// 逐条对齐源 `getMediaPreviewLabel`（L186）、`getAssetAvailabilityLabel`（L199）、
// `getMediaToneColor`（L166）、`getMediaToneBackgroundColor`（L176）、
// `getStatusPanelColor/Background/BorderColor`（L219-247）、`getStatusEmptyText`（L249）。

private fun mediaPreviewLabel(media: MediaPresentation): FtLabel = when {
    media.cover.canRenderInline -> resLabel(R.string.exercise_preview_cover)
    media.video.canRenderInline -> resLabel(R.string.exercise_preview_video)
    media.cover.hasReference || media.video.hasReference -> resLabel(R.string.exercise_preview_reference)
    else -> resLabel(R.string.exercise_preview_missing)
}

private fun assetAvailabilityLabel(asset: MediaAssetInfo): FtLabel = when {
    asset.canRenderInline -> resLabel(R.string.exercise_availability_inline)
    asset.hasReference -> resLabel(R.string.exercise_availability_reference)
    else -> resLabel(R.string.exercise_availability_missing)
}

private fun mediaToneColor(tone: String): Color = when (tone) {
    "primary" -> FtColor.accent
    "accent" -> AccentGold
    else -> TextDisabled
}

private fun mediaToneBackground(tone: String): Color = when (tone) {
    "primary" -> OverlayPrimary
    "accent" -> OverlayAccent
    else -> BorderSubtle
}

private fun statusToneColor(tone: String): Color = when (tone) {
    "warning" -> AccentGold
    "error" -> ErrorColor
    else -> InfoColor
}

private fun statusToneBackground(tone: String): Color = when (tone) {
    "warning" -> WarningBg
    "error" -> ErrorBg
    else -> InfoBg
}

private fun statusEmptyText(tone: String): FtLabel = when (tone) {
    "warning" -> resLabel(R.string.exercise_status_empty_warning)
    "error" -> resLabel(R.string.exercise_status_empty_error)
    else -> resLabel(R.string.exercise_status_empty_info)
}

// ── 屏内色值 ────────────────────────────────────────────────────────────────
//
// 取自鸿蒙 `common/styles/DesignTokens.ets`（与原型各屏 `:root` 不是同一套令牌）；
// `rgba(...)` 按 `FtColorUtil.rgba` 换算（AA = round(alpha × 255)）。

/** `ColorTokens.BG_PRIMARY`（源页 `.backgroundColor` L452） */
private val BgPrimary = Color(0xFF09100F)

/** `ColorTokens.SURFACE_STRONG`（AppCard `panel` 底） */
private val SurfaceStrong = Color(0xFF20332E)

/** `ColorTokens.SURFACE_PRIMARY`（AppCard `outlined` 底） */
private val SurfacePrimary = Color(0xFF16211F)

/** `ColorTokens.SURFACE_SECONDARY`（训练焦点内嵌块底） */
private val SurfaceSecondary = Color(0xFF1B2A27)

/** `ColorTokens.BG_ELEVATED`（瓦片 / 替代动作条目底） */
private val BgElevated = Color(0xFF1A2825)

/** `ColorTokens.SURFACE_ELEVATED`（器械标签 / 替代序号底） */
private val SurfaceElevated = Color(0xFF20332E)

/** `ColorTokens.BORDER_STRONG` `rgba(42,57,52,.92)` */
private val BorderStrong = Color(FtColorUtil.rgba(42, 57, 52, 0.92))

/** `ColorTokens.BORDER_SUBTLE` `rgba(42,57,52,.55)` */
private val BorderSubtle = Color(FtColorUtil.rgba(42, 57, 52, 0.55))

/** `ColorTokens.DIVIDER` `rgba(42,57,52,.48)` */
private val DividerColor = Color(FtColorUtil.rgba(42, 57, 52, 0.48))

/** `ColorTokens.TEXT_SECONDARY` */
private val TextSecondary = Color(0xFFA3B3AD)

/** `ColorTokens.TEXT_TERTIARY` */
private val TextTertiary = Color(0xFF6E8078)

/** `ColorTokens.TEXT_DISABLED` */
private val TextDisabled = Color(0xFF53625D)

/** `ColorTokens.ACCENT_GOLD`（同时是 `ACCENT` / `WARNING` 的取值） */
private val AccentGold = Color(0xFFB59869)

/** `ColorTokens.WARNING_BG` `rgba(181,152,105,.16)` */
private val WarningBg = Color(FtColorUtil.rgba(181, 152, 105, 0.16))

/** `ColorTokens.ERROR` */
private val ErrorColor = Color(0xFFD77C78)

/** `ColorTokens.ERROR_BG` `rgba(215,124,120,.16)` */
private val ErrorBg = Color(FtColorUtil.rgba(215, 124, 120, 0.16))

/** `ColorTokens.INFO` */
private val InfoColor = Color(0xFF7E8F96)

/** `ColorTokens.INFO_BG` `rgba(126,143,150,.16)` */
private val InfoBg = Color(FtColorUtil.rgba(126, 143, 150, 0.16))

/** `ColorTokens.OVERLAY_PRIMARY` `rgba(69,201,161,.12)` */
private val OverlayPrimary = Color(FtColorUtil.rgba(69, 201, 161, 0.12))

/** `ColorTokens.OVERLAY_ACCENT` `rgba(181,152,105,.14)` */
private val OverlayAccent = Color(FtColorUtil.rgba(181, 152, 105, 0.14))

/** `ShadowTokens.MD.color` `rgba(3,8,8,.34)` */
private val CardShadow = Color(FtColorUtil.rgba(3, 8, 8, 0.34))
