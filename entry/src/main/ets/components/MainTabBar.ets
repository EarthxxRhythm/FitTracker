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
  label: string
}

const TAB_SYMBOLS: Record<string, string> = {
  'training': '🏋',
  'movement': '📋',
  'stats': '📊',
  'profile': '👤'
}

@Component
export struct MainTabBar {
  @Link currentTab: string
  @State tabs: TabBarItem[] = [
    { key: 'training', label: '训练' },
    { key: 'movement', label: '动作库' },
    { key: 'stats', label: '统计' },
    { key: 'profile', label: '我的' }
  ]

  build() {
    Row() {
      ForEach(this.tabs, (tab: TabBarItem) => {
        Column() {
          Text(TAB_SYMBOLS[tab.key] || '●')
            .fontSize(20)
            .fontColor(tab.key === this.currentTab
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
