/**
 * BottomTabBar -- app-level bottom navigation with a highlighted training tab.
 */
import {
  ColorTokens,
  FontTokens,
  RadiusTokens,
  ShadowTokens,
  SpacingTokens,
  TouchTokens
} from '../common/styles/DesignTokens'

interface BottomTabItem {
  key: string
  label: string
  highlight: boolean
  icon: Resource
  selectedIcon: Resource
}

function createBottomTabItem(key: string, label: string, highlight: boolean, icon: Resource, selectedIcon: Resource): BottomTabItem {
  return {
    key: key,
    label: label,
    highlight: highlight,
    icon: icon,
    selectedIcon: selectedIcon
  }
}

const BOTTOM_TAB_ITEMS: BottomTabItem[] = [
  createBottomTabItem('home', '首页', false, $rawfile('首页.svg'), $rawfile('首页_选中 .svg')),
  createBottomTabItem('plan', '计划', false, $rawfile('日历.svg'), $rawfile('日历.svg')),
  createBottomTabItem('workout', '', true, $rawfile('pencil-tab-selected.svg'), $rawfile('pencil-tab-selected.svg')),
  createBottomTabItem('review', '回顾', false, $rawfile('闪电.svg'), $rawfile('闪电.svg')),
  createBottomTabItem('profile', '我的', false, $rawfile('我的.svg'), $rawfile('我的_选中.svg'))
]

@Preview
@Component
export struct BottomTabBar {
  @Link currentKey: string
  workoutAction?: () => void
  private isCurrent(item: BottomTabItem): boolean {
    return item.key === this.currentKey
  }

  private getLabelColor(item: BottomTabItem): string {
    if (this.isCurrent(item)) {
      return ColorTokens.NAV_TEXT_ACTIVE
    }
    return ColorTokens.NAV_TEXT_INACTIVE
  }

  private notifyTabChange(item: BottomTabItem): void {
    if (this.isCurrent(item)) {
      return
    }
    this.currentKey = item.key
  }

  @Builder
  private buildWorkoutPrimaryTab(item: BottomTabItem) {
    Row() {
      Image(this.isCurrent(item) ? item.selectedIcon : item.icon)
        .width(24)
        .height(24)
        .fillColor(ColorTokens.TEXT_ON_PRIMARY)
    }
    .width(72)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.isCurrent(item) ? ColorTokens.ACCENT_DEEP : ColorTokens.ACCENT_PRIMARY)
    .borderRadius(RadiusTokens.TAB_ACTIVE)
    .shadow(ShadowTokens.ACCENT)
  }

  build() {
    Row({ space: SpacingTokens.SM }) {
      ForEach(BOTTOM_TAB_ITEMS, (item: BottomTabItem) => {
        Button({ type: ButtonType.Normal }) {
          if (item.highlight) {
            Column() {
              this.buildWorkoutPrimaryTab(item)
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          } else {
            Column() {
              Text(item.label)
                .fontSize(FontTokens.NAV_LABEL_SIZE)
                .lineHeight(FontTokens.NAV_LABEL_LINE_HEIGHT)
                .fontWeight(this.isCurrent(item) ? FontWeight.Bold : FontTokens.NAV_LABEL_WEIGHT)
                .fontColor(this.getLabelColor(item))
            }
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .layoutWeight(1)
        .height(TouchTokens.TAB_BAR_HEIGHT_HOME)
        .padding(0)
        .backgroundColor('rgba(0,0,0,0)')
        .onClick(() => {
          if (item.highlight && this.workoutAction !== undefined) {
            this.workoutAction()
          } else {
            this.notifyTabChange(item)
          }
        })
      }, (item: BottomTabItem) => item.key)
    }
    .width('100%')
    .padding({
      left: SpacingTokens.MD,
      right: SpacingTokens.MD,
      top: SpacingTokens.SM,
      bottom: SpacingTokens.SM
    })
    .backgroundColor(ColorTokens.SURFACE_NAV)
    .border({
      width: { top: 1 },
      color: ColorTokens.BORDER_HAIRLINE
    })
    .shadow(ShadowTokens.NAV)
    .alignItems(VerticalAlign.Center)
  }
}
