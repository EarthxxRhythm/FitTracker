/**
 * PlanDetailPage —— 计划详情预览页
 *
 * 功能 #8: 用户点击预置计划卡片进入详情页，以纵向时间线展示所有训练日
 *          及对应动作清单（动作名+目标肌群标签），底部显示"开始此计划"按钮。
 */
import { router } from '@kit.ArkUI'
import { AppButton } from '../components/AppButton'
import TrainingPlanService, { PresetPlan, TrainingDay, ExerciseRef } from '../common/services/TrainingPlanService'
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens } from '../common/styles/DesignTokens'

const MUSCLE_COLORS: Record<string, string> = {
  '胸': '#1E88E5',
  '背': '#43A047',
  '腿': '#FB8C00',
  '肩': '#8E24AA',
  '臂': '#E53935',
  '腹': '#00897B'
}

@Entry
@Component
struct PlanDetailPage {
  @State planName: string = ''
  @State coverColor: string = '#CCCCCC'
  @State targetAudience: string = ''
  @State weeklyFrequency: string = ''
  @State trainingDays: TrainingDay[] = []
  @State loaded: boolean = false

  async aboutToAppear(): Promise<void> {
    try {
      const params = router.getParams() as Record<string, string>
      const planId = params['planId'] as string
      if (planId) {
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
      // fallback: stay on page, show empty
    }
    this.loaded = true
  }

  getMuscleColor(muscle: string): string {
    return MUSCLE_COLORS[muscle] || '#9E9E9E'
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Row() {
          Text('←')
            .fontSize(FontTokens.TITLE_SIZE)
            .fontColor(ColorTokens.PRIMARY)
            .padding({ right: SpacingTokens.SM })
          Text(this.planName || '计划详情')
            .fontSize(FontTokens.HEADLINE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .onClick(() => {
          router.back()
        })

        Blank()
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.LG, bottom: SpacingTokens.MD })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      // 计划元信息
      Row() {
        Column() {
          Text(this.targetAudience)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(Color.White)
            .padding({ left: SpacingTokens.SM, right: SpacingTokens.SM, top: 2, bottom: 2 })
            .backgroundColor(this.coverColor)
            .borderRadius(RadiusTokens.SM)

          Text(this.weeklyFrequency)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .margin({ top: SpacingTokens.XS })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.SM, bottom: SpacingTokens.MD })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      // 时间线 — 训练日列表
      Scroll() {
        Column() {
          ForEach(this.trainingDays, (day: TrainingDay, index: number) => {
            Row() {
              // 时间线左侧节点
              Column() {
                // 竖线顶部（首项隐藏）
                if (index > 0) {
                  Column()
                    .width(2)
                    .height(SpacingTokens.SM)
                    .backgroundColor(ColorTokens.NEUTRAL_100)
                } else {
                  Column()
                    .width(2)
                    .height(SpacingTokens.SM)
                    .backgroundColor(Color.Transparent)
                }

                // 圆点
                Circle()
                  .width(12)
                  .height(12)
                  .fill(this.coverColor)

                // 竖线底部（末项隐藏）
                if (index < this.trainingDays.length - 1) {
                  Column()
                    .width(2)
                    .layoutWeight(1)
                    .backgroundColor(ColorTokens.NEUTRAL_100)
                } else {
                  Column()
                    .width(2)
                    .layoutWeight(1)
                    .backgroundColor(Color.Transparent)
                }
              }
              .width(20)
              .alignItems(HorizontalAlign.Center)

              // 训练日内容
              Column() {
                Text(day.dayLabel)
                  .fontSize(FontTokens.BODY_BOLD_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                  .margin({ bottom: SpacingTokens.SM })

                ForEach(day.exercises, (exercise: ExerciseRef) => {
                  Row() {
                    Column() {
                      Text(exercise.name)
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_PRIMARY)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })

                      Row() {
                        Text(exercise.targetMuscle)
                          .fontSize(9)
                          .fontColor(Color.White)
                          .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                          .backgroundColor(this.getMuscleColor(exercise.targetMuscle))
                          .borderRadius(4)

                        Text(`${exercise.sets}×${exercise.reps}`)
                          .fontSize(FontTokens.SMALL_SIZE)
                          .fontColor(ColorTokens.TEXT_SECONDARY)
                          .margin({ left: SpacingTokens.SM })
                      }
                      .margin({ top: SpacingTokens.XS })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({
                    top: SpacingTokens.SM,
                    bottom: SpacingTokens.SM,
                    left: SpacingTokens.MD,
                    right: SpacingTokens.MD
                  })
                  .backgroundColor(ColorTokens.SURFACE_PRIMARY)
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
        }
        .width('100%')
        .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.MD, bottom: SpacingTokens.XXL + SpacingTokens.LG })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 底部"开始此计划"按钮
      Row() {
        AppButton({
          text: '开始此计划',
          type: 'primary',
          size: 'large',
          block: true,
          onButtonClick: () => {
            // 功能 #9 将实现具体的开始计划逻辑
          }
        })
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
  }
}
