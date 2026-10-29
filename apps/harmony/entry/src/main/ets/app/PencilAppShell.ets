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

  @Builder
  private contentViewport() {
    Stack() {
      Column() {
        HomeContent({
          state: this.homeState,
          onStartWorkout: () => {
            this.showWeightGate = true
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
