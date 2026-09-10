/** PencilPlanGroupDetailPage —— 计划组详细注册页（薄壳：读取路由参数后渲染 PlanGroupDetailContent）。 */
import { PlanGroupDetailContent } from '../components/PlanGroupDetailContent'

interface PlanGroupDetailParams {
  groupName?: string
  groupTags?: string[]
}

@Entry
@Component
struct PencilPlanGroupDetailPage {
  @State private groupName: string = ''
  @State private groupTags: string[] = []

  aboutToAppear(): void {
    try {
      const params = this.getUIContext().getRouter().getParams() as PlanGroupDetailParams
      if (params !== undefined) {
        if (params.groupName !== undefined) {
          this.groupName = params.groupName
        }
        if (params.groupTags !== undefined) {
          this.groupTags = params.groupTags
        }
      }
    } catch (err) {
      // 参数缺失或类型不符：保持空参数，由内容组件回落到内置的「推拉腿分裂」详情。
    }
  }

  build() {
    Column() {
      PlanGroupDetailContent({ groupName: this.groupName, groupTags: this.groupTags })
    }
  }
}
