/** PencilPreviewContent —— FitTracker 训练预览内容（依据 fittracker-training-preview.html 还原）。
 *
 * 原为 @Entry 路由页 PencilPreviewPage；现由 `PencilAppShell.build()` 在根 `Stack` 内以
 * `if (this.showPreview)` 条件渲染，作为盖住底栏的覆盖层（「中心缩放弹出」转场由
 * `TransitionEffect` 声明），故去掉 @Entry 并更名为内容组件（文件路径暂沿用）。
 *
 * 不使用 `bindContentCover`：该方案在本 SDK 的设备实测中不可用。
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
import HomePlanService from '../../../shared/services/HomePlanService'
import WorkoutPreviewService from '../../../shared/services/WorkoutPreviewService'
import { PrototypeTokens } from '../../../common/styles/PrototypeTokens'
import { MotionIntent } from '../../../common/styles/MotionIntent'

interface PreviewExerciseItem {
  name: string
  prescription: string
  current: boolean
}

@Component
export struct PencilPreviewContent {
  @State private closePressed: boolean = false
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
        this.emptyMessage = '暂时无法读取训练计划，请稍后重试'
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
          this.emptyMessage = '尚未启用训练计划，请先到「计划」页选择并启用一套计划'
          return
        }
        const plan: TrainingPlan = PlanEngine.generatePlan(goal)
        // 与首页同口径的目标日种子：预览历史上用「年内第几天」循环选天，
        // 首页用「目标创建至今第几天」，同一个今日训练日两处算出不同的动作清单。
        const daySeed: number = HomePlanService.createDaySeedFromGoal(goal.createdAt, Date.now())
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
      Text('训练预览')
        .fontFamily('Noto Sans SC')
        .fontSize(17)
        .fontWeight(600)
        .fontColor(PrototypeTokens.TEXT_HI)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      // 关闭：纯线条 ×（无底色、无描边、无圆角块）。两根 17×1.8 细条 ±45° 交叉，
      // 跨度 = 17/√2 ≈ 12vp；borderRadius = 线宽/2 得到圆头，与 back 箭头 stroke-linecap:round 同形；
      // 颜色 WHITE_A82 与那支箭头 #FFFFFF@0.82 同值。
      // 触摸区保留 44×44：顶栏高度原本由两颗 44vp 按钮撑开，补足后标题基线不漂移。
      // 按压走弹簧（SPRING_PRESS），不传 duration——springMotion 的时长由物理参数决定。
      // 参数与安卓 WorkoutPreviewScreen 的 CloseButton 逐项对齐。
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(17)
          .height(1.8)
          .borderRadius(0.9)
          .backgroundColor(PrototypeTokens.WHITE_A82)
          .rotate({ angle: 45 })
        Row()
          .width(17)
          .height(1.8)
          .borderRadius(0.9)
          .backgroundColor(PrototypeTokens.WHITE_A82)
          .rotate({ angle: -45 })
      }
      .width(44)
      .height(44)
      .onClick(() => {
        this.requestClose()
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.closePressed = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.closePressed = false
        }
      })
      .scale({
        x: this.closePressed ? MotionIntent.pressScale('close') : 1,
        y: this.closePressed ? MotionIntent.pressScale('close') : 1
      })
      .animation({ curve: MotionIntent.pressSpringCurve() })
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
        // 数据异步加载前后 badge 可能从 'Day 01' 变为空（休息日），预留行高避免 hero 高度跳变。
        .constraintSize({ minHeight: 16 })

      Text(this.dayTitle)
        .fontFamily('Noto Sans SC')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.TEXT_HI)
        .margin({ top: 8 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.daySubtitle)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(PrototypeTokens.WHITE_A54)
        .margin({ top: 8 })
        // 副标题异步到达，首帧为空串；预留一行高度，防止加载完成后把动作清单区顶高。
        .constraintSize({ minHeight: 20 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

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
        // Duolingo 硬边厚底：按下收平 + 下沉，替代缩放按压
        .border({
          width: { bottom: this.ctaPressed ? 0 : MotionTokens.PRESS_DEPTH },
          color: { bottom: PrototypeTokens.ACCENT_DEEP }
        })
        .translate({ y: this.ctaPressed ? MotionTokens.PRESS_SHIFT : 0 })
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
