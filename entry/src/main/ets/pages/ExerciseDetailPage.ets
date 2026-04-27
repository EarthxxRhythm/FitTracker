/**
 * ExerciseDetailPage —— 动作详情页
 *
 * 功能 #17: 动作详情（大图占位、动作要领/参与肌群标签页）
 * 功能 #18: 个人纪录展示（最佳1RM、最佳重量×次数、纪录日期）
 */
import { router } from '@kit.ArkUI'
import { AppCard } from '../components/AppCard'
import ExerciseService, { Exercise } from '../common/services/ExerciseService'
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens } from '../common/styles/DesignTokens'

const MUSCLE_COLORS: Record<string, string> = {
  '胸': '#1E88E5', '背': '#43A047', '腿': '#FB8C00',
  '肩': '#8E24AA', '臂': '#E53935', '腹': '#00897B'
}

@Entry
@Component
struct ExerciseDetailPage {
  @State exercise: Exercise | null = null
  @State activeTab: number = 0 // 0=动作要领, 1=参与肌群

  async aboutToAppear(): Promise<void> {
    try {
      const params = router.getParams() as Record<string, string>
      const id = params['exerciseId'] as string
      if (id) {
        this.exercise = ExerciseService.getById(id) || null
      }
    } catch (e) {
      // fallback
    }
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
          Text(this.exercise?.name || '动作详情')
            .fontSize(FontTokens.HEADLINE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .onClick(() => { router.back() })
        Blank()
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.LG, bottom: SpacingTokens.MD })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      if (this.exercise !== null) {
        Column() {
          // 顶部大图占位
          Column() {
            Text(this.exercise.name.charAt(0))
              .fontSize(48)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Text(this.exercise.name)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(Color.White)
              .margin({ top: SpacingTokens.SM })
          }
          .width('100%')
          .height(200)
          .backgroundColor(MUSCLE_COLORS[this.exercise.primaryMuscle] || '#999')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          // 主肌群/器械标签
          Row() {
            Text(this.exercise.primaryMuscle)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(Color.White)
              .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.XS, bottom: SpacingTokens.XS })
              .backgroundColor(MUSCLE_COLORS[this.exercise.primaryMuscle] || '#999')
              .borderRadius(RadiusTokens.FULL)
            Text(this.exercise.equipment)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .margin({ left: SpacingTokens.SM })
          }
          .width('100%')
          .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.MD, bottom: SpacingTokens.SM })
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)

          // 标签页：动作要领 / 参与肌群
          Row() {
            Button() {
              Text('动作要领')
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.activeTab === 0 ? Color.White : ColorTokens.TEXT_SECONDARY)
            }
            .layoutWeight(1)
            .height(36)
            .backgroundColor(this.activeTab === 0 ? ColorTokens.PRIMARY : ColorTokens.SURFACE_SECONDARY)
            .borderRadius(RadiusTokens.FULL)
            .onClick(() => { this.activeTab = 0 })

            Button() {
              Text('参与肌群')
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.activeTab === 1 ? Color.White : ColorTokens.TEXT_SECONDARY)
            }
            .layoutWeight(1)
            .height(36)
            .backgroundColor(this.activeTab === 1 ? ColorTokens.PRIMARY : ColorTokens.SURFACE_SECONDARY)
            .borderRadius(RadiusTokens.FULL)
            .margin({ left: SpacingTokens.SM })
            .onClick(() => { this.activeTab = 1 })
          }
          .width('100%')
          .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.MD, bottom: SpacingTokens.MD })
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)

          // 标签页内容
          if (this.activeTab === 0) {
            Column() {
              Text(`目标肌群：${this.exercise.primaryMuscle}`)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .margin({ bottom: SpacingTokens.SM })
                .width('100%')

              Text(`使用器械：${this.exercise.equipment}`)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
                .margin({ bottom: SpacingTokens.MD })
                .width('100%')

              Text('动作描述')
                .fontSize(FontTokens.BODY_BOLD_SIZE)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .margin({ bottom: SpacingTokens.SM })
                .width('100%')

              Text(`${this.exercise.name}是一项针对${this.exercise.primaryMuscle}部的主要训练动作，同时也能锻炼到${this.exercise.secondaryMuscle}部。建议使用${this.exercise.equipment}进行训练。`)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
                .width('100%')
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .layoutWeight(1)
          } else {
            Column() {
              Row() {
                Text('目标肌群')
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                Blank()
                Text(this.exercise.primaryMuscle)
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(Color.White)
                  .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.XS, bottom: SpacingTokens.XS })
                  .backgroundColor(MUSCLE_COLORS[this.exercise.primaryMuscle] || '#999')
                  .borderRadius(RadiusTokens.SM)
              }
              .width('100%')
              .margin({ bottom: SpacingTokens.MD })

              Row() {
                Text('次要肌群')
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                Blank()
                Text(this.exercise.secondaryMuscle)
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
                  .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.XS, bottom: SpacingTokens.XS })
                  .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                  .borderRadius(RadiusTokens.SM)
              }
              .width('100%')
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .layoutWeight(1)
          }

          // 个人纪录卡片 (#18)
          AppCard({ variant: 'outlined', padding: 'default' }) {
            Column() {
              Text('我的纪录')
                .fontSize(FontTokens.BODY_BOLD_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .width('100%')
                .margin({ bottom: SpacingTokens.MD })

              Text('尚未记录')
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_DISABLED)
                .width('100%')
              Text('完成一次训练后系统将自动记录')
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.TEXT_DISABLED)
                .margin({ top: SpacingTokens.XS })
                .width('100%')
            }
            .width('100%')
          }
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
  }
}
