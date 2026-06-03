/**
 * WorkoutSessionEditService —— 训练记录编辑态单元测试
 *
 * 功能 #11：训练总结后的记录修正
 */
import { describe, it, expect } from '@ohos/hypium'
import {
  WorkoutSession,
  createWorkoutSession,
  createWorkoutSet
} from '../../../main/ets/shared/models/TrainingModels'
import WorkoutSessionEditService, {
  WorkoutSessionEditModel
} from '../../../main/ets/features/workout/services/WorkoutSessionEditService'

export default function workoutSessionEditServiceTest(): void {
  describe('WorkoutSessionEditService', () => {
    it('creates editable model from saved session and derives 1RM state', 0, () => {
      const session: WorkoutSession = createWorkoutSession(
        'session_edit_model',
        'plan_a',
        'day_1',
        1000,
        61000,
        60,
        2,
        1350,
        3,
        'completed_sets=2;target_sets=3;coach_note=slow_eccentric',
        [
          createWorkoutSet('set_a', 'bench_press', 80, 10, 8, false),
          createWorkoutSet('set_b', 'bench_press', 75, 8, 8, false)
        ]
      )

      const model: WorkoutSessionEditModel = WorkoutSessionEditService.createEditModel(session)

      expect(model.sessionId).assertEqual('session_edit_model')
      expect(model.targetSets).assertEqual(3)
      expect(model.completedSets).assertEqual(2)
      expect(model.customNotes).assertEqual('coach_note=slow_eccentric')
      expect(model.sets.length).assertEqual(2)
      expect(model.sets[0].weightText).assertEqual('80')
      expect(model.sets[0].repsText).assertEqual('10')
      expect(model.sets[0].estimatedOneRepMax).assertEqual(107)
      expect(model.sets[0].isComplete).assertTrue()
      expect(model.sets[1].estimatedOneRepMax).assertEqual(95)
    })

    it('recalculates one rep max and completion after single-set edits', 0, () => {
      const session: WorkoutSession = createWorkoutSession(
        'session_edit_update',
        'plan_b',
        'day_2',
        2000,
        122000,
        120,
        2,
        1200,
        4,
        'completed_sets=2;target_sets=2',
        [
          createWorkoutSet('set_c', 'squat', 60, 8, 8, false),
          createWorkoutSet('set_d', 'squat', 70, 6, 9, false)
        ]
      )

      const model: WorkoutSessionEditModel = WorkoutSessionEditService.createEditModel(session)
      const weightUpdatedModel: WorkoutSessionEditModel = WorkoutSessionEditService.updateSetWeight(model, 'set_c', '90')
      const repsUpdatedModel: WorkoutSessionEditModel = WorkoutSessionEditService.updateSetReps(weightUpdatedModel, 'set_c', '10')

      expect(repsUpdatedModel.sets[0].weight).assertEqual(90)
      expect(repsUpdatedModel.sets[0].reps).assertEqual(10)
      expect(repsUpdatedModel.sets[0].estimatedOneRepMax).assertEqual(120)
      expect(repsUpdatedModel.sets[0].isComplete).assertTrue()
      expect(repsUpdatedModel.completedSets).assertEqual(2)

      const invalidatedModel: WorkoutSessionEditModel = WorkoutSessionEditService.updateSetReps(repsUpdatedModel, 'set_d', '0')
      expect(invalidatedModel.sets[1].reps).assertEqual(0)
      expect(invalidatedModel.sets[1].estimatedOneRepMax).assertEqual(0)
      expect(invalidatedModel.sets[1].isComplete).assertFalse()
      expect(invalidatedModel.completedSets).assertEqual(1)
    })

    it('creates corrected workout session with recomputed totals and filtered invalid sets', 0, () => {
      const session: WorkoutSession = createWorkoutSession(
        'session_edit_export',
        'plan_c',
        'day_3',
        5000,
        95000,
        90,
        9,
        9999,
        6,
        'completed_sets=9;target_sets=4;memo=keep_form',
        [
          createWorkoutSet('set_e', 'deadlift', 100, 5, 9, false),
          createWorkoutSet('set_f', 'deadlift', 80, 10, 8, false)
        ]
      )

      const model: WorkoutSessionEditModel = WorkoutSessionEditService.createEditModel(session)
      const invalidatedModel: WorkoutSessionEditModel = WorkoutSessionEditService.updateSetEntry(
        model,
        'set_f',
        '-10',
        '10.7'
      )
      const correctedSession: WorkoutSession = WorkoutSessionEditService.createCorrectedSession(invalidatedModel)

      expect(correctedSession.sessionId).assertEqual('session_edit_export')
      expect(correctedSession.planId).assertEqual('plan_c')
      expect(correctedSession.dayId).assertEqual('day_3')
      expect(correctedSession.durationSeconds).assertEqual(90)
      expect(correctedSession.fatigueScore).assertEqual(6)
      expect(correctedSession.totalSets).assertEqual(1)
      expect(correctedSession.totalVolume).assertEqual(500)
      expect(correctedSession.notes).assertEqual('completed_sets=1;target_sets=4;memo=keep_form')
      expect(correctedSession.sets.length).assertEqual(1)
      expect(correctedSession.sets[0].setId).assertEqual('set_e')
      expect(correctedSession.sets[0].weight).assertEqual(100)
      expect(correctedSession.sets[0].reps).assertEqual(5)
    })
  })
}
