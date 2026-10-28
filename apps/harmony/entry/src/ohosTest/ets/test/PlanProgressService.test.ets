import { describe, expect, it } from '@ohos/hypium'
import PlanProgressService, { PlanProgressSummary } from '../../../main/ets/shared/services/PlanProgressService'
import { WorkoutSession } from '../../../main/ets/shared/models/TrainingModels'

/**
 * PlanProgressService 纯函数聚合契约测试。
 *
 * 覆盖：空输入 / 单计划多会话 / 多计划混合 / 无匹配 planId / 缺 dayId。
 * 这些正是「会话里有 planId 但没人按计划聚合」补上后的核心契约；不触持久化，无需 Context。
 */

function mkSession(sessionId: string, planId: string, dayId: string, endedAt: number,
  durationSeconds: number = 1800): WorkoutSession {
  const session: WorkoutSession = {
    sessionId: sessionId,
    planId: planId,
    dayId: dayId,
    startedAt: endedAt - durationSeconds * 1000,
    endedAt: endedAt,
    durationSeconds: durationSeconds,
    totalSets: 0,
    totalVolume: 0,
    fatigueScore: 0,
    notes: '',
    sets: []
  }
  return session
}

export default function planProgressServiceTest(): void {
  describe('PlanProgressService', () => {
    it('空会话返回零态', 0, () => {
      const summary: PlanProgressSummary = PlanProgressService.createSummary([], 'plan_a')
      expect(summary.planId).assertEqual('plan_a')
      expect(summary.totalSessions).assertEqual(0)
      expect(summary.lastTrainedAt).assertEqual(0)
      expect(summary.trainedDayIds.length).assertEqual(0)
      expect(summary.dayProgress.length).assertEqual(0)
    })

    it('planId 为空时不把未归属会话算进来', 0, () => {
      const sessions: WorkoutSession[] = [mkSession('s1', 'plan_a', 'current_plan_day_1', 1000)]
      const summary: PlanProgressSummary = PlanProgressService.createSummary(sessions, '')
      expect(summary.totalSessions).assertEqual(0)
      expect(PlanProgressService.isDayTrained(summary, 'current_plan_day_1')).assertFalse()
    })

    it('单计划多会话按训练日聚合', 0, () => {
      const sessions: WorkoutSession[] = [
        mkSession('s1', 'plan_a', 'current_plan_day_1', 1000, 1800),
        mkSession('s2', 'plan_a', 'current_plan_day_1', 3000, 2400),
        mkSession('s3', 'plan_a', 'current_plan_day_2', 2000, 1200)
      ]
      const summary: PlanProgressSummary = PlanProgressService.createSummary(sessions, 'plan_a')
      expect(summary.totalSessions).assertEqual(3)
      expect(summary.totalDurationSeconds).assertEqual(5400)
      expect(summary.lastTrainedAt).assertEqual(3000)
      expect(summary.trainedDayIds.length).assertEqual(2)
      expect(PlanProgressService.isDayTrained(summary, 'current_plan_day_1')).assertTrue()
      expect(PlanProgressService.isDayTrained(summary, 'current_plan_day_2')).assertTrue()

      let day1Count: number = 0
      let day1Duration: number = 0
      for (let index = 0; index < summary.dayProgress.length; index++) {
        if (summary.dayProgress[index].dayId === 'current_plan_day_1') {
          day1Count = summary.dayProgress[index].sessionCount
          day1Duration = summary.dayProgress[index].totalDurationSeconds
        }
      }
      expect(day1Count).assertEqual(2)
      expect(day1Duration).assertEqual(4200)
    })

    it('多计划混合只统计目标计划', 0, () => {
      const sessions: WorkoutSession[] = [
        mkSession('s1', 'plan_a', 'current_plan_day_1', 1000),
        mkSession('s2', 'plan_b', 'current_plan_day_1', 2000),
        mkSession('s3', 'plan_a', 'current_plan_day_2', 3000)
      ]
      const summary: PlanProgressSummary = PlanProgressService.createSummary(sessions, 'plan_a')
      expect(summary.totalSessions).assertEqual(2)
      expect(summary.lastTrainedAt).assertEqual(3000)
      expect(PlanProgressService.isDayTrained(summary, 'current_plan_day_2')).assertTrue()
    })

    it('无匹配 planId 返回零态', 0, () => {
      const sessions: WorkoutSession[] = [mkSession('s1', 'plan_b', 'current_plan_day_1', 1000)]
      const summary: PlanProgressSummary = PlanProgressService.createSummary(sessions, 'plan_a')
      expect(summary.totalSessions).assertEqual(0)
      expect(summary.dayProgress.length).assertEqual(0)
    })

    it('缺 dayId 的会话计入总次数但不进训练日聚合', 0, () => {
      const sessions: WorkoutSession[] = [
        mkSession('s1', 'plan_a', '', 1000),
        mkSession('s2', 'plan_a', 'current_plan_day_1', 2000)
      ]
      const summary: PlanProgressSummary = PlanProgressService.createSummary(sessions, 'plan_a')
      expect(summary.totalSessions).assertEqual(2)
      expect(summary.trainedDayIds.length).assertEqual(1)
      expect(summary.trainedDayIds[0]).assertEqual('current_plan_day_1')
    })

    it('isDayTrained 对空 dayId 恒为 false', 0, () => {
      const summary: PlanProgressSummary = PlanProgressService.createEmpty('plan_a')
      expect(PlanProgressService.isDayTrained(summary, '')).assertFalse()
    })

    it('启用计划后 UserPlan id 与预置 id 不等时仍能聚合', 0, () => {
      // 真实链路：enablePlan 生成 UserPlan.id = 'user_plan_<时间戳>'，会话落的是它；
      // 计划组详情拿到的是预置 id。只比预置 id 会全部落空。
      const sessions: WorkoutSession[] = [
        mkSession('s1', 'user_plan_1700000000000', 'current_plan_day_1', 1000),
        mkSession('s2', 'user_plan_1700000000000', 'current_plan_day_2', 2000)
      ]
      const ids: string[] = ['preset_ppl', 'user_plan_1700000000000']
      const summary: PlanProgressSummary =
        PlanProgressService.createSummaryForIds(sessions, 'preset_ppl', ids)
      expect(summary.totalSessions).assertEqual(2)
      expect(PlanProgressService.isDayTrained(summary, 'current_plan_day_2')).assertTrue()
    })

    it('只传预置 id 时 user_plan 会话不计入', 0, () => {
      const sessions: WorkoutSession[] = [
        mkSession('s1', 'user_plan_1700000000000', 'current_plan_day_1', 1000)
      ]
      const summary: PlanProgressSummary = PlanProgressService.createSummary(sessions, 'preset_ppl')
      expect(summary.totalSessions).assertEqual(0)
    })

    it('sessionCountForDay 返回该日完成次数', 0, () => {
      const sessions: WorkoutSession[] = [
        mkSession('s1', 'plan_a', 'current_plan_day_1', 1000),
        mkSession('s2', 'plan_a', 'current_plan_day_1', 2000),
        mkSession('s3', 'plan_a', 'current_plan_day_2', 3000)
      ]
      const summary: PlanProgressSummary = PlanProgressService.createSummary(sessions, 'plan_a')
      expect(PlanProgressService.sessionCountForDay(summary, 'current_plan_day_1')).assertEqual(2)
      expect(PlanProgressService.sessionCountForDay(summary, 'current_plan_day_2')).assertEqual(1)
      expect(PlanProgressService.sessionCountForDay(summary, 'current_plan_day_3')).assertEqual(0)
      expect(PlanProgressService.sessionCountForDay(summary, '')).assertEqual(0)
    })
  })
}
