/**
 * TrainingPlanDetailPage -- preset training plan detail and activation entry.
 * Function #15: preset plan detail with grouped training days.
 * Function #16: each training day shows exercise list and prescription.
 * Function #17: enable preset plan and set it as current plan.
 */
import { Context } from '@kit.AbilityKit'
import { AppRoutes } from '../../../app/AppRoutes'
import TrainingPlanService, {
  ExerciseRef,
  PresetPlan,
  TrainingDay
} from '../../../common/services/TrainingPlanService'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens } from '../../../common/styles/DesignTokens'
import { AppButton } from '../../../components/AppButton'
import { AppCard } from '../../../components/AppCard'
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
struct TrainingPlanDetailPage {
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

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

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
      const params = this.getUIContext().getRouter().getParams() as Record<string, string>
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
    const context: Context | null = this.getHostContextOrNull()
    if (context === null) {
      this.enabling = false
      this.actionMessage = '当前页面上下文不可用，请稍后重试。'
      return
    }
    const enabledPlan = await TrainingPlanService.enablePlan(context, this.presetPlanId)
    this.enabling = false
    if (enabledPlan === null) {
      this.actionMessage = '\u542f\u7528\u8ba1\u5212\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5\u3002'
      return
    }

    this.actionMessage = '\u8ba1\u5212\u5df2\u542f\u7528\uff0c\u6b63\u5728\u8fd4\u56de\u9996\u9875\u3002'
    try {
      this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.HOME })
    } catch (e) {
      // stay on current page with success message
    }
  }

  async loadAdvancedPlansPresentation(plan: PresetPlan): Promise<void> {
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.advancedPlansTier = 'free'
        this.advancedPlansPresentation = AdvancedPlanVariantsService.createPresentation(plan, true, 'free')
        return
      }
      const gateResult = await MonetizationGateService.getGateResult(context, 'advanced_plans')
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
    const context: Context | null = this.getHostContextOrNull()
    if (context === null) {
      this.enablingVariantId = ''
      this.actionMessage = '当前页面上下文不可用，请稍后重试。'
      return
    }
    const enabledPlan = await TrainingPlanService.enableCustomPlan(
      context,
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
      this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.HOME })
    } catch (e) {
      // stay on current page with success message
    }
  }

  openBack(): void {
    try {
      this.getUIContext().getRouter().back()
    } catch (e) {
      try {
        this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.HOME })
      } catch (innerError) {
        // stay on current page
      }
    }
  }

  openMonetizationHub(capability: MonetizationCapability, sourceLabel: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({
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

  getHeroSubtitle(): string {
    if (this.loading) {
      return '正在整理计划结构、训练频率和可选变体，稍后会把启用入口恢复到同一条主线。'
    }
    if (!this.hasPlan) {
      return '当前没有找到对应的预置计划，请返回首页重新选择。'
    }
    return '先确认适用人群、训练频率和每个训练日的动作密度，再决定是否直接启用或切换高级变体。'
  }

  getPlanStatusText(): string {
    if (this.loading) {
      return '加载中'
    }
    if (!this.hasPlan) {
      return '未找到'
    }
    return '可启用'
  }

  getTrainingDayCount(): number {
    return this.days.length
  }

  getTotalExerciseCount(): number {
    let total: number = 0
    for (let index = 0; index < this.days.length; index++) {
      total += this.days[index].exercises.length
    }
    return total
  }

  getExerciseCountText(day: TrainingDay): string {
    return day.exercises.length.toString() + ' 个动作'
  }

  getExercisePrescriptionText(exercise: ExerciseRef): string {
    return exercise.targetMuscle + ' | ' + exercise.sets.toString() + ' 组 x ' + exercise.reps
  }

  getWeekdayLabel(dayNumber: number): string {
    if (dayNumber === 1) {
      return '周一'
    }
    if (dayNumber === 2) {
      return '周二'
    }
    if (dayNumber === 3) {
      return '周三'
    }
    if (dayNumber === 4) {
      return '周四'
    }
    if (dayNumber === 5) {
      return '周五'
    }
    if (dayNumber === 6) {
      return '周六'
    }
    if (dayNumber === 7) {
      return '周日'
    }
    return '按计划轮换'
  }

  getDayScheduleText(day: TrainingDay): string {
    if (day.dayOfWeek === undefined || day.dayOfWeek.length === 0) {
      return '按训练周节奏轮换'
    }
    let text: string = ''
    for (let index = 0; index < day.dayOfWeek.length; index++) {
      if (index > 0) {
        text += ' / '
      }
      text += this.getWeekdayLabel(day.dayOfWeek[index])
    }
    return text
  }

  @Builder
  buildStageRail() {
    Row({ space: SpacingTokens.SM }) {
      this.buildStageChip('计划', true)
      this.buildStageChip('预览', false)
      this.buildStageChip('执行', false)
    }
    .width('100%')
  }

  @Builder
  buildStageChip(label: string, active: boolean) {
    Text(label)
      .fontSize(FontTokens.SMALL_SIZE)
      .fontWeight(active ? FontWeight.Medium : FontTokens.SMALL_WEIGHT)
      .fontColor(active ? ColorTokens.TEXT_PRIMARY : ColorTokens.TEXT_TERTIARY)
      .padding({
        top: SpacingTokens.XS,
        bottom: SpacingTokens.XS,
        left: SpacingTokens.SM,
        right: SpacingTokens.SM
      })
      .backgroundColor(active ? ColorTokens.SURFACE_ELEVATED : ColorTokens.SURFACE_SECONDARY)
      .borderRadius(RadiusTokens.FULL)
      .border({
        width: 1,
        color: active ? ColorTokens.BORDER_ACCENT : ColorTokens.BORDER_SUBTLE
      })
  }

  @Builder
  buildLaneHeader(title: string, description: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(title)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(description)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildMetricTile(label: string, value: string, note: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)

      Text(value)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(note)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding(SpacingTokens.MD)
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
    .borderRadius(RadiusTokens.MD)
    .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildMetaPill(text: string) {
    Text(text)
      .fontSize(FontTokens.CAPTION_SIZE)
      .fontColor(ColorTokens.TEXT_SECONDARY)
      .padding({
        top: SpacingTokens.XS,
        bottom: SpacingTokens.XS,
        left: SpacingTokens.SM,
        right: SpacingTokens.SM
      })
      .backgroundColor(ColorTokens.SURFACE_SECONDARY)
      .borderRadius(RadiusTokens.FULL)
      .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
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
        AppCard({ variant: 'outlined', cardPadding: 'default' }) {
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

            AppButton({
              text: this.enablingVariantId === card.variantId ? '启用中...' : card.actionText,
              type: card.locked ? 'secondary' : 'primary',
              buttonSize: 'medium',
              block: true,
              loading: this.enablingVariantId === card.variantId,
              disabled: this.enablingVariantId.length > 0 && this.enablingVariantId !== card.variantId,
              onButtonClick: () => {
                if (card.locked) {
                  this.openMonetizationHub('advanced_plans', '训练计划详情')
                  return
                }
                this.enableAdvancedVariant(card.variantId)
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
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
          AppCard({ variant: 'outlined', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Text('训练计划详情')
                .fontSize(FontTokens.DISPLAY_SIZE)
                .fontWeight(FontTokens.DISPLAY_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('没有找到这个预置计划，请返回首页重新选择。')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              AppButton({
                text: '返回首页',
                type: 'secondary',
                buttonSize: 'large',
                block: true,
                onButtonClick: () => {
                  this.openBack()
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }

        if (this.loading) {
          AppCard({ variant: 'panel', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Text('训练计划详情')
                .fontSize(FontTokens.DISPLAY_SIZE)
                .fontWeight(FontTokens.DISPLAY_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('正在加载预置计划...')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }

        if (!this.loading && this.hasPlan) {
          AppCard({ variant: 'panel', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Row() {
                Column({ space: SpacingTokens.XS }) {
                  Text('预置计划')
                    .fontSize(FontTokens.MICRO_SIZE)
                    .fontWeight(FontTokens.MICRO_WEIGHT)
                    .fontColor(ColorTokens.TEXT_TERTIARY)

                  Text(this.title)
                    .fontSize(FontTokens.DISPLAY_SIZE)
                    .fontWeight(FontTokens.DISPLAY_WEIGHT)
                    .fontColor(ColorTokens.TEXT_PRIMARY)
                    .width('100%')

                  Text(this.getHeroSubtitle())
                    .fontSize(FontTokens.BODY_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                    .lineHeight(FontTokens.BODY_LINE_HEIGHT)
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text(this.getPlanStatusText())
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                  .padding({
                    top: SpacingTokens.XS,
                    bottom: SpacingTokens.XS,
                    left: SpacingTokens.SM,
                    right: SpacingTokens.SM
                  })
                  .backgroundColor(this.coverColor)
                  .borderRadius(RadiusTokens.FULL)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)

              this.buildStageRail()

              Row({ space: SpacingTokens.SM }) {
                this.buildMetricTile('训练日', this.getTrainingDayCount().toString(), '本计划覆盖的训练日数量')
                this.buildMetricTile('动作数', this.getTotalExerciseCount().toString(), '整周需要执行的动作总量')
              }
              .width('100%')

              Row({ space: SpacingTokens.SM }) {
                this.buildMetaPill('适用人群：' + this.targetAudience)
                this.buildMetaPill('训练频率：' + this.weeklyFrequency)
              }
              .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          this.buildLaneHeader('计划变体', '先看默认计划是否足够，再决定要不要切换到更强的高级训练变体。')
          this.buildAdvancedPlansSection()

          this.buildLaneHeader('训练日清单', '按训练日确认动作密度和目标肌群，避免启用后才发现节奏不适合当前阶段。')

          ForEach(this.days, (day: TrainingDay, dayIndex: number) => {
            AppCard({ variant: 'outlined', cardPadding: 'default' }) {
              Column({ space: SpacingTokens.MD }) {
                Row() {
                  Column({ space: SpacingTokens.XS }) {
                    Text(day.dayLabel)
                      .fontSize(FontTokens.TITLE_SIZE)
                      .fontWeight(FontTokens.TITLE_WEIGHT)
                      .fontColor(ColorTokens.TEXT_PRIMARY)
                      .width('100%')

                    Text(this.getDayScheduleText(day))
                      .fontSize(FontTokens.CAPTION_SIZE)
                      .fontColor(ColorTokens.TEXT_SECONDARY)
                      .width('100%')
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Text(this.getExerciseCountText(day))
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_TERTIARY)
                    .padding({
                      top: SpacingTokens.XS,
                      bottom: SpacingTokens.XS,
                      left: SpacingTokens.SM,
                      right: SpacingTokens.SM
                    })
                    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                    .borderRadius(RadiusTokens.FULL)
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)

                ForEach(day.exercises, (exercise: ExerciseRef, exerciseIndex: number) => {
                  Row({ space: SpacingTokens.SM }) {
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

                      Text(this.getExercisePrescriptionText(exercise))
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_SECONDARY)
                        .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
                        .width('100%')
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                }, (exercise: ExerciseRef, exerciseIndex: number) => day.dayLabel + exercise.name + exerciseIndex.toString())
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
          }, (day: TrainingDay, dayIndex: number) => day.dayLabel + dayIndex.toString())

          AppCard({ variant: 'panel', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Text('启用当前计划')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontTokens.TITLE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .width('100%')

              Text('确认无误后会把它设为当前启用计划，并回到首页接入今天的训练主线。')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
                .lineHeight(FontTokens.BODY_LINE_HEIGHT)
                .width('100%')

              AppButton({
                text: this.enabling ? '启用中...' : '开始此计划',
                type: 'primary',
                buttonSize: 'large',
                block: true,
                loading: this.enabling,
                onButtonClick: () => {
                  this.enablePlan()
                }
              })

              if (this.actionMessage.length > 0) {
                Text(this.actionMessage)
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
                  .width('100%')
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
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
