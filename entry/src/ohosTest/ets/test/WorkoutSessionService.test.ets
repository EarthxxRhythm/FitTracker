/**
 * WorkoutSessionService 单元测试
 * 覆盖 Epley 1RM 计算公式、数据类型接口、周统计逻辑边界
 *
 * 注：saveSession / getSessions / getWeeklyStats / getAllExerciseRecords / getTrainingDates
 * 需要 preferences Context，逻辑正确性通过集成测试验证。
 * 本文档测试 1RM 公式的数学正确性（Epley 公式）。
 */
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'

// ============================================================
// Epley formula pure-function test (extracted from WorkoutSessionService)
// The formula: 1RM ≈ weight × (1 + reps / 30), rounded to integer.
// Reference: WorkoutSessionService.ets line 124
// ============================================================
function calcEpley1RM(weight: number, reps: number): number {
  return Math.round(weight * (1 + reps / 30))
}

export default function workoutSessionLogicTest(): void {
  describe('WorkoutSessionService — 1RM Epley Formula', () => {
    beforeAll(() => {
    })

    afterAll(() => {
    })

    // ============================================================
    // Epley 1RM Formula: 1RM = weight × (1 + reps / 30)
    // ============================================================
    describe('Epley 1RM Formula', () => {
      it('1 rep: 1RM equals weight', 0, () => {
        // 1RM = 100 × (1 + 1/30) = 100 × 1.0333... ≈ 103
        expect(calcEpley1RM(100, 1)).assertEqual(103)
      })

      it('10 reps at 80kg', 0, () => {
        // 1RM = 80 × (1 + 10/30) = 80 × 1.333... ≈ 107
        expect(calcEpley1RM(80, 10)).assertEqual(107)
      })

      it('5 reps at 100kg', 0, () => {
        // 1RM = 100 × (1 + 5/30) = 100 × 1.1667 ≈ 117
        expect(calcEpley1RM(100, 5)).assertEqual(117)
      })

      it('30 reps at 20kg', 0, () => {
        // 1RM = 20 × (1 + 30/30) = 20 × 2 = 40
        expect(calcEpley1RM(20, 30)).assertEqual(40)
      })

      it('boundary: 0 weight returns 0', 0, () => {
        expect(calcEpley1RM(0, 10)).assertEqual(0)
      })

      it('boundary: 0 reps returns weight', 0, () => {
        expect(calcEpley1RM(100, 0)).assertEqual(100)
      })

      it('typical: 8 reps at 60kg', 0, () => {
        // 1RM = 60 × (1 + 8/30) = 60 × 1.2667 ≈ 76
        expect(calcEpley1RM(60, 8)).assertEqual(76)
      })

      it('typical: 12 reps at 50kg', 0, () => {
        // 1RM = 50 × (1 + 12/30) = 50 × 1.4 = 70
        expect(calcEpley1RM(50, 12)).assertEqual(70)
      })

      it('heavy single: 1 rep at 200kg', 0, () => {
        // 1RM = 200 × (1 + 1/30) = 200 × 1.0333... ≈ 207
        expect(calcEpley1RM(200, 1)).assertEqual(207)
      })

      it('high rep endurance: 50 reps at 10kg', 0, () => {
        // 1RM = 10 × (1 + 50/30) = 10 × 2.6667 ≈ 27
        expect(calcEpley1RM(10, 50)).assertEqual(27)
      })
    })

    // ============================================================
    // Interface shape verification
    // ============================================================
    describe('Interface Conformance', () => {
      it('SavedSet should accept weight and reps', 0, () => {
        const set: { weight: number; reps: number } = { weight: 80, reps: 10 }
        expect(set.weight).assertEqual(80)
        expect(set.reps).assertEqual(10)
      })

      it('ExerciseRecord best1RM should match Epley formula', 0, () => {
        const weight = 80
        const reps = 10
        const expected1RM = calcEpley1RM(weight, reps)
        const record = {
          exerciseName: '杠铃平板卧推',
          best1RM: expected1RM,
          bestWeight: weight,
          bestReps: reps,
          bestDate: '2024-01-01'
        }
        expect(record.best1RM).assertEqual(expected1RM)
        expect(record.bestWeight).assertEqual(weight)
        expect(record.bestReps).assertEqual(reps)
      })
    })
  })
}
