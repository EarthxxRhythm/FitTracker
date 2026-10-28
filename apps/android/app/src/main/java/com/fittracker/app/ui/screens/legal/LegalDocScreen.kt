package com.fittracker.app.ui.screens.legal

import android.content.Context
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.fittracker.app.R
import com.fittracker.app.data.service.currentLanguageTag
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtType

/**
 * 法律文档屏（隐私政策 / 用户协议；规格源：鸿蒙 `features/settings/pages/LegalDocPage.ets`）。
 *
 * 路由参数 `kind`：`"privacy"`（默认）| `"agreement"`——对齐鸿蒙 `LegalDocParams` 的缺失回退语义。
 * 文档源：`assets/legal/{privacy-policy,user-agreement}.txt`（自鸿蒙 `resources/rawfile/legal/` 逐字节复制）；
 * 同目录另有英文版 `{privacy-policy,user-agreement}.en.txt`——非中文语言优先读取，文件缺失时回退中文版。
 *
 * 版式（`build()/topBar()/emptyState()` 逐值移植）：
 * - 顶栏：底 `#D10A0D12`、底边 1px `#0FFFFFFF`、padding 52/10/12/12、返回键 44（圆角 14）+
 *   标题 16 Bold 居中（weight(1)）+ 右侧 44 平衡占位；
 * - 正文：Noto Sans SC 13.5 / 行高 22 / `#C9FFFFFF`，padding 20/40/20/20，独立滚动区；
 * - 空态：标题 16 Bold + 说明 13 `#9EFFFFFF`（间距 10）。
 */
@Composable
fun LegalDocScreen(
    kind: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    // 语言标签参与 key：per-app locale（AppCompat）优先，未设置时回落系统语言（与
    // `LocaleUtil.currentLanguageTag()` 同口径）。语言切换会因 AppCompat 重建
    // Activity 而重进本屏，此处作为 key 只是把依赖显式化。
    val languageTag = currentLanguageTag()
    var docText by remember(kind, languageTag) { mutableStateOf("") }
    var loadFailed by remember(kind, languageTag) { mutableStateOf(false) }

    LaunchedEffect(kind, languageTag) {
        val basePath = if (kind == "agreement") "legal/user-agreement" else "legal/privacy-policy"
        // 非中文语言优先读 `<base>.en.txt`；该文件缺失时回退中文 `<base>.txt`
        // （回退判定靠读取结果，不预先列目录——两处读取都失败才算加载失败）。
        val localized = if (languageTag.startsWith("zh")) null else readAsset(context, "$basePath.en.txt")
        val text = localized ?: readAsset(context, "$basePath.txt")
        docText = text.orEmpty()
        loadFailed = text == null
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(FtColor.ink0), // #0B0F13
    ) {
        LegalTopBar(
            title = stringResource(if (kind == "agreement") R.string.legal_title_agreement else R.string.legal_title_privacy),
            onBack = onBack,
        )

        if (loadFailed) {
            // weight 需在父 ColumnScope 内施加（此处正处于主 Column 的 lambda 中）
            LegalEmptyState(modifier = Modifier.weight(1f))
        } else {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
            ) {
                Text(
                    text = docText,
                    style = FtType.ft(13.5f, 400, lineHeight = 22f),
                    color = Color(0xC9FFFFFF),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 20.dp, end = 20.dp, top = 20.dp, bottom = 40.dp),
                )
            }
        }
    }
}

/** 读取 `assets/` 下的文本；文件不存在或读取失败返回 `null`（调用方据此回退 / 展示空态）。 */
private fun readAsset(context: Context, path: String): String? =
    try {
        context.assets.open(path).bufferedReader().use { it.readText() }
    } catch (_: Exception) {
        null
    }

/** 顶栏（`topBar()`）：返回键 + 居中标题 + 右侧平衡占位；返回键带按压缩放（`PRESS_BACK` 口径）。 */
@Composable
private fun LegalTopBar(title: String, onBack: () -> Unit) {
    var pressed by remember { mutableStateOf(false) }
    val backScale by animateFloatAsState(
        targetValue = if (pressed) FtMotion.PRESS_SCALE_ICON_BTN else 1f,
        animationSpec = tween(durationMillis = FtMotion.DURATION_PRESS, easing = FtMotion.EASE_MOTION),
        label = "legalBackPress",
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xD10A0D12))
            .drawBehind {
                // 底边 1px #0FFFFFFF（原型 `border({ width: { bottom: 1 } })`）
                val stroke = 1.dp.toPx()
                drawLine(
                    color = Color(0x0FFFFFFF),
                    start = Offset(0f, size.height - stroke / 2f),
                    end = Offset(size.width, size.height - stroke / 2f),
                    strokeWidth = stroke,
                )
            }
            .padding(start = 12.dp, end = 12.dp, top = 52.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .scale(backScale)
                .clip(RoundedCornerShape(14.dp))
                .clickableNoRipple(onClick = onBack)
                .alpha(1f),
            contentAlignment = Alignment.Center,
        ) {
            // 返回斜杠 chevron（原型 `pencil-plan-nav-chevron-left.svg`，22×22、opacity 0.7）
            BackChevronIcon(
                modifier = Modifier.size(22.dp).alpha(0.7f),
                color = Color(0xFFF7FBF8),
            )
        }

        Text(
            text = title,
            style = FtType.ft(16f, 700),
            color = FtColor.txtHi,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )

        // 右侧平衡占位（原型 44×44 空 Row）
        Box(modifier = Modifier.size(44.dp))
    }
}

/** 空态（`emptyState()`）：文档加载失败提示。 */
@Composable
private fun LegalEmptyState(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = stringResource(R.string.legal_load_failed_title),
            style = FtType.ft(16f, 700),
            color = FtColor.txtHi,
        )
        Text(
            text = stringResource(R.string.legal_load_failed_message),
            style = FtType.ft(13f, 400),
            color = Color(0x9EFFFFFF),
            modifier = Modifier.padding(top = 10.dp),
        )
    }
}

/** chevron-left 描边图标（`M15 18 L9 12 L15 6`，24 viewBox、描边 2、圆帽圆角）。 */
@Composable
private fun BackChevronIcon(modifier: Modifier = Modifier, color: Color) {
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        val path = Path().apply {
            moveTo(w * 15f / 24f, h * 18f / 24f)
            lineTo(w * 9f / 24f, h * 12f / 24f)
            lineTo(w * 15f / 24f, h * 6f / 24f)
        }
        drawPath(
            path = path,
            color = color,
            style = Stroke(
                width = 2f / 24f * w,
                cap = StrokeCap.Round,
                join = StrokeJoin.Round,
            ),
        )
    }
}
