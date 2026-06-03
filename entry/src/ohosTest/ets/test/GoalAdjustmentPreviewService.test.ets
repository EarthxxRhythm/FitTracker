import { describe, expect, it } from '@ohos/hypium'
import { TrainingPlan, UserGoal } from '../../../main/ets/shared/models/TrainingModels'
import GoalAdjustmentPreviewService, {
  GoalAdjustmentPreviewResult
} from '../../../main/ets/shared/services/GoalAdjustmentPreviewService'
import GoalSetupService, { GoalSetupPrefill } from '../../../main/ets/shared/services/GoalSetupService'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'

function createGoal(): UserGoal {
  return GoalSetupService.createGoalFromSelection(
    'goal_preview',
    'hypertrophy',
    'intermediate',
    4,
    60,
    ['eq_bodyweight', 'eq_dumbbell'],
    ['muscle_legs'],
    1000
  )
}

export default function goalAdjustmentPreviewServiceTest(): void {
  describe('GoalAdjustmentPreviewService', () => {
    it('creates preview details for a lower-pressure review adjustment', 0, () => {
      const goal: UserGoal = createGoal()
      const currentPlan: TrainingPlan = PlanEngine.generatePlan(goal)
      const selection: GoalSetupPrefill = GoalSetupService.createPrefillFromGoal(goal)
      selection.weeklyDays = 3
      selection.sessionMinutes = 45

      const preview: GoalAdjustmentPreviewResult = GoalAdjustmentPreviewService.createPreview(
        goal,
        currentPlan,
        selection,
        2000
      )

      expect(preview.hasChanges).assertTrue()
      expect(preview.changeCount).assertEqual(2)
      expect(preview.changedKeys.length).assertEqual(2)
      expect(preview.changedKeys[0]).assertEqual('weeklyDays')
      expect(preview.changedKeys[1]).assertEqual('sessionMinutes')
      expect(preview.previewGoal.createdAt).assertEqual(1000)
      expect(preview.previewGoal.updatedAt).assertEqual(2000)
      expect(preview.previewPlanSnapshot.weeklyDays).assertEqual(3)
      expect(preview.currentPlanSnapshot.weeklyDays).assertEqual(4)
      expect(preview.planChanged).assertTrue()
      expect(preview.summaryHighlights.length > 0).assertTrue()
    })

    it('keeps preview unchanged when selection matches the current goal', 0, () => {
      const goal: UserGoal = createGoal()
      const currentPlan: TrainingPlan = PlanEngine.generatePlan(goal)
      const selection: GoalSetupPrefill = GoalSetupService.createPrefillFromGoal(goal)

      const preview: GoalAdjustmentPreviewResult = GoalAdjustmentPreviewService.createPreview(
        goal,
        currentPlan,
        selection,
        3000
      )

      expect(preview.hasChanges).assertFalse()
      expect(preview.changeCount).assertEqual(0)
      expect(preview.changedKeys.length).assertEqual(0)
      expect(preview.planChanged).assertFalse()
      expect(preview.currentPlanSnapshot.weeklyDays).assertEqual(preview.previewPlanSnapshot.weeklyDays)
      expect(preview.currentPlanSnapshot.totalExercises).assertEqual(preview.previewPlanSnapshot.totalExercises)
      expect(preview.summaryHighlights.length > 0).assertTrue()
    })
  })
}
