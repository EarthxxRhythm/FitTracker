/**
 * MainTabBar —— 底部导航栏
 *
 * Tab 项: 训练 | 动作库 | 统计 | 我的
 *
 * 禁止: 修改字号(12sp)、激活色(--color-primary)、非激活色(--color-neutral-300)
 * 固定: 栏高 56vp、图标 24vp
 */
import { ColorTokens, FontTokens, SpacingTokens, TouchTokens } from '../common/styles/DesignTokens'

export interface TabBarItem {
  key: string
  icon: Resource
  activeIcon?: Resource
  label: string
}

@Component
export struct MainTabBar {
  @Link currentTab: string
  @State tabs: TabBarItem[] = [
    { key: 'training', icon: $r('app.media.ic_train'), label: '训练' },
    { key: 'movement', icon: $r('app.media.ic_movement'), label: '动作库' },
    { key: 'stats', icon: $r('app.media.ic_stats'), label: '统计' },
    { key: 'profile', icon: $r('app.media.ic_profile'), label: '我的' }
  ]

  build() {
    Row() {
      ForEach(this.tabs, (tab: TabBarItem) => {
        Column() {
          Image(tab.key === this.currentTab ? (tab.activeIcon ?? tab.icon) : tab.icon)
            .width(TouchTokens.TAB_ICON)
            .height(TouchTokens.TAB_ICON)
            .fillColor(tab.key === this.currentTab
              ? ColorTokens.PRIMARY
              : ColorTokens.NEUTRAL_300)
          Text(tab.label)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(tab.key === this.currentTab
              ? ColorTokens.PRIMARY
              : ColorTokens.NEUTRAL_300)
            .margin({ top: SpacingTokens.XS })
        }
        .layoutWeight(1)
        .onClick(() => { this.currentTab = tab.key })
      })
    }
    .width('100%')
    .height(TouchTokens.TAB_BAR_HEIGHT)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .border({
      width: { top: 0.5 },
      color: ColorTokens.NEUTRAL_100
    })
    .padding({ bottom: SpacingTokens.SM })
  }
}
