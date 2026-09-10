/** PencilProfilePage - 我的注册页（薄壳：完整渲染 ProfileContent，供独立路由直达）。 */
import { ProfileContent } from '../components/ProfileContent'

@Entry
@Component
struct PencilProfilePage {
  build() {
    Column() {
      ProfileContent()
    }
  }
}
