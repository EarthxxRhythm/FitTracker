import { describe, it, expect } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import { StartupDecision } from '../../../main/ets/app/AppState'

export default function startupRoutingTest(): void {
  describe('Current route decision', () => {
    it('routes new users to goal setup after the Pencil splash flow', 0, () => {
      const nextPage: string = StartupDecision.getInitialRoute(false)
      expect(nextPage).assertEqual(AppRoutes.GOAL_SETUP)
    })

    it('routes returning users to the Pencil app shell after saved goal check', 0, () => {
      const nextPage: string = StartupDecision.getInitialRoute(true)
      expect(nextPage).assertEqual(AppRoutes.APP_SHELL)
    })
  })
}
