/** PencilPlanGroupDetailPage —— 计划组详细注册页（薄壳：读取路由参数 planId 后渲染 PlanGroupDetailContent）。 */
import { PlanGroupDetailContent } from '../components/PlanGroupDetailContent'

interface PlanGroupDetailParams {
  planId?: string
}

@Entry
@Component
struct PencilPlanGroupDetailPage {
  @State private planId: string = ''

  aboutToAppear(): void {
    try {
      const params = this.getUIContext().getRouter().getParams() as PlanGroupDetailParams
      if (params !== undefined && params.planId !== undefined) {
        this.planId = params.planId
      }
    } catch (err) {
      // 参数缺失或类型不符：保持空 planId，由内容组件显示「未找到该计划」空态。
    }
  }

  build() {
    Column() {
      PlanGroupDetailContent({ planId: this.planId })
    }
  }
}
