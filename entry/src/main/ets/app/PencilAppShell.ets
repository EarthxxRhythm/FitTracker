/** PencilAppShell —— 统一持有底部 Tab 与常驻内容视口。功能 #27 */
import { BottomTabBar } from '../components/BottomTabBar'
import { HomeContent } from '../features/pencil/components/HomeContent'
import { PlanContent } from '../features/pencil/components/PlanContent'
import { ReviewContent } from '../features/pencil/components/ReviewContent'
import { ProfileContent } from '../features/pencil/components/ProfileContent'
import { PencilPreviewContent } from '../features/pencil/pages/PencilPreviewPage'
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
  @State private viewportOffset: number = 0
  @State private viewportOpacity: number = 1
  @State private viewportScale: number = 1
  // 常驻 Tab 的「计划」页刷新令牌：切到该 Tab 或从被压栈的页面返回时递增，
  // 触发 PlanContent 重读当前计划（可能在「计划组」里刚被改过）。
  @State private planReloadToken: number = 0
  // 训练预览的全模态开关（bindContentCover）。
  @State private showPreview: boolean = false
  private transitionRunning: boolean = false
  private previousTab: string = PencilTabKey.HOME
  private transitionToken: number = 0

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
      this.planReloadToken += 1
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

  private getTabIndex(key: string): number {
    if (key === PencilTabKey.HOME) {
      return 0
    }
    if (key === PencilTabKey.PLAN) {
      return 1
    }
    if (key === PencilTabKey.REVIEW) {
      return 2
    }
    return 3
  }

  private isVisible(key: string): Visibility {
    return this.currentTab === key ? Visibility.Visible : Visibility.Hidden
  }

  private layer(key: string): number {
    return this.currentTab === key ? 1 : 0
  }

  private handleTabChanged(): void {
    if (this.currentTab === PencilTabKey.PLAN) {
      this.planReloadToken += 1
    }
    const direction: number = this.getTabIndex(this.currentTab) >= this.getTabIndex(this.previousTab) ? 1 : -1
    this.previousTab = this.currentTab
    this.transitionToken += 1
    const currentTransitionToken: number = this.transitionToken
    this.transitionRunning = true
    this.viewportOffset = 8 * direction
    this.viewportOpacity = 0.88
    this.viewportScale = 0.99
    this.getUIContext().animateTo({ duration: 160, curve: MotionTokens.EASE_TAB }, () => {
      if (currentTransitionToken !== this.transitionToken) {
        return
      }
      this.viewportOpacity = 1
      this.viewportScale = 1
      this.viewportOffset = 0
      this.transitionRunning = false
    })
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
        PlanContent({ reloadToken: this.planReloadToken })
      }
      .width('100%')
      .height('100%')
      .visibility(this.isVisible(PencilTabKey.PLAN))
      .zIndex(this.layer(PencilTabKey.PLAN))

      Column() {
        ReviewContent()
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
    .translate({ x: this.viewportOffset, y: 0 })
    .scale({ x: this.viewportScale, y: this.viewportScale })
    .opacity(this.viewportOpacity)
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
