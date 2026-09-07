/** PencilPreviewPage —— FitTracker 训练预览页（依据 fittracker-training-preview.html 还原）。 */

import { Context } from '@kit.AbilityKit'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, MotionTokens } from '../../../common/styles/DesignTokens'
import { TrainingPlan, UserGoal } from '../../../shared/models/TrainingModels'
import { WorkoutPreviewExercise, WorkoutPreviewSummary } from '../../../shared/services/WorkoutPreviewService'
import GoalRepository from '../../../shared/services/GoalRepository'
import PlanEngine from '../../../shared/services/PlanEngine'
import WorkoutPreviewService from '../../../shared/services/WorkoutPreviewService'

interface PreviewExerciseItem {
  name: string
  prescription: string
  current: boolean
}

@Entry
@Component
struct PencilPreviewPage {
  @State private backPressed: boolean = false
  @State private morePressed: boolean = false
  @State private ctaPressed: boolean = false
  @State private dayBadge: string = 'Day 01'
  @State private dayTitle: string = '训练预览'
  @State private daySubtitle: string = ''
  @State private exerciseItems: PreviewExerciseItem[] = []
  @State private emptyMessage: string = ''

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  private resolveDaySeed(): number {
    const now: Date = new Date()
    const startOfYear: Date = new Date(now.getFullYear(), 0, 0)
    const millisPerDay: number = 24 * 60 * 60 * 1000
    const dayOfYear: number = Math.floor((now.getTime() - startOfYear.getTime()) / millisPerDay)
    if (dayOfYear < 1) {
      return 1
    }
    return dayOfYear
  }

  private resolveDayBadge(dayId: string): string {
    const marker: string = 'day_'
    const markerIndex: number = dayId.indexOf(marker)
    if (markerIndex < 0) {
      return 'Day 01'
    }
    const numberText: string = dayId.substring(markerIndex + marker.length)
    const dayNumber: number = Number.parseInt(numberText)
    if (Number.isNaN(dayNumber) || dayNumber < 1) {
      return 'Day 01'
    }
    return 'Day ' + dayNumber.toString().padStart(2, '0')
  }

  private buildExerciseItems(summary: WorkoutPreviewSummary): PreviewExerciseItem[] {
    const items: PreviewExerciseItem[] = []
    for (let index = 0; index < summary.exercises.length; index++) {
      const exercise: WorkoutPreviewExercise = summary.exercises[index]
      const item: PreviewExerciseItem = {
        name: exercise.name,
        prescription: exercise.targetSets.toString() + ' × ' + exercise.targetReps,
        current: index === 0
      }
      items.push(item)
    }
    return items
  }

  private async loadPreview(): Promise<void> {
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.emptyMessage = '暂时无法读取训练目标，请稍后重试'
        return
      }
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
      if (goal === undefined) {
        this.emptyMessage = '尚未设置训练目标，请先完成目标设置'
        return
      }
      const plan: TrainingPlan = PlanEngine.generatePlan(goal)
      const daySeed: number = this.resolveDaySeed()
      const summary: WorkoutPreviewSummary = WorkoutPreviewService.createPreview(plan, daySeed)
      this.dayBadge = this.resolveDayBadge(summary.dayId)
      this.dayTitle = summary.title
      this.daySubtitle = summary.scheduleSummary
      this.exerciseItems = this.buildExerciseItems(summary)
      if (summary.exercises.length === 0) {
        this.emptyMessage = '今天没有训练安排，保持恢复节奏就好'
      } else {
        this.emptyMessage = ''
      }
    } catch (e) {
      this.emptyMessage = '训练预览加载失败，请稍后重试'
    }
  }

  async aboutToAppear(): Promise<void> {
    await this.loadPreview()
  }

  @Builder
  private buildTopBar() {
    Row() {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Path()
            .width(21)
            .height(21)
            .commands('M13.6 4.4 L7.4 10.5 L13.6 16.6')
            .fillOpacity(0)
            .stroke('#D1FFFFFF')
            .strokeWidth(1.8)
            .strokeLineCap(LineCapStyle.Round)
        }
        .width(44)
        .height(44)
        .borderRadius(15)
        .backgroundColor('#08FFFFFF')
        .border({ width: 1, color: '#14FFFFFF' })
        .onClick(() => {
          this.getUIContext().getRouter().back()
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.backPressed = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.backPressed = false
          }
        })
        .scale({ x: this.backPressed ? MotionTokens.PRESS_ICON : 1, y: this.backPressed ? MotionTokens.PRESS_ICON : 1 })
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })

        Text('训练预览')
          .fontFamily('Noto Sans SC')
          .fontSize(17)
          .fontWeight(600)
          .fontColor('#F7FBF8')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Center)
      .layoutWeight(1)

      Stack({ alignContent: Alignment.Center }) {
        Row({ space: 3 }) {
          Circle({ width: 3.6, height: 3.6 }).fill('#D1FFFFFF')
          Circle({ width: 3.6, height: 3.6 }).fill('#D1FFFFFF')
          Circle({ width: 3.6, height: 3.6 }).fill('#D1FFFFFF')
        }
      }
      .width(44)
      .height(44)
      .borderRadius(15)
      .backgroundColor('#08FFFFFF')
      .border({ width: 1, color: '#14FFFFFF' })
      .onClick(() => {
        this.getUIContext().getPromptAction().showToast({ message: '更多选项（原型）' })
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.morePressed = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.morePressed = false
        }
      })
      .scale({ x: this.morePressed ? MotionTokens.PRESS_ICON : 1, y: this.morePressed ? MotionTokens.PRESS_ICON : 1 })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildHero() {
    Column() {
      Text(this.dayBadge)
        .fontFamily('Geist Mono')
        .fontSize(11)
        .fontColor('#50ECA7')
        .letterSpacing(2)

      Text(this.dayTitle)
        .fontFamily('Noto Sans SC')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .margin({ top: 8 })

      Text(this.daySubtitle)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#8AFFFFFF')
        .margin({ top: 8 })

      Stack({ alignContent: Alignment.Center }) {
        Image($rawfile('pencil-lucide-activity.svg'))
          .width(30)
          .height(30)
          .fillColor('#50ECA7')
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .border({ width: 2, color: '#4D50ECA7' })
      .margin({ top: 14 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 16 })
  }

  @Builder
  private buildGroupLabel(text: string, topMargin: number) {
    Text(text)
      .fontFamily('Noto Sans SC')
      .fontSize(12)
      .fontWeight(600)
      .fontColor('#8AFFFFFF')
      .letterSpacing(0.96)
      .padding({ left: 6, right: 6 })
      .margin({ top: topMargin, bottom: 8 })
  }

  @Builder
  private buildExerciseItem(item: PreviewExerciseItem) {
    Row() {
      Text(item.name)
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontWeight(item.current ? 600 : 500)
        .fontColor(item.current ? '#F7FBF8' : '#E0FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(item.prescription)
        .fontFamily('Inter')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(item.current ? '#50ECA7' : '#8AFFFFFF')
        .margin({ left: 12 })
    }
    .width('100%')
    .height(52)
    .padding({ left: 14, right: 14 })
    .alignItems(VerticalAlign.Center)
    .borderRadius(16)
    .border({ width: 1, color: item.current ? '#4750ECA7' : '#0EFFFFFF' })
    .backgroundColor(item.current ? '#1A50ECA7' : '#07FFFFFF')
  }

  @Builder
  private buildExerciseList() {
    Column() {
      if (this.exerciseItems.length > 0) {
        this.buildGroupLabel('主动作', 0)
        Column({ space: 7 }) {
          ForEach(this.exerciseItems, (item: PreviewExerciseItem) => {
            this.buildExerciseItem(item)
          }, (item: PreviewExerciseItem) => item.name)
        }
        .width('100%')
      } else {
        Text(this.emptyMessage.length > 0 ? this.emptyMessage : '暂无训练动作')
          .width('100%')
          .textAlign(TextAlign.Center)
          .fontFamily('Noto Sans SC')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#8AFFFFFF')
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .margin({ top: 16 })
  }

  @Builder
  private buildActionSection() {
    Column({ space: 12 }) {
      Text('确认动作与重量后开始训练')
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontFamily('Noto Sans SC')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#8AFFFFFF')

      Button('开始训练')
        .width('100%')
        .height(52)
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#07100B')
        .backgroundColor(ColorTokens.ACCENT_PRIMARY)
        .borderRadius(26)
        .shadow({
          radius: 28,
          color: '#3D000000',
          offsetX: 0,
          offsetY: 14
        })
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: AppRoutes.ACTIVE_WORKOUT })
        })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.ctaPressed = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.ctaPressed = false
          }
        })
        .scale({ x: this.ctaPressed ? MotionTokens.PRESS_PRIMARY : 1, y: this.ctaPressed ? MotionTokens.PRESS_PRIMARY : 1 })
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
    }
    .width('100%')
    .margin({ top: 16 })
  }

  @Builder
  private buildHomeIndicator() {
    Column() {
      Row()
        .width(134)
        .height(5)
        .borderRadius(3)
        .backgroundColor('#40FFFFFF')
    }
    .width('100%')
    .margin({ top: 8 })
  }

  build() {
    Column() {
      this.buildTopBar()
      this.buildHero()
      this.buildExerciseList()
      this.buildActionSection()
      this.buildHomeIndicator()
    }
    .width('100%')
    .height('100%')
    .padding({
      left: 18,
      right: 18,
      top: 56,
      bottom: 12
    })
    .backgroundColor('#0B0F13')
  }
}
