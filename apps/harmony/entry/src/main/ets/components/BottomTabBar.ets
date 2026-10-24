/**
 * BottomTabBar -- app-level bottom navigation with a highlighted training tab.
 */
import {
  ColorTokens,
  FontTokens,
  IconTokens,
  MotionTokens,
  RadiusTokens,
  ShadowTokens,
  SpacingTokens,
  TouchTokens
} from '../common/styles/DesignTokens'

interface BottomTabItem {
  key: string
  label: string
  highlight: boolean
}

function createBottomTabItem(key: string, label: string, highlight: boolean): BottomTabItem {
  return {
    key: key,
    label: label,
    highlight: highlight
  }
}

/**
 * 五项底部导航。
 *
 * icon / selectedIcon 字段已于图标体系收口时移除：原型
 * design/06_prototype_redraw/src/fittracker-welcome-home.html:927-942 的四个 .tab
 * 内只有 <span>文字</span>，只有中间 .tab-center 带图标位；原字段填了 8 个 iconfont
 * 资源却从未参与绘制（非高亮分支只渲染 Text），是重构残留。
 * 中间键图标固定在 buildWorkoutPrimaryTab 内引用 pencil-tab-workout.svg。
 */
const BOTTOM_TAB_ITEMS: BottomTabItem[] = [
  createBottomTabItem('home', '首页', false),
  createBottomTabItem('plan', '计划', false),
  createBottomTabItem('workout', '', true),
  createBottomTabItem('review', '回顾', false),
  createBottomTabItem('profile', '我的', false)
]

@Preview
@Component
export struct BottomTabBar {
  @Link currentKey: string
  workoutAction?: () => void
  @State private pressedKey: string = ''
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
      Image($rawfile('pencil-tab-workout.svg'))
        .width(IconTokens.SIZE_LG)
        .height(IconTokens.SIZE_LG)
        .fillColor(ColorTokens.TEXT_ON_PRIMARY)
    }
    .width(72)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.isCurrent(item) ? ColorTokens.ACCENT_DEEP : ColorTokens.ACCENT_PRIMARY)
    .borderRadius(RadiusTokens.TAB_ACTIVE)
    .shadow(this.isCurrent(item) ? ShadowTokens.TAB_PILL_ACTIVE : ShadowTokens.TAB_PILL)
    .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
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
                .fontWeight(this.isCurrent(item) ? 600 : FontTokens.NAV_LABEL_WEIGHT)
                .fontColor(this.getLabelColor(item))
                .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
            }
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .layoutWeight(1)
        .height(TouchTokens.TAB_BAR_HEIGHT_HOME)
        .padding(0)
        .backgroundColor('rgba(0,0,0,0)')
        .stateEffect(false) // 禁用 Button 默认按压底色（白/灰块）——按压反馈由自定义 scale 提供
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.pressedKey = item.key
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.pressedKey = ''
          }
        })
        .scale({ x: this.pressedKey === item.key ? MotionTokens.PRESS_TAB_PILL : 1, y: this.pressedKey === item.key ? MotionTokens.PRESS_TAB_PILL : 1 })
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
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
      color: 'rgba(255,255,255,0.05)'
    })
    .shadow(ShadowTokens.NAV)
    .alignItems(VerticalAlign.Center)
  }
}
