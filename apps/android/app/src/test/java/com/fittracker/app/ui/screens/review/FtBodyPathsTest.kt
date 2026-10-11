package com.fittracker.app.ui.screens.review

import android.content.Context
import android.graphics.Region
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asAndroidPath
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * 体态图资产与命中测试的隔离测试（`FtBodyMap.kt` 的 `FtBodyPaths`）。
 *
 * 为什么需要它：真机上「点肌肉」一直不出详情行（6 个坐标全无命中），
 * 而这条链有三段都可能坏——资产解析、路径归一化、`Region` 命中判定。
 * 真机 dump 只能告诉我「没出结果」，定位不到是哪一段，故把链路拆到 JVM 上逐段钉。
 *
 * ⚠ **必须开 `GraphicsMode.NATIVE`**：Robolectric 默认的 legacy 图形层把
 * `android.graphics.Region` 做成影子实现，`setPath`/`contains` 都不产生真实几何结果
 * （未开时本文件报「Region 命中数 0/66」，是**假红**）。开 NATIVE 后走真实 native 图形。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w390dp-h844dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class FtBodyPathsTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    /** 对照组：手工三角形的 `Region` 命中——用来判断「Region 机制本身」是否可用。 */
    @Test
    fun `Region 基准对照组三角形可命中`() {
        val tri = Path().apply {
            moveTo(10f, 10f); lineTo(100f, 10f); lineTo(100f, 100f); close()
        }
        val r = Region()
        val ok = r.setPath(tri.asAndroidPath(), Region(-1000, -1000, 1000, 1000))
        assertTrue("三角形 setPath 应返回 true（返回 false 说明 Region 机制没生效）", ok)
        assertTrue("(80,50) 应落在三角形内", r.contains(80, 50))
        assertFalse("(5,5) 不该命中", r.contains(5, 5))
    }

    @Test
    fun `资产解析出前后两个视图`() {
        val views = FtBodyPaths.of(context)
        assertEquals(setOf("front", "back"), views.keys)
        val front = views.getValue("front")
        assertTrue("设计空间应为 727×1280（归一化后）", front.vbW == 727f && front.vbH == 1280f)
        assertTrue("肌肉路径应有相当数量，实得 ${front.muscles.size}", front.muscles.size > 20)
        assertTrue("轮廓路径应有若干，实得 ${front.silhouettes.size}", front.silhouettes.isNotEmpty())
    }

    /** 归一化后，所有路径都应落在设计空间内（y 不再带 viewBox 的 95 偏移）。 */
    @Test
    fun `路径已归一化到设计空间原点`() {
        val front = FtBodyPaths.of(context).getValue("front")
        val all = front.muscles.map { it.path.getBounds() } + front.silhouettes.map { it.getBounds() }
        assertTrue("最小 y 应接近 0，实得 ${all.minOf { it.top }}", all.minOf { it.top } < 20f)
        assertTrue("最大 y 不应超出设计高，实得 ${all.maxOf { it.bottom }}", all.maxOf { it.bottom } <= front.vbH + 1f)
        assertTrue("最小 x 不应为负，实得 ${all.minOf { it.left }}", all.minOf { it.left } >= -1f)
        assertTrue("最大 x 不应超出设计宽，实得 ${all.maxOf { it.right }}", all.maxOf { it.right } <= front.vbW + 1f)
    }

    /** Region 命中：每块肌肉的**单条路径**的包围盒中心，必须落在某个该肌肉的 region 内。 */
    @Test
    fun `肌肉的包围盒中心能被自己的 Region 命中`() {
        val front = FtBodyPaths.of(context).getValue("front")
        val ids = front.muscles.map { it.id }.distinct()
        assertTrue("至少要有若干肌肉组", ids.size >= 10)

        var hitCount = 0
        for (muscle in front.muscles) {
            val b = muscle.path.getBounds()
            val cx = ((b.left + b.right) / 2f).toInt()
            val cy = ((b.top + b.bottom) / 2f).toInt()
            if (muscle.region.contains(cx, cy)) hitCount++
        }
        // 单条路径的包围盒中心一般落在该路径内（凹形可能例外），故不要求 100%，
        // 但若 Region 机制整体失效，这里会是 0——这正是真机点不中的怀疑点。
        assertTrue("Region 命中数 $hitCount / ${front.muscles.size}，疑似 Region 未生效", hitCount > 0)
        assertTrue("Region 命中率过低：$hitCount / ${front.muscles.size}", hitCount * 2 > front.muscles.size)
    }

    /** 反证：远离身体的坐标必须不命中任何肌肉。 */
    @Test
    fun `空白处不命中任何肌肉`() {
        val front = FtBodyPaths.of(context).getValue("front")
        val corners = listOf(1 to 1, (front.vbW - 2).toInt() to 1, 1 to (front.vbH - 2).toInt())
        for ((x, y) in corners) {
            assertFalse("角落 ($x,$y) 不该命中", front.muscles.any { it.region.contains(x, y) })
        }
    }
}
