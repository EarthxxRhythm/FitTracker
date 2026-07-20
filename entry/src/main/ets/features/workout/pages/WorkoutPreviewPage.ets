/**
 * WorkoutPreviewPage -- workout preview before active training.
 * Function #9: workout preview before active training.
 */
import { Context } from '@kit.AbilityKit'
import { AppRoutes } from '../../../app/AppRoutes'
import TrainingPlanService, { UserPlan } from '../../../common/services/TrainingPlanService'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import { AppButton } from '../../../components/AppButton'
import { AppCard } from '../../../components/AppCard'
import { createStageRailItem, StageRail, StageRailItem } from '../../../components/StageRail'
import { TrainingPlan, UserGoal } from '../../../shared/models/TrainingModels'
import GoalRepository from '../../../shared/services/GoalRepository'
import PlanEngine from '../../../shared/services/PlanEngine'
import TrainingDayLabelService from '../../../shared/services/TrainingDayLabelService'
import WorkoutPreviewService, {
  WorkoutPreviewExercise,
  WorkoutPreviewSummary
} from '../../../shared/services/WorkoutPreviewService'

@Entry
@Component
export struct WorkoutPreviewPage {
  @State loading: boolean = true
  @State hasGoal: boolean = false
  @State hasWorkout: boolean = false
  @State planId: string = ''
  @State planName: string = ''
  @State dayId: string = ''
  @State title: string = ''
  @State goalSummary: string = ''
  @State scheduleSummary: string = ''
  @State exerciseCount: number = 0
  @State exercises: WorkoutPreviewExercise[] = []
  @State hasFallback: boolean = false
  @State fallbackNote: string = ''
  @State usesCurrentPlan: boolean = false

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  async aboutToAppear(): Promise<void> {
    this.loading = true
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.hasGoal = false
        this.hasWorkout = false
        this.usesCurrentPlan = false
        this.loading = false
        return
      }
      const currentPlan: UserPlan | null = await TrainingPlanService.getCurrentPlan(context)
      if (currentPlan !== null) {
        const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForCurrentPlan(
          currentPlan,
          this.getDayIdParam(),
          TrainingPlanService.getTodayLabel(),
          TrainingPlanService.getTodayTraining(currentPlan)
        )
        this.applyPreview(preview)
        this.hasGoal = true
        this.usesCurrentPlan = true
        this.loading = false
        return
      }

      const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
      if (goal === undefined) {
        this.hasGoal = false
        this.hasWorkout = false
        this.usesCurrentPlan = false
        this.loading = false
        return
      }

      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const preview: WorkoutPreviewSummary = WorkoutPreviewService.createPreviewForGoal(goal, plan, this.getTodaySeed())
      this.applyPreview(preview)
      this.hasGoal = true
      this.usesCurrentPlan = false
    } catch (e) {
      this.hasGoal = false
      this.hasWorkout = false
      this.usesCurrentPlan = false
    }
    this.loading = false
  }

  applyPreview(preview: WorkoutPreviewSummary): void {
    this.hasWorkout = preview.hasWorkout
    this.planId = preview.planId
    this.planName = preview.planName
    this.dayId = preview.dayId
    this.title = preview.title
    this.goalSummary = preview.goalSummary
    this.scheduleSummary = preview.scheduleSummary
    this.exerciseCount = preview.exerciseCount
    this.exercises = this.copyPreviewExercises(preview.exercises)
    this.hasFallback = preview.hasFallback
    this.fallbackNote = preview.fallbackNote
  }

  getTodaySeed(): number {
    const today: Date = new Date()
    const day: number = today.getDay()
    if (day === 0) {
      return 7
    }
    return day
  }

  getDayIdParam(): string {
    try {
      const params = this.getUIContext().getRouter().getParams() as Record<string, string>
      if (params.dayId !== undefined) {
        return params.dayId
      }
    } catch (e) {
      return ''
    }
    return ''
  }

  openGoalSetup(): void {
    try {
      this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.GOAL_SETUP })
    } catch (e) {
      // stay on preview
    }
  }

  startWorkout(): void {
    const preview: WorkoutPreviewSummary = {
      hasWorkout: this.hasWorkout,
      planId: this.planId,
      planName: this.planName,
      dayId: this.dayId,
      title: this.title,
      goalSummary: this.goalSummary,
      scheduleSummary: this.scheduleSummary,
      exerciseCount: this.exerciseCount,
      exercises: this.copyPreviewExercises(this.exercises),
      hasFallback: this.hasFallback,
      fallbackNote: this.fallbackNote
    }
    const targetRoute: string = WorkoutPreviewService.getStartWorkoutRoute(preview)
    if (targetRoute.length === 0) {
      return
    }

    try {
      this.getUIContext().getRouter().pushUrl({
        url: targetRoute,
        params: {
          dayId: this.dayId,
          flowSource: this.usesCurrentPlan ? 'current_plan' : 'goal_plan'
        }
      })
    } catch (e) {
      // stay on preview
    }
  }

  openAlternative(exerciseId: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: AppRoutes.EXERCISE_DETAIL, params: { exerciseId: exerciseId } })
    } catch (e) {
      // stay on preview
    }
  }

  copyPreviewExercises(source: WorkoutPreviewExercise[]): WorkoutPreviewExercise[] {
    const values: WorkoutPreviewExercise[] = []
    for (let index = 0; index < source.length; index++) {
      const exercise: WorkoutPreviewExercise = source[index]
      const item: WorkoutPreviewExercise = {
        plannedExerciseId: exercise.plannedExerciseId,
        exerciseId: exercise.exerciseId,
        name: exercise.name,
        hasExerciseDetail: exercise.hasExerciseDetail,
        targetSets: exercise.targetSets,
        targetReps: exercise.targetReps,
        intensityNote: exercise.intensityNote,
        alternativeExerciseIds: this.copyStringArray(exercise.alternativeExerciseIds),
        alternativeNames: this.copyStringArray(exercise.alternativeNames),
        selectionNote: exercise.selectionNote
      }
      values.push(item)
    }
    return values
  }

  copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  getPreviewSubtitle(): string {
    if (this.loading) {
      return '\u6b63\u5728\u6574\u7406\u4eca\u5929\u7684\u8bad\u7ec3\u5b89\u6392\u4e0e\u52a8\u4f5c\u660e\u7ec6'
    }
    if (!this.hasGoal) {
      return '\u5148\u8bbe\u5b9a\u8bad\u7ec3\u76ee\u6807\uff0c\u7cfb\u7edf\u624d\u4f1a\u751f\u6210\u4eca\u5929\u7684\u8bad\u7ec3\u9884\u89c8'
    }
    if (!this.hasWorkout) {
      return '\u5f53\u524d\u8ba1\u5212\u6ca1\u6709\u53ef\u6267\u884c\u52a8\u4f5c\uff0c\u53ef\u4ee5\u5148\u8fd4\u56de\u76ee\u6807\u8bbe\u7f6e\u8c03\u6574\u8303\u56f4'
    }
    return '\u5148\u786e\u8ba4\u4eca\u65e5\u8bad\u7ec3\u5185\u5bb9\uff0c\u518d\u8fdb\u5165\u6b63\u5f0f\u8bb0\u5f55'
  }

  getPreviewHeroEyebrow(): string {
    if (this.usesCurrentPlan) {
      return '\u5f53\u524d\u542f\u7528\u8ba1\u5212'
    }
    return '\u8bad\u7ec3\u524d\u786e\u8ba4'
  }

  getPlanSourceText(): string {
    if (this.usesCurrentPlan) {
      return '\u5f53\u524d\u542f\u7528\u8ba1\u5212'
    }
    return '\u4eca\u65e5\u751f\u6210\u8ba1\u5212'
  }

  getPreviewStatusText(): string {
    if (this.hasFallback) {
      return '\u6709\u5907\u9009\u63d0\u793a'
    }
    return '\u53ef\u76f4\u63a5\u5f00\u59cb'
  }

  getPreviewStatusColor(): string {
    if (this.hasFallback) {
      return ColorTokens.WARNING
    }
    return ColorTokens.SUCCESS
  }

  getPreviewStatusBackgroundColor(): string {
    if (this.hasFallback) {
      return ColorTokens.OVERLAY_ACCENT
    }
    return ColorTokens.OVERLAY_SUCCESS
  }

  getDayBadgeText(): string {
    return TrainingDayLabelService.formatLoopBadge(this.dayId, this.title)
  }

  getFallbackBannerText(): string {
    if (this.fallbackNote.length === 0) {
      return '\u90e8\u5206\u52a8\u4f5c\u6682\u672a\u6536\u5f55\u8be6\u60c5\uff0c\u672c\u6b21\u53ef\u5148\u6309\u8ba1\u5212\u5b8c\u6210\u8bb0\u5f55\u3002'
    }
    return this.fallbackNote
  }

  getExerciseSelectionText(exercise: WorkoutPreviewExercise): string {
    if (exercise.selectionNote.length === 0 || exercise.hasExerciseDetail) {
      return ''
    }
    return exercise.selectionNote
  }

  getExerciseSectionTitle(): string {
    if (this.usesCurrentPlan) {
      return '\u4eca\u65e5\u52a8\u4f5c\u5b89\u6392'
    }
    return '\u672c\u6b21\u8bad\u7ec3\u52a8\u4f5c'
  }

  getExerciseSectionSubtitle(): string {
    if (this.hasFallback) {
      return '\u4f18\u5148\u5b8c\u6210\u4e3b\u8981\u52a8\u4f5c\uff0c\u672a\u6536\u5f55\u8be6\u60c5\u7684\u5185\u5bb9\u53ef\u5148\u6309\u8ba1\u5212\u8bb0\u5f55\u3002'
    }
    return '\u6309\u987a\u5e8f\u5b8c\u6210\u52a8\u4f5c\uff0c\u5f00\u59cb\u524d\u53ef\u5148\u67e5\u770b\u8be6\u60c5\u4e0e\u66ff\u4ee3\u52a8\u4f5c\u3002'
  }

  getExercisePrescriptionText(exercise: WorkoutPreviewExercise): string {
    return exercise.targetSets.toString() + ' \u7ec4 x ' + exercise.targetReps + ' \u6b21 | ' + exercise.intensityNote
  }

  getExerciseDetailButtonText(exercise: WorkoutPreviewExercise): string {
    if (this.shouldShowExerciseDetailButton(exercise)) {
      return '\u67e5\u770b\u52a8\u4f5c\u8be6\u60c5'
    }
    return '\u8be6\u60c5\u6574\u7406\u4e2d'
  }

  shouldShowExerciseDetailButton(exercise: WorkoutPreviewExercise): boolean {
    return exercise.hasExerciseDetail
  }

  getStageRailItems(): StageRailItem[] {
    const items: StageRailItem[] = []
    items.push(createStageRailItem('预览', true, false))
    items.push(createStageRailItem('执行', false, false))
    items.push(createStageRailItem('回顾', false, false))
    return items
  }

  @Builder
  buildPreviewMetricTile(label: string, value: string, note: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)

      Text(value)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(note)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding(SpacingTokens.MD)
    .backgroundColor(ColorTokens.BG_ELEVATED)
    .borderRadius(RadiusTokens.MD)
    .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildDetailPill(text: string) {
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

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        AppCard({ variant: 'panel', cardPadding: 'default' }) {
          Column({ space: SpacingTokens.MD }) {
            Row() {
              Column({ space: SpacingTokens.XS }) {
                Text(this.getPreviewHeroEyebrow())
                  .fontSize(FontTokens.MICRO_SIZE)
                  .fontWeight(FontTokens.MICRO_WEIGHT)
                  .fontColor(ColorTokens.TEXT_TERTIARY)

                Text('\u8bad\u7ec3\u9884\u89c8')
                  .fontSize(FontTokens.DISPLAY_SIZE)
                  .fontWeight(FontTokens.DISPLAY_WEIGHT)
                  .fontColor(ColorTokens.TEXT_PRIMARY)

                Text(this.getPreviewSubtitle())
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
                  .lineHeight(FontTokens.BODY_LINE_HEIGHT)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              if (this.hasGoal && this.hasWorkout) {
                Text(this.getPreviewStatusText())
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getPreviewStatusColor())
                  .padding({
                    top: SpacingTokens.XS,
                    bottom: SpacingTokens.XS,
                    left: SpacingTokens.SM,
                    right: SpacingTokens.SM
                  })
                  .backgroundColor(this.getPreviewStatusBackgroundColor())
                  .borderRadius(RadiusTokens.FULL)
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)

            if (this.hasGoal && this.hasWorkout) {
              StageRail({ items: this.getStageRailItems() })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        if (!this.loading && !this.hasGoal) {
          AppCard({ variant: 'outlined', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Text('\u8fd8\u6ca1\u6709\u8bad\u7ec3\u76ee\u6807')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('\u5148\u5b8c\u6210\u76ee\u6807\u8bbe\u7f6e\uff0c\u518d\u751f\u6210\u4eca\u5929\u7684\u8bad\u7ec3\u9884\u89c8\u3002')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              AppButton({
                text: '\u8bbe\u7f6e\u8bad\u7ec3\u76ee\u6807',
                type: 'primary',
                buttonSize: 'large',
                block: true,
                onButtonClick: () => {
                  this.openGoalSetup()
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }

        if (!this.loading && this.hasGoal && !this.hasWorkout) {
          AppCard({ variant: 'outlined', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Text('\u4eca\u5929\u6ca1\u6709\u53ef\u7528\u8bad\u7ec3')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('\u5f53\u524d\u76ee\u6807\u751f\u6210\u7684\u8ba1\u5212\u6ca1\u6709\u5339\u914d\u52a8\u4f5c\uff0c\u53ef\u4ee5\u5148\u56de\u5230\u76ee\u6807\u8bbe\u7f6e\u8c03\u6574\u8bad\u7ec3\u8303\u56f4\u3002')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)

              AppButton({
                text: '\u8c03\u6574\u76ee\u6807',
                type: 'primary',
                buttonSize: 'large',
                block: true,
                onButtonClick: () => {
                  this.openGoalSetup()
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }

        if (!this.loading && this.hasGoal && this.hasWorkout) {
          Column({ space: SpacingTokens.MD }) {
            AppCard({ variant: 'panel', cardPadding: 'default' }) {
              Column({ space: SpacingTokens.MD }) {
                Column({ space: SpacingTokens.XS }) {
                  Text(this.getPlanSourceText())
                    .fontSize(FontTokens.MICRO_SIZE)
                    .fontWeight(FontTokens.MICRO_WEIGHT)
                    .fontColor(ColorTokens.TEXT_TERTIARY)

                  Text(this.planName)
                    .fontSize(FontTokens.TITLE_SIZE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(ColorTokens.TEXT_PRIMARY)

                  Text(this.title)
                    .fontSize(FontTokens.HERO_SIZE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(ColorTokens.TEXT_PRIMARY)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(this.goalSummary)
                    .fontSize(FontTokens.BODY_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                    .lineHeight(FontTokens.BODY_LINE_HEIGHT)

                  Text(this.scheduleSummary)
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontColor(ColorTokens.TEXT_TERTIARY)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)

                Row({ space: SpacingTokens.SM }) {
                  this.buildPreviewMetricTile('\u8bad\u7ec3\u65e5', this.getDayBadgeText(), '\u4eca\u5929\u7684\u8bbe\u5b9a\u9636\u6bb5')
                  this.buildPreviewMetricTile('\u52a8\u4f5c\u6570', this.exerciseCount.toString(), '\u8fdb\u5165\u6267\u884c\u524d\u7684\u6e05\u5355')
                }
                .width('100%')

                AppButton({
                  text: '\u5f00\u59cb\u8bad\u7ec3',
                  type: 'primary',
                  buttonSize: 'large',
                  block: true,
                  onButtonClick: () => {
                    this.startWorkout()
                  }
                })

                if (this.hasFallback) {
                  Column({ space: SpacingTokens.XS }) {
                    Text('\u5907\u9009\u52a8\u4f5c\u63d0\u793a')
                      .fontSize(FontTokens.MICRO_SIZE)
                      .fontWeight(FontTokens.MICRO_WEIGHT)
                      .fontColor(ColorTokens.WARNING)

                    Text(this.getFallbackBannerText())
                      .fontSize(FontTokens.CAPTION_SIZE)
                      .fontColor(ColorTokens.TEXT_SECONDARY)
                  }
                  .width('100%')
                  .padding(SpacingTokens.MD)
                  .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                  .borderRadius(RadiusTokens.MD)
                  .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
                  .alignItems(HorizontalAlign.Start)
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            Column({ space: SpacingTokens.XS }) {
              Text(this.getExerciseSectionTitle())
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text(this.getExerciseSectionSubtitle())
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.TEXT_TERTIARY)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            ForEach(this.exercises, (exercise: WorkoutPreviewExercise, index: number) => {
              AppCard({ variant: 'outlined', cardPadding: 'default' }) {
                Column({ space: SpacingTokens.SM }) {
                  Row() {
                    Text((index + 1).toString())
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                      .width(28)
                      .height(28)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(ColorTokens.PRIMARY)
                      .borderRadius(RadiusTokens.FULL)

                  Column({ space: SpacingTokens.XS }) {
                    Text(exercise.name)
                      .fontSize(FontTokens.BODY_SIZE)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(ColorTokens.TEXT_PRIMARY)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    .margin({ left: SpacingTokens.SM })
                  }
                  .width('100%')

                  Flex({ wrap: FlexWrap.Wrap }) {
                    this.buildDetailPill(this.getExercisePrescriptionText(exercise))
                  }
                  .width('100%')

                  if (this.getExerciseSelectionText(exercise).length > 0) {
                    Column({ space: SpacingTokens.XS }) {
                      Text('\u52a8\u4f5c\u8bf4\u660e')
                        .fontSize(FontTokens.MICRO_SIZE)
                        .fontWeight(FontTokens.MICRO_WEIGHT)
                        .fontColor(ColorTokens.TEXT_TERTIARY)

                      Text(this.getExerciseSelectionText(exercise))
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_SECONDARY)
                    }
                    .width('100%')
                    .padding(SpacingTokens.MD)
                    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
                    .borderRadius(RadiusTokens.MD)
                    .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
                    .alignItems(HorizontalAlign.Start)
                  }

                  if (exercise.alternativeNames.length > 0) {
                    Column({ space: SpacingTokens.XS }) {
                      Text('\u66ff\u4ee3\u52a8\u4f5c')
                        .fontSize(FontTokens.MICRO_SIZE)
                        .fontWeight(FontTokens.MICRO_WEIGHT)
                        .fontColor(ColorTokens.TEXT_TERTIARY)

                      Flex({ wrap: FlexWrap.Wrap }) {
                        ForEach(exercise.alternativeNames, (name: string, alternativeIndex: number) => {
                          Button(name)
                            .height(TouchTokens.BUTTON_HEIGHT_SMALL)
                            .fontSize(FontTokens.SMALL_SIZE)
                            .fontColor(ColorTokens.TEXT_PRIMARY)
                            .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                            .borderRadius(RadiusTokens.MD)
                            .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
                            .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
                            .onClick(() => {
                              if (alternativeIndex < exercise.alternativeExerciseIds.length) {
                                this.openAlternative(exercise.alternativeExerciseIds[alternativeIndex])
                              }
                            })
                        }, (name: string, alternativeIndex: number) => name + alternativeIndex.toString())
                      }
                      .width('100%')
                    }
                    .width('100%')
                    .alignItems(HorizontalAlign.Start)
                  }

                  AppButton({
                    text: this.getExerciseDetailButtonText(exercise),
                    type: 'secondary',
                    buttonSize: 'small',
                    disabled: !this.shouldShowExerciseDetailButton(exercise),
                    onButtonClick: () => {
                      if (this.shouldShowExerciseDetailButton(exercise)) {
                        this.openAlternative(exercise.exerciseId)
                      }
                    }
                  })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }, (exercise: WorkoutPreviewExercise) => exercise.plannedExerciseId)
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
