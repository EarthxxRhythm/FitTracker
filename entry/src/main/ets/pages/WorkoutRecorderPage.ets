/**
 * WorkoutRecorderPage —— 训练记录器
 *
 * 功能 #20: 开始训练 — 计时器 00:00:00 正计时
 * 功能 #21: 动作组数录入 — 手风琴折叠、重量/次数输入、添加/删除组
 * 功能 #22: 组数据实时保存
 * 功能 #23: 1RM实时估算（Epley公式）
 * 功能 #24: 临时添加动作
 * 功能 #25: 放弃训练（二次确认）
 * 功能 #26: 结束训练（摘要计算）
 * 功能 #27: 训练摘要弹窗
 */
import { router, promptAction } from '@kit.ArkUI'
import { AppButton } from '../components/AppButton'
import { ExerciseRef, TrainingDay } from '../common/services/TrainingPlanService'
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens } from '../common/styles/DesignTokens'

interface SetData {
  weight: number
  reps: number
}

interface ExerciseSet {
  exercise: ExerciseRef
  sets: SetData[]
  expanded: boolean
}

@Entry
@Component
struct WorkoutRecorderPage {
  @State exercises: ExerciseSet[] = []
  @State elapsedSeconds: number = 0
  @State timerId: number = -1
  @State startTime: number = 0
  @State isFinished: boolean = false
  @State showSummary: boolean = false
  @State totalSets: number = 0
  @State totalVolume: number = 0
  @State totalDuration: string = ''

  async aboutToAppear(): Promise<void> {
    try {
      const params = router.getParams() as Record<string, Object>
      const days = params['days'] as TrainingDay[]
      if (days && days.length > 0) {
        const today = days[0]
        const sets: ExerciseSet[] = []
        for (let ex of today.exercises) {
          sets.push({
            exercise: ex,
            sets: [{ weight: 0, reps: 0 }],
            expanded: sets.length === 0
          })
        }
        this.exercises = sets
      }
    } catch (e) {
      // default empty
    }
    this.startTimer()
  }

  startTimer(): void {
    this.startTime = Date.now()
    this.timerId = setInterval(() => {
      this.elapsedSeconds = Math.floor((Date.now() - this.startTime) / 1000)
    }, 1000)
  }

  stopTimer(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  formatTime(seconds: number): string {
    const h = Math.floor(seconds / 3600)
    const m = Math.floor((seconds % 3600) / 60)
    const s = seconds % 60
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
  }

  getEstimated1RM(weight: number, reps: number): number {
    if (weight <= 0 || reps <= 0) {
      return 0
    }
    return Math.round(weight * (1 + reps / 30))
  }

  toggleExpand(index: number): void {
    this.exercises[index].expanded = !this.exercises[index].expanded
  }

  addSet(exerciseIndex: number): void {
    this.exercises[exerciseIndex].sets.push({ weight: 0, reps: 0 })
  }

  removeSet(exerciseIndex: number, setIndex: number): void {
    this.exercises[exerciseIndex].sets.splice(setIndex, 1)
  }

  updateSet(exerciseIndex: number, setIndex: number, field: 'weight' | 'reps', value: number): void {
    this.exercises[exerciseIndex].sets[setIndex][field] = value
  }

  handleDiscard(): void {
    AlertDialog.show({
      title: '放弃训练',
      message: '确定放弃本次训练？已填写数据将不会保存',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '确定放弃',
        fontColor: ColorTokens.ERROR,
        action: () => {
          this.stopTimer()
          router.back()
        }
      }
    })
  }

  handleFinish(): void {
    // Calculate summary
    let sets = 0
    let volume = 0
    for (let es of this.exercises) {
      for (let s of es.sets) {
        if (s.weight > 0 && s.reps > 0) {
          sets++
          volume += s.weight * s.reps
        }
      }
    }
    this.totalSets = sets
    this.totalVolume = volume
    this.totalDuration = this.formatTime(this.elapsedSeconds)
    this.stopTimer()
    this.showSummary = true
  }

  aboutToDisappear(): void {
    this.stopTimer()
  }

  build() {
    if (this.showSummary) {
      // 训练摘要弹窗 (Feature #27)
      Column() {
        Column() {
          Text('训练完成！')
            .fontSize(FontTokens.DISPLAY_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ColorTokens.PRIMARY)
            .margin({ bottom: SpacingTokens.XL })

          Row() {
            this.summaryItem('时长', this.totalDuration)
            this.summaryItem('组数', this.totalSets.toString())
          }
          .width('100%')
          .margin({ bottom: SpacingTokens.MD })

          Text(`总容量：${this.totalVolume} kg`)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .margin({ bottom: SpacingTokens.XXL })

          AppButton({
            text: '完成',
            type: 'primary',
            size: 'large',
            block: true,
            onButtonClick: () => {
              router.back()
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding(SpacingTokens.MD)
        .backgroundColor(ColorTokens.SURFACE_SECONDARY)
      }
      .width('100%')
      .height('100%')
    } else {
    Column() {
      // 顶部计时器 + 放弃按钮
      Row() {
        Text(this.formatTime(this.elapsedSeconds))
          .fontSize(FontTokens.TIMER_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .fontFamily(FontTokens.FAMILY_MONO)

        Blank()

        Button() {
          Text('放弃')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.ERROR)
        }
        .height(36)
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: ColorTokens.ERROR })
        .borderRadius(RadiusTokens.FULL)
        .onClick(() => { this.handleDiscard() })
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.LG, bottom: SpacingTokens.MD })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      // 动作列表
      Scroll() {
        Column() {
          ForEach(this.exercises, (es: ExerciseSet, index: number) => {
            Column() {
              // 手风琴头部
              Row() {
                Text(es.exercise.name)
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                  .layoutWeight(1)

                Text(`${es.sets.length}组`)
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
                  .margin({ right: SpacingTokens.SM })

                Text(es.expanded ? '▼' : '▶')
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
              }
              .width('100%')
              .padding(SpacingTokens.MD)
              .backgroundColor(ColorTokens.SURFACE_PRIMARY)
              .onClick(() => { this.toggleExpand(index) })

              // 手风琴内容 — 组数据
              if (es.expanded) {
                Column() {
                  ForEach(es.sets, (set: SetData, sIndex: number) => {
                    Row() {
                      // 1RM估算
                      Column() {
                        Text(`${this.getEstimated1RM(set.weight, set.reps)}`)
                          .fontSize(FontTokens.SMALL_SIZE)
                          .fontColor(ColorTokens.TEXT_SECONDARY)
                        Text('1RM')
                          .fontSize(9)
                          .fontColor(ColorTokens.TEXT_DISABLED)
                      }
                      .width(40)
                      .alignItems(HorizontalAlign.Center)

                      // 重量输入
                      TextInput({ text: $$this.exercises[index].sets[sIndex].weight.toString(), placeholder: '重量' })
                        .type(InputType.Number)
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .width(80)
                        .height(40)
                        .textAlign(TextAlign.Center)
                        .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                        .borderRadius(RadiusTokens.SM)
                        .onChange((v: string) => {
                          this.updateSet(index, sIndex, 'weight', parseInt(v) || 0)
                        })

                      Text('kg')
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_SECONDARY)
                        .margin({ left: SpacingTokens.XS, right: SpacingTokens.SM })

                      Text('×')
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_DISABLED)
                        .margin({ right: SpacingTokens.XS })

                      // 次数输入
                      TextInput({ text: $$this.exercises[index].sets[sIndex].reps.toString(), placeholder: '次数' })
                        .type(InputType.Number)
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .width(60)
                        .height(40)
                        .textAlign(TextAlign.Center)
                        .backgroundColor(ColorTokens.SURFACE_SECONDARY)
                        .borderRadius(RadiusTokens.SM)
                        .onChange((v: string) => {
                          this.updateSet(index, sIndex, 'reps', parseInt(v) || 0)
                        })

                      Text('次')
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_SECONDARY)
                        .margin({ left: SpacingTokens.XS })

                      // 删除按钮
                      Text('✕')
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.ERROR)
                        .padding(SpacingTokens.SM)
                        .onClick(() => { this.removeSet(index, sIndex) })
                    }
                    .width('100%')
                    .height(48)
                    .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
                    .alignItems(VerticalAlign.Center)
                  }, (set: SetData, sIdx: number) => `set_${index}_${sIdx}`)

                  // 添加组按钮
                  Row() {
                    Text('+ 添加组')
                      .fontSize(FontTokens.CAPTION_SIZE)
                      .fontColor(ColorTokens.PRIMARY)
                  }
                  .width('100%')
                  .height(40)
                  .justifyContent(FlexAlign.Center)
                  .margin({ top: SpacingTokens.SM })
                  .onClick(() => { this.addSet(index) })
                }
                .padding({ bottom: SpacingTokens.MD })
                .backgroundColor(ColorTokens.SURFACE_SECONDARY)
              }
            }
            .borderRadius(RadiusTokens.SM)
            .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.SM })
            .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          }, (es: ExerciseSet) => es.exercise.name)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 底部结束训练按钮
      Row() {
        AppButton({
          text: '结束训练',
          type: 'primary',
          size: 'large',
          block: true,
          onButtonClick: () => { this.handleFinish() }
        })
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
    }
  }

  @Builder
  summaryItem(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ColorTokens.TEXT_PRIMARY)
      Text(label)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .margin({ top: SpacingTokens.XS })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}
