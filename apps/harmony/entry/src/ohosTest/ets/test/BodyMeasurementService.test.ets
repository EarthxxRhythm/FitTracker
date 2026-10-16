import { describe, expect, it } from '@ohos/hypium'
import BodyMeasurementService from '../../../main/ets/shared/services/BodyMeasurementService'
import { BodyMeasurement, MEASUREMENT_UNSET } from '../../../main/ets/shared/models/BodyModels'

/**
 * BodyMeasurementService 纯函数部分（latest / previous / delta）——不触持久化，故无需 Context。
 *
 * 锁定语义：「未录入」（-1）与「录了 0」必须可区分；差值在任一侧未录时为 undefined。
 */

/** 本地日零点毫秒（与实现同口径，规避时区偏移）。 */
function day(year: number, month: number, date: number): number {
  return new Date(year, month - 1, date).getTime()
}

/** 构造一条只填了部分项的记录（其余保持未录）。 */
function record(dateMillis: number, waistCm: number): BodyMeasurement {
  return {
    dateMillis: dateMillis,
    chestCm: MEASUREMENT_UNSET,
    waistCm: waistCm,
    hipCm: MEASUREMENT_UNSET,
    armCm: MEASUREMENT_UNSET,
    thighCm: MEASUREMENT_UNSET,
    bodyFatPercent: MEASUREMENT_UNSET,
    skeletalMuscleKg: MEASUREMENT_UNSET,
    bodyWaterPercent: MEASUREMENT_UNSET
  }
}

export default function bodyMeasurementServiceTest(): void {
  describe('BodyMeasurementService', () => {
    it('latest_空列表返回未定义', 0, () => {
      expect(BodyMeasurementService.latest([]) === undefined).assertTrue()
    })

    it('latest_取日期最大的一条', 0, () => {
      const records: BodyMeasurement[] = [
        record(day(2026, 3, 1), 80),
        record(day(2026, 3, 10), 78),
        record(day(2026, 3, 5), 79)
      ]
      const latest = BodyMeasurementService.latest(records)
      expect(latest !== undefined).assertTrue()
      if (latest !== undefined) {
        expect(latest.dateMillis).assertEqual(day(2026, 3, 10))
        expect(latest.waistCm).assertEqual(78)
      }
    })

    it('previous_不足两条返回未定义', 0, () => {
      expect(BodyMeasurementService.previous([]) === undefined).assertTrue()
      expect(BodyMeasurementService.previous([record(day(2026, 3, 1), 80)]) === undefined).assertTrue()
    })

    it('previous_取次新的一条', 0, () => {
      const records: BodyMeasurement[] = [
        record(day(2026, 3, 1), 80),
        record(day(2026, 3, 5), 79),
        record(day(2026, 3, 10), 78)
      ]
      const previous = BodyMeasurementService.previous(records)
      expect(previous !== undefined).assertTrue()
      if (previous !== undefined) {
        expect(previous.dateMillis).assertEqual(day(2026, 3, 5))
      }
    })

    it('delta_正常求差并保留一位小数', 0, () => {
      expect(BodyMeasurementService.delta(78.5, 80.0)).assertEqual(-1.5)
    })

    it('delta_任一侧未录入返回未定义', 0, () => {
      expect(BodyMeasurementService.delta(MEASUREMENT_UNSET, 80.0) === undefined).assertTrue()
      expect(BodyMeasurementService.delta(78.0, MEASUREMENT_UNSET) === undefined).assertTrue()
      expect(BodyMeasurementService.delta(MEASUREMENT_UNSET, MEASUREMENT_UNSET) === undefined).assertTrue()
    })

    it('未录入标记与零值可区分', 0, () => {
      // 0 是合法测量值，不应被当作「未录入」。
      expect(BodyMeasurementService.delta(0, 0)).assertEqual(0)
    })
  })
}
