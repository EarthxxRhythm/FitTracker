package com.fittracker.app.ui.screens.library

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.data.service.ContentRepository
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 动作库模型（id 域映射 / 二级肌群条 / 过滤）的契约测试。
 *
 * 回归锚点：
 * ① 映射曾把 `muscle` 也填成主肌群名，二级肌群条又按展示名过滤——两处叠加使二级行恒剩
 *    「全部肌群」；Wave 8 起筛选一律按 **id**（`muscle_chest` 等），二级项由动作的
 *    涉及肌群 id（主 + 辅）派生。
 * ② 部位 / 肌群 / 器械展示名走 `ContentRepository`（按语言），故类级钉 `qualifiers = "zh-rCN"`
 *    取 `nameZh` 真源；不钉时 Robolectric 默认 en 区域（会取到 `Chest` 等英文名）。
 *
 * 期望值取自真实内容 `assets/exercise-content.json`（6 肌群 / 6 器械 / 50 动作）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class FtLibraryModelTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Before
    fun setUp() = runBlocking { ContentRepository.load(context) }

    private fun library(): List<FtLibraryExercise> =
        ContentRepository.exercises().map { FtLibraryModel.toLibraryExercise(it) }

    // ── 纯函数（手工夹具，形态与真实内容一致：主肌群 + 辅助肌群，均带 id） ─────

    private val chestA = FtLibraryExercise(
        id = "a", name = "杠铃卧推", part = "胸部", muscle = "胸部", equipment = "杠铃",
        level = "intermediate", muscles = "胸部 · 肩部 · 手臂", tip = "",
        partId = "muscle_chest", equipmentId = "eq_barbell",
        muscleIds = listOf("muscle_chest", "muscle_shoulders", "muscle_arms"),
    )
    private val chestB = FtLibraryExercise(
        id = "b", name = "哑铃飞鸟", part = "胸部", muscle = "胸部", equipment = "哑铃",
        level = "intermediate", muscles = "胸部", tip = "",
        partId = "muscle_chest", equipmentId = "eq_dumbbell",
        muscleIds = listOf("muscle_chest"),
    )
    private val backA = FtLibraryExercise(
        id = "c", name = "引体向上", part = "背部", muscle = "背部", equipment = "自重",
        level = "intermediate", muscles = "背部 · 手臂", tip = "",
        partId = "muscle_back", equipmentId = "eq_bodyweight",
        muscleIds = listOf("muscle_back", "muscle_arms"),
    )
    private val fixture = listOf(chestA, chestB, backA)

    @Test
    fun `目标肌群串按中点分隔符拆分`() {
        assertEquals(listOf("胸部", "肩部", "手臂"), FtLibraryModel.muscleNames(chestA))
        assertEquals(listOf("胸部"), FtLibraryModel.muscleNames(chestB))
    }

    @Test
    fun `肌群命中判定按 id_主肌群或任一涉及肌群`() {
        assertTrue(FtLibraryModel.matchesMuscle(chestA, "muscle_chest"))
        assertTrue(FtLibraryModel.matchesMuscle(chestA, "muscle_shoulders"))
        assertFalse(FtLibraryModel.matchesMuscle(chestA, "muscle_legs"))
    }

    @Test
    fun `部位为全部时二级肌群条为空`() {
        assertTrue(FtLibraryModel.muscleChipsFrom(FtLibraryModel.ALL_PARTS, fixture).isEmpty())
    }

    @Test
    fun `二级肌群条由涉及肌群 id 派生并剔除部位本身`() {
        val chips = FtLibraryModel.muscleChipsFrom("muscle_chest", fixture)

        assertEquals(listOf(FtLibraryModel.ALL_MUSCLES, "muscle_shoulders", "muscle_arms"), chips)
        assertFalse("部位 id 不应重复出现在二级项", "muscle_chest" in chips.drop(1))
    }

    @Test
    fun `按二级肌群过滤收窄结果`() {
        val all = FtLibraryModel.filterSource(
            fixture, "muscle_chest", FtLibraryModel.ALL_MUSCLES, false, emptySet(), "",
        )
        assertEquals(listOf("a", "b"), all.map { it.id })

        val shoulders = FtLibraryModel.filterSource(
            fixture, "muscle_chest", "muscle_shoulders", false, emptySet(), "",
        )
        assertEquals(listOf("a"), shoulders.map { it.id })
    }

    @Test
    fun `收藏与关键词过滤仍与原型一致`() {
        val favOnly = FtLibraryModel.filterSource(
            fixture, FtLibraryModel.ALL_PARTS, FtLibraryModel.ALL_MUSCLES, true, setOf("c"), "",
        )
        assertEquals(listOf("c"), favOnly.map { it.id })

        val byQuery = FtLibraryModel.filterSource(
            fixture, FtLibraryModel.ALL_PARTS, FtLibraryModel.ALL_MUSCLES, false, emptySet(), "引体",
        )
        assertEquals(listOf("c"), byQuery.map { it.id })
    }

    // ── 真实内容（id 域映射 + 展示名） ────────────────────────────────

    @Test
    fun `真实内容映射_部位取主肌群展示名且 id 域填满`() {
        val all = library()
        assertEquals(50, all.size)

        val bench = all.first { it.id == "ex_barbell_bench_press" }
        assertEquals("muscle_chest", bench.partId)
        assertEquals("胸部", bench.part)
        assertEquals("eq_barbell", bench.equipmentId)
        assertEquals("杠铃", bench.equipment)
        assertEquals(listOf("muscle_chest", "muscle_shoulders", "muscle_arms"), bench.muscleIds)
        assertEquals("胸部 · 肩部 · 手臂", bench.muscles)
        // 难度保留语言无关 token（展示名走 library_level_* 资源）
        assertEquals("intermediate", bench.level)
    }

    @Test
    fun `真实内容_二级肌群条不再恒剩全部肌群`() {
        val chips = FtLibraryModel.muscleChipsFrom("muscle_chest", library())

        assertTrue("二级项应多于「全部肌群」一项：$chips", chips.size > 1)
        assertEquals(FtLibraryModel.ALL_MUSCLES, chips.first())
        assertFalse("部位 id 不应出现在二级项", "muscle_chest" in chips.drop(1))
    }

    @Test
    fun `真实内容_按二级肌群筛选能严格收窄且结果均涉及该肌群`() {
        val source = library()
        val all = FtLibraryModel.filterSource(
            source, "muscle_chest", FtLibraryModel.ALL_MUSCLES, false, emptySet(), "",
        )
        val narrowed = FtLibraryModel.filterSource(
            source, "muscle_chest", "muscle_shoulders", false, emptySet(), "",
        )

        assertTrue("应至少有一条胸部动作涉及肩部", narrowed.isNotEmpty())
        assertTrue("筛选后应严格收窄：${narrowed.size} < ${all.size}", narrowed.size < all.size)
        assertTrue(narrowed.all { "muscle_shoulders" in it.muscleIds })
    }

    @Test
    fun `部位 id 序列与内容库肌群一致且首项为哨兵`() {
        assertEquals(FtLibraryModel.ALL_PARTS, FtLibraryModel.PART_IDS.first())
        assertEquals(
            ContentRepository.muscles().map { it.muscleId }.toSet(),
            FtLibraryModel.PART_IDS.drop(1).toSet(),
        )
    }

    // ── 动作 GIF 素材映射（W2-2） ──────────────────────────────────────

    @Test
    fun `原型样例按 id 命中 GIF 素材`() {
        val pushUp = FtLibraryModel.EXERCISES.first { it.id == "push-up" }
        assertEquals("exercise-gifs-cut/push-up.gif", FtLibraryModel.gifAssetFor(pushUp))
    }

    @Test
    fun `真实内容按动作名命中 GIF 素材`() {
        assertEquals("exercise-gifs-cut/barbell-bench-press.gif",
            FtLibraryModel.gifAssetFor("ex_barbell_bench_press", "杠铃卧推"))
        assertEquals("exercise-gifs-cut/plank.gif",
            FtLibraryModel.gifAssetFor("ex_plank", "平板支撑"))
    }

    @Test
    fun `同义动作名走别名映射`() {
        assertEquals("exercise-gifs-cut/squat.gif", FtLibraryModel.gifAssetFor("ex_barbell_squat", "杠铃深蹲"))
        assertEquals("exercise-gifs-cut/lunge.gif", FtLibraryModel.gifAssetFor("ex_walking_lunge", "行进弓步"))
    }

    @Test
    fun `未匹配动作返回 null 保留占位`() {
        org.junit.Assert.assertNull(FtLibraryModel.gifAssetFor("ex_dead_bug", "死虫式"))
        org.junit.Assert.assertNull(FtLibraryModel.gifAssetFor("", ""))
    }

    @Test
    fun `映射到的 GIF 文件在 assets 中真实存在`() {
        val names = context.assets.list(FtLibraryModel.GIF_ASSET_DIR)!!.toSet()
        assertEquals("素材目录（${FtLibraryModel.GIF_ASSET_DIR}）应有 23 个素材", 23, names.size)
        assertTrue("每个原型动作 id 都应有素材", FtLibraryModel.EXERCISES.all { "${it.id}.gif" in names })
        val resolved = library().mapNotNull { FtLibraryModel.gifAssetFor(it) }
        assertTrue("应至少命中一条真实动作：${resolved.size}", resolved.isNotEmpty())
        resolved.forEach { path ->
            assertTrue("素材缺失：$path", path.substringAfterLast('/') in names)
        }
    }
}
