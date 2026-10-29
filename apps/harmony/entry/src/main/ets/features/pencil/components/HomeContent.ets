/** HomeContent - 首页 Tab 界面体（供 PencilAppShell 与独立注册页复用）。 */
import { MotionTokens, RingTokens } from '../../../common/styles/DesignTokens'
import { DuTokens } from '../../../common/styles/DuTokens'
import { Context } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { HomeState, HomeWeekDayItem } from './states/HomeState'
import { PrototypeTokens } from '../../../common/styles/PrototypeTokens'

@Component
export struct HomeContent {
  // 由 PencilAppShell 传入：打开训练预览全模态。
  // 独立注册页 PencilHomePage 是立即 replaceUrl 到 AppShell 的薄壳，不传此回调。
  onOpenPreview?: () => void
  // 由 PencilAppShell 传入：「开始训练」先过体重记录 gate，确认后才开预览。
  // 与 onOpenPreview 分开，是因为「查看预览」不走 gate（语义是看，不是练）。
  onStartWorkout?: () => void
  // 状态层：由 PencilAppShell 传入。数据态与装载已迁入 HomeState，此处只留 UI 交互态。
  @ObjectLink state: HomeState
  private static readonly CHINESE_FONT_FAMILY: string = 'Noto Sans SC'
  private static readonly NUMBER_FONT_FAMILY: string = 'Inter'
  @State private primaryPressed: boolean = false
  @State private topInsetVp: number = 0
  // 入场错峰：三块分别在 0 / 40 / 80ms 启动，各 320ms 上浮淡入。
  // 与 Android `HomeScreen.kt:114-135` 的 DURATION_ENTER / DURATION_STAGGER 同节奏。
  @State private headIn: number = 0
  @State private todayIn: number = 0
  @State private weekIn: number = 0
  // 环形进度补间的缓动值（0→1）。存「缓动后的完成度」而不是「缓动后的百分比」：
  // 目标百分比会随 state 刷新变化，显示值 = ringEased × 当前目标，动画结束后自动跟随最新数据。
  // 环是自绘 Canvas，内容不会随状态自动重画，故用 @Watch 把每帧的缓动值变化接到重绘上。
  @State @Watch('onRingTick') private ringEased: number = 0
  private ringTimer: number = -1
  private ringCtx: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true))

  async aboutToAppear(): Promise<void> {
    await this.resolveTopInset()
    const context: Context | null = this.contextOrNull()
    if (context !== null) {
      await this.state.refresh(context)
    }
    this.playEntrance()
    this.playRingFill()
  }

  /**
   * 三块错峰上浮淡入。
   *
   * 用 `animateTo` 自带的 `delay` 而不是 `setTimeout`——后者要额外维护 timer 的生命周期
   * （项目约定「销毁时清理 timer/listener」），延迟进场这种一次性动效没必要引入清理负担。
   */
  private playEntrance(): void {
    const enter: number = MotionTokens.DURATION_ENTER
    const stagger: number = MotionTokens.DURATION_STAGGER
    // EASE_ENTER 是 CSS cubic-bezier 字符串（MotionTokens 底部的 string 版），animateTo 直接接受
    this.getUIContext().animateTo({ duration: enter, delay: 0, curve: MotionTokens.EASE_ENTER }, () => {
      this.headIn = 1
    })
    this.getUIContext().animateTo({ duration: enter, delay: stagger, curve: MotionTokens.EASE_ENTER }, () => {
      this.todayIn = 1
    })
    this.getUIContext().animateTo({ duration: enter, delay: stagger * 2, curve: MotionTokens.EASE_ENTER }, () => {
      this.weekIn = 1
    })
  }

  /**
   * 今日卡环形进度：环与中心数字用同一条曲线（EASE_ENTER）在 1200ms 内从 0 走到目标比例。
   *
   * 为什么不用 `animateTo`：`Progress.value` / `Text` 的内容是数据驱动的重绘属性，
   * 不参与属性动画插值（`animateTo` 只会把闭包前后的状态当两个离散快照）。
   * 因此这里逐帧求缓动值——环与数字读同一个 `ringEased`，「同步」由结构保证，而非两条动画的巧合。
   * 节奏与 Android `TodayRing` 的 `animateFloatAsState(DURATION_RING_FILL, EASE_ENTER)` 同值。
   */
  private playRingFill(): void {
    this.stopRingFill()
    const target: number = this.state.weeklyProgressPercent
    if (target <= 0) {
      // 无进度可画：直接置完成态（显示值仍是 0），不必空跑 1.2s 计时器。
      this.ringEased = 1
      return
    }
    const duration: number = MotionTokens.DURATION_RING_FILL
    // 与卡片入场同一错峰：等今日卡开始落位后再起画，避免环在卡片还透明时就画完。
    const delay: number = MotionTokens.DURATION_STAGGER
    const curve: ICurve = MotionTokens.EASE_ENTER_CURVE
    const startedAt: number = Date.now()
    this.ringEased = 0
    this.ringTimer = setInterval(() => {
      const elapsed: number = Date.now() - startedAt - delay
      if (elapsed <= 0) {
        return
      }
      const progress: number = elapsed >= duration ? 1 : elapsed / duration
      this.ringEased = curve.interpolate(progress)
      if (progress >= 1) {
        this.stopRingFill()
      }
    }, 16)
  }

  private stopRingFill(): void {
    if (this.ringTimer !== -1) {
      clearInterval(this.ringTimer)
      this.ringTimer = -1
    }
  }

  /** 环的每帧重绘入口：`ringEased` 变化即重画（Canvas 内容不会随状态自动更新）。 */
  private onRingTick(): void {
    this.drawRing()
  }

  /**
   * 环的分层绘制：玻璃包边 → 轨道 → 远晕 → 近晕 → 主弧。
   *
   * 全部读同一个 `fill`（`ringEased × 目标 / 100`），与中心数字同源——
   * 圆头弧的扫过角度与数字因此天然对应，不依赖两套动画的状态对齐。
   * 光晕用两层更宽的半透明圆弧衰减，而不是 blur：无 GPU 滤镜依赖，安卓侧可同构。
   */
  private drawRing(): void {
    const ctx: CanvasRenderingContext2D = this.ringCtx
    const size: number = RingTokens.SIZE
    const strokeW: number = RingTokens.STROKE
    const c: number = size / 2
    const r: number = (size - strokeW) / 2
    const raw: number = this.ringEased * this.state.weeklyProgressPercent / 100
    const fill: number = raw > 1 ? 1 : raw
    const done: boolean = fill >= RingTokens.DONE_ARC
    const start: number = -Math.PI / 2
    const full: number = Math.PI * 2
    ctx.clearRect(0, 0, size, size)
    ctx.lineCap = 'round'
    // 玻璃包边：环带内外各 1vp 极淡轮廓
    ctx.beginPath()
    ctx.arc(c, c, r, 0, full)
    ctx.lineWidth = RingTokens.GLASS_WIDTH
    ctx.strokeStyle = RingTokens.GLASS
    ctx.stroke()
    // 未完成轨道；达成后淡出，让闭环本身更亮
    ctx.beginPath()
    ctx.arc(c, c, r, 0, full)
    ctx.lineWidth = strokeW
    ctx.strokeStyle = done ? RingTokens.TRACK_DONE : RingTokens.TRACK
    ctx.stroke()
    if (fill < RingTokens.MIN_ARC) {
      // 圆头端帽在 0 附近会留下一个孤立圆点，低于阈值不画弧也不画光晕
      return
    }
    const end: number = start + full * fill
    ctx.beginPath()
    ctx.arc(c, c, r, start, end)
    ctx.lineWidth = RingTokens.GLOW_FAR_WIDTH
    ctx.strokeStyle = done ? RingTokens.GLOW_FAR_DONE : RingTokens.GLOW_FAR
    ctx.stroke()
    ctx.beginPath()
    ctx.arc(c, c, r, start, end)
    ctx.lineWidth = RingTokens.GLOW_NEAR_WIDTH
    ctx.strokeStyle = done ? RingTokens.GLOW_NEAR_DONE : RingTokens.GLOW_NEAR
    ctx.stroke()
    ctx.beginPath()
    ctx.arc(c, c, r, start, end)
    ctx.lineWidth = strokeW
    ctx.strokeStyle = PrototypeTokens.ACCENT
    ctx.stroke()
  }

  /** 中心数字的整数部分：与环共用同一个缓动值，取整显示。 */
  private ringIntegerText(): string {
    return Math.round(this.ringEased * this.state.weeklyProgressPercent).toString()
  }

  aboutToDisappear(): void {
    this.stopRingFill()
  }

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  /** 打开训练预览全模态（由 PencilAppShell 提供）。未注入时静默不响应。 */
  private openPreview(): void {
    if (this.onOpenPreview !== undefined) {
      this.onOpenPreview()
    }
  }

  /** 开始训练：交给壳层的体重 gate。未注入 onStartWorkout 时回落为直接开预览。 */
  private startWorkout(): void {
    if (this.onStartWorkout !== undefined) {
      this.onStartWorkout()
      return
    }
    this.openPreview()
  }

  private async resolveTopInset(): Promise<void> {
    // 原型 .home-content 以屏幕顶为坐标原点（padding-top 53 已把状态栏含在内）；设备侧页面区域
    // 本身就落在状态栏之下，故须从 53 中扣掉状态栏高度，内容才会落在与原型相同的 53vp。
    const context: Context | null = this.contextOrNull()
    if (context === null) {
      return
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(context)
      const avoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topInsetVp = this.getUIContext().px2vp(avoidArea.topRect.height)
    } catch (e) {
      // 取不到安全区时按 0 处理，顶距回退为原型的 53vp
      this.topInsetVp = 0
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(PrototypeTokens.BG_INK)
      Column() {
        Column() {
          Column() {
            Column({ space: 5.4 }) {
              Text(this.state.currentDateText)
                .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
                .fontSize(12.7)
                .fontColor(PrototypeTokens.WHITE_A70)
                .fontWeight(FontWeight.Medium)
                .letterSpacing(0.127)
                .width('100%')
              Text(this.state.greetingText)
                .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
                .fontSize(36.3)
                .lineHeight(43.56)
                .fontWeight(FontWeight.Bold)
                .fontColor(PrototypeTokens.TEXT_HI)
                .width('100%')
            }
            .width('100%')
            .opacity(this.headIn)
            .translate({ y: (1 - this.headIn) * 8 })
            Row()
              .height(19)
            Column() {
              this.todayCard()
            }
            .width('100%')
            .opacity(this.todayIn)
            .translate({ y: (1 - this.todayIn) * 8 })
            Row()
              .height(16)
            Column() {
              this.weekPanel()
            }
            .width('100%')
            .opacity(this.weekIn)
            .translate({ y: (1 - this.weekIn) * 8 })
          }
          .width('100%')
          .padding({
            left: 16,
            right: 16,
            top: Math.max(53 - this.topInsetVp, 0),
            bottom: 36
          })
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, currentRatio: number) => {
        if (isVisible) {
          const ctx: Context | undefined = this.getUIContext().getHostContext()
          if (ctx !== undefined) {
            this.state.refresh(ctx)
          }
        }
      })
    }
    .width('100%')
    .height('100%')
  }
  @Builder
  private todayCard() {
    Column() {
      // 受光玻璃：原型 .today 的 `box-shadow: 0 1px 0 rgba(255,255,255,.05) inset` 是紧贴上边框
      // 内侧的那 1vp 高光。ArkUI 的 .shadow() 不支持 inset，故用一条 1vp 高光行来画。它必须落在
      // 外层 padding 之外才贴得住边框——只放进内容流会被推到 card_top+19vp（设备实测那里有一条
      // 原型没有的横线，而 card_top+1 处缺高光）。用 offset 把它上移 18vp 到边框内侧：布局位置
      // 不变（后续内容仍从 card_top+20vp 起），只改绘制位置。左右沿用 padding 的 18vp 避开圆角。
      Row()
        .width('100%')
        .height(1)
        .backgroundColor(PrototypeTokens.WHITE_A05_ALT)
        .offset({ x: 0, y: -18 })
      Row({ space: 14 }) {
        Column({ space: 8 }) {
          Text('\u4eca\u65e5\u8bad\u7ec3')
            .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
            .fontSize(12.7)
            .lineHeight(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(PrototypeTokens.ACCENT)
            .letterSpacing(0.762)
          Row({ space: 8 }) {
            Text(this.state.todayTitle)
              .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
              .fontSize(22)
              .lineHeight(24.64)
              .fontWeight(FontWeight.Bold)
              .fontColor(PrototypeTokens.TEXT_HI)
            Text('\u63a8\u8350')
              .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
              .fontSize(9)
              .lineHeight(10.8)
              .fontWeight(FontWeight.Bold)
              .letterSpacing(0.18)
              .fontColor(PrototypeTokens.ACCENT)
              .backgroundColor(PrototypeTokens.ACCENT_A12)
              .border({ width: 1, color: '#2B50ECA7' })
              .borderRadius(999)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          }
          Text(this.state.todayMuscleText)
            .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
            .fontSize(12.7)
            .lineHeight(19)
            .fontColor(PrototypeTokens.WHITE_A62)
          Row({ space: 7 }) {
            Stack({ alignContent: Alignment.Center }) {
              Circle({ width: 12, height: 12 })
                .fill(PrototypeTokens.ACCENT_A12)
              Circle({ width: 6, height: 6 })
                .fill(PrototypeTokens.ACCENT)
            }
            .width(12)
            .height(12)
            Text(this.state.todayStatusText)
              .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
              .fontSize(10.9)
              .lineHeight(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(PrototypeTokens.WHITE_A54)
          }
          // 原型 .today-id .day 是 margin-top:9px，而 .label/.title-row/.muscle 都是 8px；
          // 外层 Column space:8 统一了间距，这里补回这 1vp。
          .margin({ top: 1 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Stack({ alignContent: Alignment.Center }) {
          // 原型 .today-ring .outer 的 `filter: drop-shadow(...)` 在浏览器实测渲染不出可见光晕
          // （环外沿起 12vp 内像素恒等于卡片底色），而 ArkUI `.shadow()` 会沿 96×96 矩形铺出方形光框——
          // 两者都不做，光晕改由自绘的双层半透明圆弧表达。
          // 环为自绘 Canvas：`ProgressType.Ring` 的 style 不含 `strokeRadius`（圆头端帽），
          // 平切端头正是这个环原先最显眼的廉价感来源；自绘后包边 / 光晕 / 圆头弧都由同一个 fill 求出。
          // Canvas 内容不随状态自动重画：首帧由 onReady 画，之后由 `@Watch('onRingTick')` 逐帧重绘。
          Canvas(this.ringCtx)
            .width(RingTokens.SIZE)
            .height(RingTokens.SIZE)
            .onReady(() => {
              this.drawRing()
            })
          Column()
            .width(78)
            .height(78)
            .borderRadius(39)
            // 受光玻璃：原型 .today-ring .inner 的 `radial-gradient(120% 120% at 50% 0%, rgba(255,255,255,.06), transparent 52%), var(--ring-inner)`——
            // 内圈顶部受光。小圆内用纵向线性渐变近似该径向顶光。
            .linearGradient({
              angle: 180,
              colors: [
                [PrototypeTokens.WHITE_A06, 0],
                ['#000D1117', 0.52],
                [PrototypeTokens.BG_RING_INNER, 1]
              ]
            })
            .border({ width: 1, color: RingTokens.INNER_BORDER })
            .shadow({ radius: 16, color: 'rgba(0,0,0,0.32)', offsetX: 0, offsetY: 6 })
          Column({ space: 2 }) {
            // 读数分两级：整数保持 19sp Bold 承担读数，`%` 降到 11sp 半透明，不再和数字抢同一层级
            Row({ space: 1 }) {
              Text(this.ringIntegerText())
                .fontFamily(HomeContent.NUMBER_FONT_FAMILY)
                .fontSize(19)
                .fontWeight(FontWeight.Bold)
                .fontColor(PrototypeTokens.TEXT_HI)
                .letterSpacing(-0.38)
              Text('%')
                .fontFamily(HomeContent.NUMBER_FONT_FAMILY)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(PrototypeTokens.TEXT_HI)
                .opacity(0.72)
                .margin({ bottom: 1.5 })
            }
            .alignItems(VerticalAlign.Bottom)
            Text('\u672c\u5468\u8fdb\u5ea6')
              .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
              .fontSize(9.5)
              .fontColor(PrototypeTokens.WHITE_A54)
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width(96)
        .height(96)
        .margin({ top: 4 })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Top)
      Row()
        .height(18)
      Row()
        .width('100%')
        .height(1)
        .linearGradient({ angle: 90, colors: [[PrototypeTokens.WHITE_A00, 0], ['#21FFFFFF', 0.5], [PrototypeTokens.WHITE_A00, 1]] })
      Row()
        .height(16)
      Row({ space: 10 }) {
        this.metric('dumbbell', '\u52a8\u4f5c\u6570', '\u4e2a\u52a8\u4f5c')
        this.metric('clock-3', '\u9884\u8ba1\u7528\u65f6', '\u5206\u949f')
        this.metric('target', '\u76ee\u6807\u808c\u7fa4', '\u4e2a\u808c\u7fa4')
      }
      .width('100%')
      Row()
        .height(16)
      Button('\u5f00\u59cb\u8bad\u7ec3')
        .width('100%')
        .height(40)
        .fontSize(13.6)
        .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
        .fontWeight(FontWeight.Bold)
        .fontColor('#08110D')
        .backgroundColor(PrototypeTokens.ACCENT)
        .borderRadius(20)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.primaryPressed = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.primaryPressed = false
          }
        })
        // Duolingo 硬边厚底：按下时厚边收平 + 整体下沉，替代缩放按压
        .border({
          width: { bottom: this.primaryPressed ? 0 : DuTokens.PRESS_DEPTH },
          color: { bottom: PrototypeTokens.ACCENT_DEEP }
        })
        .translate({ y: this.primaryPressed ? DuTokens.PRESS_SHIFT : 0 })
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
        .padding(0)
        .onClick(() => {
          this.startWorkout()
        })
      Row()
        .height(8)
      Button('\u67e5\u770b\u9884\u89c8')
        .width('100%')
        .height(40)
        .fontSize(13.6)
        .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
        .fontWeight(FontWeight.Medium)
        .fontColor(PrototypeTokens.TEXT_HI)
        .backgroundColor(PrototypeTokens.WHITE_A03)
        .borderRadius(20)
        .padding(0)
        .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
        .onClick(() => {
          this.openPreview()
        })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 19, bottom: 18 })
    .backgroundColor(PrototypeTokens.WHITE_A03)
    .borderRadius(26)
    .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
    .shadow({ radius: 44, color: 'rgba(0,0,0,0.24)', offsetX: 0, offsetY: 22 })
  }

  @Builder
  private weekPanel() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('\u672c\u5468\u8282\u594f')
            .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
            .fontSize(14.5)
            .fontWeight(FontWeight.Bold)
            .fontColor(PrototypeTokens.TEXT_HI)
            .height(22)
          Text('\u5468\u4e00\u2014\u5468\u65e5')
            .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
            .fontSize(10)
            .fontColor(PrototypeTokens.WHITE_A40)
            .height(16)
        }
        Text(this.state.weeklyTrainedCount.toString() + ' / ' + this.state.weeklyPlannedDays.toString() + ' 次')
          .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.ACCENT)
          .height(20)
          .translate({ y: 2 })
      }
      .width('100%')
      .height(40)
      .justifyContent(FlexAlign.SpaceBetween)
      Row()
        .height(18)
      Row({ space: 7 }) {
        ForEach(this.state.weekDays, (item: HomeWeekDayItem) => {
          this.weekDay(item.label, item.dateText, item.isTrained)
        }, (item: HomeWeekDayItem) => item.dateText + '_' + item.label)
      }
      .width('100%')
      .height(78)
    }
    .width('100%')
    .height(168)
    .padding(16)
    .backgroundColor(PrototypeTokens.WHITE_A03)
    .borderRadius(27.2)
    .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
    .shadow({ radius: 36, color: '#24000000', offsetX: 0, offsetY: 18 })
  }

  @Builder
  private metric(iconName: string, label: string, note: string) {
    Column({ space: 5 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (iconName === 'dumbbell') {
          // 原型 <symbol id="i-dumbbell">：5 条 1.8 描边的杠铃线段。
          // 不能用 .fillColor()——它连填充一起改成强调色，未显式 fill="none" 的 path 会被填成实心色块。
          Image($rawfile('pencil-home-metric-dumbbell.svg'))
            .width(20)
            .height(20)
        } else if (iconName === 'clock-3') {
          // 原型 <symbol id="i-clock">：r=8.5 描边圆 + 指针。
          Image($rawfile('pencil-home-metric-clock-3.svg'))
            .width(20)
            .height(20)
        } else {
          // 原型 <symbol id="i-target">：r=8.5 / 4.6 / 1.2 三同心圆，描边 1.8。
          // 24 viewBox 显示到 20vp → 外径 14.17vp、中径 7.67vp、线宽 1.5vp。
          Stack({ alignContent: Alignment.Center }) {
            Circle({ width: 14.17, height: 14.17 })
              .fill(Color.Transparent)
              .stroke(PrototypeTokens.ACCENT)
              .strokeWidth(1.5)
            Circle({ width: 7.67, height: 7.67 })
              .fill(Color.Transparent)
              .stroke(PrototypeTokens.ACCENT)
              .strokeWidth(1.5)
            Circle({ width: 2, height: 2 })
              .fill(PrototypeTokens.ACCENT)
          }
          .width(20)
          .height(20)
        }
      }
      .width(38)
      .height(38)
      .borderRadius(12)
      .backgroundColor(PrototypeTokens.ACCENT_A07)
      .border({ width: 1, color: PrototypeTokens.ACCENT_A12 })
      .margin({ bottom: 2 })
      Text(label)
        .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
        .fontSize(9.8)
        .fontColor(PrototypeTokens.WHITE_A62)
        .width('100%')
        .height(15)
        .textAlign(TextAlign.Center)
      // 数值必须在这里直接读 @State：若放到调用点的实参表达式里
      // （this.metric(a, b, this.todayXxx.toString(), c)），ArkUI 不会把该实参表达式登记为依赖，
      // 这三个数字会永远停在首次渲染的值（设备实测：state 已是 5/3/45，界面长期显示 0）。
      Text(this.state.metricValue(iconName))
        .fontFamily(HomeContent.NUMBER_FONT_FAMILY)
        .fontSize(26)
        .lineHeight(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.TEXT_HI)
        .letterSpacing(-0.52)
        .width('100%')
        .height(26)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(note)
        .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
        .fontSize(8.8)
        .fontColor(PrototypeTokens.WHITE_A54)
        .width('100%')
        .height(15)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private weekDay(day: string, date: string, active: boolean) {
    Column({ space: 8 }) {
      Text(day)
        .fontFamily(HomeContent.CHINESE_FONT_FAMILY)
        .fontSize(10)
        .fontWeight(600)
        .fontColor(active ? PrototypeTokens.TEXT_HI : PrototypeTokens.WHITE_A62)
        .height(14)
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(34)
          .height(34)
          .borderRadius(17)
          .backgroundColor(active ? PrototypeTokens.ACCENT : PrototypeTokens.WHITE_A06)
          .border({ width: 1, color: active ? PrototypeTokens.ACCENT : PrototypeTokens.WHITE_A08 })
          // 受光玻璃：原型 .week-day.active .dot 第一层 `0 0 0 4px var(--accent-12)` 外圈光晕
          .shadow({ radius: active ? 4 : 0, color: active ? PrototypeTokens.ACCENT_A12 : 'rgba(0,0,0,0)', offsetX: 0, offsetY: 0 })
          // 原型 .dot 的 `transition: background/border-color/box-shadow .18s ease`
          .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION })
        if (active) {
          // 原型 .dot::after：11×6 的 border-left+border-bottom 旋转 -45° 的对勾（2px 描边）。
          // 不用 ArkUI Path——其 commands 坐标此处按物理像素解释（width/height 却是 vp），
          // 在 3.38 密度下对勾只有 17×13px 且偏向左上、退化成黑块；改用 SVG 资源，尺寸随 vp 正确缩放。
          Image($rawfile('pencil-home-check.svg'))
            .width(13)
            .height(9)
        }
      }
      .width(34)
      .height(34)
      // 受光玻璃：原型 .week-day.active .dot 第二层 `0 5px 12px rgba(0,0,0,.24)` 下缘投影
      .shadow({
        radius: active ? 12 : 0,
        color: active ? PrototypeTokens.BLACK_A24 : 'rgba(0,0,0,0)',
        offsetX: 0,
        offsetY: active ? 5 : 0
      })
      Text(date)
        .fontFamily(HomeContent.NUMBER_FONT_FAMILY)
        .fontSize(10)
        .fontWeight(600)
        .fontColor(active ? PrototypeTokens.ACCENT : PrototypeTokens.WHITE_A54)
        .height(14)
    }
    .layoutWeight(1)
    .height(78)
    .alignItems(HorizontalAlign.Center)
  }
}

