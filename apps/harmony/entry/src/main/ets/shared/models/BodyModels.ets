/**
 * BodyModels —— 身体数据域模型（体重记录与趋势）。
 *
 * 口径与安卓端 `data/model/BodyRecord.kt` 对齐：
 *  - [WeightRecord.dateMillis] 为**本地日零点**的 epoch 毫秒（日粒度）；同一自然日重复记录按覆盖处理。
 *  - [WeightRecord.kg] 恒以**千克**为基准存储；展示按「设置 · 体重单位」换算（见 WeightUtils）。
 */

/** 单条体重记录。 */
export interface WeightRecord {
  dateMillis: number
  kg: number
}

/** 一段趋势序列（折线取样点 + 标签 + 区间差值 + 区间名）。 */
export interface BodyTrend {
  values: number[]
  labels: string[]
  deltaKg: number
  rangeText: string
}

/**
 * 单条身体测量记录（围度 + 体成分）。
 *
 * 与 [WeightRecord] 同为**日粒度**（`dateMillis` = 本地日零点，同一自然日覆盖）。
 * 未录入的项一律以 **-1** 表示（而非 0）——0 是合法测量值（如体脂率不可能为 0，但未录与
 * 「录了 0」必须可区分），故用 -1 作空标记，由 UI 层渲染为 `--`。
 *
 * 单位为固定口径：围度与身高为 **cm**，体脂率/身体水分为 **%**，骨骼肌为 **kg**。
 */
export interface BodyMeasurement {
  dateMillis: number
  /** 胸围（cm）。-1 = 未录入。 */
  chestCm: number
  /** 腰围（cm）。-1 = 未录入。 */
  waistCm: number
  /** 臀围（cm）。-1 = 未录入。 */
  hipCm: number
  /** 臂围（cm）。-1 = 未录入。 */
  armCm: number
  /** 大腿围（cm）。-1 = 未录入。 */
  thighCm: number
  /** 体脂率（%）。-1 = 未录入。 */
  bodyFatPercent: number
  /** 骨骼肌量（kg）。-1 = 未录入。体脂秤读数，非公式推导。 */
  skeletalMuscleKg: number
  /** 身体水分（%）。-1 = 未录入。体脂秤读数，非公式推导。 */
  bodyWaterPercent: number
}

/** 未录入标记（数值项统一口径）。 */
export const MEASUREMENT_UNSET: number = -1
