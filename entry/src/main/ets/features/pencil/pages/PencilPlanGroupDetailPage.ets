/** PencilPlanGroupDetailPage —— 计划组详细注册页（薄壳：完整渲染 PlanGroupDetailContent）。路由注册由协调者统一完成。 */
import { PlanGroupDetailContent } from '../components/PlanGroupDetailContent'

@Entry
@Component
struct PencilPlanGroupDetailPage {
  build() {
    Column() {
      PlanGroupDetailContent()
    }
  }
}
