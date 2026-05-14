/**
 * MainTabBar —— 底部导航栏 (5Tab)
 *
 * Tab 项: 首页 | 计划 | 训练 | 数据 | 我的
 * 选中态: 蓝色图标+文字 (#1E88E5)
 * 未选中: 灰色图标+文字
 * 固定: 栏高 56vp, 图标 24vp
 */
import { ColorTokens, FontTokens, SpacingTokens, TouchTokens } from '../common/styles/DesignTokens'
@Component
export struct CompletedRoutableCard {
  @Prop
  symbol: Resource = $r('sys.symbol.label');
  @Prop
  @Require
  title: string;
  @Prop
  @Require
  description: ResourceStr;

  build() {
    
  }
}

@Component
export struct ComponentCard {
  @Prop
  @Require
  title: ResourceStr;
  @Builder
  defaultContent() {
  }
  @BuilderParam content: () => void = this.defaultContent;
  @Builder
  defaultBuilder() {
    // 空实现或默认占位 UI
  }

  @Prop
  description?: ResourceStr;

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(14)
        .fontColor('#666')
      Row({ space: 12}) {
        this.content();
      }
      if (this.description) {
        Text(this.description)
          .backgroundColor('#eee')
          .borderRadius(4)
          .padding(4)
          .fontSize(12)
          .fontColor('#999')
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#fff')
    .borderRadius(12)
    .padding(12)
    .width('100%')
  }
}

export interface TabBarItem {
  key: string
  label: string
}

@Component
export struct CustomTabBar {
  // [Start custom_tab_bar_style]
  @State currentIndex: number = 0;

  @Builder
  tabBuilder(title: ResourceStr, targetIndex: number, selectedImg: Resource, normalImg: Resource) {
    Column() {
      Image(this.currentIndex === targetIndex ? selectedImg : normalImg)
        .size({ width: 25, height: 25 })
      Text(title)
        .fontColor(this.currentIndex === targetIndex ? '#1698CE' : '#6B6B6B')
    }
    .width('100%')
    .height(50)
    .justifyContent(FlexAlign.Center)
  }
  // [End custom_tab_bar_style]

  build() {
    Tabs({ barPosition: BarPosition.End }) {
      // [Start set_custom_tab_bar_style]
      TabContent() {

      }
      // app.string.mine资源文件中的value值为“我的”
      .tabBar(this.tabBuilder('首页', 0, $rawfile('首页_选中 .svg'), $rawfile('首页.svg')))
      // [End set_custom_tab_bar_style]
      TabContent() {
        Text('计划')
          .fontSize(30)
      }
      .backgroundColor(Color.Blue)
      .tabBar(this.tabBuilder('计划',
        1,
        $r('sys.media.ohos_ic_public_web'),
        $rawfile('日历.svg')))

      TabContent() {
        Text('训练')
          .fontSize(30)
      }
      .backgroundColor(Color.Green)
      .tabBar(this.tabBuilder('训练',
        2,
        $rawfile('闪电_选中.svg'),
        $rawfile('闪电.svg')))

      TabContent() {
        Text('动作库')
          .fontSize(30)
      }
      .backgroundColor(Color.Yellow)
      .tabBar(this.tabBuilder('动作库',
        3,
        $rawfile('tab哑铃_选中.svg'),
        $rawfile('tab哑铃.svg')))

      TabContent() {
        Text('我的')
          .fontSize(30)
      }
      .backgroundColor(Color.Orange)
      .tabBar(this.tabBuilder('我的',
        4,
        $rawfile('我的_选中.svg'),
        $rawfile('我的.svg')))
    }
    .height(500)
    .onChange((index: number) => {
      this.currentIndex = index; // 监听索引index的变化，实现页签内容的切换。
    })
  }
}
