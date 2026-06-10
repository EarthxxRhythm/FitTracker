/**
 * ExerciseDetailPage —— 动作详情页
 *
 * 功能 #17: 动作详情（大图占位、动作要领/参与肌群标签页）
 * 功能 #18: 个人纪录展示（最佳1RM、最佳重量×次数、纪录日期）
 */
import { Context } from '@kit.AbilityKit'
import { AppCard } from '../components/AppCard'
import ExerciseService, { Exercise } from '../common/services/ExerciseService'
import WorkoutSessionService, { ExerciseRecord } from '../common/services/WorkoutSessionService'
import { MuscleColorMap, TouchTokens, FontTokens, RadiusTokens, ColorTokens, SpacingTokens } from '../common/styles/DesignTokens'
import { SegmentedControl } from '../components/SegmentedControl'
import { Chip } from '../components/Chip'
import { EmptyState } from '../components/EmptyState'

// Muscle color mapping handled by MuscleColorMap

@Entry
@Component
struct ExerciseDetailPage {
  @State exercise: Exercise | null = null
  @State activeTab: number = 0 // 0=动作要领, 1=参与肌群
  @State best1RM: number = 0
  @State bestRecord: ExerciseRecord | null = null

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  async aboutToAppear(): Promise<void> {
    try {
      const params = this.getUIContext().getRouter().getParams() as Record<string, string>
      const id = params.exerciseId
      if (id) {
        this.exercise = ExerciseService.getById(id) || null
        if (this.exercise) {
          const context: Context | null = this.getHostContextOrNull()
          const records: ExerciseRecord[] = context !== null
            ? await WorkoutSessionService.getAllExerciseRecords(context)
            : []
          const exerciseName: string = this.exercise.name
          const match = records.find(r => r.exerciseName === exerciseName)
          if (match) {
            this.best1RM = match.best1RM
            this.bestRecord = match
          }
        }
      }
    } catch (e) {
      // fallback
    }
  }

  // DESIGN: ExerciseDetail uses HERO_SIZE/HERO_HEIGHT for hero, Chip for muscle tags, SegmentedControl for tabs, EmptyState for no-records.
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
        .onClick(() => { this.getUIContext().getRouter().back() })
        Blank()
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.LG, bottom: SpacingTokens.MD })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      if (this.exercise !== null) {
        Scroll() {
          Column() {
          // 顶部大图占位
          Column() {
            Text(this.exercise.name.charAt(0))
              .fontSize(FontTokens.HERO_SIZE)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Text(this.exercise.name)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(Color.White)
              .margin({ top: SpacingTokens.SM })
          }
          .width('100%')
          .height(TouchTokens.HERO_HEIGHT)
          .backgroundColor(MuscleColorMap.getColor(this.exercise.primaryMuscle))
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          // 主肌群/器械标签
          Row() {
            Chip({ label: this.exercise.primaryMuscle, color: MuscleColorMap.getColor(this.exercise.primaryMuscle), chipSize: 'sm' })
            Text(this.exercise.equipment)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .margin({ left: SpacingTokens.SM })
          }
          .width('100%')
          .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.MD, bottom: SpacingTokens.SM })
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)

          // 标签页：动作要领 / 参与肌群
          SegmentedControl({ selectedIndex: this.activeTab, options: ['动作要领', '参与肌群'], segmentSize: 'small' })
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
                Chip({ label: this.exercise.primaryMuscle, color: MuscleColorMap.getColor(this.exercise.primaryMuscle), chipSize: 'sm' })
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
          AppCard({ variant: 'outlined', cardPadding: 'default' }) {
            Column() {
              Text('我的纪录')
                .fontSize(FontTokens.BODY_BOLD_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .width('100%')
                .margin({ bottom: SpacingTokens.MD })

              if (this.bestRecord !== null) {
                Row() {
                  Column() {
                    Text(`${this.best1RM}`)
                      .fontSize(FontTokens.TITLE_SIZE)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ColorTokens.PRIMARY)
                    Text('最佳 1RM (kg)')
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_SECONDARY)
                      .margin({ top: SpacingTokens.XS })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)

                  Column() {
                    Text(`${this.bestRecord.bestWeight}×${this.bestRecord.bestReps}`)
                      .fontSize(FontTokens.TITLE_SIZE)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ColorTokens.TEXT_PRIMARY)
                    Text('最佳重量 × 次数')
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_SECONDARY)
                      .margin({ top: SpacingTokens.XS })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Center)
                }
                .width('100%')
                .margin({ bottom: SpacingTokens.SM })

                Text(`纪录日期：${this.bestRecord.bestDate}`)
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
                  .width('100%')
            } else {
              EmptyState({ icon: '📊', title: '尚未记录', subtitle: '完成一次训练后系统将自动记录' })
            }
            }
            .width('100%')
            .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })
          }
        }
        .width('100%')
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
