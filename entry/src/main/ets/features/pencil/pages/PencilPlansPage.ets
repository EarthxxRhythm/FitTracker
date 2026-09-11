/** PencilPlansPage —— 计划组列表注册页（薄壳：完整渲染 PlansContent）。路由注册由协调者统一完成。 */
import { PlansContent } from '../components/PlansContent'

@Entry
@Component
struct PencilPlansPage {
  build() {
    Column() {
      PlansContent()
    }
  }
}
