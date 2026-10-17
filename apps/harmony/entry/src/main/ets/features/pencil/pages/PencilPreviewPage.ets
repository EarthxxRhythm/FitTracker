/** PencilPreviewContent —— FitTracker 训练预览内容（依据 fittracker-training-preview.html 还原）。
 *
 * 原为 @Entry 路由页 PencilPreviewPage；现改由 PencilAppShell 的 bindContentCover 以
 * 「中心缩放弹出」的全模态形态承载，故去掉 @Entry 并更名为内容组件（文件路径暂沿用）。
 */

import { Context } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, MotionTokens } from '../../../common/styles/DesignTokens'
import { TrainingPlan, UserGoal } from '../../../shared/models/TrainingModels'
import TrainingPlanService, { UserPlan } from '../../../common/services/TrainingPlanService'
import { WorkoutPreviewExercise, WorkoutPreviewSummary } from '../../../shared/services/WorkoutPreviewService'
import GoalRepository from '../../../shared/services/GoalRepository'
import PlanEngine from '../../../shared/services/PlanEngine'
import WorkoutPreviewService from '../../../shared/services/WorkoutPreviewService'
import { PrototypeTokens } from '../../../common/styles/PrototypeTokens'

interface PreviewExerciseItem {
  name: string
  prescription: string
  current: boolean
}

@Component
export struct PencilPreviewContent {
  @State private backPressed: boolean = false
  @State private morePressed: boolean = false
  @State private ctaPressed: boolean = false
  @State private dayBadge: string = 'Day 01'
  @State private dayTitle: string = '训练预览'
  @State private daySubtitle: string = ''
  @State private exerciseItems: PreviewExerciseItem[] = []
  @State private emptyMessage: string = ''
  @State private topInsetVp: number = 0
  // 由 PencilAppShell 的全模态传入：请求关闭该模态（返回键 / 开始训练后离开）。
  onRequestClose?: () => void
  // 预览结果留存，供「开始训练」把动作数据带给训练执行页（否则执行页拿不到动作名）。
  private pendingPreview: WorkoutPreviewSummary | undefined = undefined

  private requestClose(): void {
    if (this.onRequestClose !== undefined) {
      this.onRequestClose()
    }
  }

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

  /** 进入训练执行页；把预览结果一并带过去，执行页据此显示真实动作名与对应演示图。 */
  private startWorkout(): void {
    // 先关闭全模态（触发缩放淡出），再推入训练执行页，避免模态层盖住执行页。
    this.requestClose()
    if (this.pendingPreview === undefined) {
      this.getUIContext().getRouter().pushUrl({ url: AppRoutes.ACTIVE_WORKOUT })
      return
    }
    this.getUIContext().getRouter().pushUrl({
      url: AppRoutes.ACTIVE_WORKOUT,
      params: { preview: this.pendingPreview }
    })
  }

  private async loadPreview(): Promise<void> {
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.emptyMessage = '暂时无法读取训练目标，请稍后重试'
        return
      }
      // 数据源优先级与「计划」Tab / 首页一致：① 计划组已启用的预置计划 → ② 目标生成计划。
      const current: UserPlan | null = await TrainingPlanService.getCurrentPlan(context)
      let summary: WorkoutPreviewSummary
      if (current !== null) {
        summary = WorkoutPreviewService.createPreviewForCurrentPlan(
          current,
          '',
          TrainingPlanService.getTodayLabel(),
          TrainingPlanService.getTodayTraining(current)
        )
      } else {
        const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
        if (goal === undefined) {
          this.emptyMessage = '尚未设置训练目标，请先完成目标设置'
          return
        }
        const plan: TrainingPlan = PlanEngine.generatePlan(goal)
        const daySeed: number = this.resolveDaySeed()
        summary = WorkoutPreviewService.createPreview(plan, daySeed)
      }
      // 当前计划在休息日不返回具体训练日（dayId 为空），此时不显示误导性的「Day 01」。
      this.dayBadge = summary.dayId.length === 0 ? '' : this.resolveDayBadge(summary.dayId)
      this.dayTitle = summary.title
      this.daySubtitle = summary.scheduleSummary
      this.exerciseItems = this.buildExerciseItems(summary)
      this.pendingPreview = summary
      if (summary.exercises.length === 0) {
        this.emptyMessage = '今天没有训练安排，保持恢复节奏就好'
      } else {
        this.emptyMessage = ''
      }
    } catch (e) {
      this.emptyMessage = '训练预览加载失败，请稍后重试'
    }
  }

  private async resolveTopInset(): Promise<void> {
    const context: Context | null = this.getHostContextOrNull()
    if (context === null) {
      return
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(context)
      const avoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topInsetVp = px2vp(avoidArea.topRect.height)
    } catch (e) {
      // 取不到安全区时按 0 处理，顶距回退为原型的 56vp
      this.topInsetVp = 0
    }
  }

  async aboutToAppear(): Promise<void> {
    // 原型 .pv-content 以屏幕顶为坐标原点（padding-top 56 已把状态栏含在内）；设备侧页面区域
    // 本身就落在状态栏之下，故须从 56 中扣掉状态栏高度，顶栏才会落在与原型相同的 56vp。
    await this.resolveTopInset()
    await this.loadPreview()
  }

  @Builder
  private buildTopBar() {
    Row() {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          // 不用 ArkUI Path——commands 坐标按物理像素解释（width/height 却是 vp），
          // 21vp 的框里箭头只画在约 6×12px 且偏向左上；改用 SVG 资源随 vp 正确缩放。
          Image($rawfile('pencil-preview-nav-back.svg'))
            .width(21)
            .height(21)
        }
        .width(44)
        .height(44)
        .borderRadius(15)
        .backgroundColor(PrototypeTokens.WHITE_A03)
        .border({ width: 1, color: PrototypeTokens.WHITE_A08 })
        .onClick(() => {
          this.requestClose()
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
          .fontColor(PrototypeTokens.TEXT_HI)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Center)
      .layoutWeight(1)

      Stack({ alignContent: Alignment.Center }) {
        Row({ space: 3 }) {
          Circle({ width: 3.6, height: 3.6 }).fill(PrototypeTokens.WHITE_A82)
          Circle({ width: 3.6, height: 3.6 }).fill(PrototypeTokens.WHITE_A82)
          Circle({ width: 3.6, height: 3.6 }).fill(PrototypeTokens.WHITE_A82)
        }
      }
      .width(44)
      .height(44)
      .borderRadius(15)
      .backgroundColor(PrototypeTokens.WHITE_A03)
      .border({ width: 1, color: PrototypeTokens.WHITE_A08 })
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
        .fontColor(PrototypeTokens.ACCENT)
        .letterSpacing(2)

      Text(this.dayTitle)
        .fontFamily('Noto Sans SC')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.TEXT_HI)
        .margin({ top: 8 })

      Text(this.daySubtitle)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(PrototypeTokens.WHITE_A54)
        .margin({ top: 8 })

      Stack({ alignContent: Alignment.Center }) {
        Image($rawfile('pencil-lucide-activity.svg'))
          .width(30)
          .height(30)
          .fillColor(PrototypeTokens.ACCENT)
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .border({ width: 2, color: PrototypeTokens.ACCENT_A30 })
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
      .fontColor(PrototypeTokens.WHITE_A54)
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
        .fontColor(item.current ? PrototypeTokens.TEXT_HI : '#E0FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(item.prescription)
        .fontFamily('Inter')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(item.current ? PrototypeTokens.ACCENT : PrototypeTokens.WHITE_A54)
        .margin({ left: 12 })
    }
    .width('100%')
    .height(52)
    .padding({ left: 14, right: 14 })
    .alignItems(VerticalAlign.Center)
    .borderRadius(16)
    .border({ width: 1, color: item.current ? '#4750ECA7' : '#0EFFFFFF' })
    .backgroundColor(item.current ? PrototypeTokens.ACCENT_A10 : '#07FFFFFF')
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
          .fontColor(PrototypeTokens.WHITE_A54)
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .layoutWeight(1)
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
        .fontColor(PrototypeTokens.WHITE_A54)

      Button('开始训练')
        .width('100%')
        .height(52)
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.TEXT_ON_ACCENT)
        .backgroundColor(ColorTokens.ACCENT_PRIMARY)
        .borderRadius(26)
        .shadow({
          radius: 28,
          color: PrototypeTokens.BLACK_A24,
          offsetX: 0,
          offsetY: 14
        })
        .onClick(() => {
          this.startWorkout()
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

  build() {
    Column() {
      this.buildTopBar()
      this.buildHero()
      this.buildExerciseList()
      this.buildActionSection()
    }
    .width('100%')
    .height('100%')
    .padding({
      left: 18,
      right: 18,
      top: Math.max(56 - this.topInsetVp, 0),
      // 去掉 home indicator 装饰条后，把它原先占的 8vp 间距 + 5vp 条高归还给底部留白，
      // 保持按钮到屏幕底仍为 25vp，手势导航条不会贴到按钮上。
      bottom: 25
    })
    .backgroundColor(PrototypeTokens.BG_INK)
  }
}
