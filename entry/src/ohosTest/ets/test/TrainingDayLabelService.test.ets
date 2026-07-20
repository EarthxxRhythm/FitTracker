import { describe, expect, it } from '@ohos/hypium'
import TrainingDayLabelService from '../../../main/ets/shared/services/TrainingDayLabelService'

export default function trainingDayLabelServiceTest(): void {
  describe('TrainingDayLabelService', () => {
    it('formats numbered generated and current-plan day ids into Chinese labels', 0, () => {
      expect(TrainingDayLabelService.formatCompact('day_2')).assertEqual('第 2 天')
      expect(TrainingDayLabelService.formatCompact('current_plan_day_4')).assertEqual('第 4 天')
      expect(TrainingDayLabelService.formatSummary('day_2')).assertEqual('训练日 第 2 天')
      expect(TrainingDayLabelService.formatSummary('current_plan_day_4')).assertEqual('当前计划 第 4 天')
    })

    it('formats workout-loop badge labels with the same compact wording', 0, () => {
      expect(TrainingDayLabelService.formatLoopBadge('day_3')).assertEqual('第 3 天')
      expect(TrainingDayLabelService.formatLoopBadge('push_day')).assertEqual('推日')
      expect(TrainingDayLabelService.formatLoopBadge('', '今日训练')).assertEqual('今日训练')
    })

    it('formats common named day ids into readable Chinese labels', 0, () => {
      expect(TrainingDayLabelService.formatCompact('push_day')).assertEqual('推日')
      expect(TrainingDayLabelService.formatCompact('day_pull')).assertEqual('拉日')
      expect(TrainingDayLabelService.formatCompact('lower_day')).assertEqual('下肢日')
      expect(TrainingDayLabelService.formatCompact('day_monday')).assertEqual('周一')
      expect(TrainingDayLabelService.formatSummary('push_day')).assertEqual('推日')
    })

    it('falls back to caller-provided labels before returning raw ids', 0, () => {
      expect(TrainingDayLabelService.formatCompact('custom_focus_day', '自定义训练日')).assertEqual('自定义训练日')
      expect(TrainingDayLabelService.formatCompact('custom_focus_day')).assertEqual('custom_focus_day')
    })
  })
}
