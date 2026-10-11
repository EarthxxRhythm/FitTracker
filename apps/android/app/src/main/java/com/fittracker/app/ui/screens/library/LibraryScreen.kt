package com.fittracker.app.ui.screens.library

import android.os.Build
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
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
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.data.service.ContentRepository
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import coil.ImageLoader
import coil.compose.SubcomposeAsyncImage
import coil.decode.GifDecoder
import coil.decode.ImageDecoderDecoder
import kotlinx.coroutines.delay

/**
 * 动作库屏（原型 `fittracker-exercise-library.html` 的 `screen-exercise-library` 帧，L554-628）。
 *
 * 画布 390×844 直绘（`.phone { width:390px; height:844px }` L123-126 + `.st-frame { inset:0 }` L142）。
 * **无底栏**（非 Tab 一级路由，见 [com.fittracker.app.nav.FtRoutes]）。
 *
 * 版式来源（原型 CSS 行号）：
 * `.st-top`/`.st-back`/`.st-title` L149-173 · `.st-scroll`/`.st-scroll-inner`/`.st-foot-note` L175-184 ·
 * `.lib-fav-filter` L187-206 · `.lib-search` L208-234 · `.cat-row`/`.cat-chip` L236-258 ·
 * `.eq-group`/`.eq-title` L260-269 · `.lib-grid`/`.lib-card` L272-291 · `.lib-media`/`.lib-fav` L293-333 ·
 * `.lib-body`/`.lib-card-name` L335-344 · `.lib-empty*` L346-352 ·
 * `.lib-sheet*` L354-469 · `.st-toast` L471-490。
 *
 * 态与交互（原型脚本 L694-898）：
 * 搜索/部位/肌群/收藏四路过滤实时重算（`render()` L732-765）；点卡片弹动作详情底部弹层
 * （`openDetail` L767-788）；心形切收藏时**不**触发卡片（`data-fav` 分支先行，L837-843）；
 * 主按钮点击后置灰 1600ms（L885-886）并弹浮层（L887）；返回键导航到 `profile`（`FT_APP.routes` L897）。
 *
 * 三处**以源码为准**的取舍：
 * 1. 原型弹层的入场位移动画（`transform: translateY(100%)→0`，L375-381）与遮罩淡入（L357-363）
 *    **未复刻**——与同仓 `ReviewScreen.GoalModal` 既有取舍一致（弹层直接出现）。
 * 2. 演示 GIF（`assets/exercise-gifs/<id>.gif`，L705）**已接入**（W2-2）：卡片（4/3）与详情弹层（16/9）
 *    命中素材时用 Coil 播放动图（见 [ExerciseGif]）；未命中 / 加载失败一律回落**同尺寸占位块**
 *    （媒体的 `aspect-ratio` 盒 + 原型自带的居中线稿图标，见 [MediaPlaceholder]），不动布局。
 * 3. 主按钮的 `:active { scale(.985) }`（L468）未复刻（同仓仅 `CompleteScreen` 的 CTA 做了按压缩放）。
 */
@Composable
fun LibraryScreen(
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var part by remember { mutableStateOf(FtLibraryModel.ALL_PARTS) }
    var muscle by remember { mutableStateOf(FtLibraryModel.ALL_MUSCLES) }
    var query by remember { mutableStateOf("") }
    var favOnly by remember { mutableStateOf(false) }
    var favorites by remember { mutableStateOf(emptySet<String>()) }
    var detail by remember { mutableStateOf<FtLibraryExercise?>(null) }
    var addedToPlan by remember { mutableStateOf(false) }
    var toast by remember { mutableStateOf<String?>(null) }

    // Wave 4 资料域接线：动作库接 [ContentRepository]（assets 真实 50 动作）。
    // 装载失败时保持原型样例 [FtLibraryModel.EXERCISES]；动作 GIF 经 [FtLibraryModel.gifAssetFor]
    // 反查（命中即播放），未命中素材回落同尺寸占位块（见本文件头取舍 2）。
    val context = LocalContext.current
    val resources = LocalResources.current
    var allExercises by remember { mutableStateOf(FtLibraryModel.EXERCISES) }
    LaunchedEffect(Unit) {
        runCatching { ContentRepository.load(context) }
        if (ContentRepository.isLoaded) {
            val mapped = ContentRepository.exercises().map { FtLibraryModel.toLibraryExercise(it) }
            if (mapped.isNotEmpty()) allExercises = mapped
        }
    }

    // 原型 `showToast` 的 `setTimeout(…, 1900)`（L692）
    LaunchedEffect(toast) {
        if (toast != null) {
            delay(1900)
            toast = null
        }
    }
    // 主按钮置灰 1600ms 后复原（原型 L886）
    LaunchedEffect(addedToPlan) {
        if (addedToPlan) {
            delay(1600)
            addedToPlan = false
        }
    }

    val list = FtLibraryModel.filterSource(allExercises, part, muscle, favOnly, favorites, query)
    val groups = groupExercises(list)

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(FtColor.ink0), // `.st-frame { background: var(--ink-0) }`
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            TopBar(
                favOnly = favOnly,
                onBack = onBack, // 原型 FT_APP.routes：父屏 profile
                onToggleFav = { favOnly = !favOnly },
            )

            // `.st-scroll > .st-scroll-inner`：gap 14、内边距 8/16/30
            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 30.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                item(key = "search") {
                    SearchBar(query = query, onQuery = { query = it })
                }
                item(key = "parts") {
                    CategoryRow(
                        ids = FtLibraryModel.PART_IDS,
                        selected = part,
                        labelOf = { id ->
                            if (id == FtLibraryModel.ALL_PARTS) {
                                stringResource(FtLibraryModel.PART_ALL_RES)
                            } else {
                                ContentRepository.getMuscleName(id)
                            }
                        },
                        onSelect = {
                            part = it
                            muscle = FtLibraryModel.ALL_MUSCLES // 原型切部位时重置肌群（L801）
                        },
                    )
                }
                if (part != FtLibraryModel.ALL_PARTS) {
                    item(key = "muscles") {
                        CategoryRow(
                            ids = FtLibraryModel.muscleChipsFrom(part, allExercises),
                            selected = muscle,
                            labelOf = { id ->
                                if (id == FtLibraryModel.ALL_MUSCLES) {
                                    stringResource(FtLibraryModel.MUSCLE_ALL_RES)
                                } else {
                                    ContentRepository.getMuscleName(id)
                                }
                            },
                            onSelect = { muscle = it },
                            small = true,
                            // `.cat-row[data-muscle-row] { margin-top: -6px }`
                            modifier = Modifier.offset(y = (-6).dp),
                        )
                    }
                }
                if (list.isEmpty()) {
                    item(key = "empty") {
                        // 空态上方的额外 14px：原型此时 `.lib-groups` 为空 div，仍占一份 gap（L755-756）
                        EmptyState(
                            favOnly = favOnly,
                            query = query,
                            modifier = Modifier.padding(top = 14.dp),
                        )
                    }
                } else {
                    // `.lib-groups` 在原型里是**无样式 div**——3 个 `.eq-group` 直接堆叠、**组间无间隙**；
                    // `.st-scroll-inner` 的 `gap: 14px` 只作用于它与搜索/筛选/foot 之间。
                    // 故三组合并为一个 item：组间 0，整块与相邻 item 保持 14
                    // （否则每组各多 14px，累积漂移——library 验收实测 +15~19px/组）。
                    item(key = "groups") {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            groups.forEach { group ->
                                ExerciseGroupSection(
                                    group = group,
                                    favorites = favorites,
                                    onToggleFav = { id ->
                                        favorites = if (id in favorites) favorites - id else favorites + id
                                    },
                                    onOpen = { detail = it },
                                )
                            }
                        }
                    }
                }
                item(key = "foot") { FootNote() }
            }
        }

        detail?.let { exercise ->
            DetailSheet(
                exercise = exercise,
                addedToPlan = addedToPlan,
                onClose = { detail = null },
                onAddToPlan = {
                    addedToPlan = true
                    toast = resources.getString(FtLibraryModel.TOAST_ADDED_RES, exercise.name)
                },
            )
        }

        // `.st-toast { bottom: 30px; left: 50% }`
        ScreenToast(
            message = toast,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 30.dp),
        )
    }
}

// ── 页头 ────────────────────────────────────────────────────────

/** `.st-top` L149-173：50/16/12 内边距、44px 返回键、居中标题、44px 收藏筛选。 */
@Composable
private fun TopBar(favOnly: Boolean, onBack: () -> Unit, onToggleFav: () -> Unit) {
    val favFilterDesc = stringResource(R.string.library_a11y_fav_filter)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 16.dp, top = 50.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp), // `.st-top { gap: 10px }`
    ) {
        CircleIconButton(
            contentDescription = stringResource(R.string.library_a11y_back), // 逐字取自原型 `.st-back` 的 aria-label（L564）
            onClick = onBack,
        ) {
            BackIcon(modifier = Modifier.size(20.dp), color = FtColor.white70)
        }

        Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
            Text(
                text = stringResource(R.string.library_title),
                style = FtType.natural(18f, 700),
                color = FtColor.txtHi,
                maxLines = 1,
            )
        }

        // 收藏筛选：`.on` 时走翡翠（原型 `.lib-fav-filter.on` L205）
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(FtShape.pill)
                .background(if (favOnly) FtColor.accent12 else CircleGlassFill)
                .border(1.dp, if (favOnly) ChipActiveBorder else CircleGlassBorder, FtShape.pill)
                .semantics { contentDescription = favFilterDesc } // 原型 aria-label（L568）
                .clickableNoRipple(onClick = onToggleFav),
            contentAlignment = Alignment.Center,
        ) {
            HeartIcon(
                filled = favOnly,
                modifier = Modifier.size(20.dp),
                color = if (favOnly) FtColor.accent else FtColor.white70,
            )
        }
    }
}

/** `.st-back` / `.lib-fav-filter` 共用的 44×44 圆形玻璃钮。 */
@Composable
private fun CircleIconButton(
    contentDescription: String,
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .clip(FtShape.pill)
            .background(CircleGlassFill) // rgba(255,255,255,.047)
            .border(1.dp, CircleGlassBorder, FtShape.pill) // rgba(255,255,255,.08)
            .semantics { this.contentDescription = contentDescription }
            .clickableNoRipple(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}

// ── 搜索栏 ──────────────────────────────────────────────────────

/** `.lib-search` L208-234：44 高、圆角 14、左侧图标 + 无边框输入。 */
@Composable
private fun SearchBar(query: String, onQuery: (String) -> Unit) {
    var focused by remember { mutableStateOf(false) }
    val searchDesc = stringResource(R.string.library_a11y_search)
    val shape = RoundedCornerShape(14.dp)
    val ring = 3.dp
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(44.dp)
            .drawBehind {
                // `.lib-search:focus-within { box-shadow: 0 0 0 3px rgba(80,236,167,.22) }`（L227）
                if (focused) {
                    val inset = ring.toPx()
                    drawRoundRect(
                        color = SearchRing,
                        topLeft = Offset(-inset, -inset),
                        size = Size(size.width + inset * 2f, size.height + inset * 2f),
                        cornerRadius = CornerRadius(17.dp.toPx(), 17.dp.toPx()), // 14 + 3
                        style = Stroke(width = inset),
                    )
                }
            }
            .clip(shape)
            .background(SearchFill) // rgba(255,255,255,.04)
            .border(1.dp, if (focused) FtColor.accent else FtColor.line10, shape)
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(9.dp), // `.lib-search { gap: 9px }`
    ) {
        SearchIcon(modifier = Modifier.size(17.dp), color = FtColor.white40)
        BasicTextField(
            value = query,
            onValueChange = onQuery,
            modifier = Modifier
                .weight(1f)
                .onFocusChanged { focused = it.isFocused }
                .semantics { contentDescription = searchDesc }, // 原型 aria-label（L577）
            singleLine = true,
            textStyle = TextStyle(
                fontFamily = FtType.cn,
                fontSize = 14.sp,
                fontWeight = FontWeight.Normal,
                color = FtColor.txtHi,
            ),
            cursorBrush = SolidColor(FtColor.accent),
            decorationBox = { inner ->
                Box(contentAlignment = Alignment.CenterStart) {
                    if (query.isEmpty()) {
                        Text(
                            text = stringResource(FtLibraryModel.SEARCH_HINT_RES),
                            style = FtType.natural(14f),
                            color = FtColor.white40,
                        )
                    }
                    inner()
                }
            },
        )
    }
}

// ── 筛选条 ──────────────────────────────────────────────────────

/**
 * `.cat-row` L236-258：横向滚动的胶囊筛选条。
 *
 * 部位行与肌群行共用；肌群行按 [small] 走更小的内边距与字号（原型
 * `.cat-row[data-muscle-row] .cat-chip { padding: 6px 12px; font-size: 12px }`，L257）。
 *
 * [ids] 是**匹配键**（部位 / 肌群 id 或哨兵）；[labelOf] 把它解析成展示名——
 * 哨兵 → 资源（[FtLibraryModel.PART_ALL_RES] / [FtLibraryModel.MUSCLE_ALL_RES]），
 * 肌群 id → `ContentRepository.getMuscleName`（随当前语言变化）。
 */
@Composable
private fun CategoryRow(
    ids: List<String>,
    selected: String,
    labelOf: @Composable (String) -> String,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
    small: Boolean = false,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .offset(x = (-2).dp) // `.cat-row { margin: 0 -2px }`
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 2.dp, vertical = 2.dp), // `.cat-row { padding: 2px }`
        horizontalArrangement = Arrangement.spacedBy(8.dp), // `.cat-row { gap: 8px }`
    ) {
        ids.forEach { id ->
            val active = id == selected
            Box(
                modifier = Modifier
                    .clip(FtShape.pill)
                    .background(if (active) ChipActiveFill else SearchFill)
                    .border(1.dp, if (active) ChipActiveBorder else FtColor.line10, FtShape.pill)
                    .clickableNoRipple(onClick = { onSelect(id) })
                    .padding(
                        horizontal = if (small) 12.dp else 14.dp,
                        vertical = if (small) 6.dp else 8.dp,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = labelOf(id),
                    // `.cat-chip.active { font-weight: 600 }`（L255），默认 500
                    style = FtType.natural(if (small) 12f else 13f, if (active) 600 else 500),
                    color = if (active) FtColor.accent else FtColor.white70,
                    maxLines = 1,
                )
            }
        }
    }
}

// ── 分组与卡片 ──────────────────────────────────────────────────

/** `.eq-group` L260-269 + `.lib-grid` L272：分组标题 + 三列卡片网格。 */
@Composable
private fun ExerciseGroupSection(
    group: FtLibraryGroup,
    favorites: Set<String>,
    onToggleFav: (String) -> Unit,
    onOpen: (FtLibraryExercise) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp), // `.eq-group { gap: 10px }`
    ) {
        Text(
            text = group.equipment,
            style = FtType.natural(14f, 700), // `.eq-title`
            color = FtColor.txtHi,
        )
        // `grid-template-columns: repeat(3, 1fr); gap: 10px`（L272）
        group.items.chunked(3).forEach { rowItems ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                rowItems.forEach { exercise ->
                    ExerciseCard(
                        exercise = exercise,
                        favorite = exercise.id in favorites,
                        onToggleFav = { onToggleFav(exercise.id) },
                        onOpen = { onOpen(exercise) },
                        modifier = Modifier.weight(1f),
                    )
                }
                // 补齐末行空位，使不满 3 张时卡片宽度与满行一致
                repeat(3 - rowItems.size) {
                    Box(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

/** `.lib-card` L275-291：媒体区（4/3）+ 名称条。 */
@Composable
private fun ExerciseCard(
    exercise: FtLibraryExercise,
    favorite: Boolean,
    onToggleFav: () -> Unit,
    onOpen: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(14.dp)
    val cardDesc = stringResource(R.string.library_a11y_card, exercise.name) // 原型 aria-label（L702）
    // 收藏 / 取消收藏 + 动作名（原型 aria-label，L706）
    val favDesc = stringResource(
        if (favorite) R.string.library_a11y_fav_remove else R.string.library_a11y_fav_add,
        exercise.name,
    )
    Column(
        modifier = modifier
            .clip(shape)
            .background(CardFill) // rgba(255,255,255,.031)
            .border(1.dp, FtColor.line10, shape)
            .semantics { contentDescription = cardDesc }
            .clickableNoRipple(onClick = onOpen),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(4f / 3f), // `.lib-media { aspect-ratio: 4 / 3 }`
        ) {
            ExerciseGif(
                // W2-2：命中素材播放动作 GIF（4/3），否则 / 加载失败回落占位块（原型 `.lib-media-fallback` L297-301）
                gifAsset = FtLibraryModel.gifAssetFor(exercise),
                iconSize = 30.dp,
                fill = MediaFill, // rgba(255,255,255,.04)
                contentDescription = stringResource(R.string.library_a11y_demo_gif, exercise.name),
            )
            // `.lib-fav { top:8px; right:8px; 30×30 }`
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 8.dp, end = 8.dp)
                    .size(30.dp)
                    .clip(FtShape.pill)
                    .background(if (favorite) FavChipOnFill else FavChipFill)
                    .border(1.dp, FavChipBorder, FtShape.pill)
                    .semantics {
                        // 原型 aria-label（L706）：收藏 / 取消收藏 + 动作名
                        contentDescription = favDesc
                    }
                    .clickableNoRipple(onClick = onToggleFav),
                contentAlignment = Alignment.Center,
            ) {
                HeartIcon(
                    filled = favorite,
                    modifier = Modifier.size(16.dp),
                    color = if (favorite) FtColor.accent else FtColor.white70,
                )
            }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 8.dp, end = 8.dp, top = 8.dp, bottom = 9.dp), // `.lib-body { padding: 8px 8px 9px }`
        ) {
            Text(
                text = exercise.name,
                style = FtType.natural(12f, 600).copy(lineHeight = 15.sp), // 1.25 × 12px（原型显式声明）
                color = FtColor.txtHi,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis, // `.lib-card-name { white-space: nowrap; text-overflow: ellipsis }`
            )
        }
    }
}

/** 媒体占位块：`aspect-ratio` 盒（由调用方给定）内居中一枚线稿图标。 */
@Composable
private fun MediaPlaceholder(iconSize: androidx.compose.ui.unit.Dp, fill: Color) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(fill),
        contentAlignment = Alignment.Center,
    ) {
        WorkoutIcon(modifier = Modifier.size(iconSize), color = FtColor.white32)
    }
}

/**
 * 动作 GIF（W2-2）：命中素材时用 Coil 播放动画 GIF，加载中 / 失败 / 无素材一律回落 [fallback]。
 *
 * Coil 2 的 GIF 解码需**显式注册**（已核 `coil-gif` AAR：无 ServiceLoader / androidx.startup 声明），
 * 故自建 [ImageLoader]：API 28+ 用 [ImageDecoderDecoder]，24-27 回落 [GifDecoder]（基于 Movie）。
 */
@Composable
internal fun ExerciseGif(
    gifAsset: String?,
    iconSize: androidx.compose.ui.unit.Dp,
    fill: Color,
    contentDescription: String? = null,
    contentScale: ContentScale = ContentScale.Crop,
    fallback: @Composable () -> Unit = { MediaPlaceholder(iconSize, fill) },
) {
    if (gifAsset == null) {
        fallback()
        return
    }
    SubcomposeAsyncImage(
        model = "file:///android_asset/$gifAsset",
        imageLoader = rememberExerciseGifImageLoader(),
        contentDescription = contentDescription,
        contentScale = contentScale,
        modifier = Modifier.fillMaxSize(),
        loading = { fallback() },
        error = { fallback() },
    )
}

/** 进程内复用的 GIF 感知 [ImageLoader]（API 28+ 优先 ImageDecoder，24-27 回落 GifDecoder）。 */
@Composable
private fun rememberExerciseGifImageLoader(): ImageLoader {
    val context = LocalContext.current
    return remember(context) {
        ImageLoader.Builder(context.applicationContext)
            .components {
                if (Build.VERSION.SDK_INT >= 28) add(ImageDecoderDecoder.Factory()) else add(GifDecoder.Factory())
            }
            .build()
    }
}

// ── 空态与页脚 ──────────────────────────────────────────────────

/** `.lib-empty` L346-352：38/20/34 内边距、居中图标 + 标题 + 提示。 */
@Composable
private fun EmptyState(favOnly: Boolean, query: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 20.dp, top = 38.dp, bottom = 34.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp), // `.lib-empty { gap: 6px }`
    ) {
        Box(
            modifier = Modifier
                .padding(bottom = 6.dp) // `.lib-empty-ic { margin-bottom: 6px }`
                .size(46.dp)
                .clip(FtShape.pill)
                .background(EmptyIconFill) // rgba(255,255,255,.05)
                .border(1.dp, FtColor.line10, FtShape.pill),
            contentAlignment = Alignment.Center,
        ) {
            LibraryIcon(modifier = Modifier.size(22.dp), color = FtColor.white40)
        }
        Text(
            text = stringResource(FtLibraryModel.emptyTitleRes(favOnly, query)),
            style = FtType.natural(14f, 600),
            color = FtColor.txtHi,
            textAlign = TextAlign.Center,
        )
        Text(
            text = stringResource(FtLibraryModel.emptyHintRes(favOnly, query)),
            style = FtType.natural(12f).copy(lineHeight = 18.sp), // 1.5 × 12px（原型显式声明）
            color = FtColor.white54,
            textAlign = TextAlign.Center,
        )
    }
}

/** `.st-foot-note` L184：居中说明文字。 */
@Composable
private fun FootNote() {
    Text(
        text = stringResource(FtLibraryModel.FOOT_NOTE_RES),
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 6.dp, end = 6.dp, top = 2.dp), // `.st-foot-note { padding: 2px 6px 0 }`
        style = FtType.natural(11f).copy(lineHeight = 17.6.sp), // 1.6 × 11px（原型显式声明）
        color = FtColor.white54,
        textAlign = TextAlign.Center,
    )
}

// ── 动作详情底部弹层 ────────────────────────────────────────────

/** `.lib-sheet` L354-469：遮罩 + 贴底卡片（`max-height: 84%`）。 */
@Composable
private fun DetailSheet(
    exercise: FtLibraryExercise,
    addedToPlan: Boolean,
    onClose: () -> Unit,
    onAddToPlan: () -> Unit,
) {
    // 难度展示：内容库给语言无关 token，展示名走资源（未知 token 回落原文）
    val levelText = FtLibraryModel.difficultyLabelRes(exercise.level)
        ?.let { stringResource(it) }
        ?: exercise.level
    val sheetDesc = stringResource(R.string.library_a11y_sheet) // 原型 `aria-label`（L607）
    val closeDesc = stringResource(R.string.library_a11y_close) // 原型 aria-label（L614）
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val maxSheetHeight = maxHeight * 0.84f // `.lib-sheet-card { max-height: 84% }`
        val shape = RoundedCornerShape(topStart = 26.dp, topEnd = 26.dp)

        // `.lib-sheet-backdrop { background: rgba(4,7,9,.55) }`
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(SheetBackdrop)
                .semantics { contentDescription = sheetDesc }
                .clickableNoRipple(onClick = onClose),
        )

        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .heightIn(max = maxSheetHeight)
                .clip(shape)
                .background(SheetFill) // #0E1316
                .border(1.dp, FtColor.line10, shape)
                // 卡片吞掉点击，避免透传到遮罩（原型只在 backdrop 命中时关闭，L857-861）
                .clickableNoRipple(onClick = {}),
        ) {
            Column(
                modifier = Modifier
                    .verticalScroll(rememberScrollState()) // `overflow-y: auto`
                    .padding(start = 18.dp, end = 18.dp, top = 12.dp, bottom = 20.dp), // `padding: 12px 18px 20px`
            ) {
                // `.lib-sheet-handle { 40×4; margin: 0 auto 16px }`
                Box(
                    modifier = Modifier
                        .padding(bottom = 16.dp)
                        .align(Alignment.CenterHorizontally)
                        .size(width = 40.dp, height = 4.dp)
                        .clip(FtShape.pill)
                        .background(HandleFill), // rgba(255,255,255,.18)
                )

                // `.lib-sheet-media`：16/9 + 演示小旗
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 16.dp) // `.lib-sheet-media { margin-bottom: 16px }`
                        .aspectRatio(16f / 9f),
                ) {
                    ExerciseGif(
                        gifAsset = FtLibraryModel.gifAssetFor(exercise),
                        iconSize = 36.dp,
                        fill = SheetMediaFill,
                        contentDescription = stringResource(R.string.library_a11y_demo_gif, exercise.name),
                    )
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopStart)
                            .padding(start = 10.dp, top = 10.dp)
                            .clip(FtShape.pill)
                            .background(FavChipFill) // rgba(7,10,12,.62)
                            .border(1.dp, FavChipBorder, FtShape.pill)
                            .padding(horizontal = 9.dp, vertical = 4.dp),
                    ) {
                        Text(
                            text = stringResource(FtLibraryModel.SHEET_MEDIA_TAG_RES),
                            style = FtType.natural(11f, 600),
                            color = FtColor.txtHi,
                            maxLines = 1,
                        )
                    }
                }

                // `.lib-sheet-head`：标题 + 关闭
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Top, // `align-items: flex-start`
                    horizontalArrangement = Arrangement.spacedBy(12.dp), // `gap: 12px`
                ) {
                    Text(
                        text = exercise.name,
                        modifier = Modifier.weight(1f),
                        style = FtType.natural(21f, 700).copy(lineHeight = 25.2.sp), // 1.2 × 21px
                        color = FtColor.txtHi,
                    )
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(FtShape.pill)
                            .background(SheetCloseFill) // rgba(255,255,255,.06)
                            .border(1.dp, FtColor.line10, FtShape.pill)
                            .semantics { contentDescription = closeDesc }
                            .clickableNoRipple(onClick = onClose),
                        contentAlignment = Alignment.Center,
                    ) {
                        CloseIcon(modifier = Modifier.size(18.dp), color = FtColor.white70)
                    }
                }

                // `.lib-sheet-tags`：部位 / 器械 / 难度（原型 L776 三枚同款标签）
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp), // `.lib-sheet-tags { margin-top: 12px }`
                        horizontalArrangement = Arrangement.spacedBy(7.dp), // `gap: 7px`
                ) {
                    listOf(exercise.part, exercise.equipment, levelText).forEach { tag ->
                        Box(
                            modifier = Modifier
                                .clip(FtShape.pill)
                                .background(FtColor.accent12) // rgba(80,236,167,.12)
                                .border(1.dp, SheetTagBorder, FtShape.pill) // rgba(80,236,167,.3)
                                .padding(horizontal = 11.dp, vertical = 4.dp),
                        ) {
                            Text(
                                text = tag,
                                style = FtType.natural(11.5f, 600),
                                color = FtColor.accent,
                                maxLines = 1,
                            )
                        }
                    }
                }

                // `.lib-sheet-rows`：三行键值（目标肌群 / 器械 / 难度）
                Column(modifier = Modifier.padding(top = 6.dp)) { // `.lib-sheet-rows { margin-top: 6px }`
                    SheetRow(
                        label = stringResource(FtLibraryModel.SHEET_ROW_LABEL_RES[0]),
                        value = exercise.muscles,
                    )
                    SheetRow(
                        label = stringResource(FtLibraryModel.SHEET_ROW_LABEL_RES[1]),
                        value = exercise.equipment,
                    )
                    SheetRow(
                        label = stringResource(FtLibraryModel.SHEET_ROW_LABEL_RES[2]),
                        value = levelText,
                    )
                }

                // `.lib-sheet-tip`：动作要点
                Text(
                    text = exercise.tip,
                    modifier = Modifier.padding(top = 14.dp), // `.lib-sheet-tip { margin-top: 14px }`
                    style = FtType.natural(13f).copy(lineHeight = 21.45.sp), // 1.65 × 13px
                    color = FtColor.white62,
                )

                // `.lib-sheet-cta`：52 高、圆角 16、翡翠底
                Box(
                    modifier = Modifier
                        .padding(top = 18.dp) // `margin-top: 18px`
                        .fillMaxWidth()
                        .height(52.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(FtColor.accent)
                        .clickableNoRipple(enabled = !addedToPlan, onClick = onAddToPlan),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = if (addedToPlan) {
                            stringResource(FtLibraryModel.SHEET_CTA_DONE_RES)
                        } else {
                            stringResource(FtLibraryModel.SHEET_CTA_RES)
                        },
                        style = FtType.natural(15f, 700).copy(letterSpacing = 0.15.sp), // .01em × 15px
                        color = FtColor.onAccent,
                    )
                }
            }
        }
    }
}

/** `.lib-sheet-row` L449-451：键左值右、底部分隔线。 */
@Composable
private fun SheetRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .drawBehind {
                // `border-bottom: 1px solid var(--hairline)`：只画底边
                drawRect(
                    color = FtColor.hairline,
                    topLeft = Offset(0f, size.height - 1.dp.toPx()),
                    size = Size(size.width, 1.dp.toPx()),
                )
            }
            .padding(vertical = 13.dp), // `padding: 13px 0`
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp), // `gap: 16px`
    ) {
        Text(
            text = label,
            style = FtType.natural(13f),
            color = FtColor.white54,
            maxLines = 1,
        )
        Box(modifier = Modifier.weight(1f))
        Text(
            text = value,
            style = FtType.natural(13f, 600),
            color = FtColor.txtHi,
            textAlign = TextAlign.End,
            maxLines = 2,
        )
    }
}

// ── 浮层提示 ────────────────────────────────────────────────────

/** `.st-toast` L471-490：底部居中胶囊，180ms 淡入 + 上移 10px。 */
@Composable
private fun ScreenToast(message: String?, modifier: Modifier = Modifier) {
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
                .background(ToastFill) // rgba(13,17,23,.94)
                .border(1.dp, FtColor.line10, FtShape.pill)
                .padding(horizontal = 16.dp, vertical = 10.dp), // `padding: 10px 16px`
        ) {
            Text(
                text = shown,
                style = FtType.natural(13f).copy(lineHeight = 18.2.sp), // 1.4 × 13px（原型显式声明）
                color = FtColor.txtHi,
                textAlign = TextAlign.Center,
            )
        }
    }
}

// ── 图标（逐字取自本文件 `<symbol>`，L511-539） ──────────────────
//
// 与 `ui/components/FtIcons.kt` 里的四个图标机制不同：那个文件承载的是欢迎页的
// 图标；本屏的六个符号只在本 HTML 内定义，按「同一抽象第三次出现才提取」的纪律
// 暂留屏内私有实现。

private const val ICON_VIEW = 24f

/** 返回（原型 `#i-back`，L513-515）：`M15.5 5 8.5 12l7 7`，描边 1.8、圆头圆角。 */
@Composable
private fun BackIcon(modifier: Modifier = Modifier, color: Color = Color.Unspecified) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val p = Path().apply {
            moveTo(15.5f * k, 5f * k)
            lineTo(8.5f * k, 12f * k)
            lineTo(15.5f * k, 19f * k)
        }
        drawPath(p, color, style = Stroke(1.8f * k, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

/** 搜索（原型 `#i-search`，L516-519）：圆 r6.5 + 柄 `m16 16 4.5 4.5`，描边 1.8。 */
@Composable
private fun SearchIcon(modifier: Modifier = Modifier, color: Color = Color.Unspecified) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        drawCircle(color, radius = 6.5f * k, center = Offset(11f * k, 11f * k), style = Stroke(1.8f * k))
        val p = Path().apply {
            moveTo(16f * k, 16f * k)
            lineTo(20.5f * k, 20.5f * k)
        }
        drawPath(p, color, style = Stroke(1.8f * k, cap = StrokeCap.Round))
    }
}

/** 关闭（原型 `#i-close`，L520-522）：`M6 6l12 12M18 6 6 18`，描边 2。 */
@Composable
private fun CloseIcon(modifier: Modifier = Modifier, color: Color = Color.Unspecified) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val p = Path().apply {
            moveTo(6f * k, 6f * k); lineTo(18f * k, 18f * k)
            moveTo(18f * k, 6f * k); lineTo(6f * k, 18f * k)
        }
        drawPath(p, color, style = Stroke(2f * k, cap = StrokeCap.Round))
    }
}

/**
 * 心形（原型 `#i-heart` L523-525 / `#i-heart-fill` L526-528）。
 *
 * 路径由两条**圆弧**与两段三次贝塞尔组成：`M12 20.5 S4 15.2 4 9.9 A4.4 4.4 0 0 1 12 6.9
 * a4.4 4.4 0 0 1 8 3 c0 5.3-8 10.6-8 10.6 z`。原型用 SVG 端点式圆弧语法，
 * 此处按半径 4.4 反解出圆心与起止角，改写成 Compose 的 `arcTo(rect, 起始角, 扫过角)`：
 * 左弧圆心 (8.369935, 9.386526)、起始角 173.29°、扫过 +152.33°；
 * 右弧为左弧关于 x=12 的镜像，圆心 (15.630065, 9.386526)、起始角 214.38°、扫过 +152.33°。
 */
@Composable
private fun HeartIcon(
    filled: Boolean,
    modifier: Modifier = Modifier,
    color: Color = Color.Unspecified,
) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        fun x(v: Float) = v * k
        fun y(v: Float) = v * k
        val r = 4.4f * k
        val path = Path().apply {
            moveTo(x(12f), y(20.5f))
            // `S4 15.2 4 9.9`：前一条命令是 M，首控制点与当前点重合
            cubicTo(x(12f), y(20.5f), x(4f), y(15.2f), x(4f), y(9.9f))
            arcTo(arcRect(x(8.369935f), y(9.386526f), r), 173.29f, 152.33f, false)
            arcTo(arcRect(x(15.630065f), y(9.386526f), r), 214.38f, 152.33f, false)
            // `c0 5.3-8 10.6-8 10.6`：回到心尖
            cubicTo(x(20f), y(15.2f), x(12f), y(20.5f), x(12f), y(20.5f))
            close()
        }
        drawPath(
            path = path,
            color = color,
            style = Stroke(width = 1.8f * k, join = StrokeJoin.Round),
        )
        if (filled) drawPath(path, color)
    }
}

/** 由圆心与半径构造圆弧包围盒。 */
private fun arcRect(cx: Float, cy: Float, r: Float) =
    androidx.compose.ui.geometry.Rect(left = cx - r, top = cy - r, right = cx + r, bottom = cy + r)

/** 动作库占位（原型 `#i-library`，L529-534）：四个 rx2 圆角方块，描边 1.8。 */
@Composable
private fun LibraryIcon(modifier: Modifier = Modifier, color: Color = Color.Unspecified) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val w = 7f * k
        val cr = CornerRadius(2f * k, 2f * k)
        listOf(4f to 4f, 13f to 4f, 4f to 13f, 13f to 13f).forEach { (lx, ly) ->
            drawRoundRect(
                color = color,
                topLeft = Offset(lx * k, ly * k),
                size = Size(w, w),
                cornerRadius = cr,
                style = Stroke(1.8f * k),
            )
        }
    }
}

/**
 * 训练握铃（原型 `#i-workout`，L535-537）：五笔 `M7 5.5v13M17 5.5v13M7 12h10M3.5 9v6M20.5 9v6`，
 * 描边 2、圆头。
 */
@Composable
private fun WorkoutIcon(modifier: Modifier = Modifier, color: Color = Color.Unspecified) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val w = 2f * k
        fun line(x1: Float, y1: Float, x2: Float, y2: Float) =
            drawLine(color, Offset(x1 * k, y1 * k), Offset(x2 * k, y2 * k), strokeWidth = w, cap = StrokeCap.Round)
        line(7f, 5.5f, 7f, 18.5f)
        line(17f, 5.5f, 17f, 18.5f)
        line(7f, 12f, 17f, 12f)
        line(3.5f, 9f, 3.5f, 15f)
        line(20.5f, 9f, 20.5f, 15f)
    }
}

// ── 屏内常量与色值 ──────────────────────────────────────────────
//
// 换算规则 AA = round(alpha × 255)。同值令牌（line-10 / accent-12 / white70 等）直接用 FtColor。

/** `.lib-card` / Card Surface 底 `rgba(255,255,255,.031)` → round(7.905) = 8 = 0x08 */
private val CardFill = Color(0x08FFFFFF)

/** `.lib-search` / `.cat-chip` 底 `rgba(255,255,255,.04)` → round(10.2) = 10 = 0x0A */
private val SearchFill = Color(0x0AFFFFFF)

/** `.lib-media` 底 `rgba(255,255,255,.04)` */
private val MediaFill = Color(0x0AFFFFFF)

/** `.st-back` / `.lib-fav-filter` 底 `rgba(255,255,255,.047)` → round(11.985) = 12 = 0x0C */
private val CircleGlassFill = Color(0x0CFFFFFF)

/** `.st-back` / `.lib-fav-filter` 描边 `rgba(255,255,255,.08)` → round(20.4) = 20 = 0x14 */
private val CircleGlassBorder = Color(0x14FFFFFF)

/** `.cat-chip.active` 底 `rgba(80,236,167,.15)` → round(38.25) = 38 = 0x26 */
private val ChipActiveFill = Color(0x2650ECA7)

/** `.cat-chip.active` / `.lib-fav-filter.on` 描边 `rgba(80,236,167,.45)` → round(114.75) = 115 = 0x73 */
private val ChipActiveBorder = Color(0x7350ECA7)

/** `.lib-search:focus-within` 外圈 `rgba(80,236,167,.22)` → round(56.1) = 56 = 0x38 */
private val SearchRing = Color(0x3850ECA7)

/** `.lib-fav` 底 `rgba(7,10,12,.62)` → round(158.1) = 158 = 0x9E */
private val FavChipFill = Color(0x9E070A0C)

/** `.lib-fav.on` 底 `rgba(7,10,12,.72)` → round(183.6) = 184 = 0xB8 */
private val FavChipOnFill = Color(0xB8070A0C)

/** `.lib-fav` / `.lib-sheet-media-tag` 描边 `rgba(255,255,255,.16)` → 0x29 */
private val FavChipBorder = Color(0x29FFFFFF)

/** `.lib-empty-ic` 底 `rgba(255,255,255,.05)` → round(12.75) = 13 = 0x0D */
private val EmptyIconFill = Color(0x0DFFFFFF)

/** `.lib-sheet-backdrop` 底 `rgba(4,7,9,.55)` → round(140.25) = 140 = 0x8C */
private val SheetBackdrop = Color(0x8C040709)

/** `.lib-sheet-card` 底 `#0E1316` */
private val SheetFill = Color(0xFF0E1316)

/** `.lib-sheet-handle` 底 `rgba(255,255,255,.18)` → round(45.9) = 46 = 0x2E */
private val HandleFill = Color(0x2EFFFFFF)

/** `.lib-sheet-media` 底 `rgba(255,255,255,.045)` → round(11.475) = 11 = 0x0B */
private val SheetMediaFill = Color(0x0BFFFFFF)

/** `.lib-sheet-close` 底 `rgba(255,255,255,.06)` → round(15.3) = 15 = 0x0F */
private val SheetCloseFill = Color(0x0FFFFFFF)

/** `.lib-sheet-tag` 描边 `rgba(80,236,167,.3)` → round(76.5) = 77 = 0x4D */
private val SheetTagBorder = Color(0x4D50ECA7)

/** `.st-toast` 底 `rgba(13,17,23,.94)` → round(239.7) = 240 = 0xF0 */
private val ToastFill = Color(0xF00D1117)


// ── 真实内容适配（ContentRepository） ───────────────────────────────────
//
// 映射 / 二级肌群筛选 / 过滤三支逻辑已收编进 [FtLibraryModel]（纯函数、可单测）；
// 本文件只保留「按器械分组」——分组顺序口径与原型 `EQUIPMENT_ORDER` 不同
// （真实器械集为杠铃 / 哑铃 / 绳索 / 固定器械 / 徒手 / 弹力带）。

/** 按器械分组——顺序取清单内首次出现序（真实器械集与原型 `EQUIPMENT_ORDER` 不同）。 */
private fun groupExercises(items: List<FtLibraryExercise>): List<FtLibraryGroup> {
    val order = LinkedHashSet<String>()
    items.forEach { order.add(it.equipment) }
    return order.mapNotNull { eq ->
        val sub = items.filter { it.equipment == eq }
        if (sub.isEmpty()) null else FtLibraryGroup(eq, sub)
    }
}
