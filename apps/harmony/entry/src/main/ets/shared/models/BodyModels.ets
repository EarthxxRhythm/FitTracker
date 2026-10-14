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
