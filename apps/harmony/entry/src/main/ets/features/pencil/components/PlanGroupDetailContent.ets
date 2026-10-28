/** PlanGroupDetailContent —— 计划组详细页界面体（对应 plan-group-detail.html · screen-plan-group-detail）。
 *  数据源：TrainingPlanService.getPresetPlanById(planId)；「使用此计划」调用 enablePlan 真正落库。 */
import { MotionTokens } from '../../../common/styles/DesignTokens'
import TrainingPlanService, {
  PresetPlan,
  TrainingDay,
  UserPlan,
  resolveTodayTrainingIndex
} from '../../../common/services/TrainingPlanService'
import { dayFocusMuscles, shortDayTag } from './PlanTabModel'
import { Context } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { PrototypeTokens } from '../../../common/styles/PrototypeTokens'
import PlanProgressService, { PlanProgressSummary } from '../../../shared/services/PlanProgressService'
import WorkoutSessionPersistenceBridgeService from '../../workout/services/WorkoutSessionPersistenceBridgeService'
import { WorkoutSession } from '../../../shared/models/TrainingModels'

interface GroupExercise {
  name: string
  sets: number
  reps: string
  muscle: string
}

interface GroupDay {
  title: string
  focus: string
  exercises: GroupExercise[]
}

function createGroupExercise(name: string, sets: number, reps: string, muscle: string): GroupExercise {
  const item: GroupExercise = {
    name: name,
    sets: sets,
    reps: reps,
    muscle: muscle
  }
  return item
}

function createGroupDay(title: string, focus: string, exercises: GroupExercise[]): GroupDay {
  const item: GroupDay = {
    title: title,
    focus: focus,
    exercises: exercises
  }
  return item
}

@Component
export struct PlanGroupDetailContent {
  // 计划 id（由 PencilPlanGroupDetailPage 从 getParams() 转入）。
  @Prop planId: string = ''

  @State private planName: string = ''
  @State private planDesc: string = ''
  @State private planTags: string[] = []
  @State private days: GroupDay[] = []
  @State private weekCells: string[] = []
  @State private notFound: boolean = false
  @State private isCurrent: boolean = false
  /** 「使用此计划」落库进行中：期间禁用 CTA，避免重复点击。 */
  @State private enabling: boolean = false
  /** 该计划的真实训练进度（由已落库会话按 planId 聚合）；无数据时为零态。 */
  @State private progress: PlanProgressSummary = PlanProgressService.createEmpty('')
  /** 周一→周日 7 格中，哪些格对应的训练日已经练过（与 [weekCells] 同序）。 */
  @State private trainedWeekFlags: boolean[] = [false, false, false, false, false, false, false]
  @State private backPressed: boolean = false
  @State private ctaPressed: boolean = false
  @State private dayKey: string = ''
  @State private exerciseKey: string = ''
  @State private activeDay: number = 0
  @State private toastMessage: string = ''
  @State private toastVisible: boolean = false
  @State private toastTimer: number = -1
  // 系统状态栏高度（vp）。页面区本身落在状态栏之下，原型顶距须扣掉它才不会双计。
  @State private topInsetVp: number = 0

  private readonly dowLabels: string[] = ['一', '二', '三', '四', '五', '六', '日']

  aboutToAppear(): void {
    // 顺序有讲究：loadPlan 的同步段会先把 days 填好，首帧才不会撞上空的 days；
    // 安全区只是顶栏 padding 的修正项，异步到达后重算即可，不能挡在数据加载前面。
    this.loadPlan()
    this.resolveTopInset()
  }

  private async resolveTopInset(): Promise<void> {
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      return
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(hostContext)
      const avoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topInsetVp = this.getUIContext().px2vp(avoidArea.topRect.height)
    } catch (e) {
      // 取不到安全区时按 0 处理，顶距回退为原型的 52vp
      this.topInsetVp = 0
    }
  }

  private async loadPlan(): Promise<void> {
    const plan: PresetPlan | undefined = TrainingPlanService.getPresetPlanById(this.planId)
    if (plan === undefined) {
      this.notFound = true
      return
    }
    this.notFound = false
    this.planName = plan.name
    this.planDesc = plan.description
    this.planTags = [plan.targetAudience, plan.weeklyFrequency, plan.days.length.toString() + ' 个训练日']
    this.days = this.buildDays(plan)
    this.weekCells = this.buildWeekCells(plan)
    // 默认落在今天对应的训练日（与训练预览同一份 resolveTodayTrainingIndex 口径），
    // 打开计划组看到的动作清单就是预览页展示的那天；今天休息时回退到第一天浏览。
    const todayIndex: number = resolveTodayTrainingIndex(plan.days, new Date().getDay())
    this.activeDay = todayIndex >= 0 ? todayIndex : 0
    await this.refreshCurrentState()
    await this.loadProgress(plan)
  }

  /**
   * 加载并聚合本计划的训练进度。
   *
   * 会话里一直有 `planId` / `dayId`，此前没有读取方，计划组因此看不到「练了几次」。
   * 读取失败保持零态，不阻塞页面其余部分。
   */
  private async loadProgress(plan: PresetPlan): Promise<void> {
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      return
    }
    let sessions: WorkoutSession[] = []
    try {
      sessions = await WorkoutSessionPersistenceBridgeService.loadPersistedSessions(hostContext)
    } catch (error) {
      this.progress = PlanProgressService.createEmpty(this.planId)
      this.trainedWeekFlags = [false, false, false, false, false, false, false]
      return
    }
    // 会话里落的是 `UserPlan.id`（`user_plan_<时间戳>`），本页拿到的是预置 id；
    // 当前计划就是本组时把它的 `UserPlan.id` 一并纳入匹配，否则聚合会全部落空。
    const ids: string[] = [this.planId]
    try {
      const current: UserPlan | null = await TrainingPlanService.getCurrentPlan(hostContext)
      if (current !== null && TrainingPlanService.getPresetIdForPlan(current) === this.planId) {
        ids.push(current.id)
      }
    } catch (error) {
      // 读不到当前计划时只按预置 id 匹配（历史数据里两者相等的情况仍然可用）。
    }
    this.progress = PlanProgressService.createSummaryForIds(sessions, this.planId, ids)
    this.trainedWeekFlags = this.buildTrainedWeekFlags(plan, this.progress)
  }

  /** 7 格节奏里每格对应的训练日是否已完成过（同一格可能覆盖多个训练日，任一练过即标记）。 */
  private buildTrainedWeekFlags(plan: PresetPlan, progress: PlanProgressSummary): boolean[] {
    const flags: boolean[] = []
    for (let index = 0; index < 7; index++) {
      const dayNum: number = index === 6 ? 0 : index + 1
      let trained: boolean = false
      for (let dayIndex = 0; dayIndex < plan.days.length; dayIndex++) {
        const week: number[] | undefined = plan.days[dayIndex].dayOfWeek
        if (week === undefined || week.indexOf(dayNum) < 0) {
          continue
        }
        if (PlanProgressService.isDayTrained(progress, this.planDayId(dayIndex))) {
          trained = true
          break
        }
      }
      flags.push(trained)
    }
    return flags
  }

  /**
   * 训练日 id 口径：与 `WorkoutPreviewService.getCurrentPlanDayId` / `HomePlanService` 一致，
   * 会话里落库的就是 `current_plan_day_<序号>`（序号从 1 起）。`TrainingDay` 本身不带 id。
   */
  private planDayId(dayIndex: number): string {
    return 'current_plan_day_' + (dayIndex + 1).toString()
  }

  /** 进度文案：「已练 N 次 · 最近 X」；未训练时为「尚未开始」。 */
  private progressText(): string {
    if (this.progress.totalSessions <= 0) {
      return '尚未开始训练'
    }
    const lastText: string = this.formatLastTrainedAt(this.progress.lastTrainedAt)
    if (lastText.length === 0) {
      return '已练 ' + this.progress.totalSessions.toString() + ' 次'
    }
    return '已练 ' + this.progress.totalSessions.toString() + ' 次 · 最近 ' + lastText
  }

  /** 当前选中训练日的完成次数（`activeDay` 是 `days` 的下标，与 `current_plan_day_<序号>` 同序）。 */
  private activeDaySessionCount(): number {
    return PlanProgressService.sessionCountForDay(this.progress, this.planDayId(this.activeDay))
  }

  private formatLastTrainedAt(timestamp: number): string {
    if (timestamp <= 0) {
      return ''
    }
    const date: Date = new Date(timestamp)
    return (date.getMonth() + 1).toString() + ' 月 ' + date.getDate().toString() + ' 日'
  }

  private buildDays(plan: PresetPlan): GroupDay[] {
    const result: GroupDay[] = []
    for (let dayIndex = 0; dayIndex < plan.days.length; dayIndex++) {
      const day: TrainingDay = plan.days[dayIndex]
      const exercises: GroupExercise[] = []
      for (let exerciseIndex = 0; exerciseIndex < day.exercises.length; exerciseIndex++) {
        const exercise = day.exercises[exerciseIndex]
        exercises.push(createGroupExercise(
          exercise.name,
          exercise.sets,
          exercise.reps,
          exercise.targetMuscle
        ))
      }
      result.push(createGroupDay(day.dayLabel, dayFocusMuscles(day), exercises))
    }
    return result
  }

  /** 周一→周日 7 格节奏：该日若有训练日覆盖则显示该日短标签，否则「休」。 */
  private buildWeekCells(plan: PresetPlan): string[] {
    const cells: string[] = []
    for (let index = 0; index < 7; index++) {
      const dayNum: number = index === 6 ? 0 : index + 1
      let label: string = '休'
      for (let dayIndex = 0; dayIndex < plan.days.length; dayIndex++) {
        const week: number[] | undefined = plan.days[dayIndex].dayOfWeek
        if (week !== undefined && week.indexOf(dayNum) >= 0) {
          label = shortDayTag(plan.days[dayIndex].dayLabel)
          break
        }
      }
      cells.push(label)
    }
    return cells
  }

  private async refreshCurrentState(): Promise<void> {
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      return
    }
    const current: UserPlan | null = await TrainingPlanService.getCurrentPlan(hostContext)
    if (current === null) {
      this.isCurrent = false
      return
    }
    // 按预置身份比较而不是显示名：历史数据里同名的计划副本可能有多份，
    // 用 name 相等会把「已在使用」错标到另一个计划组上（也会误判本组已启用）。
    this.isCurrent = TrainingPlanService.getPresetIdForPlan(current) === this.planId
  }

  private handleBack(): void {
    this.getUIContext().getRouter().back()
  }

  private showToast(message: string): void {
    this.toastMessage = message
    this.toastVisible = true
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
    this.toastTimer = setTimeout(() => {
      this.toastVisible = false
    }, 1600)
  }

  private async usePlan(): Promise<void> {
    if (this.notFound || this.enabling || this.isCurrent) {
      return
    }
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      this.showToast('启用失败：缺少运行环境')
      return
    }
    this.enabling = true
    try {
      const enabled: UserPlan | null = await TrainingPlanService.enablePlan(hostContext, this.planId)
      if (enabled === null) {
        this.showToast('启用失败，请稍后重试')
        return
      }
      // 用落盘后的真实状态回填，而不是无条件置 true：
      // 写入失败时按钮不能停在「当前使用中」，否则用户会以为切换生效了。
      await this.refreshCurrentState()
      if (!this.isCurrent) {
        this.showToast('已启用「' + enabled.name + '」，但保存未完成')
        return
      }
      // 切换成功 → 返回计划组列表：列表页 onPageShow 会重读当前计划，
      // 顶部「当前计划」卡立即反映这次切换，闭环才算走完。
      this.showToast('已切换到「' + enabled.name + '」')
      this.toastTimer = setTimeout(() => {
        this.toastVisible = false
        this.getUIContext().getRouter().back()
      }, 900)
    } finally {
      this.enabling = false
    }
  }

  aboutToDisappear(): void {
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
  }

  private isWeekRest(cell: string): boolean {
    return cell === '休'
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 环境光层：为液态玻璃提供可折射/透出的明暗与色相变化（对应原型 .appshell 的径向光晕）
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['16%', '6%'],
          radius: 320,
          colors: [[PrototypeTokens.ACCENT_A12, 0], [PrototypeTokens.ACCENT_A00, 1]]
        })
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['88%', '78%'],
          radius: 300,
          colors: [['#1645C9A1', 0], ['#0045C9A1', 1]]
        })
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['94%', '16%'],
          radius: 253,
          colors: [['#0E8CEBCC', 0], ['#008CEBCC', 1]]
        })

      Column() {
        this.topBar()

        if (this.notFound) {
          this.emptyState()
        } else if (this.days.length > 0) {
          Scroll() {
            Column({ space: 16 }) {
              this.summaryCard()
              this.rhythmSection()
              this.dayTabs()
              this.dayPanel()
            }
            .width('100%')
            .padding({ top: 16, bottom: 16, left: 16, right: 16 })
          }
          .width('100%')
          .layoutWeight(1)
          // 同 PlansContent：layoutWeight 限高后 Scroll 内容不足一屏会居中，align(Top) 拉回顶部。
          .align(Alignment.Top)
          .scrollBar(BarState.Off)

          this.ctaBar()
        }
      }
      .width('100%')
      .height('100%')

      if (this.toastVisible) {
        Row() {
          Text(this.toastMessage)
            .fontFamily('Noto Sans SC')
            .fontSize(13)
            .fontColor(PrototypeTokens.TEXT_HI)
            .lineHeight(18)
            .textAlign(TextAlign.Center)
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .constraintSize({ maxWidth: 320 })
        .backgroundColor('#F00D1117')
        .borderRadius(999)
        .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
        .margin({ bottom: 88 })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 10 }))
          .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION }))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PrototypeTokens.BG_INK)
  }

  @Builder
  private emptyState() {
    Column({ space: 10 }) {
      Text('未找到该计划')
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.TEXT_HI)
      Text('计划参数缺失或已下线，请返回重新选择。')
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontColor(PrototypeTokens.WHITE_A62)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private topBar() {
    Row({ space: 8 }) {
      Row() {
        // 不用 ArkUI Path——其 commands 坐标按物理像素解释（width/height 却是 vp），
        // 在 3.38 密度下 22vp 的箭头只画出约 4.4×6.5vp 且贴在容器左上；改用 SVG 资源。
        Image($rawfile('pencil-plan-nav-chevron-left.svg'))
          .width(22)
          .height(22)
          .opacity(0.7)
      }
      .width(44)
      .height(44)
      .borderRadius(14)
      .justifyContent(FlexAlign.Center)
      .scale({ x: this.backPressed ? MotionTokens.PRESS_BACK : 1, y: this.backPressed ? MotionTokens.PRESS_BACK : 1 })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.backPressed = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.backPressed = false
        }
      })
      .onClick(() => {
        this.handleBack()
      })

      Text(this.planName)
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.TEXT_HI)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row()
        .width(44)
        .height(44)
    }
    .width('100%')
    .padding({ top: Math.max(52 - this.topInsetVp, 0), bottom: 10, left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#D10A0D12')
    .border({ width: { bottom: 1 }, color: PrototypeTokens.WHITE_A06 })
  }

  @Builder
  private summaryCard() {
    Column() {
      Text('计划组')
        .fontFamily('Noto Sans SC')
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.ACCENT)
        .letterSpacing(0.33)
      Text(this.planName)
        .fontFamily('Noto Sans SC')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .lineHeight(26)
        .fontColor(PrototypeTokens.TEXT_HI)
        .margin({ top: 8 })
        .padding({ right: 8 })
      Text(this.planDesc)
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .lineHeight(21)
        .fontColor(PrototypeTokens.WHITE_A62)
        .margin({ top: 8 })
      Row({ space: 7 }) {
        ForEach(this.planTags, (tag: string) => {
          Text(tag)
            .fontFamily('Noto Sans SC')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(PrototypeTokens.ACCENT)
            .padding({ top: 4, bottom: 4, left: 11, right: 11 })
            .backgroundColor('#2450ECA7')
            .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
            .borderRadius(999)
        }, (tag: string) => tag)
      }
      .width('100%')
      .margin({ top: 12 })
      // 真实训练进度：会话按 planId 聚合，此前计划组完全看不到这层数据。
      Row({ space: 6 }) {
        Image($rawfile('pencil-lucide-dumbbell.svg'))
          .width(14)
          .height(14)
          .fillColor(this.progress.totalSessions > 0 ? PrototypeTokens.ACCENT : PrototypeTokens.WHITE_A40)
        Text(this.progressText())
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor(this.progress.totalSessions > 0 ? PrototypeTokens.ACCENT : PrototypeTokens.WHITE_A54)
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding({ top: 16, bottom: 15, left: 16, right: 16 })
    // Card Surface v1（白系玻璃）：底 rgba(255,255,255,.031) + 描边 rgba(255,255,255,.102)，
    // 与首页「本周节奏」卡（HomeContent.weekPanel）逐值一致。注意：冻结原型
    // fittracker-plan-group-detail.html 的 .pgd-summary 写的是绿系实心 #12241D，此处按需求
    // 取中性玻璃面，属有意偏离（同 PlanContent master card 的先例，原型不手改）。
    .backgroundColor(PrototypeTokens.WHITE_A03)
    .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
    .borderRadius(22)
    .shadow({ radius: 30, color: '#5C000000', offsetX: 0, offsetY: 14 })
  }

  @Builder
  private rhythmSection() {
    Column({ space: 10 }) {
      Text('每周节奏')
        .fontFamily('Noto Sans SC')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.WHITE_A54)
        .letterSpacing(0.24)
      Row({ space: 5 }) {
        ForEach(this.weekCells, (cell: string, index: number) => {
          Column({ space: 6 }) {
            Text(this.dowLabels[index])
              .fontFamily('Noto Sans SC')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(PrototypeTokens.WHITE_A40)
            Column({ space: 2 }) {
              Text(cell)
                .fontFamily('Noto Sans SC')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isWeekRest(cell) ? PrototypeTokens.WHITE_A40 : PrototypeTokens.TEXT_ON_ACCENT)
              // 该训练日已练过：格内加一个「已完成」点，让计划组能看到真实进度。
              if (this.trainedWeekFlags[index] === true) {
                Text('已完成')
                  .fontFamily('Noto Sans SC')
                  .fontSize(8.5)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(PrototypeTokens.TEXT_ON_ACCENT)
                  .opacity(0.82)
              }
            }
            .width('100%')
            .height(34)
            .justifyContent(FlexAlign.Center)
            .borderRadius(10)
            .backgroundColor(this.isWeekRest(cell) ? '#151D1B' : PrototypeTokens.ACCENT)
            .border({
              width: 1,
              color: this.trainedWeekFlags[index] === true && this.isWeekRest(cell) === false
                ? PrototypeTokens.WHITE_A70
                : (this.isWeekRest(cell) ? PrototypeTokens.WHITE_A08 : PrototypeTokens.TRANSPARENT)
            })
            .shadow(this.isWeekRest(cell)
              ? { radius: 0, color: PrototypeTokens.TRANSPARENT, offsetX: 0, offsetY: 0 }
              : { radius: 12, color: PrototypeTokens.ACCENT_A20, offsetX: 0, offsetY: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }, (cell: string, index: number) => index.toString() + cell + (this.trainedWeekFlags[index] ? '-done' : ''))
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private dayTabs() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.days, (day: GroupDay, index: number) => {
          Button({ type: ButtonType.Normal }) {
            Column({ space: 3 }) {
              Text('第 ' + (index + 1).toString() + ' 天')
                .fontFamily('Inter')
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.activeDay === index ? '#A307100B' : PrototypeTokens.WHITE_A54)
              Text(day.title)
                .fontFamily('Noto Sans SC')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.activeDay === index ? PrototypeTokens.TEXT_ON_ACCENT : PrototypeTokens.TEXT_HI)
            }
            // 原型 .pgd-day-tab 是 flex:0 0 auto + min-width:96px——宽度按内容、多个标签并排横向滚动。
            // 这里不能给 Column 设 width('100%')：它会撑满 Scroll 视口，导致只有第一个训练日可见。
            .alignItems(HorizontalAlign.Start)
          }
          .constraintSize({ minWidth: 96 })
          .padding({ top: 10, bottom: 10, left: 12, right: 12 })
          .backgroundColor(this.activeDay === index ? PrototypeTokens.ACCENT : '#141B1A')
          .border({ width: 1, color: this.activeDay === index ? PrototypeTokens.TRANSPARENT : PrototypeTokens.WHITE_A08 })
          .shadow(this.activeDay === index
            ? { radius: 20, color: PrototypeTokens.ACCENT_A24, offsetX: 0, offsetY: 8 }
            : { radius: 0, color: PrototypeTokens.TRANSPARENT, offsetX: 0, offsetY: 0 })
          .borderRadius(14)
          .scale({ x: this.dayKey === day.title ? MotionTokens.PRESS_SHORTCUT : 1, y: this.dayKey === day.title ? MotionTokens.PRESS_SHORTCUT : 1 })
          .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.dayKey = day.title
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.dayKey = ''
            }
          })
          .onClick(() => {
            this.activeDay = index
          })
        }, (day: GroupDay, index: number) => index.toString() + day.title)
      }
      .padding(2)
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  @Builder
  private dayPanel() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text(this.days[this.activeDay].title)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_HI)
        Text(this.days[this.activeDay].focus)
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor(PrototypeTokens.WHITE_A54)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        // 该训练日已练次数（会话按 planId + dayId 聚合）；未练过时不显示。
        if (this.activeDaySessionCount() > 0) {
          Text('已练 ' + this.activeDaySessionCount().toString() + ' 次')
            .fontFamily('Noto Sans SC')
            .fontSize(11)
            .fontColor(PrototypeTokens.ACCENT)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Column({ space: 9 }) {
        ForEach(this.days[this.activeDay].exercises, (exercise: GroupExercise, index: number) => {
          Row({ space: 12 }) {
            Column() {
              Text((index + 1).toString())
                .fontFamily('Inter')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(PrototypeTokens.TEXT_ON_ACCENT)
            }
            .width(28)
            .height(28)
            .justifyContent(FlexAlign.Center)
            .borderRadius(9)
            .backgroundColor(PrototypeTokens.ACCENT)
            .border({ width: 1, color: PrototypeTokens.TRANSPARENT })
            .shadow({ radius: 10, color: PrototypeTokens.ACCENT_A20, offsetX: 0, offsetY: 3 })

            Column({ space: 3 }) {
              Row({ space: 7 }) {
                Text(exercise.name)
                  .fontFamily('Noto Sans SC')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(PrototypeTokens.TEXT_HI)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(exercise.muscle)
                  .fontFamily('Noto Sans SC')
                  .fontSize(10)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(PrototypeTokens.WHITE_A54)
                  .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                  .backgroundColor(PrototypeTokens.WHITE_A06)
                  .border({ width: 1, color: PrototypeTokens.WHITE_A06 })
                  .borderRadius(999)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text(exercise.sets.toString() + ' × ' + exercise.reps)
              .fontFamily('Inter')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(PrototypeTokens.ACCENT_SOFT)
          }
          .width('100%')
          .padding({ top: 12, bottom: 12, left: 13, right: 13 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor('#151B20')
          .border({ width: 1, color: PrototypeTokens.WHITE_A08 })
          .borderRadius(15)
          .scale({ x: this.exerciseKey === exercise.name ? MotionTokens.PRESS_PRIMARY : 1, y: this.exerciseKey === exercise.name ? MotionTokens.PRESS_PRIMARY : 1 })
          .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.exerciseKey = exercise.name
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.exerciseKey = ''
            }
          })
        }, (exercise: GroupExercise, index: number) => index.toString() + exercise.name)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private ctaBar() {
    Column() {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 7 }) {
          Image($rawfile('pencil-plan-cta-check.svg'))
            .width(16)
            .height(16)
          Text(this.isCurrent ? '当前使用中' : (this.enabling ? '启用中…' : '使用此计划'))
            .fontFamily('Noto Sans SC')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isCurrent ? PrototypeTokens.WHITE_A54 : PrototypeTokens.TEXT_ON_ACCENT)
            .letterSpacing(0.15)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height(52)
      .padding(0)
      // 已是当前计划 / 正在落库时置为不可重复点击态，避免重复启用。
      .backgroundColor(this.isCurrent ? PrototypeTokens.WHITE_A10 : PrototypeTokens.ACCENT)
      .borderRadius(16)
      .enabled(!this.isCurrent && !this.enabling)
      // Duolingo 硬边厚底：按下收平 + 下沉，替代缩放按压
      .border({
        width: { bottom: this.ctaPressed ? 0 : MotionTokens.PRESS_DEPTH },
        color: { bottom: PrototypeTokens.ACCENT_DEEP }
      })
      .translate({ y: this.ctaPressed ? MotionTokens.PRESS_SHIFT : 0 })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.ctaPressed = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.ctaPressed = false
        }
      })
      .onClick(() => {
        this.usePlan()
      })
    }
    .width('100%')
    .padding({ top: 12, bottom: 20, left: 16, right: 16 })
    .backgroundColor('#EB0A0D12')
    .border({ width: { top: 1 }, color: PrototypeTokens.WHITE_A06 })
  }
}
