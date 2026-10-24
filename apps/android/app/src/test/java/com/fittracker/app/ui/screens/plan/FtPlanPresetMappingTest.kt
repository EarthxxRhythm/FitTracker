package com.fittracker.app.ui.screens.plan

import com.fittracker.app.data.service.TrainingPlanRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 计划页动作清单的「同源映射」契约。
 *
 * 背景（设备实测 PKB110）：计划组详情读 `PresetPlans` 最新模板，而计划页原先读
 * `getCurrentPlan` 的落盘克隆——预设更新后两份漂移，同名「三分化 · 谭成义」在计划组
 * 有 5 个动作、计划页只有 3 个（日标签还停在旧版「拉」）。计划页改用
 * `ftPlanDaysFromPreset` 映射预设模板后，两处必须逐字段一致。
 *
 * 本测试锁两件事：映射不丢动作、预设模板的动作数就是计划页应显示的数目。
 */
class FtPlanPresetMappingTest {

    @Test
    fun `预设映射逐日保留标签与全部动作`() {
        val preset = TrainingPlanRepository.getPresetPlanById(PRESET_PPL)
        assertTrue("预设计划 $PRESET_PPL 必须存在", preset != null)

        val days = ftPlanDaysFromPreset(preset!!)
        assertEquals("训练日数应一致", preset.days.size, days.size)

        preset.days.forEachIndexed { index, day ->
            assertEquals("第 ${index + 1} 天的日标签", day.dayLabel, days[index].title)
            assertEquals(
                "第 ${index + 1} 天的动作数",
                day.exercises.size,
                days[index].exercises.size,
            )
            day.exercises.forEachIndexed { exIndex, ref ->
                assertEquals(
                    "第 ${index + 1} 天第 ${exIndex + 1} 个动作名",
                    ref.name,
                    days[index].exercises[exIndex].name,
                )
                assertEquals(
                    "第 ${index + 1} 天第 ${exIndex + 1} 个动作组数",
                    ref.sets.toString(),
                    days[index].exercises[exIndex].sets,
                )
            }
        }
    }

    /**
     * 回归锚点：三分化第 2 天「背 + 二头」在预设里是 5 个动作。
     *
     * 若有人把计划页的数据源改回落盘副本，这条会在旧设备上变红（旧副本只有 3 个）。
     */
    @Test
    fun `三分化第二天映射出五个动作`() {
        val preset = TrainingPlanRepository.getPresetPlanById(PRESET_PPL)!!
        val days = ftPlanDaysFromPreset(preset)

        assertEquals("背后束二头", days[1].title)
        assertEquals(5, days[1].exercises.size)
        assertEquals(
            listOf("单臂钢线下拉", "对握下拉", "单臂器械划船", "坐姿开肘划船", "钢线弯举"),
            days[1].exercises.map { it.name },
        )
    }

    private companion object {
        const val PRESET_PPL = "preset_ppl"
    }
}
