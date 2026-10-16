/**
 * BodyMetrics —— 身体指标派生纯函数（BMI / 基础代谢 / 体脂健康区间 / 围度差值）。
 *
 * 全部为无副作用的纯函数，便于单测（不触持久化、不依赖 Context）。
 * 口径：
 *  - BMI = 体重(kg) / 身高(m)²，分级用中国成人标准（<18.5 偏低 / 18.5–24 正常 / 24–28 偏高 / ≥28 肥胖）。
 *  - 基础代谢用 Mifflin-St Jeor 公式（不依赖体脂率，故体脂率可保持可选录入）。
 *  - 体脂健康区间按性别给出参考范围（男 10–20%、女 18–28%）——这是**参考区间**，
 *    用于给体脂秤读数定位，非医学诊断。
 */
import { Gender } from '../services/UserProfileService'

/** BMI 分级（语义枚举；中文标签由 [bmiCategoryLabel] 提供）。 */
export type BmiCategory = 'low' | 'normal' | 'high' | 'obese'

/** BMI 分级阈值（中国成人标准）。 */
const BMI_LOW_MAX: number = 18.5
const BMI_NORMAL_MAX: number = 24
const BMI_HIGH_MAX: number = 28

/** 体脂率健康区间（百分比）。 */
export interface BodyFatRange {
  low: number
  high: number
}

/** BMI：体重(kg) 与身高(cm) 任一无效（非有限 / ≤0）时返回 undefined。 */
export function computeBmi(weightKg: number, heightCm: number): number | undefined {
  if (!Number.isFinite(weightKg) || !Number.isFinite(heightCm)) {
    return undefined
  }
  if (weightKg <= 0 || heightCm <= 0) {
    return undefined
  }
  const heightM: number = heightCm / 100
  const bmi: number = weightKg / (heightM * heightM)
  return Math.round(bmi * 10) / 10
}

/** BMI 分级。 */
export function bmiCategory(bmi: number): BmiCategory {
  if (bmi < BMI_LOW_MAX) {
    return 'low'
  }
  if (bmi < BMI_NORMAL_MAX) {
    return 'normal'
  }
  if (bmi < BMI_HIGH_MAX) {
    return 'high'
  }
  return 'obese'
}

/** BMI 分级的中文标签（用户可见文本）。 */
export function bmiCategoryLabel(category: BmiCategory): string {
  if (category === 'low') {
    return '偏低'
  }
  if (category === 'normal') {
    return '正常范围'
  }
  if (category === 'high') {
    return '偏高'
  }
  return '肥胖'
}

/**
 * 基础代谢（kcal/日，Mifflin-St Jeor）：
 *  男 BMR = 10·体重 + 6.25·身高 − 5·年龄 + 5
 *  女 BMR = 10·体重 + 6.25·身高 − 5·年龄 − 161
 * 性别未填或任一参数无效时返回 undefined。
 */
export function basalMetabolicRate(
  weightKg: number,
  heightCm: number,
  age: number,
  gender: Gender
): number | undefined {
  if (gender !== 'male' && gender !== 'female') {
    return undefined
  }
  if (!Number.isFinite(weightKg) || !Number.isFinite(heightCm) || !Number.isFinite(age)) {
    return undefined
  }
  if (weightKg <= 0 || heightCm <= 0 || age <= 0) {
    return undefined
  }
  const base: number = 10 * weightKg + 6.25 * heightCm - 5 * age
  const bmr: number = gender === 'male' ? base + 5 : base - 161
  return Math.round(bmr)
}

/** 由出生年与当前时间求周岁；出生年未填（0）或晚于当前年时返回 0。 */
export function ageFromBirthYear(birthYear: number, now: number): number {
  if (!Number.isFinite(birthYear) || birthYear <= 0) {
    return 0
  }
  const currentYear: number = new Date(now).getFullYear()
  const age: number = currentYear - birthYear
  return age > 0 ? age : 0
}

/** 体脂率健康参考区间；性别未填时返回 undefined。 */
export function bodyFatHealthyRange(gender: Gender): BodyFatRange | undefined {
  if (gender === 'male') {
    return { low: 10, high: 20 }
  }
  if (gender === 'female') {
    return { low: 18, high: 28 }
  }
  return undefined
}

/** 体脂率是否落在健康区间；区间未知或读数未录（-1）时返回 undefined。 */
export function isBodyFatHealthy(bodyFatPercent: number, gender: Gender): boolean | undefined {
  const range: BodyFatRange | undefined = bodyFatHealthyRange(gender)
  if (range === undefined || !Number.isFinite(bodyFatPercent) || bodyFatPercent < 0) {
    return undefined
  }
  return bodyFatPercent >= range.low && bodyFatPercent <= range.high
}

/**
 * 单项「较上次」差值（保留一位小数）；任一侧未录（-1）时返回 undefined。
 * 与 `BodyMeasurementService.delta` 同口径，此处的独立函数供 UI 在无 service 引用时复用。
 */
export function measurementDelta(latest: number, previous: number, unset: number): number | undefined {
  if (latest === unset || previous === unset) {
    return undefined
  }
  return Math.round((latest - previous) * 10) / 10
}
