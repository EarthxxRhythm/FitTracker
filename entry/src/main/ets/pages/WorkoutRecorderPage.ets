/**
 * WorkoutRecorderPage —— 训练记录器 (原型 8+9)
 *
 * View A: 训练编辑 (重量/次数/组数/休息 ± 控件, 完成按钮)
 * View B: 计时器 (进度环, 开始/暂停, 任务列表, 浮动添加按钮)
 */
import { router } from '@kit.ArkUI'
import { ExerciseRef, TrainingDay } from '../common/services/TrainingPlanService'
import TrainingPlanService from '../common/services/TrainingPlanService'
import WorkoutSessionService, { WorkoutSession, SavedExercise, SavedSet } from '../common/services/WorkoutSessionService'
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens, TouchTokens, StopwatchTokens } from '../common/styles/DesignTokens'
import { CustomTabBar } from '../components/MainTabBar'
import { promptAction } from '@kit.ArkUI'

interface ExEditorData {
  name: string
  weight: number
  reps: number
  sets: number
  rest: number
}
@Preview
@Component
export struct WorkoutRecorderPage {
  @State currentTab: string = 'training'
  @State viewMode: number = 1 // 0=editor, 1=timer
  @State timerSeconds: number = 0
  @State timerRunning: boolean = false
  private timerId: number = -1
  private planId: string = ''
  private planName: string = ''
  private dayLabel: string = ''
  private trainingDays: TrainingDay[] = []

  // Editor state
  @State exercises: ExEditorData[] = [
    { name: '深蹲', weight: 60, reps: 12, sets: 4, rest: 90 },
    { name: '卧推', weight: 50, reps: 10, sets: 4, rest: 120 },
    { name: '硬拉', weight: 80, reps: 8, sets: 3, rest: 180 }
  ]

  // Timer state
  private totalMinutes: number = 45
  private tasksTotal: number = 5
  private tasksDone: number = 3

  aboutToAppear(): void {
    try {
      const params = router.getParams() as Record<string, Object>
      if (params) {
        if (params['days'] !== undefined) {
          this.trainingDays = params['days'] as TrainingDay[]
        }
        if (params['planId'] !== undefined) {
          this.planId = params['planId'] as string
        }
        if (params['planName'] !== undefined) {
          this.planName = params['planName'] as string
        }
        if (params['dayLabel'] !== undefined) {
          this.dayLabel = params['dayLabel'] as string
        }
      }
    } catch (e) {
      // params parse failed
    }
  }

  aboutToDisappear(): void {
    this.stopTimer()
  }

  startTimer(): void {
    if (!this.timerRunning) {
      this.timerRunning = true
      this.timerId = setInterval(() => {
        this.timerSeconds++
      }, 1000)
    }
  }

  pauseTimer(): void {
    this.timerRunning = false
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  stopTimer(): void {
    this.timerRunning = false
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  resetTimer(): void {
    this.pauseTimer()
    this.timerSeconds = 0
  }

  async finishWorkout(): Promise<void> {
    const exercises: SavedExercise[] = []
    let totalSets = 0
    let totalVolume = 0

    for (let i = 0; i < this.exercises.length; i++) {
      const ex = this.exercises[i]
      const sets: SavedSet[] = []
      for (let s = 0; s < ex.sets; s++) {
        const set: SavedSet = { weight: ex.weight, reps: ex.reps }
        sets.push(set)
        totalVolume += ex.weight * ex.reps
      }
      totalSets += ex.sets
      const savedEx: SavedExercise = {
        name: ex.name,
        targetMuscle: '',
        sets: sets
      }
      exercises.push(savedEx)
    }

    const now = Date.now()
    const dateStr = `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, '0')}-${String(new Date().getDate()).padStart(2, '0')}`

    const session: WorkoutSession = {
      id: `session_${now}`,
      planId: this.planId,
      planName: this.planName || '自由训练',
      dayLabel: this.dayLabel || '',
      startTime: now - this.timerSeconds * 1000,
      endTime: now,
      durationSeconds: this.timerSeconds,
      totalSets: totalSets,
      totalVolume: totalVolume,
      notes: '',
      exercises: exercises,
      createdAt: dateStr
    }

    await WorkoutSessionService.saveSession(getContext(this), session)
    promptAction.showToast({ message: '训练已保存' })
    router.back()
  }

  formatTime(totalSec: number): string {
    const m = Math.floor(totalSec / 60)
    const s = totalSec % 60
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
  }

  build() {
    Column() {
      if (this.viewMode === 0) {
        this.EditorView()
      } else {
        this.TimerView()
      }

      // CustomTabBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }

  // ═══════════════ VIEW A: 训练记录编辑 ═══════════════
  @Builder
  EditorView() {
    Column() {
      // Header
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .padding({ right: SpacingTokens.SM })
          .onClick(() => { router.back() })
        Text('训练记录编辑')
          .fontSize(FontTokens.HEADLINE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.TEXT_PRIMARY)
        Blank()
        Text(new Date().toLocaleDateString())
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.LG, bottom: SpacingTokens.MD })

      Scroll() {
        Column() {
          ForEach(this.exercises, (ex: ExEditorData, idx: number) => {
            Column() {
              // 标题行
              Row() {
                Column() {
                  Text('🏋')
                    .fontSize(20)
                }
                .width(36)
                .height(36)
                .borderRadius(RadiusTokens.FULL)
                .backgroundColor(ColorTokens.OVERLAY_PRIMARY)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)

                Text(ex.name)
                  .fontSize(FontTokens.BODY_BOLD_SIZE)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                  .margin({ left: SpacingTokens.SM })
                  .layoutWeight(1)

                Text('⋯')
                  .fontSize(20)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
              }
              .width('100%')
              .margin({ bottom: SpacingTokens.MD })

              // Row 1: 重量 | 次数
              Row() {
                this.NumberField('重量(kg)', ex.weight, (v: number) => { this.exercises[idx].weight = v })
                Column().width(SpacingTokens.SM)
                this.NumberField('次数', ex.reps, (v: number) => { this.exercises[idx].reps = v })
              }
              .width('100%')
              .margin({ bottom: SpacingTokens.SM })

              // Row 2: 组数 | 休息
              Row() {
                this.NumberField('组数', ex.sets, (v: number) => { this.exercises[idx].sets = v })
                Column().width(SpacingTokens.SM)
                this.NumberField('休息(s)', ex.rest, (v: number) => { this.exercises[idx].rest = v })
              }
              .width('100%')
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .backgroundColor(ColorTokens.SURFACE_PRIMARY)
            .borderRadius(RadiusTokens.LG)
            .margin({ bottom: SpacingTokens.SM })
          }, (ex: ExEditorData, idx: number) => `${idx}`)

          // 完成按钮
          Button('完成')
            .width('100%')
            .height(TouchTokens.BUTTON_HEIGHT_LARGE)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_ON_PRIMARY)
            .backgroundColor(ColorTokens.PRIMARY)
            .borderRadius(RadiusTokens.FULL)
            .margin({ top: SpacingTokens.MD, bottom: SpacingTokens.XXL })
            .onClick(() => { this.finishWorkout() })
        }
        .width('100%')
        .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  NumberField(label: string, value: number, onChange: (v: number) => void) {
    Column() {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .margin({ bottom: SpacingTokens.XS })
      Row() {
        Text('−')
          .fontSize(18)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .width(32)
          .height(32)
          .textAlign(TextAlign.Center)
          .backgroundColor(ColorTokens.SURFACE_ELEVATED)
          .borderRadius(RadiusTokens.XS)
          .onClick(() => { if (value > 0) onChange(value - 1) })

        Text(`${value}`)
          .fontSize(FontTokens.BODY_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('+')
          .fontSize(18)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .width(32)
          .height(32)
          .textAlign(TextAlign.Center)
          .backgroundColor(ColorTokens.SURFACE_ELEVATED)
          .borderRadius(RadiusTokens.XS)
          .onClick(() => { onChange(value + 1) })
      }
      .width('100%')
    }
    .layoutWeight(1)
    .padding(SpacingTokens.XS)
    .backgroundColor(ColorTokens.BG_SECONDARY)
    .borderRadius(RadiusTokens.SM)
  }

  // ═══════════════ VIEW B: 计时器 + 任务列表 ═══════════════
  @Builder
  TimerView() {
    Column() {
      Scroll() {
        Column() {
          // ═══ 计时器卡片 ═══
          Column() {
            MechanicalStopwatch({ elapsedSeconds: this.timerSeconds, isRunning: this.timerRunning })

            // 开始/暂停按钮
            Row() {
              Button(this.timerRunning ? '⏸ 暂停' : '▶ 开始')
                .fontSize(FontTokens.BODY_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                .backgroundColor(this.timerRunning
                  ? ColorTokens.ACCENT
                  : ColorTokens.PRIMARY)
                .borderRadius(RadiusTokens.FULL)
                .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
                .layoutWeight(1)
                .shadow({
                  radius: 8,
                  color: this.timerRunning
                    ? 'rgba(255,152,0,0.35)'
                    : 'rgba(30,136,229,0.35)',
                  offsetX: 0,
                  offsetY: 4
                })
                .onClick(() => { this.timerRunning ? this.pauseTimer() : this.startTimer() })

              Column().width(SpacingTokens.MD)

              Button('↺ 重置')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                .borderRadius(RadiusTokens.FULL)
                .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
                .layoutWeight(1)
                .onClick(() => { this.resetTimer() })
            }
            .width('100%')
            .margin({ bottom: SpacingTokens.MD })

            // 分隔线
            Row()
              .width('100%')
              .height(1)
              .backgroundColor('rgba(255,255,255,0.06)')
              .margin({ bottom: SpacingTokens.MD })

            // 任务进度
            Row() {
              Column() {
                Text(`${this.tasksDone}/${this.tasksTotal}`)
                  .fontSize(FontTokens.TITLE_SIZE)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                Text('今日任务')
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
              }
              .layoutWeight(1)

              Column() {
                Text(`${Math.round(this.tasksDone / this.tasksTotal * 100)}%`)
                  .fontSize(FontTokens.TITLE_SIZE)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ColorTokens.SUCCESS)
                Text('完成度')
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
              }
              .layoutWeight(1)
            }
            .width('100%')
          }
          .width('95%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.LG)
          .border({
            width: { top: 2 },
            color: { top: ColorTokens.PRIMARY },
            radius: { topLeft: RadiusTokens.LG, topRight: RadiusTokens.LG }
          })
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })

          // ═══ 任务列表 ═══
          Column( {space : 10} ) {
            ForEach(this.trainingDays.length > 0 && this.trainingDays[0].exercises.length > 0
              ? this.trainingDays[0].exercises
              : [
                  { name: '哑铃卧推', targetMuscle: '胸', sets: 4, reps: '12' },
                  { name: '坐姿划船', targetMuscle: '背', sets: 4, reps: '10' },
                  { name: '肩部推举', targetMuscle: '肩', sets: 3, reps: '12' },
                  { name: '三头肌绳索下拉', targetMuscle: '臂', sets: 3, reps: '15' }
                ] as ExerciseRef[],
              (ex: ExerciseRef, idx: number) => {
                Row() {
                  Text(`${idx + 1}`)
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                    .width(28)
                    .height(28)
                    .borderRadius(RadiusTokens.FULL)
                    .backgroundColor(ColorTokens.PRIMARY)
                    .textAlign(TextAlign.Center)
                    .margin({
                      left: SpacingTokens.SM,
                      right: SpacingTokens.SM,
                      bottom: SpacingTokens.SM,
                      top: SpacingTokens.SM
                    })

                  Column() {
                    Text(ex.name)
                      .fontSize(FontTokens.BODY_SIZE)
                      .fontColor(ColorTokens.TEXT_PRIMARY)
                    Text(`${ex.sets}组 x ${ex.reps}次`)
                      .fontSize(FontTokens.CAPTION_SIZE)
                      .fontColor(ColorTokens.TEXT_SECONDARY)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  .margin({ left: SpacingTokens.SM })

                  Text('')
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                    .width(28)
                    .height(28)
                    .border({ width: 1, color: ColorTokens.TEXT_SECONDARY })
                    .borderRadius(RadiusTokens.FULL)
                    .textAlign(TextAlign.Center)
                    .margin({
                      left: SpacingTokens.SM,
                      right: SpacingTokens.SM,
                    })
                }
                .width('100%')
                .backgroundColor(ColorTokens.BG_SECONDARY)
                .padding({ top: SpacingTokens.SM, bottom: SpacingTokens.SM })
                .borderRadius(RadiusTokens.MD)
              }, (ex: ExerciseRef, idx: number) => `${idx}`)

          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.LG)
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.XXL })
        }
        .width('90%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 浮动添加按钮
      Stack() {
        Button('+')
          .width(56)
          .height(56)
          .fontSize(28)
          .fontColor(ColorTokens.TEXT_ON_PRIMARY)
          .backgroundColor(ColorTokens.PRIMARY)
          .borderRadius(RadiusTokens.FULL)
          .position({ x: '80%', y: '-20%' })
          .onClick(() => { this.viewMode = 0 })
      }
    }
    .layoutWeight(1)
    .width('100%')
  }
}

// ═══════════════════════════════════════════════════════════════
// MechanicalStopwatch — 精密计时秒表 (Precision Instrument)
//
// 美学方向：高端运动计时码表
//   深度层次：3 层同心圆（表盘基色 → 微光晕 → 内圈高光）
//   外表圈：双环装饰线模拟金属表圈
//   指针：青色秒针 + 配重尾端，白色分针
//   中心枢纽：双层圆（外环 + 内实心），计时中切换为暖橙
//   数字时间：等宽字体 + 蓝色微光阴影
// ═══════════════════════════════════════════════════════════════
@Component
export struct MechanicalStopwatch {
  @Prop elapsedSeconds: number = 0
  @Prop isRunning: boolean = false

  private readonly SECOND_MARKS: number[] = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55]
  private readonly ALL_TICKS: number[] = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
    10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
    20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
    30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
    40, 41, 42, 43, 44, 45, 46, 47, 48, 49,
    50, 51, 52, 53, 54, 55, 56, 57, 58, 59
  ]

  getDisplayTime(): string {
    const mins = Math.floor(this.elapsedSeconds / 60)
    const secs = this.elapsedSeconds % 60
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`
  }

  getSecondsAngle(): number {
    return this.elapsedSeconds * 6
  }

  getMinutesAngle(): number {
    return Math.floor(this.elapsedSeconds / 60) * 6
  }

  build() {
    Stack() {
      Stack() {
        // ────── Layer 1: 表盘基底（最深）────────
        Circle()
          .width('100%')
          .height('100%')
          .fill(StopwatchTokens.DIAL_BASE)

        // ────── Layer 2: 微光晕层（92% 直径，淡蓝色）────────
        Circle()
          .width('92%')
          .height('92%')
          .fill(StopwatchTokens.DIAL_OVERLAY)

        // ────── Layer 3: 内圈高光（78% 直径）────────
        Circle()
          .width('78%')
          .height('78%')
          .fill(StopwatchTokens.DIAL_INNER)

        // ────── 外表圈装饰 — 双环线 ────────
        Circle()
          .width('96%')
          .height('96%')
          .fill(Color.Transparent)
          .stroke(StopwatchTokens.BEZEL_STROKE)
          .strokeWidth(1.5)

        Circle()
          .width('98%')
          .height('98%')
          .fill(Color.Transparent)
          .stroke(StopwatchTokens.BEZEL_STROKE)
          .strokeWidth(0.5)

        // ═══════════════ 主刻度（每 5 秒）+ 数字 ═══════════════
        ForEach(this.SECOND_MARKS, (second: number) => {
          Stack() {
            Rect()
              .width(2.5)
              .height(16)
              .fill(StopwatchTokens.TICK_MAJOR)
              .borderRadius(1.25)
              .offset({ y: -126 })
            Text(second.toString())
              .fontSize(FontTokens.SMALL_SIZE)
              .fontWeight(FontWeight.Bold)
              .fontColor(StopwatchTokens.TICK_MAJOR)
              .offset({ y: -106 })
              .rotate({ angle: -second * 6 })
          }
          .width('100%')
          .height('100%')
          .rotate({ angle: second * 6, centerX: '50%', centerY: '50%' })
        })

        // ═══════════════ 小刻度（每 1 秒，跳过 5 倍数）═══════════════
        ForEach(this.ALL_TICKS, (second: number) => {
          if (second % 5 !== 0) {
            Stack() {
              Rect()
                .width(1)
                .height(6)
                .fill(StopwatchTokens.TICK_MINOR)
                .borderRadius(0.5)
                .offset({ y: -131 })
            }
            .width('100%')
            .height('100%')
            .rotate({ angle: second * 6, centerX: '50%', centerY: '50%' })
          }
        })

        // ═══════════════ 秒针 — 配重尾端 + 细长针体 ═══════════════
        // 配重圆（针尾）
        Circle()
          .width(8)
          .height(8)
          .fill(StopwatchTokens.SECOND_HAND)
          .position({ x: '50%', y: '50%' })
          .translate({ x: -4, y: 14 })

        // 秒针主体
        Rect()
          .width(2)
          .height(120)
          .fill(StopwatchTokens.SECOND_HAND)
          .borderRadius(1)
          .position({ x: '50%', y: '50%' })
          .translate({ x: -1, y: -122 })
          .rotate({
            angle: this.getSecondsAngle(),
            centerX: 1,
            centerY: 122
          })

        // ═══════════════ 中心枢纽 — 双层圆 ═══════════════
        // 外环（透明填充 + 描边）
        Circle()
          .width(18)
          .height(18)
          .fill(Color.Transparent)
          .stroke(this.isRunning
            ? StopwatchTokens.RUNNING_GLOW
            : StopwatchTokens.CENTER_RING)
          .strokeWidth(2.5)
          .position({ x: '50%', y: '50%' })
          .translate({ x: -9, y: -9 })

        // 内实心圆（计时中橙色，暂停蓝色）
        Circle()
          .width(8)
          .height(8)
          .fill(this.isRunning
            ? ColorTokens.ACCENT
            : ColorTokens.PRIMARY)
          .position({ x: '50%', y: '50%' })
          .translate({ x: -4, y: -4 })

        // ═══════════════ 子表盘 — 累计分钟 ═══════════════
        Stack() {
          Circle()
            .width('100%')
            .height('100%')
            .fill(StopwatchTokens.SUBDIAL_FILL)
            .stroke(StopwatchTokens.SUBDIAL_STROKE)
            .strokeWidth(1)

          ForEach([0, 10, 20, 30, 40, 50], (minute: number) => {
            Stack() {
              Rect()
                .width(1.5)
                .height(5)
                .fill(StopwatchTokens.TICK_MINOR)
                .borderRadius(0.75)
                .offset({ y: -28 })
              Text(minute.toString())
                .fontSize(FontTokens.MICRO_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
                .offset({ y: -18 })
                .rotate({ angle: -minute * 6 })
            }
            .width('100%')
            .height('100%')
            .rotate({ angle: minute * 6, centerX: '50%', centerY: '50%' })
          })

          // 分针
          Rect()
            .width(2)
            .height(22)
            .fill(StopwatchTokens.MINUTE_HAND)
            .borderRadius(1)
            .position({ x: '50%', y: '50%' })
            .translate({ x: -1, y: -25 })
            .rotate({
              angle: this.getMinutesAngle(),
              centerX: 1,
              centerY: 32
            })

          // 子表盘中心点
          Circle()
            .width(5)
            .height(5)
            .fill(ColorTokens.PRIMARY)
            .position({ x: '50%', y: '50%' })
            .translate({ x: -2.5, y: -2.5 })
        }
        .width(62)
        .height(62)
        .position({ x: '53%', y: '72%' })
        .translate({ x: -31, y: -31 })

        // ═══════════════ 数字时间 ═══════════════
        Text(this.getDisplayTime())
          .fontSize(FontTokens.HERO_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .fontFamily(FontTokens.FAMILY_MONO)
          .shadow({
            radius: 12,
            color: 'rgba(30,136,229,0.18)',
            offsetX: 0,
            offsetY: 0
          })
          .position({ x: '50%', y: '26%' })
          .translate({ x: '-50%', y: '-50%' })
      }
      .width(StopwatchTokens.CASE_SIZE)
      .height(StopwatchTokens.CASE_SIZE)
      .shadow({
        radius: 32,
        color: 'rgba(0,0,0,0.55)',
        offsetX: 0,
        offsetY: 12
      })
    }
    .width('100%')
    .height(StopwatchTokens.CONTAINER_HEIGHT)
    .alignContent(Alignment.Center)
    .backgroundColor(Color.Transparent)
  }
}
