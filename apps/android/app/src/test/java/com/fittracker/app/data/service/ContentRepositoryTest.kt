package com.fittracker.app.data.service

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.data.model.EquipmentItem
import com.fittracker.app.data.model.MuscleGroup
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 内容库装载与查询的契约测试（`ContentRepository` + `assets/exercise-content.json`）。
 *
 * 期望值取自种子数据 `LocalExerciseContent.ets`（LOCAL_MUSCLES L7-14 / LOCAL_EQUIPMENT L16-23 /
 * LOCAL_EXERCISES L25 起）：共 6 肌群、7 器械、102 动作。字段名与鸿蒙模型逐字一致，
 * 故断言直接用 camelCase 字段。
 *
 * 2026-10-16：内容资产由 `tools/sync-content-to-android.mjs` 从鸿蒙内容源同步生成
 * （此前 Android 资产停留在 50 动作 / 6 器械的旧快照）。计数随源更新，勿手工改资产。
 *
 * `@Config(sdk = [34])`：与既有 `JsonStoreTest` 一致——项目 targetSdk 37 超出
 * Robolectric 4.16 支持范围，必须钉到受支持的 SDK。
 * `qualifiers = "zh-rCN"`（Wave 8）：肌群 / 器械展示名改为**按当前语言**返回
 * （`nameZh` / `nameEn`），不钉区域限定符时 Robolectric 默认走 en 资源。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class ContentRepositoryTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    private fun ids(exercises: List<com.fittracker.app.data.model.ExerciseContent>): Set<String> =
        exercises.map { it.exerciseId }.toSet()

    @Before
    fun setUp() = runBlocking { ContentRepository.load(context) }

    // ── 装载 ─────────────────────────────────────────────────────

    @Test
    fun `从资产装载成功且三个集合计数与种子一致`() {
        assertEquals(6, ContentRepository.muscles().size)
        assertEquals(7, ContentRepository.equipment().size)
        assertEquals(102, ContentRepository.exercises().size)
        assertTrue(ContentRepository.isLoaded)
    }

    @Test
    fun `肌群与器械中文名取自种子数据`() {
        assertEquals("胸部", ContentRepository.getMuscleName("muscle_chest"))
        assertEquals("背部", ContentRepository.getMuscleName("muscle_back"))
        assertEquals("核心", ContentRepository.getMuscleName("muscle_core"))
        assertEquals("杠铃", ContentRepository.getEquipmentName("eq_barbell"))
        assertEquals("弹力带", ContentRepository.getEquipmentName("eq_band"))
    }

    @Test
    fun `未知 id 回退为原 id 且未知动作返回 null`() {
        assertEquals("muscle_unknown", ContentRepository.getMuscleName("muscle_unknown"))
        assertEquals("eq_unknown", ContentRepository.getEquipmentName("eq_unknown"))
        assertNull(ContentRepository.getExercise("ex_not_exist"))
    }

    /**
     * 新增器械 `eq_kettlebell`（2026-10-16 随内容同步引入）。
     * Android 侧器械展示名取自内容库而非字符串资源，故只需资产里存在即可生效。
     */
    @Test
    fun `新增器械 eq_kettlebell 可解析且带双语名`() {
        assertEquals("壶铃", ContentRepository.getEquipmentName("eq_kettlebell"))

        val kettlebell = ContentRepository.equipment().first { it.equipmentId == "eq_kettlebell" }
        assertEquals("壶铃", kettlebell.nameZh)
        assertEquals("Kettlebell", kettlebell.nameEn)

        // 且确有动作使用它（否则器械表里会留下无人引用的空维度）
        val users = ContentRepository.search(equipmentId = "eq_kettlebell")
        assertTrue("应有动作使用 eq_kettlebell：${users.size}", users.isNotEmpty())
    }

    // ── 内容双语（Wave 8） ────────────────────────────────────────

    @Test
    fun `种子数据带 nameEn 且非空`() {
        val muscles = ContentRepository.muscles().associateBy { it.muscleId }
        val equipment = ContentRepository.equipment().associateBy { it.equipmentId }

        assertEquals("Chest", muscles.getValue("muscle_chest").nameEn)
        assertEquals("Back", muscles.getValue("muscle_back").nameEn)
        assertEquals("Legs", muscles.getValue("muscle_legs").nameEn)
        assertEquals("Shoulders", muscles.getValue("muscle_shoulders").nameEn)
        assertEquals("Arms", muscles.getValue("muscle_arms").nameEn)
        assertEquals("Core", muscles.getValue("muscle_core").nameEn)

        assertEquals("Barbell", equipment.getValue("eq_barbell").nameEn)
        assertEquals("Dumbbell", equipment.getValue("eq_dumbbell").nameEn)
        assertEquals("Cable", equipment.getValue("eq_cable").nameEn)
        assertEquals("Machine", equipment.getValue("eq_machine").nameEn)
        assertEquals("Bodyweight", equipment.getValue("eq_bodyweight").nameEn)
        assertEquals("Band", equipment.getValue("eq_band").nameEn)

        assertTrue("所有肌群都应带 nameEn", ContentRepository.muscles().all { it.nameEn.isNotBlank() })
        assertTrue("所有器械都应带 nameEn", ContentRepository.equipment().all { it.nameEn.isNotBlank() })
    }

    /**
     * 「选名」纯函数两态（不依赖区域限定符——直接传 `languageTag` 断言）。
     * `nameEn` 为空时回落中文（旧数据 / 旧互通包兼容）。
     */
    @Test
    fun `选名纯函数按 languageTag 取双语且空 nameEn 回落中文`() {
        val chest = MuscleGroup("muscle_chest", "胸部", "upper", "Chest")
        val legacy = MuscleGroup("muscle_legacy", "旧肌群", "upper") // nameEn 默认空
        val barbell = EquipmentItem("eq_barbell", "杠铃", "Barbell")
        val legacyEq = EquipmentItem("eq_legacy", "旧器械") // nameEn 默认空

        assertEquals("胸部", ContentRepository.muscleDisplayName(chest, "zh"))
        assertEquals("胸部", ContentRepository.muscleDisplayName(chest, "zh-CN"))
        assertEquals("Chest", ContentRepository.muscleDisplayName(chest, "en"))
        assertEquals("Chest", ContentRepository.muscleDisplayName(chest, "en-US"))
        assertEquals("旧肌群", ContentRepository.muscleDisplayName(legacy, "en"))

        assertEquals("杠铃", ContentRepository.equipmentDisplayName(barbell, "zh"))
        assertEquals("Barbell", ContentRepository.equipmentDisplayName(barbell, "en"))
        assertEquals("旧器械", ContentRepository.equipmentDisplayName(legacyEq, "en"))
    }

    /** English 资源 / 名称生效（`values-en/` + `nameEn`）——方法级区域限定符覆盖类级 `zh-rCN`。 */
    @Test
    @Config(sdk = [34], qualifiers = "en-rUS")
    fun `英文区域下肌群与器械名取 nameEn`() {
        assertEquals("Chest", ContentRepository.getMuscleName("muscle_chest"))
        assertEquals("Legs", ContentRepository.getMuscleName("muscle_legs"))
        assertEquals("Barbell", ContentRepository.getEquipmentName("eq_barbell"))
        assertEquals("Machine", ContentRepository.getEquipmentName("eq_machine"))
        assertEquals("Bodyweight", ContentRepository.getEquipmentName("eq_bodyweight"))
        // 未知 id 仍回落 id 本身
        assertEquals("muscle_unknown", ContentRepository.getMuscleName("muscle_unknown"))
    }

    @Test
    fun `按 id 取回完整动作条目`() {
        val exercise = ContentRepository.getExercise("ex_barbell_bench_press")!!
        assertEquals("杠铃卧推", exercise.nameZh)
        assertEquals("Barbell Bench Press", exercise.nameEn)
        assertEquals("intermediate", exercise.difficulty)
        assertEquals(listOf("muscle_chest"), exercise.primaryMuscleIds)
        assertEquals(listOf("muscle_shoulders", "muscle_arms"), exercise.secondaryMuscleIds)
        assertEquals(listOf("eq_barbell"), exercise.equipmentIds)
        assertEquals(3, exercise.steps.size)
        assertEquals(1, exercise.contentVersion)
    }

    // ── 检索：关键词 ─────────────────────────────────────────────

    @Test
    fun `关键词命中中文名`() {
        assertEquals(
            setOf("ex_barbell_bench_press", "ex_dumbbell_bench_press", "ex_incline_dumbbell_press"),
            ids(ContentRepository.search("卧推")),
        )
    }

    @Test
    fun `关键词命中英文名且大小写不敏感`() {
        assertEquals(
            setOf("ex_barbell_bench_press", "ex_dumbbell_bench_press"),
            ids(ContentRepository.search("BENCH")),
        )
    }

    @Test
    fun `关键词命中别名`() {
        // ex_romanian_deadlift 的 alias 为 "rdl"；ex_single_leg_romanian_deadlift 名内含 rdl
        assertEquals(
            setOf("ex_romanian_deadlift", "ex_single_leg_romanian_deadlift"),
            ids(ContentRepository.search("rdl")),
        )
    }

    @Test
    fun `无关键词无过滤返回全库`() {
        assertEquals(102, ContentRepository.search().size)
        assertEquals(ContentRepository.exercises().size, ContentRepository.search("").size)
    }

    @Test
    fun `查无匹配返回空`() {
        assertTrue(ContentRepository.search("zzzznope").isEmpty())
    }

    // ── 检索：过滤 ───────────────────────────────────────────────

    @Test
    fun `按肌群过滤取主或次肌群`() {
        val results = ContentRepository.search(muscleId = "muscle_chest")
        assertEquals(24, results.size)
        assertTrue(
            "每条结果的 primary/secondary 都应含 muscle_chest",
            results.all { "muscle_chest" in it.primaryMuscleIds || "muscle_chest" in it.secondaryMuscleIds },
        )
        assertTrue("ex_barbell_bench_press" in ids(results))
        assertFalse("背部动作 ex_lat_pulldown 不该入选", "ex_lat_pulldown" in ids(results))
    }

    @Test
    fun `按器械过滤`() {
        val results = ContentRepository.search(equipmentId = "eq_band")
        assertEquals(6, results.size)
        assertTrue("每条结果都应含 eq_band", results.all { "eq_band" in it.equipmentIds })
    }

    @Test
    fun `关键词与肌群复合过滤`() {
        assertEquals(
            setOf(
                "ex_barbell_bench_press", "ex_dumbbell_bench_press", "ex_incline_dumbbell_press",
                "ex_incline_machine_press", "ex_machine_chest_press",
            ),
            ids(ContentRepository.search("press", muscleId = "muscle_chest")),
        )
    }

    @Test
    fun `关键词与器械复合过滤`() {
        assertEquals(
            setOf("ex_band_squat"),
            ids(ContentRepository.search("squat", equipmentId = "eq_band")),
        )
    }

    @Test
    fun `空过滤等同不约束`() {
        assertEquals(
            ContentRepository.search("").size,
            ContentRepository.search("", muscleId = "  ", equipmentId = "").size,
        )
    }
}
