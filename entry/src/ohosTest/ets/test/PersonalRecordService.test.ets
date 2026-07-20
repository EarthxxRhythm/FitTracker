import { describe, it, expect } from '@ohos/hypium'
import { WorkoutSession, createWorkoutSession, createWorkoutSet } from '../../../main/ets/shared/models/TrainingModels'
import PersonalRecordService, {
  ExercisePersonalRecord,
  ExercisePersonalRecordDetail
} from '../../../main/ets/shared/services/PersonalRecordService'

export default function personalRecordServiceTest(): void {
  describe('PersonalRecordService', () => {
    it('returns empty records when there are no sessions', 0, () => {
      const sessions: WorkoutSession[] = []

      const records: ExercisePersonalRecord[] = PersonalRecordService.createRecords(sessions)

      expect(records.length).assertEqual(0)
    })

    it('aggregates historical best 1RM, best weight, and best reps for every exercised movement', 0, () => {
      const sessions: WorkoutSession[] = [
        createWorkoutSession(
          'session_record_1',
          'plan_record',
          'day_1',
          1714521600000,
          1714523400000,
          1800,
          3,
          0,
          0,
          'completed_sets=3;target_sets=3',
          [
            createWorkoutSet('set_record_1', 'ex_barbell_bench_press', 80, 8, 8, false),
            createWorkoutSet('set_record_2', 'ex_barbell_bench_press', 60, 15, 7, false),
            createWorkoutSet('set_record_invalid_empty', '', 120, 5, 8, false),
            createWorkoutSet('set_record_invalid_weight', 'ex_barbell_bench_press', 0, 20, 8, false),
            createWorkoutSet('set_record_3', 'ex_barbell_row', 70, 8, 8, false)
          ]
        ),
        createWorkoutSession(
          'session_record_2',
          'plan_record',
          'day_2',
          1715126400000,
          1715128200000,
          1800,
          3,
          0,
          0,
          'completed_sets=3;target_sets=3',
          [
            createWorkoutSet('set_record_4', 'ex_barbell_bench_press', 95, 3, 9, false),
            createWorkoutSet('set_record_5', 'ex_barbell_bench_press', 100, 1, 5, true),
            createWorkoutSet('set_record_invalid_reps', 'ex_barbell_row', 120, 0, 8, false),
            createWorkoutSet('set_record_6', 'ex_barbell_row', 75, 10, 8, false)
          ]
        )
      ]

      const records: ExercisePersonalRecord[] = PersonalRecordService.createRecords(sessions)

      expect(records.length).assertEqual(2)
      expect(records[0].exerciseId).assertEqual('ex_barbell_bench_press')
      expect(records[0].bestOneRepMax).assertEqual(105)
      expect(records[0].bestWeight).assertEqual(95)
      expect(records[0].bestReps).assertEqual(15)
      expect(records[0].bestDateText).assertEqual('2024-05-08')

      expect(records[1].exerciseId).assertEqual('ex_barbell_row')
      expect(records[1].bestOneRepMax).assertEqual(100)
      expect(records[1].bestWeight).assertEqual(75)
      expect(records[1].bestReps).assertEqual(10)
      expect(records[1].bestDateText).assertEqual('2024-05-08')
    })

    it('builds record details with per-session counts, recent totals, sorting, and warmup exclusion', 0, () => {
      const sessions: WorkoutSession[] = [
        createWorkoutSession(
          'session_detail_1',
          'plan_record',
          'day_1',
          1714521600000,
          1714523400000,
          1800,
          4,
          0,
          0,
          'completed_sets=4;target_sets=4',
          [
            createWorkoutSet('set_detail_1', 'ex_barbell_bench_press', 80, 8, 8, false),
            createWorkoutSet('set_detail_2', 'ex_barbell_bench_press', 85, 6, 8, false),
            createWorkoutSet('set_detail_3', 'ex_barbell_row', 70, 10, 8, false)
          ]
        ),
        createWorkoutSession(
          'session_detail_2',
          'plan_record',
          'day_2',
          1715126400000,
          1715128200000,
          1800,
          4,
          0,
          0,
          'completed_sets=4;target_sets=4',
          [
            createWorkoutSet('set_detail_4', 'ex_barbell_bench_press', 90, 5, 9, false),
            createWorkoutSet('set_detail_5', 'ex_barbell_bench_press', 40, 12, 6, true),
            createWorkoutSet('set_detail_6', 'ex_barbell_row', 75, 8, 8, false)
          ]
        )
      ]

      const details: ExercisePersonalRecordDetail[] = PersonalRecordService.createRecordDetails(sessions)

      expect(details.length).assertEqual(2)
      expect(details[0].exerciseId).assertEqual('ex_barbell_bench_press')
      expect(details[0].bestOneRepMax).assertEqual(105)
      expect(details[0].bestWeight).assertEqual(90)
      expect(details[0].bestReps).assertEqual(8)
      expect(details[0].bestDateText).assertEqual('2024-05-08')
      expect(details[0].lastPerformedDateText).assertEqual('2024-05-08')
      expect(details[0].sessionCount).assertEqual(2)
      expect(details[0].performedSetCount).assertEqual(3)
      expect(details[0].recentOneRepMax).assertEqual(105)
      expect(details[0].recentWeight).assertEqual(90)
      expect(details[0].recentReps).assertEqual(5)
      expect(details[0].recentVolume).assertEqual(450)

      expect(details[1].exerciseId).assertEqual('ex_barbell_row')
      expect(details[1].sessionCount).assertEqual(2)
      expect(details[1].performedSetCount).assertEqual(2)
      expect(details[1].recentOneRepMax).assertEqual(95)
      expect(details[1].recentVolume).assertEqual(600)
    })

    it('aggregates recent volume across sets in the latest session and reports PR gap text when recent set is below best', 0, () => {
      const sessions: WorkoutSession[] = [
        createWorkoutSession(
          'session_trend_1',
          'plan_record',
          'day_1',
          1714521600000,
          1714523400000,
          1800,
          2,
          0,
          0,
          'completed_sets=2;target_sets=2',
          [createWorkoutSet('set_trend_1', 'ex_barbell_bench_press', 100, 5, 9, false)]
        ),
        createWorkoutSession(
          'session_trend_2',
          'plan_record',
          'day_2',
          1715126400000,
          1715128200000,
          1800,
          3,
          0,
          0,
          'completed_sets=3;target_sets=3',
          [
            createWorkoutSet('set_trend_2', 'ex_barbell_bench_press', 80, 5, 8, false),
            createWorkoutSet('set_trend_3', 'ex_barbell_bench_press', 82.5, 4, 8, false)
          ]
        )
      ]

      const details: ExercisePersonalRecordDetail[] = PersonalRecordService.createRecordDetails(sessions)
      const bench = details[0]

      expect(bench.bestOneRepMax).assertEqual(117)
      expect(bench.recentOneRepMax).assertEqual(94)
      expect(bench.recentWeight).assertEqual(82.5)
      expect(bench.recentReps).assertEqual(4)
      expect(bench.recentVolume).assertEqual(730)
      expect(bench.trendText.indexOf('23') >= 0).assertTrue()
    })
  })
}
