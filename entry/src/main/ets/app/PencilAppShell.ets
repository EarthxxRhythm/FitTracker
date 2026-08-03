/** PencilAppShell —— 统一持有底部 Tab 与常驻内容视口。功能 #27 */
import { BottomTabBar } from '../components/BottomTabBar'
import { PencilHomeContent } from '../features/pencil/PencilHomePage'
import { PencilPlanContent } from '../features/pencil/PencilPlanPage'
import { PencilReviewContent } from '../features/pencil/PencilReviewPage'
import { PencilProfileContent } from '../features/pencil/PencilProfilePage'
import { PencilActiveContent } from '../features/pencil/PencilActivePage'
import { AppRoutes } from './AppRoutes'

enum PencilTabKey {
  HOME = 'home',
  PLAN = 'plan',
  WORKOUT = 'workout',
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
  private transitionRunning: boolean = false
  private previousTab: string = PencilTabKey.HOME
  private transitionToken: number = 0

  private getTabIndex(key: string): number {
    if (key === PencilTabKey.HOME) {
      return 0
    }
    if (key === PencilTabKey.PLAN) {
      return 1
    }
    if (key === PencilTabKey.WORKOUT) {
      return 2
    }
    if (key === PencilTabKey.REVIEW) {
      return 3
    }
    return 4
  }

  private isVisible(key: string): Visibility {
    return this.currentTab === key ? Visibility.Visible : Visibility.Hidden
  }

  private layer(key: string): number {
    return this.currentTab === key ? 1 : 0
  }

  private handleTabChanged(): void {
    const direction: number = this.getTabIndex(this.currentTab) >= this.getTabIndex(this.previousTab) ? 1 : -1
    this.previousTab = this.currentTab
    this.transitionToken += 1
    const currentTransitionToken: number = this.transitionToken
    this.transitionRunning = true
    this.viewportOffset = 8 * direction
    this.viewportOpacity = 0.88
    this.viewportScale = 0.99
    this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
      if (currentTransitionToken !== this.transitionToken) {
        return
      }
      this.viewportOffset = 0
      this.viewportOpacity = 1
      this.viewportScale = 1
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
    if (route === AppRoutes.ACTIVE_WORKOUT) {
      this.selectTab(PencilTabKey.WORKOUT)
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
        PencilHomeContent()
      }
      .width('100%')
      .height('100%')
      .visibility(this.isVisible(PencilTabKey.HOME))
      .zIndex(this.layer(PencilTabKey.HOME))

      Column() {
        PencilPlanContent()
      }
      .width('100%')
      .height('100%')
      .visibility(this.isVisible(PencilTabKey.PLAN))
      .zIndex(this.layer(PencilTabKey.PLAN))

      Column() {
        PencilActiveContent()
      }
      .width('100%')
      .height('100%')
      .visibility(this.isVisible(PencilTabKey.WORKOUT))
      .zIndex(this.layer(PencilTabKey.WORKOUT))

      Column() {
        PencilReviewContent()
      }
      .width('100%')
      .height('100%')
      .visibility(this.isVisible(PencilTabKey.REVIEW))
      .zIndex(this.layer(PencilTabKey.REVIEW))

      Column() {
        PencilProfileContent()
      }
      .width('100%')
      .height('100%')
      .visibility(this.isVisible(PencilTabKey.PROFILE))
      .zIndex(this.layer(PencilTabKey.PROFILE))
    }
    .width('100%')
    .height('100%')
    .translate({ x: this.viewportOffset, y: 0 })
    .opacity(this.viewportOpacity)
    .scale({ x: this.viewportScale, y: this.viewportScale })
  }

  build() {
    Column() {
      Column() {
        this.contentViewport()
      }
      .layoutWeight(1)
      .width('100%')
      .clip(true)

      BottomTabBar({ currentKey: $currentTab })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }
}
