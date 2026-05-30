import { describe, it, expect } from '@ohos/hypium'
import { ExerciseContent, UserGoal, createUserGoal } from '../../../main/ets/shared/models/TrainingModels'
import ContentRepository, {
  ContentSourceInfo,
  ExerciseDetailViewModel,
  ExerciseLibraryItem
} from '../../../main/ets/shared/services/ContentRepository'
import { DatabaseContentDataSource } from '../../../main/ets/shared/services/DatabaseContentDataSource'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'

function hasValue(values: string[], targetValue: string): boolean {
  for (let index = 0; index < values.length; index++) {
    if (values[index] === targetValue) {
      return true
    }
  }
  return false
}

export default function contentRepositoryTest(): void {
  describe('ContentRepository', () => {
    it('reads exercise content through the JSONL seed adapter', 0, () => {
      const sourceInfo: ContentSourceInfo = ContentRepository.getContentSourceInfo()

      expect(sourceInfo.sourceId).assertEqual('jsonl_seed')
      expect(sourceInfo.sourceName).assertEqual('JSONL seed content')
      expect(sourceInfo.databaseBacked).assertFalse()
      expect(sourceInfo.buildValidationRequired).assertTrue()
    })

    it('can switch repository reads to a database content source', 0, () => {
      const databaseSource: DatabaseContentDataSource = new DatabaseContentDataSource(
        ContentRepository.getMuscles(),
        ContentRepository.getEquipment(),
        ContentRepository.getExercises()
      )

      ContentRepository.useContentDataSource(databaseSource)
      const sourceInfo: ContentSourceInfo = ContentRepository.getContentSourceInfo()
      const exercise: ExerciseContent | undefined = ContentRepository.getExerciseById('ex_push_up')

      expect(sourceInfo.sourceId).assertEqual('local_database')
      expect(sourceInfo.databaseBacked).assertTrue()
      expect(exercise !== undefined).assertTrue()

      ContentRepository.useJsonlSeedSource()
    })

    it('returns Chinese labels for local exercise metadata', 0, () => {
      expect(ContentRepository.getMuscleName('muscle_chest')).assertEqual('胸部')
      expect(ContentRepository.getEquipmentName('eq_bodyweight')).assertEqual('徒手')
    })

    it('keeps local action library seeded with Chinese exercise detail', 0, () => {
      const exercise: ExerciseContent | undefined = ContentRepository.getExerciseById('ex_push_up')
      expect(exercise !== undefined).assertTrue()
      if (exercise !== undefined) {
        expect(exercise.nameZh).assertEqual('俯卧撑')
        expect(exercise.steps.length > 0).assertTrue()
        expect(ContentRepository.hasVideoAsset(exercise)).assertFalse()
      }
    })

    it('builds exercise detail display data with local video placeholder and alternatives', 0, () => {
      const detail: ExerciseDetailViewModel | undefined = ContentRepository.getExerciseDetailViewModel('ex_push_up')
      expect(detail !== undefined).assertTrue()
      if (detail !== undefined) {
        expect(detail.name).assertEqual('俯卧撑')
        expect(detail.steps.length).assertLarger(0)
        expect(detail.safetyNotes.length).assertLarger(0)
        expect(detail.alternativeNames.length).assertEqual(1)
        expect(detail.alternativeNames[0]).assertEqual('哑铃卧推')
        expect(detail.videoPlaceholder).assertEqual('视频占位：本地动作库暂未接入视频素材')
      }
    })

    it('builds local exercise library display rows with key metadata', 0, () => {
      const rows: ExerciseLibraryItem[] = ContentRepository.getExerciseLibraryItems()
      expect(rows.length).assertLarger(29)
      expect(rows[0].exerciseId).assertEqual('ex_barbell_bench_press')
      expect(rows[0].name).assertEqual('杠铃卧推')
      expect(rows[0].primaryMuscleName).assertEqual('胸部')
      expect(rows[0].equipmentText).assertEqual('杠铃')
      expect(rows[0].difficultyText).assertEqual('进阶')
    })

    it('keeps expanded exercise content local and covered across key categories', 0, () => {
      const exercises: ExerciseContent[] = ContentRepository.getExercises()
      let advancedCount: number = 0
      let bandCount: number = 0
      let stabilityCount: number = 0
      let localVideoCount: number = 0

      for (let index = 0; index < exercises.length; index++) {
        const exercise: ExerciseContent = exercises[index]
        if (exercise.difficulty === 'advanced') {
          advancedCount++
        }
        if (hasValue(exercise.equipmentIds, 'eq_band')) {
          bandCount++
        }
        if (hasValue(exercise.goalTags, 'stability')) {
          stabilityCount++
        }
        if (exercise.videoUrl.length > 0) {
          expect(exercise.videoUrl.indexOf('http://')).assertEqual(-1)
          expect(exercise.videoUrl.indexOf('https://')).assertEqual(-1)
          expect(exercise.videoUrl.indexOf('local://')).assertEqual(0)
          localVideoCount++
        }
      }

      expect(exercises.length).assertLarger(29)
      expect(advancedCount).assertLarger(1)
      expect(bandCount).assertLarger(1)
      expect(stabilityCount).assertLarger(2)
      expect(localVideoCount).assertLarger(0)
    })

    it('filters local exercise library rows by goal equipment muscle and difficulty', 0, () => {
      const allRows: ExerciseLibraryItem[] = ContentRepository.filterExerciseLibraryItems('', '', '', '')
      expect(allRows.length).assertEqual(ContentRepository.getExerciseLibraryItems().length)

      const rows: ExerciseLibraryItem[] = ContentRepository.filterExerciseLibraryItems(
        'strength',
        'eq_barbell',
        'muscle_chest',
        'intermediate'
      )
      expect(rows.length).assertEqual(1)
      expect(rows[0].exerciseId).assertEqual('ex_barbell_bench_press')
      expect(rows[0].equipmentIds[0]).assertEqual('eq_barbell')
      expect(rows[0].primaryMuscleId).assertEqual('muscle_chest')
      expect(rows[0].difficulty).assertEqual('intermediate')
    })

    it('filters candidate exercises by goal equipment muscle and difficulty', 0, () => {
      const candidates: ExerciseContent[] = ContentRepository.getCandidateExercises(
        'hypertrophy',
        'beginner',
        ['eq_bodyweight'],
        'muscle_chest',
        []
      )
      expect(candidates.length).assertLarger(0)
      expect(candidates[0].exerciseId).assertEqual('ex_push_up')
    })

    it('reads machine strength candidates from local JSONL content', 0, () => {
      const candidates: ExerciseContent[] = ContentRepository.getCandidateExercises(
        'strength',
        'beginner',
        ['eq_machine'],
        'muscle_legs',
        []
      )
      expect(candidates.length).assertLarger(0)
      expect(candidates[0].exerciseId).assertEqual('ex_machine_leg_press')
      expect(candidates[0].equipmentIds[0]).assertEqual('eq_machine')
    })

    it('lets plan engine select bodyweight beginner actions for hypertrophy goal', 0, () => {
      const goal: UserGoal = createUserGoal(
        'test_goal',
        'hypertrophy',
        'beginner',
        1,
        45,
        ['eq_bodyweight'],
        [],
        1,
        1
      )
      const plan = PlanEngine.generatePlan(goal)
      expect(plan.days.length).assertEqual(1)
      expect(plan.days[0].exercises.length).assertLarger(0)
      expect(plan.days[0].exercises[0].exerciseId).assertEqual('ex_push_up')
    })
  })
}
