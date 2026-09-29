import { describe, it, expect } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import { StartupDecision } from '../../../main/ets/app/AppState'

export default function startupRoutingTest(): void {
  describe('Current route decision', () => {
    it('routes unauthenticated cold start to the login page', 0, () => {
      expect(StartupDecision.getInitialRoute(false, false)).assertEqual(AppRoutes.LOGIN)
      expect(StartupDecision.getInitialRoute(false, true)).assertEqual(AppRoutes.LOGIN)
    })

    it('routes authenticated users without a goal to goal setup', 0, () => {
      expect(StartupDecision.getInitialRoute(true, false)).assertEqual(AppRoutes.GOAL_SETUP)
    })

    it('routes authenticated users with a saved goal to the app shell', 0, () => {
      expect(StartupDecision.getInitialRoute(true, true)).assertEqual(AppRoutes.APP_SHELL)
    })
  })
}
