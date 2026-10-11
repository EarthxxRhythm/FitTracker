/** BodyDataPage —— 身体数据注册页（薄壳：完整渲染 BodyDataContent）。路由注册由协调者统一完成。 */
import { BodyDataContent } from '../components/BodyDataContent'

@Entry
@Component
struct BodyDataPage {
  build() {
    Column() {
      BodyDataContent()
    }
  }
}
