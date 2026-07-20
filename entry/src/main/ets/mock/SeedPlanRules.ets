/**
 * SeedPlanRules -- local plan generation rules for target-loop planning.
 *
 * Feature #3: plan engine and review calculations.
 */

export interface PlanRule {
  goalType: string
  planName: string
  cycleWeeks: number
  targetSets: number
  targetReps: string
  intensityNote: string
}

export function createPlanRule(
  goalType: string,
  planName: string,
  cycleWeeks: number,
  targetSets: number,
  targetReps: string,
  intensityNote: string
): PlanRule {
  const item: PlanRule = {
    goalType: goalType,
    planName: planName,
    cycleWeeks: cycleWeeks,
    targetSets: targetSets,
    targetReps: targetReps,
    intensityNote: intensityNote
  }
  return item
}

export const SEED_PLAN_RULES: PlanRule[] = [
  createPlanRule('hypertrophy', '增肌基础计划', 4, 3, '8-12', '控制节奏，保留 1-2 次余力'),
  createPlanRule('strength', '力量基础计划', 4, 5, '3-5', '采用大重量组，组间充分休息'),
  createPlanRule('fat_loss', '减脂基础计划', 4, 3, '10-15', '保持稳定节奏，缩短组间休息'),
  createPlanRule('posture', '体态基础计划', 4, 2, '12-15', '动作节奏平稳，注意姿势精确')
]
