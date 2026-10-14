import { describe, expect, it } from '@ohos/hypium'
import BodyRecordService from '../../../main/ets/shared/services/BodyRecordService'
import { WeightRecord } from '../../../main/ets/shared/models/BodyModels'

/**
 * BodyRecordService 纯函数部分（趋势取样 / 差值）——不触持久化，故无需 Context。
 *
 * 锁定语义：缺记录的日期按「最近一条 ≤ 该日」前向填充；若无则回填最早一条。
 * 取样方向搞反不会报错、只会静默显示错曲线，故在此固定。
 */

/** 本地日零点毫秒（与实现同口径，规避时区偏移）。 */
function day(year: number, month: number, date: number): number {
  return new Date(year, month - 1, date).getTime()
}

/** 两条样例记录：6/1 = 70kg、6/8 = 71kg。 */
function sampleRecords(): WeightRecord[] {
  return [
    { dateMillis: day(2026, 6, 1), kg: 70 },
    { dateMillis: day(2026, 6, 8), kg: 71 }
  ]
}

export default function bodyRecordServiceTest(): void {
  describe('BodyRecordService', () => {
    it('空记录_趋势为未定义且差值为零', 0, () => {
      const empty: WeightRecord[] = []
      expect(BodyRecordService.weekTrend(empty, Date.now(), 'monday') === undefined).assertTrue()
      expect(BodyRecordService.monthTrend(empty, Date.now()) === undefined).assertTrue()
      expect(BodyRecordService.yearTrend(empty, Date.now()) === undefined).assertTrue()
      expect(BodyRecordService.weekDeltaKg(empty, Date.now())).assertEqual(0)
      expect(BodyRecordService.latestKg(empty) === undefined).assertTrue()
    })

    it('单条记录_趋势各点同值且差值为零', 0, () => {
      const one: WeightRecord[] = [{ dateMillis: day(2026, 6, 8), kg: 72 }]
      const week = BodyRecordService.weekTrend(one, day(2026, 6, 10), 'monday')
      expect(week !== undefined).assertTrue()
      if (week !== undefined) {
        expect(week.values.length).assertEqual(7)
        for (let i = 0; i < week.values.length; i++) {
          expect(week.values[i]).assertEqual(72)
        }
        expect(week.deltaKg).assertEqual(0)
      }
      expect(BodyRecordService.weekDeltaKg(one, day(2026, 6, 10))).assertEqual(0)
    })

    it('较上周差值_取最新一条与该日回溯七天的取样', 0, () => {
      // 最新 6/8 = 71；回溯 7 天 = 6/1 = 70；差 1。
      expect(BodyRecordService.weekDeltaKg(sampleRecords(), day(2026, 6, 10))).assertEqual(1)
    })

    it('月趋势_锚点前向填充与首尾差值', 0, () => {
      // 今天 6/10；锚点回溯 30/25/20/15/10/5/0 天 → 5/11..6/5 取样均为 70，6/10 为 71。
      const month = BodyRecordService.monthTrend(sampleRecords(), day(2026, 6, 10))
      expect(month !== undefined).assertTrue()
      if (month !== undefined) {
        expect(month.values.length).assertEqual(7)
        expect(month.values[0]).assertEqual(70)
        expect(month.values[6]).assertEqual(71)
        expect(month.deltaKg).assertEqual(1)
        expect(month.rangeText).assertEqual('近 30 天')
      }
    })

    it('周趋势_周首为周一时从 6/8 起取样', 0, () => {
      const week = BodyRecordService.weekTrend(sampleRecords(), day(2026, 6, 10), 'monday')
      expect(week !== undefined).assertTrue()
      if (week !== undefined) {
        expect(week.values[0]).assertEqual(71)
        expect(week.values[6]).assertEqual(71)
      }
    })

    it('周首切周日时_标签序随之联动', 0, () => {
      const monday = BodyRecordService.weekTrend(sampleRecords(), day(2026, 6, 10), 'monday')
      const sunday = BodyRecordService.weekTrend(sampleRecords(), day(2026, 6, 10), 'sunday')
      expect(monday !== undefined).assertTrue()
      expect(sunday !== undefined).assertTrue()
      if (monday !== undefined && sunday !== undefined) {
        expect(monday.labels[0]).assertEqual('一')
        expect(sunday.labels[0]).assertEqual('日')
      }
    })

    it('最新体重_取日期最晚的一条且不依赖入参顺序', 0, () => {
      const reversed: WeightRecord[] = [
        { dateMillis: day(2026, 6, 8), kg: 71 },
        { dateMillis: day(2026, 6, 1), kg: 70 }
      ]
      expect(BodyRecordService.latestKg(reversed)).assertEqual(71)
    })
  })
}
