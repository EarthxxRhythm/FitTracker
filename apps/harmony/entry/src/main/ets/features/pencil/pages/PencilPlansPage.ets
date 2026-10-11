/** PencilPlansPage —— 计划组列表注册页（薄壳：读取当前计划后渲染 PlansContent）。路由注册由协调者统一完成。 */
import { PlansContent } from '../components/PlansContent'
import TrainingPlanService, { UserPlan } from '../../../common/services/TrainingPlanService'
import { Context } from '@kit.AbilityKit'

@Entry
@Component
struct PencilPlansPage {
  @State private currentPlanName: string = ''
  @State private currentPlanMeta: string = ''
  @State private hasCurrentPlan: boolean = false

  onPageShow(): void {
    this.loadCurrentPlan()
  }

  private async loadCurrentPlan(): Promise<void> {
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      return
    }
    const current: UserPlan | null = await TrainingPlanService.getCurrentPlan(hostContext)
    if (current === null) {
      this.hasCurrentPlan = false
      this.currentPlanName = ''
      this.currentPlanMeta = ''
      return
    }
    this.hasCurrentPlan = true
    this.currentPlanName = current.name
    this.currentPlanMeta = current.targetAudience + ' · ' + current.days.length.toString() + ' 练分化 · ' + current.weeklyFrequency
  }

  build() {
    Column() {
      PlansContent({
        currentPlanName: this.currentPlanName,
        currentPlanMeta: this.currentPlanMeta,
        hasCurrentPlan: this.hasCurrentPlan
      })
    }
  }
}
