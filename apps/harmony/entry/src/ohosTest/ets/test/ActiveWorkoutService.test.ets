import { describe, it, expect } from '@ohos/hypium'
import { TrainingPlan, UserGoal, WorkoutSession, createUserGoal } from '../../../main/ets/shared/models/TrainingModels'
import TrainingPlanService, { PresetPlan, UserPlan } from '../../../main/ets/common/services/TrainingPlanService'
import ActiveWorkoutService, { ActiveWorkoutExercise, ActiveWorkoutState } from '../../../main/ets/shared/services/ActiveWorkoutService'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'
import WorkoutPreviewService, { WorkoutPreviewSummary } from '../../../main/ets/shared/services/WorkoutPreviewService'
import WorkoutRepository from '../../../main/ets/shared/services/WorkoutRepository'
import {
  ActiveExerciseRecordGroup,
  buildRecordGroups
} from '../../../main/ets/features/pencil/components/ActiveSetRecordModel'

export default function activeWorkoutServiceTest(): void {
  describe('ActiveWorkoutService', () => {
    it('creates active workout state with current exercise and set progress from preview flow', 0, () => {
      const equipmentIds: string[] = ['eq_bodyweight']
      const restrictedMuscleIds: string[] = []
      const goal: UserGoal = createUserGoal(
        'goal_active_flow',
        'hypertrophy',
        'beginner',
        3,
        45,
        equipmentIds,
        restrictedMuscleIds,
        100,
        100
      )
      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreview(plan, 1)
      const state: ActiveWorkoutState = ActiveWorkoutService.createState(preview)

      expect(preview.hasWorkout).assertTrue()
      expect(state.hasWorkout).assertTrue()
      expect(state.currentExerciseName).assertEqual(preview.exercises[0].name)
      expect(state.currentExerciseSetProgress).assertEqual('0/' + preview.exercises[0].targetSets.toString() + ' 正式组')

      const firstExercise: ActiveWorkoutExercise = state.exercises[0]
      const progressedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
        state.exercises,
        firstExercise.plannedExerciseId,
        0,
        '1',
        '1'
      )
      const progressedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, progressedExercises)

      expect(progressedState.completedSets).assertEqual(1)
      expect(progressedState.currentExerciseName).assertEqual(firstExercise.name)
      expect(progressedState.currentExerciseSetProgress).assertEqual('1/' + firstExercise.targetSets.toString() + ' 正式组')
    })

    it('updates a set entry with weight and reps then exposes instant Epley 1RM reference', 0, () => {
      const equipmentIds: string[] = ['eq_bodyweight']
      const restrictedMuscleIds: string[] = []
      const goal: UserGoal = createUserGoal(
        'goal_active_one_rm',
        'hypertrophy',
        'beginner',
        3,
        45,
        equipmentIds,
        restrictedMuscleIds,
        100,
        100
      )
      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreview(plan, 1)
      const state: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
      const firstExercise: ActiveWorkoutExercise = state.exercises[0]

      const updatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
        state.exercises,
        firstExercise.plannedExerciseId,
        0,
        '80',
        '10'
      )
      const updatedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, updatedExercises)

      expect(updatedState.completedSets).assertEqual(1)
      expect(updatedState.exercises[0].sets[0].weightText).assertEqual('80')
      expect(updatedState.exercises[0].sets[0].repsText).assertEqual('10')
      expect(updatedState.exercises[0].sets[0].estimatedOneRepMax).assertEqual(107)
      expect(updatedState.exercises[0].sets[0].oneRepMaxText).assertEqual('参考 1RM 107 kg')
    })

    it('creates active workout state from the current enabled preset plan preview', 0, () => {
      const presetPlan: PresetPlan | undefined = TrainingPlanService.getPresetPlanById('preset_upper_lower')
      expect(presetPlan !== undefined).assertTrue()
      if (presetPlan !== undefined) {
        const currentPlan: UserPlan = {
          id: presetPlan.id,
          name: presetPlan.name,
          coverColor: presetPlan.coverColor,
          targetAudience: presetPlan.targetAudience,
          weeklyFrequency: presetPlan.weeklyFrequency,
          description: presetPlan.description,
          days: presetPlan.days,
          enabledAt: 100
        }
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForCurrentPlan(
          currentPlan,
          'current_plan_day_1',
          '周一',
          currentPlan.days[0]
        )
        const state: ActiveWorkoutState = ActiveWorkoutService.createState(preview)

        expect(state.hasWorkout).assertTrue()
        expect(state.planId).assertEqual(currentPlan.id)
        expect(state.dayId).assertEqual('current_plan_day_1')
        expect(state.currentExerciseName).assertEqual(preview.exercises[0].name)
        expect(state.currentExerciseSetProgress).assertEqual('0/' + preview.exercises[0].targetSets.toString() + ' 正式组')
      }
    })

    it('preserves current-plan identifiers through progress updates and session creation', 0, () => {
      const presetPlan: PresetPlan | undefined = TrainingPlanService.getPresetPlanById('preset_upper_lower')
      expect(presetPlan !== undefined).assertTrue()
      if (presetPlan !== undefined) {
        const currentPlan: UserPlan = {
          id: presetPlan.id,
          name: presetPlan.name,
          coverColor: presetPlan.coverColor,
          targetAudience: presetPlan.targetAudience,
          weeklyFrequency: presetPlan.weeklyFrequency,
          description: presetPlan.description,
          days: presetPlan.days,
          enabledAt: 101
        }
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForCurrentPlan(
          currentPlan,
          'current_plan_day_2',
          '星期四',
          currentPlan.days[0]
        )
        const state: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
        const firstExercise: ActiveWorkoutExercise = state.exercises[0]
        const updatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
          state.exercises,
          firstExercise.plannedExerciseId,
          0,
          '50',
          '8'
        )
        const progressedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, updatedExercises)
        const session: WorkoutSession = ActiveWorkoutService.createCompletedSession(
          'session_current_plan_state',
          progressedState,
          1000,
          61000,
          progressedState.completedSets
        )

        expect(state.planId).assertEqual(currentPlan.id)
        expect(state.dayId).assertEqual('current_plan_day_2')
        expect(state.title).assertEqual(currentPlan.days[1].dayLabel)
        expect(progressedState.planId).assertEqual(state.planId)
        expect(progressedState.dayId).assertEqual(state.dayId)
        expect(progressedState.title).assertEqual(state.title)
        expect(progressedState.completedSets).assertEqual(1)
        expect(progressedState.currentExerciseName).assertEqual(firstExercise.name)
        expect(progressedState.currentExerciseSetProgress).assertEqual('1/' + firstExercise.targetSets.toString() + ' 正式组')
        expect(session.planId).assertEqual(currentPlan.id)
        expect(session.dayId).assertEqual('current_plan_day_2')
        expect(session.totalSets).assertEqual(1)
        expect(session.sets.length).assertEqual(1)
        expect(session.sets[0].setId).assertEqual('current_plan_day_2_exercise_1_set_1')
      }
    })

    it('preserves the latest sibling field when weight and reps are entered separately', 0, () => {
      const equipmentIds: string[] = ['eq_bodyweight']
      const restrictedMuscleIds: string[] = []
      const goal: UserGoal = createUserGoal(
        'goal_active_separate_input',
        'hypertrophy',
        'beginner',
        3,
        45,
        equipmentIds,
        restrictedMuscleIds,
        100,
        100
      )
      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreview(plan, 1)
      const state: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
      const firstExercise: ActiveWorkoutExercise = state.exercises[0]

      const weightUpdatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetWeight(
        state.exercises,
        firstExercise.plannedExerciseId,
        0,
        '40'
      )
      const repsUpdatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetReps(
        weightUpdatedExercises,
        firstExercise.plannedExerciseId,
        0,
        '10'
      )
      const updatedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, repsUpdatedExercises)

      expect(updatedState.completedSets).assertEqual(1)
      expect(updatedState.exercises[0].sets[0].weightText).assertEqual('40')
      expect(updatedState.exercises[0].sets[0].repsText).assertEqual('10')
      expect(updatedState.exercises[0].sets[0].estimatedOneRepMax).assertEqual(53)
      expect(updatedState.exercises[0].sets[0].oneRepMaxText).assertEqual('参考 1RM 53 kg')
    })

    it('saves completed workout session with set entries, totals, volume and duration through local repository', 0, () => {
      WorkoutRepository.clear()
      const equipmentIds: string[] = ['eq_bodyweight']
      const restrictedMuscleIds: string[] = []
      const goal: UserGoal = createUserGoal(
        'goal_active_save',
        'hypertrophy',
        'beginner',
        3,
        45,
        equipmentIds,
        restrictedMuscleIds,
        100,
        100
      )
      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreview(plan, 1)
      const state: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
      const firstExercise: ActiveWorkoutExercise = state.exercises[0]
      const firstUpdatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
        state.exercises,
        firstExercise.plannedExerciseId,
        0,
        '80',
        '5'
      )
      const secondUpdatedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
        firstUpdatedExercises,
        firstExercise.plannedExerciseId,
        1,
        '40',
        '10'
      )
      const progressedState: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, secondUpdatedExercises)

      const session: WorkoutSession = ActiveWorkoutService.createCompletedSession(
        'session_active_save',
        progressedState,
        1000,
        181000,
        progressedState.completedSets
      )
      WorkoutRepository.saveSession(session)

      const savedSession: WorkoutSession | undefined = WorkoutRepository.getSessionById('session_active_save')
      expect(savedSession !== undefined).assertTrue()
      if (savedSession !== undefined) {
        expect(savedSession.totalSets).assertEqual(2)
        expect(savedSession.totalVolume).assertEqual(800)
        expect(savedSession.durationSeconds).assertEqual(180)
        expect(savedSession.sets.length).assertEqual(2)
        expect(savedSession.sets[0].setId).assertEqual(firstExercise.plannedExerciseId + '_set_1')
        expect(savedSession.sets[0].exerciseId).assertEqual(firstExercise.exerciseId)
        expect(savedSession.sets[0].weight).assertEqual(80)
        expect(savedSession.sets[0].reps).assertEqual(5)
        expect(savedSession.sets[1].setId).assertEqual(firstExercise.plannedExerciseId + '_set_2')
        expect(savedSession.sets[1].exerciseId).assertEqual(firstExercise.exerciseId)
        expect(savedSession.sets[1].weight).assertEqual(40)
        expect(savedSession.sets[1].reps).assertEqual(10)
      }
    })

    it('advances to the next exercise only after the current one is fully recorded', 0, () => {
      // 缺陷回归：训练页曾把整场训练写死成 6 组、动作名只在进入时赋值一次，
      // 于是做完一个动作的组后不会切到下一个动作。此处锁住「组记录 → 动作推进」契约。
      const presetPlan: PresetPlan | undefined = TrainingPlanService.getPresetPlanById('preset_upper_lower')
      expect(presetPlan !== undefined).assertTrue()
      if (presetPlan !== undefined) {
        const currentPlan: UserPlan = {
          id: presetPlan.id,
          name: presetPlan.name,
          coverColor: presetPlan.coverColor,
          targetAudience: presetPlan.targetAudience,
          weeklyFrequency: presetPlan.weeklyFrequency,
          description: presetPlan.description,
          days: presetPlan.days,
          enabledAt: 102
        }
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForCurrentPlan(
          currentPlan,
          'current_plan_day_1',
          '周一',
          currentPlan.days[0]
        )
        const initial: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
        expect(initial.exercises.length >= 2).assertTrue()

        const first: ActiveWorkoutExercise = initial.exercises[0]
        const second: ActiveWorkoutExercise = initial.exercises[1]
        expect(ActiveWorkoutService.nextPlannedExerciseId(initial)).assertEqual(first.plannedExerciseId)
        expect(ActiveWorkoutService.nextSetIndex(initial)).assertEqual(0)

        let state: ActiveWorkoutState = initial
        for (let index = 0; index < first.targetSets - 1; index++) {
          state = ActiveWorkoutService.recordSet(state, '40', '10')
        }
        // 差一组时仍停在第一个动作，下一组下标指向它的最后一组
        expect(state.currentExerciseName).assertEqual(first.name)
        expect(ActiveWorkoutService.nextPlannedExerciseId(state)).assertEqual(first.plannedExerciseId)
        expect(ActiveWorkoutService.nextSetIndex(state)).assertEqual(first.targetSets - 1)

        state = ActiveWorkoutService.recordSet(state, '40', '10')
        // 第一个动作录满 → 当前动作切到第二个动作的第 1 组
        expect(state.exercises[0].completedSets).assertEqual(first.targetSets)
        expect(state.currentExerciseName).assertEqual(second.name)
        expect(state.currentExerciseSetProgress).assertEqual('0/' + second.targetSets.toString() + ' 正式组')
        expect(ActiveWorkoutService.nextPlannedExerciseId(state)).assertEqual(second.plannedExerciseId)
        expect(ActiveWorkoutService.nextSetIndex(state)).assertEqual(0)
      }
    })

    it('recordSet 连续做满一个动作后分组记录条数等于目标组数（训练页 UI 路径回归）', 0, () => {
      // 设备实测：训练页连做 4 组后分组只显示 1 条，而顶栏组计数正常增长。
      // 此用例复刻页面调用序列——反复把 recordSet 结果写回同一变量，再用
      // buildRecordGroups 派生——用于判定问题出在服务层还是展示层。
      const presetPlan: PresetPlan | undefined = TrainingPlanService.getPresetPlanById('preset_upper_lower')
      expect(presetPlan !== undefined).assertTrue()
      if (presetPlan !== undefined) {
        const currentPlan: UserPlan = {
          id: presetPlan.id,
          name: presetPlan.name,
          coverColor: presetPlan.coverColor,
          targetAudience: presetPlan.targetAudience,
          weeklyFrequency: presetPlan.weeklyFrequency,
          description: presetPlan.description,
          days: presetPlan.days,
          enabledAt: 103
        }
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForCurrentPlan(
          currentPlan,
          'current_plan_day_1',
          '周一',
          currentPlan.days[0]
        )
        let state: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
        const firstExercise: ActiveWorkoutExercise = state.exercises[0]
        for (let index = 0; index < firstExercise.targetSets; index++) {
          state = ActiveWorkoutService.recordSet(state, '20', '8')
        }

        expect(state.exercises[0].completedSets).assertEqual(firstExercise.targetSets)
        const groups: ActiveExerciseRecordGroup[] = buildRecordGroups(state.exercises)
        expect(groups.length >= 1).assertTrue()
        expect(groups[0].sets.length).assertEqual(firstExercise.targetSets)
      }
    })

    it('reports workout completion only after every exercise target is recorded', 0, () => {
      // 结束判据必须是计划总组数（跨动作求和），不是页面里的固定段数常量。
      const equipmentIds: string[] = ['eq_bodyweight']
      const restrictedMuscleIds: string[] = []
      const goal: UserGoal = createUserGoal(
        'goal_active_finish',
        'hypertrophy',
        'beginner',
        3,
        45,
        equipmentIds,
        restrictedMuscleIds,
        100,
        100
      )
      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreview(plan, 1)
      const initial: ActiveWorkoutState = ActiveWorkoutService.createState(preview)
      expect(initial.hasWorkout).assertTrue()

      let expectedTotal: number = 0
      for (let index = 0; index < initial.exercises.length; index++) {
        expectedTotal += initial.exercises[index].targetSets
      }
      expect(expectedTotal > 0).assertTrue()
      expect(ActiveWorkoutService.totalTargetSets(initial)).assertEqual(expectedTotal)

      let state: ActiveWorkoutState = initial
      for (let index = 0; index < expectedTotal - 1; index++) {
        state = ActiveWorkoutService.recordSet(state, '40', '8')
      }
      expect(state.completedSets).assertEqual(expectedTotal - 1)
      expect(ActiveWorkoutService.nextExercise(state) !== undefined).assertTrue()

      state = ActiveWorkoutService.recordSet(state, '40', '8')
      expect(state.completedSets).assertEqual(expectedTotal)
      expect(ActiveWorkoutService.nextExercise(state) === undefined).assertTrue()
    })
  })
}
