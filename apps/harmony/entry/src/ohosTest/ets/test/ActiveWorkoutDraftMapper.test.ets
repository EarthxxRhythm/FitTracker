import { describe, expect, it } from '@ohos/hypium'
import { UserGoal, createUserGoal } from '../../../main/ets/shared/models/TrainingModels'
import ActiveWorkoutService, {
  ActiveWorkoutState
} from '../../../main/ets/shared/services/ActiveWorkoutService'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'
import WorkoutPreviewService, {
  WorkoutPreviewSummary
} from '../../../main/ets/shared/services/WorkoutPreviewService'
import {
  WorkoutDraftSnapshot,
  createEmptyWorkoutDraftSnapshot,
  hasWorkoutDraftProgress,
  isValidWorkoutDraftSnapshot,
  normalizeWorkoutDraft
} from '../../../main/ets/common/services/WorkoutDraftService'
import {
  fromWorkoutDraft,
  toWorkoutDraft
} from '../../../main/ets/shared/services/ActiveWorkoutDraftMapper'

/**
 * 固定前置：由目标生成计划推出的活跃训练态（不依赖预置计划资源是否存在，
 * 避免资源调整时用例整体失败）。
 */
function createActiveState(): ActiveWorkoutState {
  const equipmentIds: string[] = ['eq_bodyweight']
  const restrictedMuscleIds: string[] = []
  const goal: UserGoal = createUserGoal(
    'goal_draft_mapper',
    'hypertrophy',
    'beginner',
    3,
    45,
    equipmentIds,
    restrictedMuscleIds,
    100,
    100
  )
  const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreview(PlanEngine.generatePlan(goal), 1)
  return ActiveWorkoutService.createState(preview)
}

/** 记两组后的训练态（首动作的第 1、2 组各一次）。 */
function createRecordedState(): ActiveWorkoutState {
  const state: ActiveWorkoutState = createActiveState()
  const plannedExerciseId: string = state.exercises[0].plannedExerciseId
  const once: ActiveWorkoutState = ActiveWorkoutService.recordSetFor(state, plannedExerciseId, '60', '8')
  return ActiveWorkoutService.recordSetFor(once, plannedExerciseId, '62.5', '8')
}

export default function activeWorkoutDraftMapperTest(): void {
  describe('ActiveWorkoutDraftMapper', () => {
    it('round trips a recorded workout state through draft and back without losing sets', 0, () => {
      const state: ActiveWorkoutState = createRecordedState()
      const draft: WorkoutDraftSnapshot = toWorkoutDraft(state, '上肢下肢两分化', '周一', 1000, 5000)

      // 草稿侧：顶层口径与训练态一致
      expect(draft.completedSets).assertEqual(2)
      expect(draft.totalTargetSets).assertEqual(state.totalTargetSets)
      expect(draft.startedAt).assertEqual(1000)
      expect(draft.updatedAt).assertEqual(5000)
      expect(draft.exercises.length).assertEqual(state.exercises.length)

      const restored: ActiveWorkoutState = fromWorkoutDraft(draft)
      expect(restored.completedSets).assertEqual(2)
      expect(restored.totalTargetSets).assertEqual(state.totalTargetSets)
      expect(restored.exercises.length).assertEqual(state.exercises.length)
      expect(restored.exercises[0].plannedExerciseId).assertEqual(state.exercises[0].plannedExerciseId)
      expect(restored.exercises[0].exerciseId).assertEqual(state.exercises[0].exerciseId)
      expect(restored.exercises[0].name).assertEqual(state.exercises[0].name)
      expect(restored.exercises[0].sets.length).assertEqual(state.exercises[0].sets.length)
      // 组内容逐项保留（重量/次数/完成态）
      expect(restored.exercises[0].sets[0].isComplete).assertTrue()
      expect(restored.exercises[0].sets[0].weightText).assertEqual('60')
      expect(restored.exercises[0].sets[0].repsText).assertEqual('8')
      expect(restored.exercises[0].sets[1].weightText).assertEqual('62.5')
      expect(restored.exercises[0].sets[2].isComplete).assertFalse()
    })

    it('recomputes derived fields instead of trusting stale draft values', 0, () => {
      const state: ActiveWorkoutState = createRecordedState()
      const draft: WorkoutDraftSnapshot = toWorkoutDraft(state, 'P', 'D', 0, 0)
      // 故意写坏冗余值：恢复后必须按 exercises 重算，否则首页会显示错误的「已做 N 组」
      draft.completedSets = 999
      draft.currentExerciseName = '被篡改的动作名'
      draft.currentExerciseProgress = '999/999 正式组'

      const restored: ActiveWorkoutState = fromWorkoutDraft(draft)
      expect(restored.completedSets).assertEqual(2)
      expect(restored.currentExerciseName === '被篡改的动作名').assertFalse()
      expect(restored.currentExerciseSetProgress === '999/999 正式组').assertFalse()
    })

    it('normalizes legacy draft without plannedExerciseId by falling back to exerciseId', 0, () => {
      // 旧版本写下的草稿：exercises 项里没有 plannedExerciseId 字段
      const json: string = '{"planId":"plan_1","planName":"上肢","dayLabel":"周一","startedAt":10,' +
        '"totalTargetSets":3,"completedSets":1,"currentExerciseName":"俯卧撑",' +
        '"currentExerciseProgress":"1/3","exercises":[{"exerciseId":"push_up","name":"俯卧撑",' +
        '"targetMuscle":"胸","targetSets":3,"targetReps":"8","completedSets":1,"sets":[' +
        '{"setIndex":0,"weightText":"60","repsText":"8","estimatedOneRepMax":76,' +
        '"oneRepMaxText":"参考 1RM 76 kg","isComplete":true}]}],"updatedAt":20}'
      const parsed: WorkoutDraftSnapshot = JSON.parse(json) as WorkoutDraftSnapshot
      // 旧草稿必须判定为合法，否则升级后用户的学习记录会整体消失
      expect(isValidWorkoutDraftSnapshot(parsed)).assertTrue()

      const normalized: WorkoutDraftSnapshot = normalizeWorkoutDraft(parsed)
      expect(normalized.exercises[0].plannedExerciseId).assertEqual('push_up')
      // 归一化是深拷贝：不改动入参
      expect(parsed.exercises[0].plannedExerciseId === 'push_up').assertFalse()
    })

    it('treats typed-but-unfinished input as draft progress', 0, () => {
      const empty: WorkoutDraftSnapshot = createEmptyWorkoutDraftSnapshot(1)
      expect(hasWorkoutDraftProgress(empty)).assertFalse()

      const draft: WorkoutDraftSnapshot = toWorkoutDraft(createActiveState(), 'P', 'D', 0, 0)
      // 没有任何完成组
      expect(hasWorkoutDraftProgress(draft)).assertFalse()
      // 只填了重量、还没完成：仍算有进度（用户输到一半被打断，回来不该看到空态）
      draft.exercises[0].sets[0].weightText = '40'
      expect(hasWorkoutDraftProgress(draft)).assertTrue()
    })
  })
}
