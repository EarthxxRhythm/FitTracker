/**
 * WeightUtils — 体重单位换算与格式化工具。
 *
 * 约定：业务数据一律以 kg 为基准存储；lbs 只出现在显示层（显示时换算、输入时换算回 kg）。
 * 体重单位来源：UserProfileService.weightUnit（设置页「体重单位」）。
 */
import { WeightUnit } from '../services/UserProfileService'

const KG_TO_LBS: number = 2.2046226218

export function weightUnitLabel(unit: WeightUnit): string {
  return unit === 'lbs' ? 'lbs' : 'kg'
}

/** kg 基准值 → 当前单位数值。 */
export function kgToDisplay(kg: number, unit: WeightUnit): number {
  if (unit === 'lbs') {
    return kg * KG_TO_LBS
  }
  return kg
}

/** 当前单位数值 → kg 基准值。 */
export function displayToKg(value: number, unit: WeightUnit): number {
  if (unit === 'lbs') {
    return value / KG_TO_LBS
  }
  return value
}

/** kg 基准值 → 当前单位下 1 位小数的展示文本。 */
export function formatWeight(kg: number, unit: WeightUnit): string {
  return kgToDisplay(kg, unit).toFixed(1)
}
