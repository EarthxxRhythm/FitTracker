import { describe, it, expect } from '@ohos/hypium'
import { resolveInitialPage } from '../main/ets/entryability/EntryAbility'

export default function startupRoutingTest() {
  describe('Startup routing', () => {
    it('should route logged-out users to the login page', 0, () => {
      expect(resolveInitialPage(false)).assertEqual('pages/LoginPage')
    })

    it('should route logged-in users to the index page', 0, () => {
      expect(resolveInitialPage(true)).assertEqual('pages/Index')
    })
  })
}
