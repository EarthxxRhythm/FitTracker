/** PlanContent - 计划 Tab 界面体（供 PencilAppShell 与独立注册页复用）。 */

import { AppRoutes } from '../../../app/AppRoutes'
import { MotionTokens } from '../../../common/styles/DesignTokens'
import { window } from '@kit.ArkUI'
import {
  PlanDayItem,
  PlanExerciseItem,
  daySubtitle
} from './PlanTabModel'
import { PlanState } from './states/PlanState'
import { PrototypeTokens } from '../../../common/styles/PrototypeTokens'

/**
 * 当前计划卡（原型 .master-card）高度，单位 vp。
 * 原型 390×844 画布下 `.current-plan{flex:2}` 与 `.today-plan{flex:8}` 分的是
 * 「画布高 - 53(上) - 24(下) - 72(tabbar) - 16(间距)」= 679，卡实高 20% × 679 ≈ 135。
 * 设备上状态栏(39vp)与手势条 inset 会压缩这段可用高度，若继续按 layoutWeight 分，
 * 卡片只剩 ~122vp，底部进度行随之上移 ~13vp，与原型不符；故按原型实高定死，
 * 由下方 deck 区吸收平台差异（计划页整体保持不可滑）。
 */
const PLAN_MASTER_CARD_HEIGHT: number = 135

/**
 * 训练日卡（原型 .deck-card）宽度，单位 vp。
 * 原型 .deck-card 是 left:24px / right:24px（相对 358vp 宽的 .deck）→ 卡宽 310vp；
 * 其相邻卡步长也印证了这个宽度：stepPx() = (deck 宽 − 48) × 0.86 = 310 × 0.86。
 * 设备实现原写死 342vp（左右各 24vp），比原型宽 32vp、两侧留白偏窄。
 */
const PLAN_DECK_CARD_WIDTH: number = 310
/** 卡在 deck Stack 内的左侧起点：原型卡距屏幕 40vp（页边距 16 + deck 内 left 24）− Stack 自身起点 16vp。 */
const PLAN_DECK_CARD_OFFSET_X: number = 24
/** 相邻卡的横向步长（原型 stepPx()）；与卡宽绑定，改宽度须同步。 */
const PLAN_DECK_STEP_X: number = PLAN_DECK_CARD_WIDTH * 0.86

@Component
export struct PlanContent {
  // 数据源优先级不变（见 PlanState）：① 计划组「已启用的预置计划」→ ② 目标生成计划。
  // 数据态与装载已迁入 PlanState（壳 @State 持有，本组件 @ObjectLink 消费），
  // 此处只留 UI 交互态。
  @State private activeCard: number = 0
  @State private masterPressed: boolean = false
  // 系统状态栏高度（vp）。页面区本身落在状态栏之下，原型顶距须扣掉它才不会双计。
  @State private topInsetVp: number = 0
  // 状态层：由 PencilAppShell 传入。数据在 tab 间存活，切回时按需重读（invalidate 置脏）。
  @ObjectLink state: PlanState

  aboutToAppear(): void {
    this.resolveTopInset()
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext !== undefined) {
      this.state.refresh(hostContext)
    }
  }

  /**
   * 原型 .plan-content 的 padding-top: 53 以屏幕顶为原点（已把状态栏含在内）；设备侧页面区本身
   * 落在状态栏之下，若原样使用 53 就与系统避让重复计数，卡片整体下移一个状态栏高度（实测 39vp）。
   * 口径同 HomeContent / PlansContent / PlanGroupDetailContent。
   */
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
      // 取不到安全区时按 0 处理，顶距回退为原型的 53vp
      this.topInsetVp = 0
    }
  }

  private activeDayCaption(): string {
    if (this.state.planDays.length === 0) {
      return '暂无安排'
    }
    const safeIndex: number = Math.min(this.activeCard, this.state.planDays.length - 1)
    return '第 ' + (safeIndex + 1).toString() + ' 天 · ' + this.state.planDays[safeIndex].tag
  }

  private rel(index: number): number {
    return index - this.activeCard
  }

  private opacityFor(rel: number): number {
    const distance: number = Math.abs(rel)
    if (distance <= 1) {
      return 1 - 0.26 * distance
    }
    if (distance < 1.2) {
      return 0.74 * (1 - (distance - 1) / 0.2)
    }
    return 0
  }

  private scaleFor(rel: number): number {
    return 1 - 0.18 * Math.min(Math.abs(rel), 1.2)
  }

  private zFor(rel: number): number {
    return Math.max(1, 100 - Math.abs(rel) * 30)
  }

  private darkenFor(rel: number): number {
    const distance: number = Math.abs(rel)
    if (distance <= 1) {
      return 0.1 * distance
    }
    if (distance < 1.2) {
      return 0.1 + (distance - 1)
    }
    return 0.3
  }

  build() {
    Column() {
      Column({ space: 16 }) {
        this.masterCard()
        Stack({ alignContent: Alignment.TopStart }) {
          ForEach(this.state.planDays, (day: PlanDayItem, index: number) => {
            this.deckCard(day, index)
          }, (day: PlanDayItem) => day.title)
        }
        .width('100%')
        .layoutWeight(1)
        .clip(true)
        .gesture(
          SwipeGesture({ direction: SwipeDirection.Horizontal })
            .onAction((event: GestureEvent) => {
              if (event.angle !== undefined) {
                const horizontal: number = Math.abs(event.angle)
                const isLeft: boolean = horizontal > 90 && horizontal < 270
                if (isLeft && this.activeCard < this.state.planDays.length - 1) {
                  this.activeCard += 1
                } else if (!isLeft && this.activeCard > 0) {
                  this.activeCard -= 1
                }
              }
            })
        )
      }
      .width('100%')
      .height('100%')
      // 原型以屏幕顶为原点；设备页面区已在状态栏下方，扣掉状态栏高度才是与原型一致的 53vp 顶距。
      .padding({
        left: 16,
        right: 16,
        top: Math.max(53 - this.topInsetVp, 0),
        bottom: 24
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PrototypeTokens.BG_INK)
    // Tab 常驻（`visibility` 切换，`aboutToAppear` 只跑一次）：壳切到本 Tab 或从压栈页面返回时
    // 只调 `invalidate()` 置脏；脏标记必须由本组件的可见性变化消费掉，否则数据永远停在首次装载。
    // 口径同 HomeContent。ratios [0,1] 在显隐时可能多次回调，`needRefresh` + 装载并发保护会挡掉重复。
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, currentRatio: number) => {
      if (isVisible) {
        const context: Context | undefined = this.getUIContext().getHostContext()
        if (context !== undefined) {
          this.state.refresh(context)
        }
      }
    })
  }

  @Builder
  private masterCard() {
    Column() {
      Row() {
        Text('当前计划')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.ACCENT)
        Text(this.state.weeklyProgress)
          .fontFamily('Inter')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.ACCENT)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text(this.state.planName)
        .fontFamily('Noto Sans SC')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(PrototypeTokens.TEXT_HI)
        .width('100%')
        .margin({ top: 8 })

      Text(this.state.planMeta)
        .fontFamily('Noto Sans SC')
        .fontSize(11.5)
        .fontColor(PrototypeTokens.WHITE_A62)
        .width('100%')
        .margin({ top: 5 })

      Blank()

      Row({ space: 10 }) {
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(6)
            .backgroundColor('#2450ECA7')
            .borderRadius(999)
          Row()
            .width(this.state.progressPercent.toString() + '%')
            .height(6)
            .backgroundColor(PrototypeTokens.ACCENT)
            .borderRadius(999)
        }
        .layoutWeight(1)
        .height(6)

        Text(this.activeDayCaption())
          .fontFamily('Inter')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(PrototypeTokens.WHITE_A62)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(PLAN_MASTER_CARD_HEIGHT)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    // Card Surface v1（白系玻璃）：底 rgba(255,255,255,.031) + 描边 rgba(255,255,255,.102)。
    // 注意：冻结原型 fittracker-plan.html 的 .master-card 写的是绿系（rgba(80,236,167,.06)/.22），
    // 与原型参考图及 cards.md「不要把所有卡都染绿」相悖，此处按参考图/设计规范取中性。
    .backgroundColor(PrototypeTokens.WHITE_A03)
    .borderRadius(24)
    .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
    .shadow({ radius: 28, color: '#33000000', offsetX: 0, offsetY: 14 })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.masterPressed = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.masterPressed = false
      }
    })
    .scale({ x: this.masterPressed ? MotionTokens.PRESS_ICON : 1, y: this.masterPressed ? MotionTokens.PRESS_ICON : 1 })
    .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({ url: AppRoutes.PLANS })
    })
  }

  @Builder
  private deckCard(day: PlanDayItem, index: number) {
    Stack() {
      // 卡面：Card Surface v1 的观感 = 页面底色(#0B0F13) 叠 3.1% 白玻璃(#08FFFFFF)，实测成色 #13171A。
      // 但 deck 是 prev/front/next 三张叠放，半透明卡面挡不住背后的卡——相邻卡的字与描边会透过当前卡
      // 显示（原型 .deck-card 用不透明 #151B20 才有遮挡）。故这里直接用合成色做不透明卡面：观感与玻璃
      // 卡一致，同时恢复遮挡。圆角须与卡面一致——Stack 未开 clip，直角会从圆角外露出来。
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(24)
        .backgroundColor('#13171A')

      Column() {
        Column({ space: 14 }) {
          Row({ space: 10 }) {
            Text('第 ' + (index + 1).toString() + ' 天 · ' + day.tag)
              .fontFamily('Geist Mono')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(PrototypeTokens.WHITE_A62)
            Text(day.badge)
              .fontFamily('Noto Sans SC')
              .fontSize(10)
              .fontWeight(day.today ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(day.today ? PrototypeTokens.TEXT_ON_ACCENT : PrototypeTokens.WHITE_A62)
              .padding({ left: 9, right: 9, top: 4, bottom: 4 })
              .backgroundColor(day.today ? PrototypeTokens.ACCENT : PrototypeTokens.WHITE_A06)
              .borderRadius(999)
              .border({ width: 1, color: day.today ? PrototypeTokens.WHITE_A00 : PrototypeTokens.WHITE_A06 })
            Blank()
            Stack({ alignContent: Alignment.Center }) {
              Image($rawfile('pencil-lucide-dumbbell.svg'))
                .width(20)
                .height(20)
                .fillColor(PrototypeTokens.ACCENT)
            }
            .width(40)
            .height(40)
            .borderRadius(12)
            .backgroundColor(PrototypeTokens.ACCENT_A10)
            .border({ width: 1, color: '#4050ECA7' })
          }
          .width('100%')

          Text(day.title)
            .fontFamily('Noto Sans SC')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(PrototypeTokens.TEXT_HI)
            .width('100%')

          Text(daySubtitle(day))
            .fontFamily('Noto Sans SC')
            .fontSize(14)
            .fontColor(PrototypeTokens.WHITE_A62)
            .width('100%')
        }
        .width('100%')

        Scroll() {
          Column({ space: 5 }) {
            Text('动作清单')
              .fontFamily('Noto Sans SC')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(PrototypeTokens.WHITE_A54)
              .width('100%')
            ForEach(day.exercises, (exercise: PlanExerciseItem, exerciseIndex: number) => {
              Row({ space: 10 }) {
                Text((exerciseIndex + 1).toString().padStart(2, '0'))
                  .fontFamily('Geist Mono')
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(PrototypeTokens.ACCENT)
                  .width(24)
                Text(exercise.name)
                  .fontFamily('Noto Sans SC')
                  .fontSize(13.5)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(PrototypeTokens.TEXT_HI)
                Text(exercise.muscle)
                  .fontFamily('Noto Sans SC')
                  .fontSize(11)
                  .fontColor(PrototypeTokens.WHITE_A54)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(exercise.sets + ' × ' + exercise.reps)
                  .fontFamily('Inter')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(PrototypeTokens.WHITE_A62)
              }
              .width('100%')
              .height(44)
              .padding({ left: 10, right: 10 })
              .backgroundColor(PrototypeTokens.WHITE_A06)
              .borderRadius(10)
              .alignItems(VerticalAlign.Center)
            }, (exercise: PlanExerciseItem) => exercise.name)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ top: 14 })
        // Scroll 被 layoutWeight 限高后内容不足一屏会垂直居中（faqs-arkui-725），留白被平分成
        // 「清单上方 / 清单下方」各一块。原型 .deck-card 是 space-between，动作清单贴卡片底部、
        // 余量留在标题与清单之间；故用 align(Bottom) 还原原型排布。
        .align(Alignment.Bottom)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .padding(18)

      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(this.darkenFor(this.rel(index)))
        .borderRadius(24)
        .animation({ duration: MotionTokens.DURATION_MARKER, curve: MotionTokens.EASE_MOTION })
    }
    .width(PLAN_DECK_CARD_WIDTH)
    .height('100%')
    // 卡面底色改由卡内首层 Column 承担（叠放场景需用不透明合成色，见 deckCard 顶部注释）。
    .borderRadius(24)
    .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
    .shadow({ radius: 36, color: '#52000000', offsetX: 0, offsetY: 18 })
    .position({ x: PLAN_DECK_CARD_OFFSET_X, y: 0 })
    .translate({ x: this.rel(index) * PLAN_DECK_STEP_X, y: 16 * Math.abs(this.rel(index)) })
    .rotate({ angle: this.rel(index) * 6 })
    .scale({ x: this.scaleFor(this.rel(index)), y: this.scaleFor(this.rel(index)) })
    .opacity(this.opacityFor(this.rel(index)))
    .zIndex(this.zFor(this.rel(index)))
    .animation({ duration: MotionTokens.DURATION_MARKER, curve: MotionTokens.EASE_MOTION })
  }
}

