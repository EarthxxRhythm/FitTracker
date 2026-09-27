/** PencilPlanPage - 计划注册页（薄壳：完整渲染 PlanContent，供独立路由直达）。 */
import { PlanContent } from '../components/PlanContent'

@Entry
@Component
struct PencilPlanPage {
  // 页面重新显示时递增，让 PlanContent 重读当前计划（与 PencilAppShell 同口径）。
  @State private reloadToken: number = 0

  onPageShow(): void {
    this.reloadToken += 1
  }

  build() {
    Column() {
      PlanContent({ reloadToken: this.reloadToken })
    }
  }
}
