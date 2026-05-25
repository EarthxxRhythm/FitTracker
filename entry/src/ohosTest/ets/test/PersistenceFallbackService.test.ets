import { describe, it, expect } from '@ohos/hypium'
import { TrainingPlan, UserGoal, WorkoutSession } from '../../../main/ets/shared/models/TrainingModels'
import { StartupDecision } from '../../../main/ets/app/AppState'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import PersistenceFallbackService, {
  PersistenceFallbackStatus
} from '../../../main/ets/shared/services/PersistenceFallbackService'
import PlanEngine from '../../../main/ets/shared/services/PlanEngine'

export default function persistenceFallbackServiceTest(): void {
  describe('PersistenceFallbackService', () => {
    it('records storage fallback status when preference loading fails', 0, () => {
      PersistenceFallbackService.clearStatus()

      PersistenceFallbackService.recordFallback('goal', 'load_goal_failed', 'default_goal', 1000)
      const status: PersistenceFallbackStatus = PersistenceFallbackService.getStatus()

      expect(status.degraded).assertTrue()
      expect(status.scope).assertEqual('goal')
      expect(status.errorCode).assertEqual('load_goal_failed')
      expect(status.fallbackDataName).assertEqual('default_goal')
      expect(status.updatedAt).assertEqual(1000)
      expect(PersistenceFallbackService.hasFallback()).assertTrue()
    })

    it('creates a usable default goal for plan generation after storage failure', 0, () => {
      const goal: UserGoal = PersistenceFallbackService.createDefaultGoal(2000)
      const plan: TrainingPlan = PlanEngine.generatePlan(goal)

      expect(goal.goalId).assertEqual('goal_default_fallback')
      expect(goal.goalType).assertEqual('hypertrophy')
      expect(goal.level).assertEqual('beginner')
      expect(goal.weeklyDays).assertEqual(3)
      expect(goal.sessionMinutes).assertEqual(45)
      expect(goal.equipmentIds.length).assertEqual(1)
      expect(goal.equipmentIds[0]).assertEqual('eq_bodyweight')
      expect(plan.days.length).assertEqual(3)
    })

    it('routes startup to home when fallback default goal is available', 0, () => {
      const goal: UserGoal = PersistenceFallbackService.createDefaultGoal(4000)
      const route: string = StartupDecision.getInitialRoute(goal.goalId.length > 0)

      expect(route).assertEqual(AppRoutes.HOME)
    })

    it('returns isolated empty workout sessions as default data', 0, () => {
      const sessions: WorkoutSession[] = PersistenceFallbackService.createDefaultWorkoutSessions()
      sessions.push(PersistenceFallbackService.createDefaultWorkoutSession(3000))

      const nextSessions: WorkoutSession[] = PersistenceFallbackService.createDefaultWorkoutSessions()

      expect(sessions.length).assertEqual(1)
      expect(nextSessions.length).assertEqual(0)
    })
  })
}
