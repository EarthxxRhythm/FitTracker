import { describe, it, expect } from '@ohos/hypium'
import { AppRoutes } from '../../../main/ets/app/AppRoutes'
import { StartupDecision } from '../../../main/ets/app/AppState'
import { resolveInitialPage } from '../../../main/ets/entryability/EntryAbility'

export default function startupRoutingTest(): void {
  describe('Startup routing', () => {
    it('loads the target-loop startup page before user state routing', 0, () => {
      expect(resolveInitialPage(false)).assertEqual('app/StartupPage')
    })

    it('keeps the startup page stable for returning users', 0, () => {
      expect(resolveInitialPage(true)).assertEqual('app/StartupPage')
    })

    it('routes new users from startup to goal setup after saved goal check', 0, () => {
      const firstPage: string = resolveInitialPage(false)
      const nextPage: string = StartupDecision.getInitialRoute(false)
      expect(firstPage).assertEqual(AppRoutes.STARTUP)
      expect(nextPage).assertEqual(AppRoutes.GOAL_SETUP)
    })

    it('routes returning users from startup to home after saved goal check', 0, () => {
      const firstPage: string = resolveInitialPage(false)
      const nextPage: string = StartupDecision.getInitialRoute(true)
      expect(firstPage).assertEqual(AppRoutes.STARTUP)
      expect(nextPage).assertEqual(AppRoutes.HOME)
    })
  })
}
