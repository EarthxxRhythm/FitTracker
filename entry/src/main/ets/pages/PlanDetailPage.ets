/**
 * PlanDetailPage —— 计划详情 (原型 6)
 * 深色主题 | 计划概览卡(标题/日期/难度/进度条/说明) | 训练日时间线
 */
import { router } from '@kit.ArkUI'
import { AppButton } from '../components/AppButton'
import TrainingPlanService, { PresetPlan, TrainingDay, ExerciseRef } from '../common/services/TrainingPlanService'
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens, TouchTokens, MuscleColorMap } from '../common/styles/DesignTokens'
import { PageHeader } from '../components/PageHeader'
import { Chip } from '../components/Chip'

@Entry
@Component
struct PlanDetailPage {
  @State planId: string = ''
  @State planName: string = ''
  @State coverColor: string = ColorTokens.MUSCLE_DEFAULT
  @State targetAudience: string = ''
  @State weeklyFrequency: string = ''
  @State trainingDays: TrainingDay[] = []
  @State enabling: boolean = false

  async aboutToAppear(): Promise<void> {
    try {
      const params = router.getParams() as Record<string, string>
      const planId = params['planId'] as string
      if (planId) {
        this.planId = planId
        const plan = TrainingPlanService.getPresetPlanById(planId)
        if (plan) {
          this.planName = plan.name
          this.coverColor = plan.coverColor
          this.targetAudience = plan.targetAudience
          this.weeklyFrequency = plan.weeklyFrequency
          this.trainingDays = plan.days
        }
      }
    } catch (e) {
      // fallback
    }
  }

  async handleEnablePlan(): Promise<void> {
    if (!this.planId) {
      return
    }
    this.enabling = true
    try {
      await TrainingPlanService.enablePlan(getContext(this), this.planId)
    } catch (e) {
      // fallback
    }
    this.enabling = false
    router.back()
  }

  build() {
    Column() {
      PageHeader({ title: '计划详情', showBack: true })

      Scroll() {
        Column() {
          // ═══ 计划概览卡片 (原型 6) ═══
          Column() {
            // 标题 + 星标
            Row() {
              Text(this.planName)
                .fontSize(FontTokens.HEADLINE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .layoutWeight(1)
              Text('★')
                .fontSize(24)
                .fontColor(ColorTokens.ACCENT)
            }
            .width('100%')
            .margin({ bottom: SpacingTokens.SM })

            // 日期 + 难度
            Row() {
              Text('📅')
                .fontSize(14)
                .fontColor(ColorTokens.INFO)
              Text(' 2026-04-30 至 2026-05-29')
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
              Blank()
              Text('🔥')
                .fontSize(14)
                .fontColor(ColorTokens.ACCENT)
              Text(` ${this.targetAudience} · ${this.weeklyFrequency}`)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
            }
            .width('100%')
            .margin({ bottom: SpacingTokens.MD })

            // 进度条
            Row() {
              Text('计划进度')
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
              Blank()
              Text(`1/${this.trainingDays.length}天`)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
            }
            .width('100%')
            .margin({ bottom: SpacingTokens.SM })

            Row() {
              Row()
                .width(`${100 / this.trainingDays.length}%`)
                .height(TouchTokens.PROGRESS_BAR_HEIGHT)
                .backgroundColor(ColorTokens.PRIMARY)
                .borderRadius(RadiusTokens.FULL)
            }
            .width('100%')
            .height(TouchTokens.PROGRESS_BAR_HEIGHT)
            .backgroundColor(ColorTokens.BG_SECONDARY)
            .borderRadius(RadiusTokens.FULL)
            .margin({ bottom: SpacingTokens.SM })

            // 说明文字
            Row() {
              Text('ℹ')
                .fontSize(14)
                .fontColor(ColorTokens.INFO)
              Text(' 专注核心肌群强化，提升身体稳定性与力量')
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
            }
            .width('100%')
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.LG)
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.MD, bottom: SpacingTokens.LG })

          // ═══ 训练日时间线 ═══
          ForEach(this.trainingDays, (day: TrainingDay, index: number) => {
            Row() {
              // 时间线左侧节点
              Column() {
                if (index > 0) {
                  Column()
                    .width(2)
                    .height(SpacingTokens.SM)
                    .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                } else {
                  Column()
                    .width(2)
                    .height(SpacingTokens.SM)
                    .backgroundColor(Color.Transparent)
                }

                Circle()
                  .width(12)
                  .height(12)
                  .fill(this.coverColor)

                if (index < this.trainingDays.length - 1) {
                  Column()
                    .width(2)
                    .layoutWeight(1)
                    .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                } else {
                  Column()
                    .width(2)
                    .layoutWeight(1)
                    .backgroundColor(Color.Transparent)
                }
              }
              .width(TouchTokens.TIMELINE_COL_WIDTH)
              .alignItems(HorizontalAlign.Center)

              // 训练日内容
              Column() {
                Row() {
                  Text(day.dayLabel)
                    .fontSize(FontTokens.BODY_BOLD_SIZE)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(ColorTokens.TEXT_PRIMARY)
                    .margin({ bottom: SpacingTokens.SM })
                  Text('35分钟')
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                    .margin({ left: SpacingTokens.MD })
                }

                ForEach(day.exercises, (exercise: ExerciseRef, idx: number) => {
                  Row() {
                    // 蓝色圆形编号徽章
                    Text(`${idx + 1}`)
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                      .width(24)
                      .height(24)
                      .borderRadius(RadiusTokens.FULL)
                      .backgroundColor(ColorTokens.PRIMARY)
                      .textAlign(TextAlign.Center)

                    Column() {
                      Text(exercise.name)
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_PRIMARY)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })

                      Row() {
                        Chip({ label: exercise.targetMuscle, color: MuscleColorMap.getColor(exercise.targetMuscle), chipSize: 'sm' })
                        Text(`${exercise.sets}组 × ${exercise.reps}次`)
                          .fontSize(FontTokens.SMALL_SIZE)
                          .fontColor(ColorTokens.TEXT_SECONDARY)
                          .margin({ left: SpacingTokens.SM })
                      }
                      .margin({ top: SpacingTokens.XS })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    .margin({ left: SpacingTokens.SM })

                    // 帮助按钮
                    Text('?')
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_SECONDARY)
                      .width(24)
                      .height(24)
                      .border({ width: 1, color: ColorTokens.TEXT_SECONDARY })
                      .borderRadius(RadiusTokens.FULL)
                      .textAlign(TextAlign.Center)
                  }
                  .width('100%')
                  .padding({ top: SpacingTokens.SM, bottom: SpacingTokens.SM, left: SpacingTokens.MD, right: SpacingTokens.MD })
                  .backgroundColor(ColorTokens.BG_SECONDARY)
                  .borderRadius(RadiusTokens.SM)
                  .margin({ bottom: SpacingTokens.XS })
                }, (exercise: ExerciseRef) => exercise.name + day.dayLabel)
              }
              .layoutWeight(1)
              .margin({ left: SpacingTokens.SM, bottom: SpacingTokens.MD })
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }, (day: TrainingDay) => day.dayLabel)

          // ═══ 底部间距 ═══
          Column()
            .height(SpacingTokens.XXL + SpacingTokens.LG)
            .width('100%')
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })

      // ═══ 底部"开始此计划"按钮 ═══
      Row() {
        AppButton({
          text: '开始此计划',
          type: 'primary',
          buttonSize: 'large',
          block: true,
          loading: this.enabling,
          onButtonClick: () => {
            this.handleEnablePlan()
          }
        })
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })
      .backgroundColor(ColorTokens.BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
