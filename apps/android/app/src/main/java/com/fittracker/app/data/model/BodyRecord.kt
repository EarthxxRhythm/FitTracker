package com.fittracker.app.data.model

import kotlinx.serialization.Serializable

/**
 * 单条体重记录（原型完整实现 Wave 3 · W3-1）。
 *
 * [dateMillis] 为**本地日零点**的 epoch 毫秒（日粒度）：同一自然日重复记录按「覆盖」处理
 * （见 `BodyRecordService.addRecord`）。口径与仓内时间约定一致——统一用 epoch 毫秒
 * （`UserGoal.createdAt` / `WorkoutSession.startedAt` / `System.currentTimeMillis()`），
 * 不引入 `java.time`（`minSdk = 24`，避免 desugaring 依赖；同 `StatsDashboardService` 头注）。
 *
 * [kg] 恒以**千克**为基准存储（与 `FtBodyModel` 全屏质量基准一致）；展示时按设置项
 * 「体重单位」换算（`FtBodyModel.toDisplay` / `toKilograms`）。
 */
@Serializable
data class WeightRecord(
    val dateMillis: Long,
    val kg: Double,
)

/**
 * 未录入标记（数值项统一口径）——与鸿蒙 `BodyModels.ets` 的 `MEASUREMENT_UNSET` 同值。
 *
 * 用 -1 而非 0 作空标记：0 是合法测量值（如腰围理论上可为 0 但无意义、体脂率为 0 亦需区分），
 * 故「未录」与「录了 0」必须可区分。UI 层渲染为 `--`。
 */
const val MEASUREMENT_UNSET: Int = -1

/**
 * 单条身体测量记录（围度 + 体成分）——对应鸿蒙 `shared/models/BodyModels.ets` 的 `BodyMeasurement`。
 *
 * 与 [WeightRecord] 同为**日粒度**（[dateMillis] = 本地日零点，同一自然日覆盖）。
 * 未录入项一律为 [MEASUREMENT_UNSET]（-1）。
 *
 * 单位为固定口径：围度与身高为 **cm**，体脂率/身体水分为 **%**，骨骼肌为 **kg**。
 * 字段用 `Double`：围度可带小数（如 96.5cm），且与 [WeightRecord.kg] 的类型口径一致。
 */
@Serializable
data class BodyMeasurement(
    val dateMillis: Long,
    /** 胸围（cm）。[MEASUREMENT_UNSET] = 未录入。 */
    val chestCm: Double = MEASUREMENT_UNSET.toDouble(),
    /** 腰围（cm）。[MEASUREMENT_UNSET] = 未录入。 */
    val waistCm: Double = MEASUREMENT_UNSET.toDouble(),
    /** 臀围（cm）。[MEASUREMENT_UNSET] = 未录入。 */
    val hipCm: Double = MEASUREMENT_UNSET.toDouble(),
    /** 臂围（cm）。[MEASUREMENT_UNSET] = 未录入。 */
    val armCm: Double = MEASUREMENT_UNSET.toDouble(),
    /** 大腿围（cm）。[MEASUREMENT_UNSET] = 未录入。 */
    val thighCm: Double = MEASUREMENT_UNSET.toDouble(),
    /** 体脂率（%）。[MEASUREMENT_UNSET] = 未录入。 */
    val bodyFatPercent: Double = MEASUREMENT_UNSET.toDouble(),
    /** 骨骼肌量（kg）。[MEASUREMENT_UNSET] = 未录入。体脂秤读数，非公式推导。 */
    val skeletalMuscleKg: Double = MEASUREMENT_UNSET.toDouble(),
    /** 身体水分（%）。[MEASUREMENT_UNSET] = 未录入。体脂秤读数，非公式推导。 */
    val bodyWaterPercent: Double = MEASUREMENT_UNSET.toDouble(),
)
