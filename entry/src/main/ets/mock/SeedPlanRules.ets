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
  createPlanRule('hypertrophy', 'Hypertrophy Base Plan', 4, 3, '8-12', 'Controlled reps with 1-2 reps in reserve'),
  createPlanRule('strength', 'Strength Base Plan', 4, 5, '3-5', 'Heavy sets with full rest between efforts'),
  createPlanRule('fat_loss', 'Fat Loss Base Plan', 4, 3, '10-15', 'Steady pace with short rest periods'),
  createPlanRule('posture', 'Posture Base Plan', 4, 2, '12-15', 'Smooth tempo and precise positions')
]
