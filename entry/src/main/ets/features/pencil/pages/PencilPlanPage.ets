/** PencilPlanPage - 计划注册页（薄壳：完整渲染 PlanContent，供独立路由直达）。 */
import { PlanContent } from '../components/PlanContent'

@Entry
@Component
struct PencilPlanPage {
  build() {
    Column() {
      PlanContent()
    }
  }
}
