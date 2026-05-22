/**
 * TargetLoopSkeleton -- shared training model tests.
 *
 * Feature #1: shared data models for the target loop skeleton.
 */
import { describe, it, expect } from '@ohos/hypium'
import { StartupDecision } from '../main/ets/app/AppState'
import ContentRepository from '../main/ets/shared/services/ContentRepository'
import GoalRepository from '../main/ets/shared/services/GoalRepository'
import GoalSetupService from '../main/ets/shared/services/GoalSetupService'
import PlanEngine from '../main/ets/shared/services/PlanEngine'
import ReviewService from '../main/ets/shared/services/ReviewService'
import SyncService from '../main/ets/shared/services/SyncService'
import WorkoutRepository from '../main/ets/shared/services/WorkoutRepository'
import {
  ContentSyncStatus,
  ExerciseContent,
  TrainingPlan,
  UserGoal,
  WorkoutSession,
  WorkoutSet,
  createExerciseContent,
  createUserGoal,
  createWorkoutSet,
  estimateOneRepMax
} from '../main/ets/shared/models/TrainingModels'

export default function targetLoopSkeletonTest() {
  describe('TargetLoop models', () => {
    it('creates a typed user goal', 0, () => {
      const equipmentIds: string[] = ['eq_dumbbell']
      const restrictedMuscleIds: string[] = ['muscle_knee_sensitive']
      const goal: UserGoal = createUserGoal(
        'goal_1',
        'hypertrophy',
        'beginner',
        3,
        60,
        equipmentIds,
        restrictedMuscleIds,
        1000,
        1000
      )

      expect(goal.goalId).assertEqual('goal_1')
      expect(goal.goalType).assertEqual('hypertrophy')
      expect(goal.level).assertEqual('beginner')
      expect(goal.weeklyDays).assertEqual(3)
      expect(goal.sessionMinutes).assertEqual(60)
      expect(goal.equipmentIds.length).assertEqual(1)
      expect(goal.restrictedMuscleIds.length).assertEqual(1)
      expect(goal.createdAt).assertEqual(1000)
      expect(goal.updatedAt).assertEqual(1000)
    })

    it('creates typed exercise content', 0, () => {
      const aliases: string[] = ['bench']
      const primaryMuscleIds: string[] = ['muscle_chest']
      const secondaryMuscleIds: string[] = ['muscle_triceps']
      const equipmentIds: string[] = ['eq_barbell']
      const goalTags: string[] = ['hypertrophy']
      const steps: string[] = ['Set shoulders', 'Press the bar']
      const cues: string[] = ['Keep wrist neutral']
      const commonMistakes: string[] = ['Flaring elbows']
      const safetyNotes: string[] = ['Use a spotter']
      const alternativeExerciseIds: string[] = ['ex_dumbbell_press']
      const ex: ExerciseContent = createExerciseContent(
        'ex_barbell_bench_press',
        'barbell bench press',
        'Barbell Bench Press',
        aliases,
        primaryMuscleIds,
        secondaryMuscleIds,
        equipmentIds,
        'intermediate',
        goalTags,
        '',
        '',
        steps,
        cues,
        commonMistakes,
        safetyNotes,
        alternativeExerciseIds,
        1
      )

      expect(ex.exerciseId).assertEqual('ex_barbell_bench_press')
      expect(ex.nameZh).assertEqual('barbell bench press')
      expect(ex.nameEn).assertEqual('Barbell Bench Press')
      expect(ex.aliases[0]).assertEqual('bench')
      expect(ex.primaryMuscleIds[0]).assertEqual('muscle_chest')
      expect(ex.secondaryMuscleIds[0]).assertEqual('muscle_triceps')
      expect(ex.equipmentIds[0]).assertEqual('eq_barbell')
      expect(ex.difficulty).assertEqual('intermediate')
      expect(ex.goalTags[0]).assertEqual('hypertrophy')
      expect(ex.steps.length).assertEqual(2)
      expect(ex.cues[0]).assertEqual('Keep wrist neutral')
      expect(ex.commonMistakes[0]).assertEqual('Flaring elbows')
      expect(ex.safetyNotes[0]).assertEqual('Use a spotter')
      expect(ex.alternativeExerciseIds[0]).assertEqual('ex_dumbbell_press')
      expect(ex.contentVersion).assertEqual(1)
    })

    it('creates typed workout sets with effort fields', 0, () => {
      const set: WorkoutSet = createWorkoutSet('set_1', 'ex_barbell_bench_press', 100, 5, 8, false)

      expect(set.setId).assertEqual('set_1')
      expect(set.exerciseId).assertEqual('ex_barbell_bench_press')
      expect(set.weight).assertEqual(100)
      expect(set.reps).assertEqual(5)
      expect(set.rpe).assertEqual(8)
      expect(set.isWarmup).assertFalse()
    })

    it('estimates one rep max with Epley formula', 0, () => {
      const set: WorkoutSet = createWorkoutSet('set_1', 'ex_barbell_bench_press', 100, 5, 8, false)

      expect(estimateOneRepMax(set.weight, set.reps)).assertEqual(116.67)
    })

    it('loads local seed muscles', 0, () => {
      expect(ContentRepository.getMuscles().length).assertEqual(6)
    })

    it('loads local seed equipment', 0, () => {
      expect(ContentRepository.getEquipment().length).assertEqual(6)
    })

    it('returns bench press alternatives in preferred order', 0, () => {
      const alternatives: ExerciseContent[] = ContentRepository.getAlternativeExercises('ex_barbell_bench_press')

      expect(alternatives.length >= 1).assertTrue()
      expect(alternatives[0].exerciseId).assertEqual('ex_dumbbell_bench_press')
    })

    it('finds exercise content by id', 0, () => {
      const exercise: ExerciseContent | undefined = ContentRepository.getExerciseById('ex_barbell_bench_press')

      expect(exercise !== undefined).assertTrue()
      if (exercise !== undefined) {
        expect(exercise.exerciseId).assertEqual('ex_barbell_bench_press')
      }
    })

    it('searches exercise names and aliases', 0, () => {
      const results: ExerciseContent[] = ContentRepository.searchExercises('bench')

      expect(results.length >= 1).assertTrue()
      expect(results[0].exerciseId).assertEqual('ex_barbell_bench_press')
    })

    it('filters exercises by muscle', 0, () => {
      const results: ExerciseContent[] = ContentRepository.getExercisesByMuscle('muscle_chest')

      expect(results.length >= 1).assertTrue()
    })

    it('filters exercises by equipment', 0, () => {
      const results: ExerciseContent[] = ContentRepository.getExercisesByEquipment('eq_dumbbell')

      expect(results.length >= 1).assertTrue()
    })

    it('returns empty values for missing exercise ids', 0, () => {
      const exercise: ExerciseContent | undefined = ContentRepository.getExerciseById('ex_unknown')
      const alternatives: ExerciseContent[] = ContentRepository.getAlternativeExercises('ex_unknown')

      expect(exercise === undefined).assertTrue()
      expect(alternatives.length).assertEqual(0)
    })

    it('returns defensive copies of exercise arrays', 0, () => {
      const firstRead: ExerciseContent | undefined = ContentRepository.getExerciseById('ex_barbell_bench_press')

      expect(firstRead !== undefined).assertTrue()
      if (firstRead !== undefined) {
        firstRead.steps.push('mutated')
      }

      const secondRead: ExerciseContent | undefined = ContentRepository.getExerciseById('ex_barbell_bench_press')

      expect(secondRead !== undefined).assertTrue()
      if (secondRead !== undefined) {
        expect(secondRead.steps.includes('mutated')).assertFalse()
      }
    })

    it('generates a three day hypertrophy plan from available barbell and dumbbell equipment', 0, () => {
      const equipmentIds: string[] = ['eq_barbell', 'eq_dumbbell']
      const restrictedMuscleIds: string[] = []
      const goal: UserGoal = createUserGoal(
        'goal_plan_engine',
        'hypertrophy',
        'beginner',
        3,
        60,
        equipmentIds,
        restrictedMuscleIds,
        2000,
        2000
      )

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)

      expect(plan.days.length).assertEqual(3)
      for (let index = 0; index < plan.days.length; index++) {
        expect(plan.days[index].exercises.length > 0).assertTrue()
      }
      expect(plan.generatedBy).assertEqual('rule_v1')
    })

    it('calculates workout volume from completed working sets', 0, () => {
      const sets: WorkoutSet[] = [
        createWorkoutSet('set_volume_1', 'ex_barbell_bench_press', 100, 5, 8, false),
        createWorkoutSet('set_volume_2', 'ex_barbell_bench_press', 90, 8, 8, false)
      ]

      expect(ReviewService.calculateVolume(sets)).assertEqual(1220)
    })

    it('excludes warmup sets from workout volume', 0, () => {
      const sets: WorkoutSet[] = [
        createWorkoutSet('set_warmup_1', 'ex_barbell_bench_press', 60, 10, 5, true),
        createWorkoutSet('set_work_1', 'ex_barbell_bench_press', 100, 5, 8, false)
      ]

      expect(ReviewService.calculateVolume(sets)).assertEqual(500)
    })

    it('calculates best estimated one rep max from non-warmup sets', 0, () => {
      const sets: WorkoutSet[] = [
        createWorkoutSet('set_warmup_1', 'ex_barbell_bench_press', 150, 5, 5, true),
        createWorkoutSet('set_work_1', 'ex_barbell_bench_press', 100, 5, 8, false),
        createWorkoutSet('set_work_2', 'ex_barbell_bench_press', 110, 3, 9, false)
      ]

      expect(ReviewService.calculateBestEstimatedOneRepMax(sets)).assertEqual(121)
    })

    it('calculates completion rate with zero-plan guard and rounded percentage', 0, () => {
      expect(ReviewService.calculateCompletionRate(2, 0)).assertEqual(0)
      expect(ReviewService.calculateCompletionRate(2, 3)).assertEqual(67)
    })

    it('returns local content sync status', 0, () => {
      const status: ContentSyncStatus = SyncService.getLocalStatus()

      expect(status.localVersion).assertEqual(1)
      expect(status.status).assertEqual('local_available')
    })

    it('routes users with goals to home page on startup', 0, () => {
      expect(StartupDecision.getInitialRoute(true)).assertEqual('pages/HomePage')
    })

    it('routes users without goals to onboarding goal setup on startup', 0, () => {
      expect(StartupDecision.getInitialRoute(false)).assertEqual('features/onboarding/pages/GoalSetupPage')
    })

    it('stores the current goal locally', 0, () => {
      GoalRepository.clearLocal()
      const equipmentIds: string[] = ['eq_dumbbell']
      const restrictedMuscleIds: string[] = []
      const goal: UserGoal = createUserGoal(
        'goal_repo_1',
        'hypertrophy',
        'beginner',
        3,
        45,
        equipmentIds,
        restrictedMuscleIds,
        3000,
        3000
      )

      GoalRepository.saveLocalGoal(goal)

      const savedGoal: UserGoal | undefined = GoalRepository.getLocalGoal()
      expect(GoalRepository.hasLocalGoal()).assertTrue()
      expect(savedGoal !== undefined).assertTrue()
      if (savedGoal !== undefined) {
        expect(savedGoal.goalId).assertEqual('goal_repo_1')
        expect(savedGoal.weeklyDays).assertEqual(3)
      }
    })

    it('returns defensive copies of local goal arrays', 0, () => {
      GoalRepository.clearLocal()
      const equipmentIds: string[] = ['eq_barbell']
      const restrictedMuscleIds: string[] = ['muscle_knee_sensitive']
      const goal: UserGoal = createUserGoal(
        'goal_repo_copy',
        'strength',
        'intermediate',
        4,
        60,
        equipmentIds,
        restrictedMuscleIds,
        4000,
        4000
      )

      GoalRepository.saveLocalGoal(goal)
      const firstRead: UserGoal | undefined = GoalRepository.getLocalGoal()
      if (firstRead !== undefined) {
        firstRead.equipmentIds.push('eq_mutated')
        firstRead.restrictedMuscleIds.push('muscle_mutated')
      }

      const secondRead: UserGoal | undefined = GoalRepository.getLocalGoal()
      expect(secondRead !== undefined).assertTrue()
      if (secondRead !== undefined) {
        expect(secondRead.equipmentIds.length).assertEqual(1)
        expect(secondRead.restrictedMuscleIds.length).assertEqual(1)
      }
    })

    it('creates a goal from onboarding questionnaire selections', 0, () => {
      const equipmentIds: string[] = ['eq_dumbbell', 'eq_bodyweight']
      const restrictedMuscleIds: string[] = ['muscle_knee_sensitive']

      const goal: UserGoal = GoalSetupService.createGoalFromSelection(
        'goal_selection_1',
        'fat_loss',
        'beginner',
        4,
        50,
        equipmentIds,
        restrictedMuscleIds,
        5000
      )

      expect(goal.goalId).assertEqual('goal_selection_1')
      expect(goal.goalType).assertEqual('fat_loss')
      expect(goal.level).assertEqual('beginner')
      expect(goal.weeklyDays).assertEqual(4)
      expect(goal.sessionMinutes).assertEqual(50)
      expect(goal.equipmentIds.length).assertEqual(2)
      expect(goal.restrictedMuscleIds.length).assertEqual(1)
      expect(goal.createdAt).assertEqual(5000)
      expect(goal.updatedAt).assertEqual(5000)
    })

    it('copies onboarding questionnaire arrays into the created goal', 0, () => {
      const equipmentIds: string[] = ['eq_barbell']
      const restrictedMuscleIds: string[] = []

      const goal: UserGoal = GoalSetupService.createGoalFromSelection(
        'goal_selection_copy',
        'strength',
        'intermediate',
        5,
        60,
        equipmentIds,
        restrictedMuscleIds,
        6000
      )

      equipmentIds.push('eq_mutated')
      restrictedMuscleIds.push('muscle_mutated')

      expect(goal.equipmentIds.length).assertEqual(1)
      expect(goal.restrictedMuscleIds.length).assertEqual(0)
    })

    it('stores created workout sessions locally', 0, () => {
      WorkoutRepository.clear()
      const sets: WorkoutSet[] = [
        createWorkoutSet('set_repo_1', 'ex_barbell_bench_press', 100, 5, 8, false)
      ]
      const session: WorkoutSession = WorkoutRepository.createSession(
        'session_repo_1',
        'plan_goal_repo',
        'day_1',
        1000,
        1600,
        600,
        1,
        500,
        3,
        'felt strong',
        sets
      )

      WorkoutRepository.saveSession(session)

      const sessions: WorkoutSession[] = WorkoutRepository.getSessions()
      expect(sessions.length > 0).assertTrue()
      expect(sessions[0].sessionId).assertEqual('session_repo_1')
      expect(sessions[0].totalVolume).assertEqual(500)
      expect(sessions[0].sets[0].setId).assertEqual('set_repo_1')
      expect(sessions[0].sets[0].exerciseId).assertEqual('ex_barbell_bench_press')
      expect(sessions[0].sets[0].weight).assertEqual(100)
      expect(sessions[0].sets[0].reps).assertEqual(5)
      expect(sessions[0].sets[0].rpe).assertEqual(8)
      expect(sessions[0].sets[0].isWarmup).assertFalse()
    })

    it('returns defensive copies of stored workout session sets', 0, () => {
      WorkoutRepository.clear()
      const sets: WorkoutSet[] = [
        createWorkoutSet('set_copy_1', 'ex_barbell_bench_press', 80, 6, 7, false)
      ]
      const session: WorkoutSession = WorkoutRepository.createSession(
        'session_copy_1',
        'plan_goal_copy',
        'day_1',
        2000,
        2600,
        600,
        1,
        480,
        2,
        'copy check',
        sets
      )

      WorkoutRepository.saveSession(session)
      const firstRead: WorkoutSession[] = WorkoutRepository.getSessions()
      firstRead[0].sets[0].reps = 99

      const secondRead: WorkoutSession[] = WorkoutRepository.getSessions()
      expect(secondRead[0].sets[0].reps).assertEqual(6)
    })
  })
}
