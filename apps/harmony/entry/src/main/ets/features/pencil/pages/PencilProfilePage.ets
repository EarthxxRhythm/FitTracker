/** PencilProfilePage - 我的注册页（薄壳：完整渲染 ProfileContent，供独立路由直达）。 */
import { ProfileContent } from '../components/ProfileContent'
import { ProfileState } from '../components/states/ProfileState'

@Entry
@Component
struct PencilProfilePage {
  // 状态层：独立页持有自己的 ProfileState 实例（与 PencilAppShell 同口径）。
  @State private profileState: ProfileState = new ProfileState()

  build() {
    Column() {
      ProfileContent({ state: this.profileState })
    }
  }
}
