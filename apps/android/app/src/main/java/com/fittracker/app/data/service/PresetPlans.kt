package com.fittracker.app.data.service

import com.fittracker.app.data.model.ExerciseRef
import com.fittracker.app.data.model.PresetPlan
import com.fittracker.app.data.model.TrainingDay

/**
 * 4 套预置训练计划——逐字移植自鸿蒙 `common/services/TrainingPlanService.ets:86-262`
 * 的 `PRESET_PLANS` 常量（二/三/四/五分化，功能 #7）。
 *
 * 只读模板：启用时由 [TrainingPlanRepository.enablePlan] 克隆为用户的 `UserPlan`
 * （源 `TrainingPlanService.ets:284` 的 `enablePlan` / `:320` 的 `enableUserPlan`）。
 *
 * 移植口径：计划元数据与动作清单（名称 / 目标肌群 / 组数 / 次数区间）**逐字对齐源**——
 * 这些字符串既参与备份包跨平台互通，也是内容库（`ContentRepository`）按名匹配的锚点，
 * 不得为「Kotlin 味」改写。
 *
 * 模型对齐 `data/model/PlanModels.kt` 的 `PresetPlan` / `TrainingDay` / `ExerciseRef`
 * （各自 Doc 已标注对应的源接口行号）。
 */
object PresetPlans {

    /**
     * 全部预置计划，顺序与源 `PRESET_PLANS` 一致：
     * 二分化（上下肢） → 三分化 · 谭成义 → 四分化 → 五分化。
     *
     * 源块位置：`:88` / `:128` / `:161` / `:201`。
     */
    val ALL: List<PresetPlan> = listOf(
        // 源 :88-127 —— 二分化（上下肢）：上肢 / 下肢 交替，每周 4 练
        PresetPlan(
            id = "preset_upper_lower",
            name = "二分化（上下肢）",
            coverColor = "#43A047",
            targetAudience = "初中级健身者",
            weeklyFrequency = "4 天/周",
            description = "按上肢、下肢两类交替安排，每周各练两次，兼顾训练频率与恢复，适合初中级训练者起步。",
            days = listOf(
                TrainingDay(
                    dayLabel = "上肢A",
                    dayOfWeek = listOf(1),
                    exercises = listOf(
                        ExerciseRef("杠铃平板卧推", "胸部", 4, "8-12"),
                        ExerciseRef("哑铃推举", "肩部", 3, "8-12"),
                        ExerciseRef("上斜哑铃飞鸟", "胸部", 3, "10-15"),
                        ExerciseRef("侧平举", "肩部", 3, "12-15"),
                        ExerciseRef("绳索下压", "手臂", 3, "12-15"),
                    ),
                ),
                TrainingDay(
                    dayLabel = "下肢A",
                    dayOfWeek = listOf(2),
                    exercises = listOf(
                        ExerciseRef("杠铃深蹲", "腿部", 4, "8-12"),
                        ExerciseRef("罗马尼亚硬拉", "腿部", 3, "8-12"),
                        ExerciseRef("保加利亚分腿蹲", "腿部", 3, "10-12"),
                        ExerciseRef("腿弯举", "腿部", 3, "12-15"),
                        ExerciseRef("提踵", "腿部", 3, "15-20"),
                    ),
                ),
                TrainingDay(
                    dayLabel = "上肢B",
                    dayOfWeek = listOf(4),
                    exercises = listOf(
                        ExerciseRef("引体向上", "背部", 4, "8-12"),
                        ExerciseRef("杠铃划船", "背部", 3, "8-12"),
                        ExerciseRef("高位下拉", "背部", 3, "10-12"),
                        ExerciseRef("面拉", "背部", 3, "12-15"),
                        ExerciseRef("杠铃弯举", "手臂", 3, "10-12"),
                    ),
                ),
                TrainingDay(
                    dayLabel = "下肢B",
                    dayOfWeek = listOf(5),
                    exercises = listOf(
                        ExerciseRef("杠铃深蹲", "腿部", 4, "6-10"),
                        ExerciseRef("腿举", "腿部", 3, "10-12"),
                        ExerciseRef("腿弯举", "腿部", 3, "12-15"),
                        ExerciseRef("腿伸展", "腿部", 3, "12-15"),
                        ExerciseRef("提踵", "腿部", 3, "15-20"),
                    ),
                ),
            ),
        ),

        // 源 :128-160 —— 三分化 · 谭成义（2026版）：胸肩三头 / 背后束二头 / 下肢，三练一循环
        PresetPlan(
            id = "preset_ppl",
            name = "三分化 · 谭成义",
            coverColor = "#FB8C00",
            targetAudience = "新手与进阶爱好者",
            weeklyFrequency = "3-6 天/周",
            description = "谭成义三分化（2026版）：胸+肩中束+三头 / 背+肩后束+二头 / 下肢以后侧为主。" +
                "保留自由重量主项，用 RPE8 与渐进超负荷推进；复合动作留余量，单关节小动作可力竭。",
            days = listOf(
                TrainingDay(
                    dayLabel = "胸肩三头",
                    dayOfWeek = listOf(1, 4),
                    exercises = listOf(
                        ExerciseRef("杠铃卧推", "胸部", 4, "12/10/8"),
                        ExerciseRef("哑铃上斜卧推", "胸部", 4, "12"),
                        ExerciseRef("双杠臂屈伸", "胸部", 4, "12"),
                        ExerciseRef("仰卧杠铃臂屈伸", "手臂", 4, "15→12"),
                        ExerciseRef("外侧侧平举", "肩部", 3, "10+10"),
                    ),
                ),
                TrainingDay(
                    dayLabel = "背后束二头",
                    dayOfWeek = listOf(2, 5),
                    exercises = listOf(
                        ExerciseRef("单臂钢线下拉", "背部", 4, "12（末组10+5）"),
                        ExerciseRef("对握下拉", "背部", 4, "12-8"),
                        ExerciseRef("单臂器械划船", "背部", 4, "10+5"),
                        ExerciseRef("坐姿开肘划船", "背部", 3, "12-15"),
                        ExerciseRef("钢线弯举", "手臂", 3, "10-12"),
                    ),
                ),
                TrainingDay(
                    dayLabel = "腿（后侧为主）",
                    dayOfWeek = listOf(3, 6),
                    exercises = listOf(
                        ExerciseRef("单腿硬拉", "腿部", 3, "10-12"),
                        ExerciseRef("保加利亚蹲", "腿部", 3, "10-12"),
                        ExerciseRef("颈前深蹲", "腿部", 3, "10-12"),
                        ExerciseRef("罗马尼亚硬拉", "腿部", 3, "10-12"),
                        ExerciseRef("山羊挺身", "腿部", 3, "12-15"),
                    ),
                ),
            ),
        ),

        // 源 :161-200 —— 四分化：胸+三头 / 背+二头 / 腿 / 肩+臂，每周 4 练
        PresetPlan(
            id = "preset_split_4",
            name = "四分化",
            coverColor = "#1E88E5",
            targetAudience = "中高级健身者",
            weeklyFrequency = "4 天/周",
            description = "每个训练日聚焦一个大肌群并搭配协同肌：胸+三头、背+二头、腿、肩+臂，一周循环一次，适合中高级训练者。",
            days = listOf(
                TrainingDay(
                    dayLabel = "胸 + 三头",
                    dayOfWeek = listOf(1),
                    exercises = listOf(
                        ExerciseRef("杠铃平板卧推", "胸部", 4, "8-12"),
                        ExerciseRef("上斜哑铃卧推", "胸部", 3, "8-12"),
                        ExerciseRef("双杠臂屈伸", "胸部", 3, "8-12"),
                        ExerciseRef("绳索夹胸", "胸部", 3, "12-15"),
                        ExerciseRef("绳索下压", "手臂", 3, "12-15"),
                    ),
                ),
                TrainingDay(
                    dayLabel = "背 + 二头",
                    dayOfWeek = listOf(2),
                    exercises = listOf(
                        ExerciseRef("引体向上", "背部", 4, "8-12"),
                        ExerciseRef("杠铃划船", "背部", 4, "8-12"),
                        ExerciseRef("高位下拉", "背部", 3, "10-12"),
                        ExerciseRef("坐姿划船", "背部", 3, "10-12"),
                        ExerciseRef("杠铃弯举", "手臂", 3, "10-12"),
                    ),
                ),
                TrainingDay(
                    dayLabel = "腿",
                    dayOfWeek = listOf(4),
                    exercises = listOf(
                        ExerciseRef("杠铃深蹲", "腿部", 4, "8-12"),
                        ExerciseRef("罗马尼亚硬拉", "腿部", 3, "8-12"),
                        ExerciseRef("腿举", "腿部", 3, "10-12"),
                        ExerciseRef("腿弯举", "腿部", 3, "12-15"),
                        ExerciseRef("提踵", "腿部", 4, "15-20"),
                    ),
                ),
                TrainingDay(
                    dayLabel = "肩 + 臂",
                    dayOfWeek = listOf(5),
                    exercises = listOf(
                        ExerciseRef("杠铃推举", "肩部", 4, "8-12"),
                        ExerciseRef("哑铃侧平举", "肩部", 3, "12-15"),
                        ExerciseRef("俯身飞鸟", "肩部", 3, "12-15"),
                        ExerciseRef("哑铃锤式弯举", "手臂", 3, "10-12"),
                        ExerciseRef("绳索下压", "手臂", 3, "12-15"),
                    ),
                ),
            ),
        ),

        // 源 :201-262 —— 五分化：胸 / 背 / 腿 / 肩 / 臂，每周 5 练
        PresetPlan(
            id = "preset_bro_split",
            name = "五分化",
            coverColor = "#E53935",
            targetAudience = "中高级健身者",
            weeklyFrequency = "5 天/周",
            description = "每个肌群单独一天：胸、背、腿、肩、手臂，一周五个训练日，单次容量集中，适合恢复能力较好的中高级训练者。",
            days = listOf(
                TrainingDay(
                    dayLabel = "周一 胸部",
                    dayOfWeek = listOf(1),
                    exercises = listOf(
                        ExerciseRef("杠铃平板卧推", "胸部", 4, "8-12"),
                        ExerciseRef("上斜哑铃卧推", "胸部", 3, "8-12"),
                        ExerciseRef("哑铃飞鸟", "胸部", 3, "12-15"),
                        ExerciseRef("绳索夹胸", "胸部", 3, "12-15"),
                        ExerciseRef("双杠臂屈伸", "胸部", 3, "8-12"),
                    ),
                ),
                TrainingDay(
                    dayLabel = "周二 背部",
                    dayOfWeek = listOf(2),
                    exercises = listOf(
                        ExerciseRef("引体向上", "背部", 4, "8-12"),
                        ExerciseRef("杠铃划船", "背部", 4, "8-12"),
                        ExerciseRef("高位下拉", "背部", 3, "10-12"),
                        ExerciseRef("坐姿划船", "背部", 3, "10-12"),
                        ExerciseRef("面拉", "背部", 3, "12-15"),
                    ),
                ),
                TrainingDay(
                    dayLabel = "周三 腿部",
                    dayOfWeek = listOf(3),
                    exercises = listOf(
                        ExerciseRef("杠铃深蹲", "腿部", 4, "8-12"),
                        ExerciseRef("罗马尼亚硬拉", "腿部", 3, "8-12"),
                        ExerciseRef("腿举", "腿部", 3, "10-12"),
                        ExerciseRef("腿弯举", "腿部", 3, "12-15"),
                        ExerciseRef("提踵", "腿部", 4, "15-20"),
                    ),
                ),
                TrainingDay(
                    dayLabel = "周四 肩部",
                    dayOfWeek = listOf(4),
                    exercises = listOf(
                        ExerciseRef("杠铃推举", "肩部", 4, "8-12"),
                        ExerciseRef("哑铃侧平举", "肩部", 3, "12-15"),
                        ExerciseRef("前平举", "肩部", 3, "12-15"),
                        ExerciseRef("俯身飞鸟", "肩部", 3, "12-15"),
                        ExerciseRef("耸肩", "肩部", 3, "12-15"),
                    ),
                ),
                TrainingDay(
                    dayLabel = "周五 手臂",
                    dayOfWeek = listOf(5),
                    exercises = listOf(
                        ExerciseRef("杠铃弯举", "手臂", 4, "8-12"),
                        ExerciseRef("哑铃锤式弯举", "手臂", 3, "10-12"),
                        ExerciseRef("窄距卧推", "手臂", 4, "8-12"),
                        ExerciseRef("绳索下压", "手臂", 3, "12-15"),
                        ExerciseRef("集中弯举", "手臂", 3, "12-15"),
                    ),
                ),
            ),
        ),
    )

    /** 源 `TrainingPlanService.ets:272` `getAllPresetPlans`。 */
    fun getAll(): List<PresetPlan> = ALL

    /** 源 `TrainingPlanService.ets:276` `getPresetPlanById`——未命中返回 `null`（源 `undefined`）。 */
    fun getById(id: String): PresetPlan? = ALL.firstOrNull { it.id == id }

    /** 源 `TrainingPlanService.ets:280` `getPlanCount`。 */
    fun count(): Int = ALL.size
}
