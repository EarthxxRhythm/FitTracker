/**
 * GoalSetupPage -- goal setup placeholder
 * Function #5: Routes and placeholder pages
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, FontTokens, SpacingTokens } from '../../../common/styles/DesignTokens'
import { createUserGoal, UserGoal } from '../../../shared/models/TrainingModels'
import GoalRepository from '../../../shared/services/GoalRepository'

@Entry
@Component
export struct GoalSetupPage {
  @State saving: boolean = false

  async saveDefaultGoal(): Promise<void> {
    if (this.saving) {
      return
    }
    this.saving = true
    const equipmentIds: string[] = ['eq_dumbbell', 'eq_bodyweight']
    const restrictedMuscleIds: string[] = []
    const now: number = Date.now()
    const goal: UserGoal = createUserGoal(
      'goal_default',
      'hypertrophy',
      'beginner',
      3,
      45,
      equipmentIds,
      restrictedMuscleIds,
      now,
      now
    )

    try {
      await GoalRepository.saveGoal(getContext(this), goal)
      router.replaceUrl({ url: AppRoutes.HOME })
    } catch (e) {
      this.saving = false
    }
  }

  build() {
    Column() {
      Text('Goal Setup')
        .fontSize(FontTokens.DISPLAY_SIZE)
        .fontWeight(FontTokens.DISPLAY_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text('Goal Setup placeholder')
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .margin({ top: SpacingTokens.SM })

      Button(this.saving ? 'Saving' : 'Save Default Goal')
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_ON_PRIMARY)
        .backgroundColor(ColorTokens.PRIMARY)
        .margin({ top: SpacingTokens.LG })
        .onClick(() => {
          this.saveDefaultGoal()
        })
    }
    .width('100%')
    .height('100%')
    .padding(SpacingTokens.LG)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
