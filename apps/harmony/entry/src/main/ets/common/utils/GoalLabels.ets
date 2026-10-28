/**
 * GoalLabels —— 训练目标类型 → 中文标签。
 *
 * 计划页（`PlanState`）与个人页（`ProfileState`）共用同一映射，避免两处文案漂移。
 */

export function goalTypeLabel(goalType: string): string {
  if (goalType === 'hypertrophy') {
    return '增肌'
  }
  if (goalType === 'strength') {
    return '力量'
  }
  if (goalType === 'fat_loss') {
    return '减脂'
  }
  if (goalType === 'posture') {
    return '体态'
  }
  return goalType
}
