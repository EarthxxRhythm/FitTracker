import { describe, expect, it } from '@ohos/hypium'
import {
  computeBmi,
  bmiCategory,
  bmiCategoryLabel,
  basalMetabolicRate,
  ageFromBirthYear,
  bodyFatHealthyRange,
  isBodyFatHealthy,
  measurementDelta
} from '../../../main/ets/common/utils/BodyMetrics'

/**
 * BodyMetrics 派生纯函数契约测试（Wave 1）——不触持久化，故无需 Context。
 *
 * 锁定 golden 值（BMI / Mifflin-St Jeor 基础代谢）与边界（未填 / 无效输入回落 undefined）。
 */

/** 未录入标记（与 BodyModels.MEASUREMENT_UNSET 同值）。 */
const UNSET: number = -1

export default function bodyMetricsTest(): void {
  describe('BodyMetrics', () => {
    it('BMI_按公式计算并保留一位小数', 0, () => {
      // 72.5 / 1.78² = 22.882... → 22.9
      expect(computeBmi(72.5, 178)).assertEqual(22.9)
      // 60 / 1.70² = 20.761... → 20.8
      expect(computeBmi(60, 170)).assertEqual(20.8)
    })

    it('BMI_无效输入回落未定义', 0, () => {
      expect(computeBmi(0, 178) === undefined).assertTrue()
      expect(computeBmi(72.5, 0) === undefined).assertTrue()
      expect(computeBmi(-1, 178) === undefined).assertTrue()
    })

    it('BMI_分级按中国成人标准', 0, () => {
      expect(bmiCategory(18.4)).assertEqual('low')
      expect(bmiCategory(18.5)).assertEqual('normal')
      expect(bmiCategory(23.9)).assertEqual('normal')
      expect(bmiCategory(24)).assertEqual('high')
      expect(bmiCategory(28)).assertEqual('obese')
    })

    it('BMI_分级中文标签', 0, () => {
      expect(bmiCategoryLabel('normal')).assertEqual('正常范围')
      expect(bmiCategoryLabel('obese')).assertEqual('肥胖')
    })

    it('基础代谢_按 Mifflin-St Jeor 计算', 0, () => {
      // 男：10·72.5 + 6.25·178 − 5·30 + 5 = 1692.5 → 1693
      expect(basalMetabolicRate(72.5, 178, 30, 'male')).assertEqual(1693)
      // 女：725 + 1112.5 − 150 − 161 = 1526.5 → 1527
      expect(basalMetabolicRate(72.5, 178, 30, 'female')).assertEqual(1527)
    })

    it('基础代谢_性别未填或参数无效回落未定义', 0, () => {
      expect(basalMetabolicRate(72.5, 178, 30, '') === undefined).assertTrue()
      expect(basalMetabolicRate(0, 178, 30, 'male') === undefined).assertTrue()
      expect(basalMetabolicRate(72.5, 178, 0, 'male') === undefined).assertTrue()
    })

    it('周岁_由出生年与当前年求差', 0, () => {
      const now: number = new Date(2026, 5, 15).getTime()
      expect(ageFromBirthYear(1995, now)).assertEqual(31)
      expect(ageFromBirthYear(0, now)).assertEqual(0)
      expect(ageFromBirthYear(2030, now)).assertEqual(0)
    })

    it('体脂健康区间_按性别给出', 0, () => {
      const male = bodyFatHealthyRange('male')
      expect(male !== undefined).assertTrue()
      if (male !== undefined) {
        expect(male.low).assertEqual(10)
        expect(male.high).assertEqual(20)
      }
      expect(bodyFatHealthyRange('') === undefined).assertTrue()
    })

    it('体脂健康判定_含边界', 0, () => {
      expect(isBodyFatHealthy(10, 'male')).assertEqual(true)
      expect(isBodyFatHealthy(20, 'male')).assertEqual(true)
      expect(isBodyFatHealthy(20.1, 'male')).assertEqual(false)
      expect(isBodyFatHealthy(16, '') === undefined).assertTrue()
    })

    it('围度差值_任一侧未录返回未定义', 0, () => {
      expect(measurementDelta(78, 80, UNSET)).assertEqual(-2)
      expect(measurementDelta(78.5, 78, UNSET)).assertEqual(0.5)
      expect(measurementDelta(UNSET, 80, UNSET) === undefined).assertTrue()
      expect(measurementDelta(78, UNSET, UNSET) === undefined).assertTrue()
    })
  })
}
