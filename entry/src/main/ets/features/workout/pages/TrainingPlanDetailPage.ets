/**
 * TrainingPlanDetailPage -- preset training plan detail and activation entry.
 * Function #15: preset plan detail with grouped training days.
 * Function #16: each training day shows exercise list and prescription.
 * Function #17: enable preset plan and set it as current plan.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import TrainingPlanService, {
  ExerciseRef,
  PresetPlan,
  TrainingDay
} from '../../../common/services/TrainingPlanService'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import MonetizationGateService from '../../../shared/services/MonetizationGateService'
import { MonetizationCapability, MonetizationTier } from '../../../shared/models/MonetizationModels'
import AdvancedPlanVariantsService, {
  AdvancedPlanVariantCardViewModel,
  AdvancedPlanVariantId,
  AdvancedPlanVariantsPresentation,
  AdvancedPlanVariantDraft
} from '../../../shared/services/AdvancedPlanVariantsService'

@Entry
@Component
export struct TrainingPlanDetailPage {
  @State loading: boolean = true
  @State enabling: boolean = false
  @State enablingVariantId: string = ''
  @State hasPlan: boolean = false
  @State presetPlanId: string = ''
  @State title: string = ''
  @State targetAudience: string = ''
  @State weeklyFrequency: string = ''
  @State coverColor: string = ColorTokens.PRIMARY
  @State days: TrainingDay[] = []
  @State actionMessage: string = ''
  @State advancedPlansPresentation: AdvancedPlanVariantsPresentation = AdvancedPlanVariantsService.createDefaultPresentation()
  @State advancedPlansTier: MonetizationTier = 'free'

  aboutToAppear(): void {
    this.loadPage()
  }

  async loadPage(): Promise<void> {
    const presetPlanId: string = this.getPresetPlanId()
    if (presetPlanId.length === 0) {
      this.loading = false
      this.hasPlan = false
      return
    }

    const presetPlan: PresetPlan | undefined = TrainingPlanService.getPresetPlanById(presetPlanId)
    if (presetPlan === undefined) {
      this.loading = false
      this.hasPlan = false
      return
    }

    this.applyPlan(presetPlan)
    await this.loadAdvancedPlansPresentation(presetPlan)
    this.loading = false
  }

  getPresetPlanId(): string {
    try {
      const params = router.getParams() as Record<string, string>
      if (params.presetPlanId !== undefined) {
        return params.presetPlanId
      }
    } catch (e) {
      return ''
    }
    return ''
  }

  applyPlan(plan: PresetPlan): void {
    this.hasPlan = true
    this.presetPlanId = plan.id
    this.title = plan.name
    this.targetAudience = plan.targetAudience
    this.weeklyFrequency = plan.weeklyFrequency
    this.coverColor = plan.coverColor
    this.days = this.copyTrainingDays(plan.days)
  }

  copyTrainingDays(source: TrainingDay[]): TrainingDay[] {
    const days: TrainingDay[] = []
    for (let index = 0; index < source.length; index++) {
      const sourceDay: TrainingDay = source[index]
      const item: TrainingDay = {
        dayLabel: sourceDay.dayLabel,
        dayOfWeek: this.copyNumbers(sourceDay.dayOfWeek),
        exercises: this.copyExercises(sourceDay.exercises)
      }
      days.push(item)
    }
    return days
  }

  copyExercises(source: ExerciseRef[]): ExerciseRef[] {
    const exercises: ExerciseRef[] = []
    for (let index = 0; index < source.length; index++) {
      const sourceExercise: ExerciseRef = source[index]
      const item: ExerciseRef = {
        name: sourceExercise.name,
        targetMuscle: sourceExercise.targetMuscle,
        sets: sourceExercise.sets,
        reps: sourceExercise.reps
      }
      exercises.push(item)
    }
    return exercises
  }

  copyNumbers(source: number[] | undefined): number[] | undefined {
    if (source === undefined) {
      return undefined
    }
    const values: number[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  async enablePlan(): Promise<void> {
    if (this.enabling || this.presetPlanId.length === 0) {
      return
    }

    this.enabling = true
    this.actionMessage = ''
    const enabledPlan = await TrainingPlanService.enablePlan(getContext(this), this.presetPlanId)
    this.enabling = false
    if (enabledPlan === null) {
      this.actionMessage = '\u542f\u7528\u8ba1\u5212\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5\u3002'
      return
    }

    this.actionMessage = '\u8ba1\u5212\u5df2\u542f\u7528\uff0c\u6b63\u5728\u8fd4\u56de\u9996\u9875\u3002'
    try {
      router.replaceUrl({ url: AppRoutes.HOME })
    } catch (e) {
      // stay on current page with success message
    }
  }

  async loadAdvancedPlansPresentation(plan: PresetPlan): Promise<void> {
    try {
      const gateResult = await MonetizationGateService.getGateResult(getContext(this), 'advanced_plans')
      this.advancedPlansTier = gateResult.activeTier
      this.advancedPlansPresentation = AdvancedPlanVariantsService.createPresentation(
        plan,
        !gateResult.allowed,
        gateResult.activeTier
      )
    } catch (e) {
      this.advancedPlansTier = 'free'
      this.advancedPlansPresentation = AdvancedPlanVariantsService.createPresentation(plan, true, 'free')
    }
  }

  async enableAdvancedVariant(variantId: AdvancedPlanVariantId): Promise<void> {
    if (this.enablingVariantId.length > 0 || this.presetPlanId.length === 0) {
      return
    }
    const presetPlan: PresetPlan | undefined = TrainingPlanService.getPresetPlanById(this.presetPlanId)
    if (presetPlan === undefined) {
      return
    }

    this.enablingVariantId = variantId
    this.actionMessage = ''
    const draft: AdvancedPlanVariantDraft = AdvancedPlanVariantsService.createVariantDraft(presetPlan, variantId)
    const enabledPlan = await TrainingPlanService.enableCustomPlan(
      getContext(this),
      draft.name,
      presetPlan.coverColor,
      draft.targetAudience,
      draft.weeklyFrequency,
      draft.days
    )
    this.enablingVariantId = ''
    if (enabledPlan === null) {
      this.actionMessage = '启用高级变体失败，请稍后重试。'
      return
    }

    this.actionMessage = '高级计划变体已启用，正在返回首页。'
    try {
      router.replaceUrl({ url: AppRoutes.HOME })
    } catch (e) {
      // stay on current page with success message
    }
  }

  openBack(): void {
    try {
      router.back()
    } catch (e) {
      try {
        router.replaceUrl({ url: AppRoutes.HOME })
      } catch (innerError) {
        // stay on current page
      }
    }
  }

  openMonetizationHub(capability: MonetizationCapability, sourceLabel: string): void {
    try {
      router.pushUrl({
        url: AppRoutes.MONETIZATION_HUB,
        params: {
          focusCapability: capability,
          focusSourceLabel: sourceLabel
        }
      })
    } catch (e) {
      // stay on current page
    }
  }

  @Builder
  buildAdvancedPlansSection() {
    Column({ space: SpacingTokens.MD }) {
      Row() {
        Column({ space: SpacingTokens.XS }) {
          Text(this.advancedPlansPresentation.title)
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .width('100%')

          Text(this.advancedPlansPresentation.description)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.advancedPlansPresentation.statusLabel)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(this.advancedPlansPresentation.locked ? ColorTokens.WARNING : ColorTokens.SUCCESS)
          .padding({
            left: SpacingTokens.SM,
            right: SpacingTokens.SM,
            top: SpacingTokens.XS,
            bottom: SpacingTokens.XS
          })
          .backgroundColor(this.advancedPlansPresentation.locked ? ColorTokens.WARNING_BG : ColorTokens.SUCCESS_BG)
          .borderRadius(RadiusTokens.FULL)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      ForEach(this.advancedPlansPresentation.cards, (card: AdvancedPlanVariantCardViewModel) => {
        Column({ space: SpacingTokens.SM }) {
          Row() {
            Text(card.badgeText)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(card.locked ? ColorTokens.WARNING : ColorTokens.INFO)
              .padding({
                left: SpacingTokens.SM,
                right: SpacingTokens.SM,
                top: SpacingTokens.XS,
                bottom: SpacingTokens.XS
              })
              .backgroundColor(card.locked ? ColorTokens.WARNING_BG : ColorTokens.INFO_BG)
              .borderRadius(RadiusTokens.FULL)

            Blank()

            if (card.locked) {
              Text('预览')
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_TERTIARY)
            }
          }
          .width('100%')

          Text(card.title)
            .fontSize(FontTokens.BODY_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .width('100%')

          Text(card.summary)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .width('100%')

          Text(card.detail)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_TERTIARY)
            .width('100%')

          Button(this.enablingVariantId === card.variantId ? '启用中...' : card.actionText)
            .width('100%')
            .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
            .fontSize(FontTokens.BODY_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(card.locked ? ColorTokens.TEXT_PRIMARY : ColorTokens.TEXT_ON_PRIMARY)
            .backgroundColor(card.locked ? ColorTokens.SURFACE_BUTTON_SECONDARY : this.coverColor)
            .borderRadius(RadiusTokens.FULL)
            .enabled(this.enablingVariantId.length === 0)
            .onClick(() => {
              if (card.locked) {
                this.openMonetizationHub('advanced_plans', '训练计划详情')
                return
              }
              this.enableAdvancedVariant(card.variantId)
            })
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(ColorTokens.SURFACE_PRIMARY)
        .border({
          width: 1,
          color: card.locked ? ColorTokens.BORDER_ACCENT : this.coverColor
        })
        .alignItems(HorizontalAlign.Start)
      }, (card: AdvancedPlanVariantCardViewModel) => card.variantId)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        Row() {
          Text('返回')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.PRIMARY)
            .onClick(() => {
              this.openBack()
            })

          Blank()
        }
        .width('100%')

        if (!this.loading && !this.hasPlan) {
          Column({ space: SpacingTokens.SM }) {
            Text('训练计划详情')
              .fontSize(FontTokens.DISPLAY_SIZE)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('没有找到这个预置计划，请返回首页重新选择。')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)
          .alignItems(HorizontalAlign.Start)
        }

        if (this.loading) {
          Column({ space: SpacingTokens.SM }) {
            Text('训练计划详情')
              .fontSize(FontTokens.DISPLAY_SIZE)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('正在加载预置计划...')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)
          .alignItems(HorizontalAlign.Start)
        }

        if (!this.loading && this.hasPlan) {
          Column({ space: SpacingTokens.MD }) {
            Column({ space: SpacingTokens.SM }) {
              Text(this.title)
                .fontSize(FontTokens.DISPLAY_SIZE)
                .fontWeight(FontTokens.DISPLAY_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('适用人群：' + this.targetAudience)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              Text('训练频率：' + this.weeklyFrequency)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.BG_SECONDARY)
            .border({
              width: 1,
              color: this.coverColor
            })
            .alignItems(HorizontalAlign.Start)

            this.buildAdvancedPlansSection()

            ForEach(this.days, (day: TrainingDay, dayIndex: number) => {
              Column({ space: SpacingTokens.SM }) {
                Text(day.dayLabel)
                  .fontSize(FontTokens.TITLE_SIZE)
                  .fontWeight(FontTokens.TITLE_WEIGHT)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                  .width('100%')

                ForEach(day.exercises, (exercise: ExerciseRef, exerciseIndex: number) => {
                  Row() {
                    Text((exerciseIndex + 1).toString())
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                      .width(24)
                      .height(24)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(this.coverColor)
                      .borderRadius(RadiusTokens.FULL)

                    Column({ space: SpacingTokens.XS }) {
                      Text(exercise.name)
                        .fontSize(FontTokens.BODY_SIZE)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(ColorTokens.TEXT_PRIMARY)
                        .width('100%')

                      Text(exercise.targetMuscle + ' | ' + exercise.sets.toString() + ' 组 x ' + exercise.reps)
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_SECONDARY)
                        .width('100%')
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    .margin({ left: SpacingTokens.SM })
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                }, (exercise: ExerciseRef, exerciseIndex: number) => day.dayLabel + exercise.name + exerciseIndex.toString())
              }
              .width('100%')
              .padding(SpacingTokens.MD)
              .borderRadius(RadiusTokens.SM)
              .backgroundColor(ColorTokens.SURFACE_PRIMARY)
              .alignItems(HorizontalAlign.Start)
            }, (day: TrainingDay, dayIndex: number) => day.dayLabel + dayIndex.toString())

            Button(this.enabling ? '启用中...' : '开始此计划')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_LARGE)
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .backgroundColor(this.enabling ? ColorTokens.PRIMARY_DISABLED : this.coverColor)
              .borderRadius(RadiusTokens.FULL)
              .enabled(!this.enabling)
              .onClick(() => {
                this.enablePlan()
              })

            if (this.actionMessage.length > 0) {
              Text(this.actionMessage)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
                .width('100%')
            }
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(SpacingTokens.LG)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
