/** PencilPlanPage - 计划注册页（薄壳：完整渲染 PlanContent，供独立路由直达）。 */
import { PlanContent } from '../components/PlanContent'
import { PlanState } from '../components/states/PlanState'

@Entry
@Component
struct PencilPlanPage {
  // 状态层：独立页持有自己的 PlanState 实例（与 PencilAppShell 同口径）。
  // 页面重新显示时置脏，让 PlanContent 按需重读当前计划。
  @State private planState: PlanState = new PlanState()

  onPageShow(): void {
    this.planState.invalidate()
  }

  build() {
    Column() {
      PlanContent({ state: this.planState })
    }
  }
}
