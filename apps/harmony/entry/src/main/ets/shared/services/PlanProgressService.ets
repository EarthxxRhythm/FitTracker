/**
 * PlanProgressService —— 按计划聚合训练会话的派生服务。
 *
 * 背景：`WorkoutSession` 一直带 `planId` / `dayId` 并正确落库，但此前没有任何读取方
 * 按计划聚合，导致「计划组」看不到进度、回顾也不感知计划归属。本服务把这份已存数据
 * 变成可展示的进度摘要。
 *
 * 纯函数、无 IO：调用方自己加载 `WorkoutSession[]` 再传入，便于单测。
 */
import { WorkoutSession } from '../models/TrainingModels'

/** 单个训练日的完成情况。 */
export interface PlanDayProgress {
  dayId: string
  sessionCount: number
  totalDurationSeconds: number
  /** 最近一次练该训练日的时间戳（毫秒）；0 表示尚未练过。 */
  lastTrainedAt: number
}

/** 一个计划下的聚合进度。 */
export interface PlanProgressSummary {
  planId: string
  /** 该计划下的训练总次数。 */
  totalSessions: number
  totalDurationSeconds: number
  /** 最近一次训练时间戳（毫秒）；0 表示尚未训练。 */
  lastTrainedAt: number
  /** 已练过的训练日 id（去重，顺序按首次出现）。 */
  trainedDayIds: string[]
  /** 每个训练日的完成情况（仅含有会话的训练日）。 */
  dayProgress: PlanDayProgress[]
}

class PlanProgressService {
  /** 空进度：`planId` 保留传入值，其余归零。 */
  createEmpty(planId: string): PlanProgressSummary {
    return {
      planId: planId,
      totalSessions: 0,
      totalDurationSeconds: 0,
      lastTrainedAt: 0,
      trainedDayIds: [],
      dayProgress: []
    }
  }

  /**
   * 聚合指定计划的进度。
   *
   * 只统计 `session.planId === planId` 的会话；`planId` 为空时返回空进度，
   * 避免把「未归属计划」的历史会话错误算到某个计划上。
   */
  createSummary(sessions: WorkoutSession[], planId: string): PlanProgressSummary {
    const ids: string[] = []
    if (planId.length > 0) {
      ids.push(planId)
    }
    return this.createSummaryForIds(sessions, planId, ids)
  }

  /**
   * 按「一组等价计划 id」聚合。
   *
   * 为什么需要：启用计划走 `enablePlan` 时 `UserPlan.id` 是 `user_plan_<时间戳>`，
   * 而计划组详情拿到的是**预置 id**（`preset_ppl` 等）；会话里落库的 `planId` 又是
   * `UserPlan.id`。两者不相等，只比单个 id 会让聚合全部落空。
   * 调用方把预置 id 与当前 `UserPlan.id` 一起传入即可覆盖两种历史数据。
   */
  createSummaryForIds(sessions: WorkoutSession[], planId: string, planIds: string[]): PlanProgressSummary {
    const summary: PlanProgressSummary = this.createEmpty(planId)
    if (planIds.length === 0 || sessions.length === 0) {
      return summary
    }
    for (let index = 0; index < sessions.length; index++) {
      const session: WorkoutSession = sessions[index]
      if (!this.containsId(planIds, session.planId)) {
        continue
      }
      summary.totalSessions += 1
      summary.totalDurationSeconds += session.durationSeconds
      if (session.endedAt > summary.lastTrainedAt) {
        summary.lastTrainedAt = session.endedAt
      }
      this.applyDayProgress(summary, session)
    }
    return summary
  }

  private containsId(ids: string[], value: string): boolean {
    for (let index = 0; index < ids.length; index++) {
      if (ids[index] === value) {
        return true
      }
    }
    return false
  }

  /** 判断某训练日是否已完成过（供计划组详情的「每周节奏」标记）。 */
  isDayTrained(summary: PlanProgressSummary, dayId: string): boolean {
    if (dayId.length === 0) {
      return false
    }
    for (let index = 0; index < summary.trainedDayIds.length; index++) {
      if (summary.trainedDayIds[index] === dayId) {
        return true
      }
    }
    return false
  }

  /** 某训练日的完成次数；未练过返回 0（供训练日面板显示「已练 N 次」）。 */
  sessionCountForDay(summary: PlanProgressSummary, dayId: string): number {
    if (dayId.length === 0) {
      return 0
    }
    for (let index = 0; index < summary.dayProgress.length; index++) {
      if (summary.dayProgress[index].dayId === dayId) {
        return summary.dayProgress[index].sessionCount
      }
    }
    return 0
  }

  private applyDayProgress(summary: PlanProgressSummary, session: WorkoutSession): void {
    const dayId: string = session.dayId
    if (dayId.length === 0) {
      return
    }
    let target: PlanDayProgress | undefined = undefined
    for (let index = 0; index < summary.dayProgress.length; index++) {
      if (summary.dayProgress[index].dayId === dayId) {
        target = summary.dayProgress[index]
        break
      }
    }
    if (target === undefined) {
      const created: PlanDayProgress = {
        dayId: dayId,
        sessionCount: 1,
        totalDurationSeconds: session.durationSeconds,
        lastTrainedAt: session.endedAt
      }
      summary.dayProgress.push(created)
      summary.trainedDayIds.push(dayId)
      return
    }
    target.sessionCount += 1
    target.totalDurationSeconds += session.durationSeconds
    if (session.endedAt > target.lastTrainedAt) {
      target.lastTrainedAt = session.endedAt
    }
  }
}

export default new PlanProgressService()
