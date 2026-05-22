import { describe, it, expect } from '@ohos/hypium'
import { resolveInitialPage } from '../../../main/ets/entryability/EntryAbility'

export default function startupRoutingTest(): void {
  describe('Startup routing', () => {
    it('loads the target-loop startup page before user state routing', 0, () => {
      expect(resolveInitialPage(false)).assertEqual('app/StartupPage')
    })

    it('keeps the startup page stable for returning users', 0, () => {
      expect(resolveInitialPage(true)).assertEqual('app/StartupPage')
    })
  })
}
