/** WorkoutCompletePage - FitTracker workout completion page. */
import { AppRoutes } from '../../../app/AppRoutes'
import { MotionTokens } from '../../../common/styles/DesignTokens'
import WorkoutSessionService from '../../../common/services/WorkoutSessionService'
import WorkoutSessionPersistenceBridgeService from '../../../features/workout/services/WorkoutSessionPersistenceBridgeService'
import WorkoutSummaryService, { WorkoutSummary } from '../../../shared/services/WorkoutSummaryService'
import { WorkoutSession } from '../../../shared/models/TrainingModels'

const STREAK_DAYS: string[] = ['一', '二', '三', '四', '五', '六', '日']

interface ConfettiPiece {
  id: string
  x: number
  y: number
  width: number
  height: number
  rot: number
  color: string
}

const CONFETTI_PIECES: ConfettiPiece[] = [
  { id: 'cf0', x: 24, y: 18, width: 8, height: 14, rot: 18, color: '#50ECA7' },
  { id: 'cf1', x: 66, y: 96, width: 7, height: 12, rot: -24, color: '#8CEBCC' },
  { id: 'cf2', x: 108, y: 42, width: 9, height: 16, rot: 33, color: '#45C9A1' },
  { id: 'cf3', x: 152, y: 128, width: 7, height: 13, rot: -12, color: '#7EF0CB' },
  { id: 'cf4', x: 196, y: 26, width: 8, height: 15, rot: 41, color: '#E6F3FBF7' },
  { id: 'cf5', x: 238, y: 108, width: 9, height: 14, rot: -33, color: '#50ECA7' },
  { id: 'cf6', x: 282, y: 34, width: 7, height: 12, rot: 15, color: '#8CEBCC' },
  { id: 'cf7', x: 322, y: 92, width: 8, height: 15, rot: -21, color: '#45C9A1' },
  { id: 'cf8', x: 356, y: 40, width: 8, height: 13, rot: 28, color: '#7EF0CB' },
  { id: 'cf9', x: 42, y: 178, width: 8, height: 14, rot: -18, color: '#E6F3FBF7' },
  { id: 'cf10', x: 92, y: 234, width: 7, height: 12, rot: 26, color: '#50ECA7' },
  { id: 'cf11', x: 138, y: 288, width: 8, height: 14, rot: -40, color: '#8CEBCC' },
  { id: 'cf12', x: 182, y: 186, width: 9, height: 15, rot: 12, color: '#45C9A1' },
  { id: 'cf13', x: 226, y: 252, width: 7, height: 13, rot: -26, color: '#7EF0CB' },
  { id: 'cf14', x: 270, y: 300, width: 8, height: 14, rot: 36, color: '#E6F3FBF7' },
  { id: 'cf15', x: 312, y: 176, width: 8, height: 15, rot: -14, color: '#50ECA7' },
  { id: 'cf16', x: 352, y: 226, width: 7, height: 12, rot: 22, color: '#8CEBCC' },
  { id: 'cf17', x: 58, y: 320, width: 8, height: 14, rot: -30, color: '#45C9A1' },
  { id: 'cf18', x: 132, y: 356, width: 7, height: 12, rot: 17, color: '#7EF0CB' },
  { id: 'cf19', x: 214, y: 330, width: 8, height: 14, rot: -22, color: '#E6F3FBF7' }
]

@Entry
@Component
export struct WorkoutCompletePage {
  @State private confettiVisible: boolean = true
  @State private badgeScale: number = 0.82
  @State private badgeOpacity: number = 0
  @State private titleOffsetY: number = 14
  @State private titleOpacity: number = 0
  @State private subOffsetY: number = 14
  @State private subOpacity: number = 0
  @State private streakOffsetY: number = 14
  @State private streakOpacity: number = 0
  @State private dockOffsetY: number = 14
  @State private dockOpacity: number = 0
  @State private confettiFall: number = 0
  @State private ctaPressed: boolean = false
  @State private summary: WorkoutSummary = WorkoutSummaryService.createEmptySummary()
  @State private streakCount: number = 0
  @State private weekActiveFlags: boolean[] = [false, false, false, false, false, false, false]
  private confettiTimer: number = -1

  aboutToAppear(): void {
    this.playEntranceAnimations()
    this.loadWorkoutStats()
    this.confettiTimer = setTimeout(() => {
      this.confettiVisible = false
      this.confettiTimer = -1
    }, 3200)
  }

  aboutToDisappear(): void {
    if (this.confettiTimer !== -1) {
      clearTimeout(this.confettiTimer)
      this.confettiTimer = -1
    }
  }

  private playEntranceAnimations(): void {
    this.getUIContext().keyframeAnimateTo(
      { delay: MotionTokens.DELAY_CF_POP },
      [
        {
          duration: 300,
          curve: MotionTokens.EASE_MOTION,
          event: () => {
            this.badgeScale = 1.04
            this.badgeOpacity = 1
          }
        },
        {
          duration: 200,
          curve: MotionTokens.EASE_MOTION,
          event: () => {
            this.badgeScale = 1
            this.badgeOpacity = 1
          }
        }
      ]
    )
    this.getUIContext().animateTo({ duration: MotionTokens.DURATION_CF_RISE_FAST, curve: MotionTokens.EASE_MOTION, delay: 160 }, () => {
      this.titleOffsetY = 0
      this.titleOpacity = 1
    })
    this.getUIContext().animateTo({ duration: MotionTokens.DURATION_CF_RISE_FAST, curve: MotionTokens.EASE_MOTION, delay: 260 }, () => {
      this.subOffsetY = 0
      this.subOpacity = 1
    })
    this.getUIContext().animateTo({ duration: MotionTokens.DURATION_CF_RISE_BASE, curve: MotionTokens.EASE_MOTION, delay: 360 }, () => {
      this.streakOffsetY = 0
      this.streakOpacity = 1
    })
    this.getUIContext().animateTo({ duration: MotionTokens.DURATION_CF_RISE_BASE, curve: MotionTokens.EASE_MOTION, delay: 600 }, () => {
      this.dockOffsetY = 0
      this.dockOpacity = 1
    })
    this.getUIContext().animateTo({ duration: MotionTokens.DURATION_CONFETTI_FALL, curve: MotionTokens.EASE_FALL }, () => {
      this.confettiFall = 520
    })
  }

  private async loadWorkoutStats(): Promise<void> {
    const ctx: Context | undefined = this.getUIContext().getHostContext()
    if (ctx === undefined) {
      this.summary = WorkoutSummaryService.createEmptySummary()
      this.streakCount = 0
      this.weekActiveFlags = []
      return
    }
    try {
      const sessions: WorkoutSession[] = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(ctx)
      if (sessions.length > 0) {
        const latestSession: WorkoutSession = sessions[sessions.length - 1]
        this.summary = WorkoutSummaryService.createSummary(latestSession)
      } else {
        this.summary = WorkoutSummaryService.createEmptySummary()
      }
      const trainingDates: string[] = await WorkoutSessionService.getTrainingDates(ctx)
      this.streakCount = this.computeStreakCount(trainingDates)
      this.weekActiveFlags = this.computeWeekActiveFlags(trainingDates)
    } catch (error) {
      this.summary = WorkoutSummaryService.createEmptySummary()
      this.streakCount = 0
      this.weekActiveFlags = []
    }
  }

  private computeStreakCount(trainingDates: string[]): number {
    const dateSet: Set<string> = new Set<string>()
    trainingDates.forEach((date: string) => {
      dateSet.add(date)
    })
    let cursor: Date = new Date()
    if (!dateSet.has(this.formatDate(cursor))) {
      cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() - 1)
    }
    let count: number = 0
    while (dateSet.has(this.formatDate(cursor))) {
      count++
      cursor = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() - 1)
    }
    return count
  }

  private computeWeekActiveFlags(trainingDates: string[]): boolean[] {
    const dateSet: Set<string> = new Set<string>()
    trainingDates.forEach((date: string) => {
      dateSet.add(date)
    })
    const today: Date = new Date()
    const dayOfWeek: number = today.getDay()
    const mondayOffset: number = dayOfWeek === 0 ? 6 : dayOfWeek - 1
    const monday: Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - mondayOffset)
    const flags: boolean[] = []
    for (let index = 0; index < 7; index++) {
      const day: Date = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + index)
      flags.push(dateSet.has(this.formatDate(day)))
    }
    return flags
  }

  private formatDate(date: Date): string {
    return date.getFullYear().toString() + '-' + this.padTwoDigits(date.getMonth() + 1) + '-' +
      this.padTwoDigits(date.getDate())
  }

  private padTwoDigits(value: number): string {
    if (value < 10) {
      return '0' + value.toString()
    }
    return value.toString()
  }

  private returnHome(): void {
    this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.APP_SHELL })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Scroll() {
          Column() {
            this.completionHero()
            this.streakCard()
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 48, bottom: 48 })
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)

        Column() {
          Button('继续')
            .width('100%')
            .height(52)
            .padding(0)
            .fontFamily('HarmonyOS Sans')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#07100B')
            .backgroundColor('#50ECA7')
            .borderRadius(18)
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.ctaPressed = true
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.ctaPressed = false
              }
            })
            .scale({ x: this.ctaPressed ? MotionTokens.PRESS_PRIMARY : 1, y: this.ctaPressed ? MotionTokens.PRESS_PRIMARY : 1 })
            .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
            .onClick(() => {
              this.returnHome()
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 20 })
        .backgroundColor('#07100F')
        .border({ width: { top: 1 }, color: '#0FFFFFFF' })
        .opacity(this.dockOpacity)
        .translate({ y: this.dockOffsetY })
      }
      .width('100%')
      .height('100%')

      this.confettiLayer()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#07100F')
  }

  @Builder
  private confettiLayer() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(CONFETTI_PIECES, (piece: ConfettiPiece) => {
        Row()
          .width(piece.width)
          .height(piece.height)
          .backgroundColor(piece.color)
          .borderRadius(2)
          .rotate({ angle: piece.rot })
          .translate({ y: this.confettiFall })
          .position({ x: piece.x, y: piece.y })
          .hitTestBehavior(HitTestMode.None)
      }, (piece: ConfettiPiece) => piece.id)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .opacity(this.confettiVisible ? 1 : 0)
    .visibility(this.confettiVisible ? Visibility.Visible : Visibility.Hidden)
    .animation({ duration: 500, curve: Curve.Ease })
  }

  @Builder
  private completionHero() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(102)
          .height(102)
          .borderRadius(51)
          .backgroundColor('#122D28')
          .border({ width: 1, color: '#3B50ECA7' })
        Path()
          .width(80)
          .height(80)
          .commands('M31.04 59.88 L49.28 59.88 M40.16 50.76 L40.16 59.88 M28.76 21.12 L51.56 21.12 L53.84 32.52 C53.84 39.36 49.28 43.92 40.16 43.92 C31.04 43.92 26.48 39.36 26.48 32.52 Z M24.2 21.12 L56.12 21.12 M24.2 32.52 L19.64 32.52 A4.56 4.56 0 0 0 24.2 37.08 M56.12 32.52 L60.68 32.52 A4.56 4.56 0 0 1 56.12 37.08')
          .fillOpacity(0)
          .stroke('#7EF0CB')
          .strokeWidth(4.56)
          .strokeLineCap(LineCapStyle.Round)
          .strokeLineJoin(LineJoinStyle.Round)
      }
      .width(102)
      .height(102)
      .scale({ x: this.badgeScale, y: this.badgeScale })
      .opacity(this.badgeOpacity)

      Text('训练完成')
        .fontFamily('HarmonyOS Sans')
        .fontSize(36)
        .lineHeight(44)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .margin({ top: 26 })
        .opacity(this.titleOpacity)
        .translate({ y: this.titleOffsetY })

      Text('今天的训练已保存，做得很好。')
        .fontFamily('HarmonyOS Sans')
        .fontSize(18)
        .lineHeight(24)
        .fontColor('#B8FFFFFF')
        .textAlign(TextAlign.Center)
        .margin({ top: 10 })
        .opacity(this.subOpacity)
        .translate({ y: this.subOffsetY })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private streakCard() {
    Column({ space: 12 }) {
      Row() {
        Text('训练连续记录')
          .fontFamily('HarmonyOS Sans')
          .fontSize(18)
          .lineHeight(21.6)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text(this.streakCount > 0 ? '连续 ' + this.streakCount.toString() + ' 天' : '开始连续训练')
          .fontFamily('Inter')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        ForEach(STREAK_DAYS, (day: string, index: number) => {
          Column({ space: 6 }) {
            Row()
              .width(28)
              .height(28)
              .backgroundColor(this.weekActiveFlags[index] ? '#50ECA7' : '#14FFFFFF')
              .borderRadius(14)
            Text(day)
              .fontFamily('HarmonyOS Sans')
              .fontSize(11)
              .lineHeight(11)
              .fontColor(this.weekActiveFlags[index] ? '#50ECA7' : '#8AFFFFFF')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }, (day: string) => day)
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#171C23')
    .borderRadius(28)
    .border({ width: 1, color: '#14FFFFFF' })
    .margin({ top: 30 })
    .opacity(this.streakOpacity)
    .translate({ y: this.streakOffsetY })
  }
}
