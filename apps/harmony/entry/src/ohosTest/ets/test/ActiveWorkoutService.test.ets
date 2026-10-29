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

/**
 * 固定前置：预设上/下肢计划的活跃训练态。
 *
 * recordSetFor 的用例只关心「写哪个动作」，不需要每次重写一遍计划装配；
 * 预设取不到时回退到 PlanEngine 生成的计划，保证用例不因资源变动而整体跳过。
 */
function createPresetActiveState(enabledAt: number): ActiveWorkoutState {
  const presetPlan: PresetPlan | undefined = TrainingPlanService.getPresetPlanById('preset_upper_lower')
  if (presetPlan === undefined) {
    const equipmentIds: string[] = ['eq_bodyweight']
    const restrictedMuscleIds: string[] = []
    const goal: UserGoal = createUserGoal(
      'goal_preset_fallback',
      'hypertrophy',
      'beginner',
      3,
      45,
      equipmentIds,
      restrictedMuscleIds,
      100,
      100
    )
    return ActiveWorkoutService.createState(WorkoutPreviewService.createPreview(PlanEngine.generatePlan(goal), 1))
  }
  const currentPlan: UserPlan = {
    id: presetPlan.id,
    name: presetPlan.name,
    coverColor: presetPlan.coverColor,
    targetAudience: presetPlan.targetAudience,
    weeklyFrequency: presetPlan.weeklyFrequency,
    description: presetPlan.description,
    days: presetPlan.days,
    enabledAt: enabledAt
  }
  const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForCurrentPlan(
    currentPlan,
    'current_plan_day_' + enabledAt.toString(),
    '周一',
    currentPlan.days[0]
  )
  return ActiveWorkoutService.createState(preview)
}

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

    it('recordSetFor 写入界面选中的动作，不影响其它动作', 0, () => {
      // 训练页顶部动作切换胶囊的契约：选哪个动作就写哪个动作。
      // 若沿用 recordSet（首个未录满动作），用户看着动作 3 记录却写进动作 1，且无任何报错。
      const initial: ActiveWorkoutState = createPresetActiveState(104)
      expect(initial.exercises.length >= 2).assertTrue()
      if (initial.exercises.length >= 2) {
        const second: ActiveWorkoutExercise = initial.exercises[1]
        const next: ActiveWorkoutState =
          ActiveWorkoutService.recordSetFor(initial, second.plannedExerciseId, '60', '8')

        expect(next.exercises[1].sets[0].isComplete).assertTrue()
        expect(next.exercises[1].sets[0].weightText).assertEqual('60')
        expect(next.exercises[1].completedSets).assertEqual(1)
        // 「不写错动作」的判据：第一个动作的组数不受影响
        expect(next.exercises[0].completedSets).assertEqual(0)
        expect(next.completedSets).assertEqual(1)
      }
    })

    it('recordSetFor 在目标动作已录满时原样返回同一 state 引用', 0, () => {
      let state: ActiveWorkoutState = createPresetActiveState(105)
      const first: ActiveWorkoutExercise = state.exercises[0]
      for (let index = 0; index < first.targetSets; index++) {
        state = ActiveWorkoutService.recordSetFor(state, first.plannedExerciseId, '40', '10')
      }
      expect(state.exercises[0].completedSets).assertEqual(first.targetSets)

      const afterFull: ActiveWorkoutState =
        ActiveWorkoutService.recordSetFor(state, first.plannedExerciseId, '40', '10')
      // 同一引用 = 没有写到任何地方（既没覆盖已满动作，也没溢出到别的动作）
      expect(afterFull === state).assertTrue()
    })

    it('nextEmptySetIndex 返回动作内首个空组，热身组按已填处理', 0, () => {
      const state: ActiveWorkoutState = createPresetActiveState(106)
      const first: ActiveWorkoutExercise = state.exercises[0]
      expect(first.targetSets >= 2).assertTrue()
      expect(ActiveWorkoutService.nextEmptySetIndex(first)).assertEqual(0)

      // 跳过第 0 组先填第 1 组：下一个空组仍是 0
      const skippedExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
        state.exercises, first.plannedExerciseId, 1, '40', '10')
      const skipped: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, skippedExercises)
      expect(ActiveWorkoutService.nextEmptySetIndex(skipped.exercises[0])).assertEqual(0)

      // 第 0 组已录且标为热身：不该被当成空组覆盖
      const filledExercises: ActiveWorkoutExercise[] = ActiveWorkoutService.updateSetEntry(
        state.exercises, first.plannedExerciseId, 0, '20', '15')
      const warmedExercises: ActiveWorkoutExercise[] =
        ActiveWorkoutService.updateSetWarmup(filledExercises, first.plannedExerciseId, 0, true)
      const warmed: ActiveWorkoutState = ActiveWorkoutService.createStateWithProgress(state, warmedExercises)
      expect(warmed.exercises[0].sets[0].isWarmup).assertTrue()
      expect(ActiveWorkoutService.nextEmptySetIndex(warmed.exercises[0])).assertEqual(1)

      // 没有组条目 → -1（调用方据此判定不可写）
      const emptySets: ActiveWorkoutExercise = {
        plannedExerciseId: 'planned_empty',
        exerciseId: 'ex_empty',
        name: '空动作',
        targetSets: 0,
        targetReps: '8-12',
        intensityNote: '',
        completedSets: 0,
        sets: []
      }
      expect(ActiveWorkoutService.nextEmptySetIndex(emptySets)).assertEqual(-1)
    })

    it('endExercise 把动作收缩到已完成的组数，其它动作不受影响', 0, () => {
      const initial: ActiveWorkoutState = createPresetActiveState(107)
      const first: ActiveWorkoutExercise = initial.exercises[0]
      expect(first.targetSets >= 2).assertTrue()
      if (first.targetSets >= 2) {
        // 先做 1 组，再提前结束 → 收缩到 1 组
        const afterOne: ActiveWorkoutState =
          ActiveWorkoutService.recordSetFor(initial, first.plannedExerciseId, '40', '10')
        const ended: ActiveWorkoutState =
          ActiveWorkoutService.endExercise(afterOne, first.plannedExerciseId)

        expect(ended.exercises[0].targetSets).assertEqual(1)
        expect(ended.exercises[0].completedSets).assertEqual(1)
        expect(ended.exercises[0].sets.length).assertEqual(1)
        expect(ended.exercises[0].sets[0].isComplete).assertTrue()
        // 其它动作原样保留
        expect(ended.exercises[1].targetSets).assertEqual(initial.exercises[1].targetSets)
        expect(ended.exercises[1].completedSets).assertEqual(0)
        // 总组数按新的 targetSets 重算
        let expectedTotal: number = 0
        for (let index = 0; index < ended.exercises.length; index++) {
          expectedTotal += ended.exercises[index].targetSets
        }
        expect(ended.totalTargetSets).assertEqual(expectedTotal)
      }
    })

    it('endExercise 在动作已录满时原样返回同一引用', 0, () => {
      let state: ActiveWorkoutState = createPresetActiveState(108)
      const first: ActiveWorkoutExercise = state.exercises[0]
      for (let index = 0; index < first.targetSets; index++) {
        state = ActiveWorkoutService.recordSetFor(state, first.plannedExerciseId, '40', '10')
      }
      const afterEnd: ActiveWorkoutState =
        ActiveWorkoutService.endExercise(state, first.plannedExerciseId)
      // 同一引用 = 没有改写任何字段（调用方据此判定无需结束）
      expect(afterEnd === state).assertTrue()
    })

    it('endExercise 允许一组未做就结束，nextExercise 跳过该动作', 0, () => {
      const initial: ActiveWorkoutState = createPresetActiveState(109)
      expect(initial.exercises.length >= 2).assertTrue()
      if (initial.exercises.length >= 2) {
        const first: ActiveWorkoutExercise = initial.exercises[0]
        const second: ActiveWorkoutExercise = initial.exercises[1]
        const ended: ActiveWorkoutState =
          ActiveWorkoutService.endExercise(initial, first.plannedExerciseId)

        expect(ended.exercises[0].targetSets).assertEqual(0)
        expect(ended.exercises[0].sets.length).assertEqual(0)
        const next: ActiveWorkoutExercise | undefined = ActiveWorkoutService.nextExercise(ended)
        expect(next !== undefined).assertTrue()
        if (next !== undefined) {
          expect(next.plannedExerciseId).assertEqual(second.plannedExerciseId)
        }
      }
    })

    it('endExercise 逐个结束后 nextExercise 为空，训练可收尾', 0, () => {
      let state: ActiveWorkoutState = createPresetActiveState(110)
      expect(state.exercises.length > 0).assertTrue()
      for (let index = 0; index < state.exercises.length; index++) {
        const exercise: ActiveWorkoutExercise = state.exercises[index]
        state = ActiveWorkoutService.endExercise(state, exercise.plannedExerciseId)
      }
      expect(ActiveWorkoutService.nextExercise(state) === undefined).assertTrue()
    })
  })
}
