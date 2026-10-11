package com.fittracker.app.ui.screens.library

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.R
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 动作库域（library 屏 + [FtLibraryModel]）文案资源的**逐字真源**断言（Wave 8 i18n）。
 *
 * 中文真值在 `values/strings_library.xml`（逐字取自原型
 * `design/06_prototype_redraw/src/fittracker-exercise-library.html` 与既有硬编码），
 * 此处以 `context.getString` 解析校验；改动中文即红。
 *
 * `qualifiers = "zh-rCN"`：不钉区域限定符时 Robolectric 默认走 en 资源。
 * 注意：Kotlin 字符串里的模板占位须转义为 `%1\$s`（资源 XML 里照写 `%1$s`）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class FtLibraryStringsTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun `动作库域文案中文逐字对齐原型`() {
        val expectations = listOf(
            R.string.library_title to "动作库",
            R.string.library_a11y_back to "返回个人页",
            R.string.library_a11y_fav_filter to "只看收藏",
            R.string.library_search_hint to "搜索动作、肌群或器械",
            R.string.library_a11y_search to "搜索动作",
            R.string.library_part_all to "全部",
            R.string.library_muscle_all to "全部肌群",
            R.string.library_a11y_card to "查看 %1\$s 详情",
            R.string.library_a11y_fav_add to "收藏%1\$s",
            R.string.library_a11y_fav_remove to "取消收藏%1\$s",
            R.string.library_a11y_demo_gif to "%1\$s 动作演示",
            R.string.library_empty_fav_title to "暂无收藏",
            R.string.library_empty_fav_hint to "点右上角心形，收藏常用动作",
            R.string.library_empty_query_title to "没有匹配的动作",
            R.string.library_empty_query_hint to "换个关键词试试",
            R.string.library_empty_part_title to "该部位暂无动作",
            R.string.library_empty_part_hint to "换个部位或肌群筛选试试",
            R.string.library_foot_note to "动作数据为演示内容；点击卡片查看动作要点，点右上角心形可收藏。",
            R.string.library_a11y_sheet to "动作详情",
            R.string.library_sheet_media_tag to "动作演示",
            R.string.library_a11y_close to "关闭",
            R.string.library_sheet_row_muscles to "目标肌群",
            R.string.library_sheet_row_equipment to "器械",
            R.string.library_sheet_row_level to "难度",
            R.string.library_sheet_cta to "加入训练计划",
            R.string.library_sheet_cta_done to "已加入今日计划",
            R.string.library_toast_added to "已把「%1\$s」加入今日计划",
            R.string.library_level_beginner to "入门",
            R.string.library_level_intermediate to "进阶",
            R.string.library_level_advanced to "熟练",
        )

        assertEquals("动作库域 zh 文案应为 30 条", 30, expectations.size)
        expectations.forEach { (id, expected) ->
            assertEquals("资源 id=$id 与原型中文不一致", expected, context.getString(id))
        }
    }

    /** 带参文案插值逐字（含全角括号「」与空格位置）。 */
    @Test
    fun `带参文案插值逐字`() {
        assertEquals("查看 杠铃卧推 详情", context.getString(R.string.library_a11y_card, "杠铃卧推"))
        assertEquals("收藏杠铃卧推", context.getString(R.string.library_a11y_fav_add, "杠铃卧推"))
        assertEquals("取消收藏杠铃卧推", context.getString(R.string.library_a11y_fav_remove, "杠铃卧推"))
        assertEquals("杠铃卧推 动作演示", context.getString(R.string.library_a11y_demo_gif, "杠铃卧推"))
        assertEquals("已把「杠铃卧推」加入今日计划", context.getString(R.string.library_toast_added, "杠铃卧推"))
    }

    /** 难度 token → 资源（未知 token 由 UI 层回落原文，见 [FtLibraryModel.difficultyLabelRes]）。 */
    @Test
    fun `难度 token 映射到资源`() {
        assertEquals(R.string.library_level_beginner, FtLibraryModel.difficultyLabelRes("beginner"))
        assertEquals(R.string.library_level_intermediate, FtLibraryModel.difficultyLabelRes("intermediate"))
        assertEquals(R.string.library_level_advanced, FtLibraryModel.difficultyLabelRes("advanced"))
        assertEquals(R.string.library_level_advanced, FtLibraryModel.difficultyLabelRes("ADVANCED"))
        assertEquals(null, FtLibraryModel.difficultyLabelRes("入门"))
    }

    /** English 资源生效（`values-en/strings_library.xml`）——方法级区域限定符覆盖类级 `zh-rCN`。 */
    @Test
    @Config(sdk = [34], qualifiers = "en-rUS")
    fun `英文资源在 en 区域生效`() {
        assertEquals("Exercise Library", context.getString(R.string.library_title))
        assertEquals("All", context.getString(R.string.library_part_all))
        assertEquals("All muscles", context.getString(R.string.library_muscle_all))
        assertEquals("Add to plan", context.getString(R.string.library_sheet_cta))
        assertEquals("Added to today's plan", context.getString(R.string.library_sheet_cta_done))
        assertEquals("Intermediate", context.getString(R.string.library_level_intermediate))
        assertEquals(
            "Added \u201cBench Press\u201d to today's plan",
            context.getString(R.string.library_toast_added, "Bench Press"),
        )
        assertEquals(
            "View Bench Press details",
            context.getString(R.string.library_a11y_card, "Bench Press"),
        )
    }
}
