/** PencilProfileEditPage —— 个人资料编辑注册页（薄壳：完整渲染 ProfileEditContent）。 */
import { ProfileEditContent } from '../components/ProfileEditContent'

@Entry
@Component
struct PencilProfileEditPage {
  build() {
    Column() {
      ProfileEditContent()
    }
  }
}
