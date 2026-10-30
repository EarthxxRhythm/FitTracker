/** PencilAppShell —— 统一持有底部 Tab 与常驻内容视口。功能 #27 */
import { BottomTabBar } from '../components/BottomTabBar'
import { HomeContent } from '../features/pencil/components/HomeContent'
import { PlanContent } from '../features/pencil/components/PlanContent'
import { ReviewContent } from '../features/pencil/components/ReviewContent'
import { ProfileContent } from '../features/pencil/components/ProfileContent'
import { PencilPreviewContent } from '../features/pencil/pages/PencilPreviewPage'
import { WeightRecordDialog } from '../features/pencil/components/WeightRecordDialog'
import { PlanState } from '../features/pencil/components/states/PlanState'
import { ProfileState } from '../features/pencil/components/states/ProfileState'
import { HomeState } from '../features/pencil/components/states/HomeState'
import { AppRoutes } from './AppRoutes'
import { Context } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { MotionTokens, SpacingTokens, TouchTokens } from '../common/styles/DesignTokens'
import { PrototypeTokens } from '../common/styles/PrototypeTokens'

/**
 * 「训练进行中」悬浮条底色：沿用训练页 dock 的 rgba(10,13,18,.98)（原型 `.wo-dock`，
 * 见 ActiveContent 同值）。收成命名常量是为了不把裸色值写在 `.backgroundColor()` 实参里
 * （DS-01：内联色值必须走 DesignTokens 或就近命名常量）。
 */
const RESUME_BAR_SURFACE: string = '#FA0A0D12'

enum PencilTabKey {
  HOME = 'home',
  PLAN = 'plan',
  REVIEW = 'review',
  PROFILE = 'profile'
}

@Entry
@Component
export struct PencilAppShell {
  @State @Watch('handleTabChanged') currentTab: string = PencilTabKey.HOME
  // 常驻 Tab 的「计划」页状态层：切到该 Tab 或从被压栈的页面返回时置脏，
  // 触发 PlanContent 按需重读当前计划（可能在「计划组」里刚被改过）。
  @State private homeState: HomeState = new HomeState()
  @State private planState: PlanState = new PlanState()
  @State private profileState: ProfileState = new ProfileState()
  /** 切到「回顾」Tab 时 bump——体重/会话更新后回顾页需重读（Tab 常驻同因）。 */
  @State private reviewReloadToken: number = 0
  // 训练预览覆盖层的开关（条件渲染，不是 bindContentCover）。
  @State private showPreview: boolean = false
  // 「开始训练」前置体重记录弹窗（居中，缩放 + 弹簧进场）。与预览同为壳层覆盖层，
  // 放在壳层而非首页内：底栏中央训练键也要走同一个 gate。
  @State private showWeightGate: boolean = false
  /**
   * 底栏收起态（由回顾页滚动写入，对齐安卓 `FtChromeState`）。
   *
   * 任何 Tab 切换 / 从压栈页返回都必须复位：否则在回顾页滚动收起后切到别的 Tab，
   * 底栏会一直藏着，且没有滚动事件能把它拉回来。
   */
  @State private tabBarCollapsed: boolean = false
  /** 胶囊被按下时的收束量（0→1）：只在「点按 → 进训练页」的 110ms 里非 0。 */
  @State private resumeBarSink: number = 0

  async aboutToAppear(): Promise<void> {
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      return
    }
    const mainWindow: window.Window = await window.getLastWindow(hostContext)
    await mainWindow.setWindowLayoutFullScreen(false)
  }

  // 从「计划组」列表/详情、身体数据、设置等被压栈页面返回时重新显示本页——若当前停在该 Tab，
  // 需重读数据，否则压栈页里的改动不会反映回来。
  //
  // 这里必须「置脏 + 立即重读」，不能只 invalidate：返回时 Tab 内容一直可见，`visibility` 没变化，
  // 不会触发 `*Content` 的 `onVisibleAreaChange`，只置脏就再没有消费者（脏标记会一直挂着）。
  onPageShow(): void {
    const context: Context | undefined = this.getUIContext().getHostContext()
    if (context === undefined) {
      return
    }
    // 与安卓 `FtApp` 的「任何帧切换都 chrome.updateCollapsed(false)」同构。
    this.tabBarCollapsed = false
    // 「首页」和「计划」两个 Tab 都读 getCurrentPlan（计划组里切换后必须一起刷新）。
    // 旧实现按 currentTab 只刷一个：用户从「计划组」切完计划回到另一个 Tab 时，
    // 那个 Tab 仍是旧计划，看起来就像「切换没生效」。
    this.homeState.invalidate()
    this.planState.invalidate()
    this.homeState.refresh(context)
    this.planState.refresh(context)
    if (this.currentTab === PencilTabKey.REVIEW) {
      this.reviewReloadToken += 1
      return
    }
    if (this.currentTab === PencilTabKey.PROFILE) {
      this.profileState.invalidate()
      this.profileState.refresh(context)
    }
  }

  // 训练预览覆盖层打开时，系统返回键先关闭它，不退出页面。
  // 体重 gate 叠在更上层，故先于预览处理。
  onBackPress(): boolean {
    if (this.showWeightGate) {
      this.showWeightGate = false
      return true
    }
    if (this.showPreview) {
      this.showPreview = false
      return true
    }
    return false
  }

  private isVisible(key: string): Visibility {
    return this.currentTab === key ? Visibility.Visible : Visibility.Hidden
  }

  private layer(key: string): number {
    return this.currentTab === key ? 1 : 0
  }

  // Tab 切换不带内容区转场：按需求直接切换（「训练」按钮打开的预览弹层动效保留）。
  private handleTabChanged(): void {
    const context: Context | undefined = this.getUIContext().getHostContext()
    // Tab 间切换一律复位底栏收起态（同安卓 `FtApp.kt:91-99`）。
    this.tabBarCollapsed = false
    if (this.currentTab === PencilTabKey.HOME) {
      this.homeState.invalidate()
      if (context !== undefined) {
        this.homeState.refresh(context)
      }
    }
    if (this.currentTab === PencilTabKey.PLAN) {
      // 只 invalidate 不 refresh 时，脏标记只能等 *Content 的 onVisibleAreaChange 触发；
      // 从常驻 Tab 切回来并不总会抛该回调，计划就会停在旧值。这里直接置脏 + 立即重读。
      this.planState.invalidate()
      if (context !== undefined) {
        this.planState.refresh(context)
      }
    }
    if (this.currentTab === PencilTabKey.REVIEW) {
      this.reviewReloadToken += 1
    }
    if (this.currentTab === PencilTabKey.PROFILE) {
      this.profileState.invalidate()
      if (context !== undefined) {
        this.profileState.refresh(context)
      }
    }
  }

  private selectTab(key: string): void {
    if (key !== this.currentTab) {
      this.currentTab = key
    }
  }

  /** 续练：不带 preview 参数进训练页，由训练页自己从草稿恢复进度与计时。 */
  private openActiveWorkout(): void {
    this.showPreview = false
    this.getUIContext().getRouter().pushUrl({ url: AppRoutes.ACTIVE_WORKOUT })
  }

  /** 底栏当前占位高度（收起 / 体重 gate 时为 0，与 build() 里的高度表达式同源）。 */
  private tabBarHeight(): number {
    if (this.tabBarCollapsed || this.showWeightGate) {
      return 0
    }
    return TouchTokens.TAB_BAR_HEIGHT_HOME + SpacingTokens.SM * 2
  }

  /**
   * 是否显示「训练进行中」悬浮条。
   *
   * 判据只有一条：首页状态层从草稿读出的完成组数 > 0。预览/体重 gate 打开时隐藏——
   * 那两层是覆盖式流程，悬浮条压在上面会遮住它们的底部按钮。
   */
  private hasActiveDraft(): boolean {
    return this.homeState.activeDraftCompletedSets > 0 && !this.showPreview && !this.showWeightGate
  }

  private navigate(route: string): void {
    if (route === AppRoutes.HOME) {
      this.selectTab(PencilTabKey.HOME)
      return
    }
    if (route === AppRoutes.TRAINING_PLAN_DETAIL) {
      this.selectTab(PencilTabKey.PLAN)
      return
    }
    if (route === AppRoutes.REVIEW_HOME) {
      this.selectTab(PencilTabKey.REVIEW)
      return
    }
    if (route === AppRoutes.PROFILE) {
      this.selectTab(PencilTabKey.PROFILE)
      return
    }
    this.getUIContext().getRouter().pushUrl({ url: route })
  }

  /**
   * 「训练进行中」悬浮胶囊。
   *
   * 信息分三层，与训练页的阅读顺序一致（整体 → 当前 → 局部）：
   *   ① 环内 3/12 —— 全场组数计数器。环的角度给比例、环内数字给精确值；
   *      只给数字会丢掉「还剩多少」的直觉，只给环会丢掉「到底几组」。
   *   ② 当前动作名 —— 告诉用户点进去会看到哪个动作（与训练页选中口径同源）。
   *   ③ 第 2 组 / 共 4 组 · 32 分钟 —— 动作内位置 + 已训练时长。
   *
   * 形态：贴底栏上沿、左右各 18 留白；用 Stack 覆盖不参与布局，切 Tab 时不挤内容区。
   * 底色 RESUME_BAR_SURFACE 不透明——半透明会让下面的 Tab 内容透上来，在深色页上读成脏色。
   */
  @Builder
  private resumeWorkoutBar() {
    Column() {
      Row({ space: 12 }) {
        this.resumeRing()

        Column({ space: 3 }) {
          Text(this.resumeExerciseName())
            .fontFamily('Noto Sans SC')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(PrototypeTokens.TEXT_HI)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.resumeBarCaption())
            .fontFamily('Noto Sans SC')
            .fontSize(11)
            .fontColor(PrototypeTokens.WHITE_A54)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 只留一条极淡的箭头提示「可进入」，不放按钮：整条胶囊本身就是点击区
        // （与列表行的 › 同一语汇），加按钮会让它读成「卡片 + 两个操作」。
        Path()
          .width(9)
          .height(14)
          .commands('M2 2 L7 7 L2 12')
          .fill(PrototypeTokens.TRANSPARENT)
          .stroke(PrototypeTokens.WHITE_A40)
          .strokeWidth(1.6)
          .strokeLineCap(LineCapStyle.Round)
          .strokeLineJoin(LineJoinStyle.Round)
      }
      .width('100%')
      .height(68)
      .padding({ left: 14, right: 14 })
      .backgroundColor(RESUME_BAR_SURFACE)
      .borderRadius(20)
      .border({ width: 1, color: PrototypeTokens.WHITE_A10 })
      .shadow({ radius: 24, color: '#7A000000', offsetX: 0, offsetY: 10 })
      .accessibilityText('继续上次训练：' + this.resumeExerciseName() + '，' + this.resumeBarCaption())
      // 点按收束：胶囊压扁下沉淡出，与随后的页面推入连成一拍。
      // 不是「按了没反应突然换屏」——110ms 足够让眼睛把两次变化接成一次。
      .scale({ x: 1 - 0.03 * this.resumeBarSink, y: 1 - 0.08 * this.resumeBarSink })
      .opacity(1 - 0.55 * this.resumeBarSink)
      .translate({ y: 6 * this.resumeBarSink })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
      .onClick(() => {
        this.sinkResumeBarAndOpen()
      })
    }
    .width('100%')
    .padding({ left: 18, right: 18, bottom: 10 })
    // 出现/消失：自底栏方向上浮 28 + 缩放回弹 + 淡入。
    // 从训练页收起回来时，胶囊「长」出来而不是硬切上来，接住上一个动作的注意力。
    .transition(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ y: 28 }))
        .combine(TransitionEffect.scale({ x: 0.92, y: 0.92, centerX: '50%', centerY: '100%' }))
        .animation({ duration: MotionTokens.DURATION_ENTER, curve: MotionTokens.EASE_ENTER_CURVE })
    )
  }

  /** 左侧环形计数器：环角度 = 全场完成比例，环内给精确数字（3 在上、/12 在下）。 */
  @Builder
  private resumeRing() {
    Stack({ alignContent: Alignment.Center }) {
      Progress({
        value: this.homeState.activeDraftCompletedSets,
        total: this.resumeRingTotal(),
        type: ProgressType.Ring
      })
        .width(44)
        .height(44)
        .color(PrototypeTokens.ACCENT)
        .backgroundColor(PrototypeTokens.WHITE_A10)
        .style({ strokeWidth: 3 })
      Column({ space: 0 }) {
        Text(this.homeState.activeDraftCompletedSets.toString())
          .fontFamily('Geist Mono')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(PrototypeTokens.TEXT_HI)
        Text('/' + this.homeState.activeDraftTotalSets.toString())
          .fontFamily('Geist Mono')
          .fontSize(9)
          .fontColor(PrototypeTokens.WHITE_A40)
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width(44)
    .height(44)
  }

  /** Progress 的 total 不能为 0：无草稿总组数时给 1，环退化为空环而不是报错。 */
  private resumeRingTotal(): number {
    return this.homeState.activeDraftTotalSets > 0 ? this.homeState.activeDraftTotalSets : 1
  }

  private resumeExerciseName(): string {
    return this.homeState.activeDraftExerciseName.length > 0
      ? this.homeState.activeDraftExerciseName
      : '训练进行中'
  }

  /**
   * 副行文案。
   *
   * 三种形态互斥：该动作未满 → 「第 N 组 / 共 M 组」；已满 → 「本动作已完成 · 共 M 组」；
   * 拿不到动作组数（旧草稿）→ 退回全局「已做 N 组」。时长只在非 0 时追加。
   */
  private resumeBarCaption(): string {
    const completed: number = this.homeState.activeDraftExerciseCompleted
    const target: number = this.homeState.activeDraftExerciseTarget
    let caption: string = ''
    if (target > 0 && completed >= target) {
      caption = '本动作已完成 · 共 ' + target.toString() + ' 组'
    } else if (target > 0) {
      caption = '第 ' + (completed + 1).toString() + ' 组 / 共 ' + target.toString() + ' 组'
    } else {
      caption = '已做 ' + this.homeState.activeDraftCompletedSets.toString() + ' 组'
    }
    if (this.homeState.activeDraftElapsedMinutes > 0) {
      caption += ' · ' + this.homeState.activeDraftElapsedMinutes.toString() + ' 分钟'
    }
    return caption
  }

  /** 点按胶囊：先收束 110ms 再进训练页，让「按下」与「换页」连成一拍。 */
  private sinkResumeBarAndOpen(): void {
    this.getUIContext().animateTo({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION }, () => {
      this.resumeBarSink = 1
    })
    setTimeout(() => {
      this.resumeBarSink = 0
      this.openActiveWorkout()
    }, MotionTokens.DURATION_PRESS)
  }

  @Builder
  private contentViewport() {
    Stack() {
      Column() {
        HomeContent({
          state: this.homeState,
          onStartWorkout: () => {
            this.showWeightGate = true
          },
          // 续练：不带 preview 参数进训练页，训练页会自己从草稿恢复进度与计时。
          // 与「开始训练」分开是因为它不该过体重 gate——gate 是开新一场前的记账。
          onResumeWorkout: () => {
            this.openActiveWorkout()
          },
          onOpenPreview: () => {
            this.showPreview = true
          }
        })
      }
      .width('100%')
      .height('100%')
      .visibility(this.isVisible(PencilTabKey.HOME))
      .zIndex(this.layer(PencilTabKey.HOME))

      Column() {
        PlanContent({ state: this.planState })
      }
      .width('100%')
      .height('100%')
      .visibility(this.isVisible(PencilTabKey.PLAN))
      .zIndex(this.layer(PencilTabKey.PLAN))

      Column() {
        ReviewContent({
          reloadToken: this.reviewReloadToken,
          onChromeCollapsed: (collapsed: boolean) => {
            this.tabBarCollapsed = collapsed
          }
        })
      }
      .width('100%')
      .height('100%')
      .visibility(this.isVisible(PencilTabKey.REVIEW))
      .zIndex(this.layer(PencilTabKey.REVIEW))

      Column() {
        ProfileContent({ state: this.profileState })
      }
      .width('100%')
      .height('100%')
      .visibility(this.isVisible(PencilTabKey.PROFILE))
      .zIndex(this.layer(PencilTabKey.PROFILE))
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      Column() {
        Column() {
          this.contentViewport()
        }
        .layoutWeight(1)
        .width('100%')
        .clip(true)

        // 底栏收起：高度归零 + 裁剪，内容区是 layoutWeight(1) 会自动长高——
        // 等价于安卓 Scaffold 收缩 `inner`。**不要改用 translate**：平移只改绘制位置，
        // 内容区不会长高，底部会留一条空白死区。
        // 高度由 token 组合，不写死 72（BottomTabBar 内部：8 + 56 + 8）。
        Column() {
          BottomTabBar({
            currentKey: $currentTab,
            workoutAction: () => {
              // 中央训练键与首页「开始训练」同一入口语义：先记体重再进预览。
              this.showWeightGate = true
            }
          })
        }
        .width('100%')
        // 体重 gate 打开时收起主导航栏：面板贴底，底栏必须让位
        .height((this.tabBarCollapsed || this.showWeightGate) ? 0 : TouchTokens.TAB_BAR_HEIGHT_HOME + SpacingTokens.SM * 2)
        .clip(true)
        .animation({ duration: MotionTokens.DURATION_OVERLAY, curve: MotionTokens.EASE_PANEL })
      }
      .width('100%')
      .height('100%')

      // 训练进行中的悬浮入口：贴在底栏上方，跨 Tab 常驻。
      // 与首页卡片内的「继续训练」CTA 不冲突：那个随内容滚动会移出视口，
      // 而「有一场没做完的训练」是需要持续可见的状态，不能滚走就消失。
      if (this.hasActiveDraft()) {
        Column() {
          this.resumeWorkoutBar()
          Row()
            .height(this.tabBarHeight() + 10)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.End)
        // 空白区域不拦截触摸：否则整屏内容（含底栏与 Tab 内容）都点不动
        .hitTestBehavior(HitTestMode.Transparent)
      }

      // 体重记录 gate：压在预览覆盖层之下（先记体重，确认后才开预览）。
      if (this.showWeightGate) {
        WeightRecordDialog({
          onCancel: () => {
            this.showWeightGate = false
          },
          onConfirmed: () => {
            this.showWeightGate = false
            this.showPreview = true
          }
        })
      }

      if (this.showPreview) {
        // 训练预览「缩放弹出」：遮罩淡入 + 内容 0.92 → 1 缩放淡入（关闭时反向）。
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
          .opacity(0.6)
          .transition(TransitionEffect.OPACITY.animation({
            duration: MotionTokens.DURATION_MODAL_SCRIM,
            curve: MotionTokens.EASE_MOTION
          }))

        Column() {
          PencilPreviewContent({
            onRequestClose: () => {
              this.showPreview = false
            }
          })
        }
        .width('100%')
        .height('100%')
        .transition(
          // 缩放锚点钉在底边中点：贴底的「开始训练」按钮在转场全程位置不动，
          // 只有面板上半部向内收拢——旧的中心锚点会让按钮从内缩位置跳到落定位。
          TransitionEffect.scale({
            x: MotionTokens.MODAL_POP_SCALE,
            y: MotionTokens.MODAL_POP_SCALE,
            centerX: '50%',
            centerY: '100%'
          })
            .combine(TransitionEffect.OPACITY)
            .animation({ duration: MotionTokens.DURATION_MODAL_POP, curve: MotionTokens.EASE_PANEL })
        )
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }
}
