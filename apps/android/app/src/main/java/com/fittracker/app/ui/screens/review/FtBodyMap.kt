package com.fittracker.app.ui.screens.review

import android.content.Context
import android.graphics.Region
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import org.json.JSONObject

/**
 * 肌肉地图（原型 `renderBodyMap()` / `buildBodyView()`，L1637-1678）。
 *
 * 路径数据来自 `app/src/main/assets/body-paths.json`——由
 * `tools/extract-body-paths.mjs` 从原型的 `assets/opengym-ref/body-paths.js`
 * （ES module，93KB）里抽出 `male.front` / `male.back` 两个视图，去掉用不到的 female 与其它视图。
 * 重跑该脚本即可复现同一份 JSON。
 *
 * 三条实现取舍：
 * 1. **路径在解析期就归一化**（平移到 viewBox 原点），绘制期只做一次等比缩放——
 *    避免「先缩放还是先平移」在 `withTransform` 里的顺序歧义。
 * 2. **命中测试用 `android.graphics.Region.setPath`** 做精确包含判定，而不是包围盒：
 *    肌肉形状是凹多边形 + 多条子路径，包围盒会把相邻肌肉也算命中。
 * 3. 描边宽度按 SVG 语义随缩放走（在设计空间里给 2.5 / 选中 7），与原型
 *    `.bm-v path { stroke-width: 2.5px }` 一致。
 */
private val SILHOUETTE_IDS =
    listOf("head", "hair", "neck", "hands", "feet", "knees", "ankles")

/** 一组已归一化到视图空间的肌肉路径 + 用于点选的区域。 */
internal class BodyMuscle(val id: String, val path: Path, val region: Region)

/** 一个身体视图（front / back）。坐标已归一化：左上为 (0,0)，右下为 (vbW,vbH)。 */
internal class BodyView(
    val vbW: Float,
    val vbH: Float,
    val silhouettes: List<Path>,
    val muscles: List<BodyMuscle>,
)

internal object FtBodyPaths {

    @Volatile
    private var cache: Map<String, BodyView>? = null

    /** 读一次资产并缓存；解析失败时返回空表（屏内退化为不画图，不崩）。 */
    fun of(context: Context): Map<String, BodyView> {
        cache?.let { return it }
        return synchronized(this) {
            cache ?: runCatching { load(context) }.getOrDefault(emptyMap()).also { cache = it }
        }
    }

    private fun load(context: Context): Map<String, BodyView> {
        val json = context.assets.open("body-paths.json").bufferedReader().use { it.readText() }
        val root = JSONObject(json)
        return root.keys().asSequence().associateWith { parseView(root.getJSONObject(it)) }
    }

    private fun parseView(o: JSONObject): BodyView {
        // viewBox 形如 "0 95 727 1280"：minX minY 宽 高
        val vb = o.getString("vb").trim().split(Regex("\\s+")).map { it.toFloat() }
        val (minX, minY, vbW, vbH) = vb
        val p = o.getJSONObject("p")

        val silhouettes = mutableListOf<Path>()
        val muscles = mutableListOf<BodyMuscle>()
        for (group in p.keys()) {
            val arr = p.getJSONArray(group)
            for (i in 0 until arr.length()) {
                val path = normalize(PathParser().parsePathString(arr.getString(i)).toPath(), minX, minY)
                if (group in SILHOUETTE_IDS) {
                    silhouettes += path
                } else {
                    val region = Region()
                    region.setPath(
                        path.asAndroidPath(),
                        Region(-100_000, -100_000, 100_000, 100_000),
                    )
                    muscles += BodyMuscle(group, path, region)
                }
            }
        }
        return BodyView(vbW, vbH, silhouettes, muscles)
    }

    /** 平移到视图原点：后续绘制只需一次 `scale`。 */
    private fun normalize(path: Path, minX: Float, minY: Float): Path {
        if (minX != 0f || minY != 0f) {
            path.transform(Matrix().apply { translate(-minX, -minY) })
        }
        return path
    }
}

/**
 * 并排渲染 front / back 两个视图（原型 `renderBodyMap()` 依次 append 两个 `<svg>`）。
 *
 * [onSelect] 在点到某块肌肉时回调；原型里点空白不改变选中态。
 */
@Composable
internal fun BodyMapView(
    mode: MuscleMode,
    selected: String?,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val views = remember(context) { FtBodyPaths.of(context) }

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(6.dp), // `.bodymap { gap: 6px }`
    ) {
        listOf("front", "back").forEach { key ->
            val view = views[key]
            if (view != null) {
                BodyViewCanvas(view = view, mode = mode, selected = selected, onSelect = onSelect)
            }
        }
    }
}

@Composable
private fun RowScope.BodyViewCanvas(
    view: BodyView,
    mode: MuscleMode,
    selected: String?,
    onSelect: (String) -> Unit,
) {
    Canvas(
        modifier = Modifier
            .weight(1f) // `.bm-v { flex: 1 }`
            .aspectRatio(view.vbW / view.vbH) // SVG 的 width:100% + height:auto
            .pointerInput(view, mode) {
                detectTapGestures { offset ->
                    val s = size.width.toFloat() / view.vbW
                    val vx = (offset.x / s).toInt()
                    val vy = (offset.y / s).toInt()
                    // 后画的在上层——与原型 append 顺序一致，从后往前取第一个命中的
                    view.muscles.lastOrNull { it.region.contains(vx, vy) }?.let { onSelect(it.id) }
                }
            },
    ) {
        val s = size.width / view.vbW
        withTransform({ scale(s, s, Offset.Zero) }) {
            view.silhouettes.forEach { path ->
                drawPath(path, FtReviewColors.bmSil)
                drawPath(path, FtReviewColors.bmStroke, style = Stroke(FtReviewColors.BM_STROKE_W))
            }
            view.muscles.forEach { muscle ->
                val isSel = muscle.id == selected
                drawPath(
                    muscle.path,
                    FtReviewColors.muscleFill(mode, FtReviewModel.muscleLevel(mode, muscle.id)),
                )
                drawPath(
                    muscle.path,
                    if (isSel) FtReviewColors.bmSelStroke else FtReviewColors.bmStroke,
                    style = Stroke(
                        if (isSel) FtReviewColors.BM_SEL_STROKE_W else FtReviewColors.BM_STROKE_W,
                    ),
                )
            }
        }
    }
}
