/**
 * TargetLoopSkeleton -- shared training model tests.
 *
 * Feature #1: shared data models for the target loop skeleton.
 */
import { describe, it, expect } from '@ohos/hypium'
import ContentRepository from '../main/ets/shared/services/ContentRepository'
import {
  ExerciseContent,
  UserGoal,
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
  })
}
