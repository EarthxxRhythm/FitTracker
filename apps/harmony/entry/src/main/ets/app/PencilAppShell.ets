/** PencilAppShell —— 统一持有底部 Tab 与常驻内容视口。功能 #27 */
import { BottomTabBar } from '../components/BottomTabBar'
import { HomeContent } from '../features/pencil/components/HomeContent'
import { PlanContent } from '../features/pencil/components/PlanContent'
import { ReviewContent } from '../features/pencil/components/ReviewContent'
import { ProfileContent } from '../features/pencil/components/ProfileContent'
import { PencilPreviewContent } from '../features/pencil/pages/PencilPreviewPage'
import { PlanState } from '../features/pencil/components/states/PlanState'
import { AppRoutes } from './AppRoutes'
import { Context } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { MotionTokens } from '../common/styles/DesignTokens'

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
  @State private planState: PlanState = new PlanState()
  /** 切到「回顾」Tab 时 bump——体重/会话更新后复盘页需重读（Tab 常驻同因）。 */
  @State private reviewReloadToken: number = 0
  // 训练预览的全模态开关。
  @State private showPreview: boolean = false

  async aboutToAppear(): Promise<void> {
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      return
    }
    const mainWindow: window.Window = await window.getLastWindow(hostContext)
    await mainWindow.setWindowLayoutFullScreen(false)
  }

  // 从「计划组」列表/详情等被压栈页面返回时重新显示本页——若当前停在「计划」Tab，
  // 需重读当前计划，否则启用结果不会反映到计划页。
  onPageShow(): void {
    if (this.currentTab === PencilTabKey.PLAN) {
      this.planState.invalidate()
    }
  }

  // 训练预览覆盖层打开时，系统返回键先关闭它，不退出页面。
  onBackPress(): boolean {
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
    if (this.currentTab === PencilTabKey.PLAN) {
      this.planState.invalidate()
    }
    if (this.currentTab === PencilTabKey.REVIEW) {
      this.reviewReloadToken += 1
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
        ReviewContent({ reloadToken: this.reviewReloadToken })
      }
      .width('100%')
      .height('100%')
      .visibility(this.isVisible(PencilTabKey.REVIEW))
      .zIndex(this.layer(PencilTabKey.REVIEW))

      Column() {
        ProfileContent()
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

        BottomTabBar({
          currentKey: $currentTab,
          workoutAction: () => {
            this.showPreview = true
          }
        })
      }
      .width('100%')
      .height('100%')

      if (this.showPreview) {
        // 训练预览「中心缩放弹出」：遮罩淡入 + 内容 0.92 → 1 缩放淡入（关闭时反向）。
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
          TransitionEffect.scale({ x: MotionTokens.MODAL_POP_SCALE, y: MotionTokens.MODAL_POP_SCALE })
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
