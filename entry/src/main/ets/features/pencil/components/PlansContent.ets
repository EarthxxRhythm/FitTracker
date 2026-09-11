/** PlansContent —— 计划组列表页界面体（对应 plan-detail.html · screen-plan-detail）。 */
import { AppRoutes } from '../../../app/AppRoutes'
import { MotionTokens } from '../../../common/styles/DesignTokens'

interface GroupCard {
  name: string
  audience: string
  freq: string
  days: number
  examples: string
  icon: string
}

function createGroupCard(name: string, audience: string, freq: string, days: number, examples: string, icon: string): GroupCard {
  return {
    name: name,
    audience: audience,
    freq: freq,
    days: days,
    examples: examples,
    icon: icon
  }
}

@Component
export struct PlansContent {
  @State private backPressed: boolean = false
  @State private pressedCardKey: string = ''

  // 封面 icon 与 HTML `<symbol id="i-*">` 一一对应（layers/activity/zap/dumbbell/target/chevrons-up/down/core/home/heart）。
  private readonly groups: GroupCard[] = [
    createGroupCard('上下肢分裂', '初中级健身者', '4 天 / 周', 4, '杠铃卧推 · 杠铃深蹲 · 引体向上', 'layers'),
    createGroupCard('推拉腿分裂', '初中高级通用', '3-6 天 / 周', 3, '杠铃卧推 · 引体向上 · 杠铃深蹲', 'activity'),
    createGroupCard('全身训练 3x', '初级健身者', '3 天 / 周', 3, '杠铃深蹲 · 杠铃卧推 · 杠铃划船', 'zap'),
    createGroupCard('力量举基础', '力量举入门', '3-4 天 / 周', 4, '杠铃深蹲 · 杠铃卧推 · 杠铃硬拉', 'dumbbell'),
    createGroupCard('胸背分化', '中高级健身者', '4 天 / 周', 4, '杠铃卧推 · 引体向上 · 高位下拉', 'target'),
    createGroupCard('肩臂强化', '初中级健身者', '3 天 / 周', 3, '哑铃侧平举 · 哑铃弯举 · 绳索下压', 'chevrons-up'),
    createGroupCard('下肢力量', '初中高级通用', '3 天 / 周', 3, '杠铃深蹲 · 杠铃硬拉 · 提踵', 'chevrons-down'),
    createGroupCard('核心腰腹', '初级健身者', '3 天 / 周', 3, '卷腹 · 平板支撑 · 悬垂举腿', 'core'),
    createGroupCard('家庭自重', '初级健身者', '3 天 / 周', 3, '俯卧撑 · 自重深蹲 · 平板支撑', 'home'),
    createGroupCard('有氧燃脂', '通用', '3-5 天 / 周', 3, '开合跳 · 高抬腿 · 波比跳', 'heart')
  ]

  private handleBack(): void {
    this.getUIContext().getRouter().back()
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#0B0F13', 0], ['#0A0D12', 1]] })

      Column() {
        Row({ space: 8 }) {
          Row() {
            Path()
              .width(22)
              .height(22)
              .commands('M15 5 L8 12 L15 19')
              .fillOpacity(0)
              .stroke('#B3FFFFFF')
              .strokeWidth(2)
              .strokeLineCap(LineCapStyle.Round)
              .strokeLineJoin(LineJoinStyle.Round)
          }
          .width(40)
          .height(40)
          .borderRadius(12)
          .justifyContent(FlexAlign.Center)
          .scale({ x: this.backPressed ? MotionTokens.PRESS_BACK : 1, y: this.backPressed ? MotionTokens.PRESS_BACK : 1 })
          .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.backPressed = true
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.backPressed = false
            }
          })
          .onClick(() => {
            this.handleBack()
          })
          Text('计划组')
            .fontFamily('Noto Sans SC')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Row()
            .width(40)
            .height(40)
        }
        .width('100%')
        .padding({ top: 52, bottom: 10, left: 12, right: 12 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor('#F50A0D12')
        .border({ width: { bottom: 1 }, color: '#0FFFFFFF' })

        Scroll() {
          Column({ space: 20 }) {
            this.currentCard()

            Column() {
              Text('计划组')
                .fontFamily('Noto Sans SC')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#8AFFFFFF')
                .width('100%')
              Column({ space: 10 }) {
                ForEach(this.groups, (group: GroupCard) => {
                  this.groupCard(group)
                }, (group: GroupCard) => group.name)
              }
              .width('100%')
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 28 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }

  @Builder
  private currentCard() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 0 }) {
        Text('当前计划')
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
        Text('五日增肌计划')
          .fontFamily('Noto Sans SC')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
          .lineHeight(23)
          .margin({ top: 9 })
          .padding({ right: 76 })
        Text('增肌 · 5 练分化 · 6 周推进')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor('#9EFFFFFF')
          .margin({ top: 6 })
      }
      .width('100%')
      .padding({ top: 16, right: 16, bottom: 15, left: 16 })
      .alignItems(HorizontalAlign.Start)

      Text('当前使用')
        .fontFamily('Noto Sans SC')
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor('#07100B')
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor('#50ECA7')
        .borderRadius(999)
        .margin({ top: 14, right: 14 })
    }
    .width('100%')
    .backgroundColor('#1450ECA7')
    .border({ width: 1, color: '#6680ECA7' })
    .borderRadius(20)
    .shadow({ radius: 28, color: '#33000000', offsetX: 0, offsetY: 14 })
  }

  @Builder
  private groupCard(group: GroupCard) {
    Row({ space: 13 }) {
      Row() {
        this.coverIcon(group.icon)
      }
      .width(52)
      .height(52)
      .borderRadius(14)
      .backgroundColor('#1A50ECA7')
      .border({ width: 1, color: '#3850ECA7' })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      Column({ space: 5 }) {
        Text(group.name)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Row({ space: 8 }) {
          Text(group.audience)
            .fontFamily('Noto Sans SC')
            .fontSize(11)
            .fontColor('#9EFFFFFF')
            .padding({ left: 9, right: 9, top: 3, bottom: 3 })
            .backgroundColor('#0FFFFFFF')
            .border({ width: 1, color: '#0FFFFFFF' })
            .borderRadius(999)
          Text(group.freq)
            .fontFamily('Noto Sans SC')
            .fontSize(11)
            .fontColor('#8AFFFFFF')
          Text(group.days.toString() + ' 个训练日')
            .fontFamily('Inter')
            .fontSize(11)
            .fontColor('#8AFFFFFF')
        }
        Text('示例 ' + group.examples)
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#8AFFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Path()
        .width(20)
        .height(20)
        .commands('M9 5 L16 12 L9 19')
        .fillOpacity(0)
        .stroke('#66FFFFFF')
        .strokeWidth(2)
        .strokeLineCap(LineCapStyle.Round)
        .strokeLineJoin(LineJoinStyle.Round)
    }
    .width('100%')
    .padding({ top: 13, right: 14, bottom: 13, left: 14 })
    .backgroundColor('#151B20')
    .border({ width: 1, color: '#14FFFFFF' })
    .borderRadius(18)
    .constraintSize({ minHeight: 92 })
    .scale({ x: this.pressedCardKey === group.name ? MotionTokens.PRESS_PRIMARY : 1, y: this.pressedCardKey === group.name ? MotionTokens.PRESS_PRIMARY : 1 })
    .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedCardKey = group.name
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedCardKey = ''
      }
    })
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({
        url: AppRoutes.PLAN_GROUP_DETAIL,
        params: {
          groupName: group.name,
          groupTags: [group.audience, group.freq, group.days.toString() + ' 个训练日']
        }
      })
    })
  }

  @Builder
  private coverIcon(icon: string) {
    if (icon === 'layers') {
      Path()
        .width(24)
        .height(24)
        .commands('M12 3 L3 8 L12 13 L21 8 Z M3 12 L12 17 L21 12 M3 16 L12 21 L21 16')
        .fillOpacity(0)
        .stroke('#50ECA7')
        .strokeWidth(1.8)
        .strokeLineJoin(LineJoinStyle.Round)
    } else if (icon === 'activity') {
      Path()
        .width(24)
        .height(24)
        .commands('M3 12 H7 L9.5 5 L13.5 19 L16 12 H21')
        .fillOpacity(0)
        .stroke('#50ECA7')
        .strokeWidth(2)
        .strokeLineCap(LineCapStyle.Round)
        .strokeLineJoin(LineJoinStyle.Round)
    } else if (icon === 'zap') {
      Path()
        .width(24)
        .height(24)
        .commands('M13 2.5 L4.5 13.5 H10.5 L9.5 21.5 L19.5 10.5 H13.5 Z')
        .fillOpacity(0)
        .stroke('#50ECA7')
        .strokeWidth(1.8)
        .strokeLineJoin(LineJoinStyle.Round)
    } else if (icon === 'dumbbell') {
      Path()
        .width(24)
        .height(24)
        .commands('M7 7 V17 M17 7 V17 M7 12 H17 M3.5 9 V15 M20.5 9 V15')
        .fillOpacity(0)
        .stroke('#50ECA7')
        .strokeWidth(2)
        .strokeLineCap(LineCapStyle.Round)
    } else if (icon === 'target') {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(16)
          .height(16)
          .fillOpacity(0)
          .stroke('#50ECA7')
          .strokeWidth(1.8)
        Circle()
          .width(6)
          .height(6)
          .fillOpacity(0)
          .stroke('#50ECA7')
          .strokeWidth(1.8)
        Circle()
          .width(1.2)
          .height(1.2)
          .fill('#50ECA7')
      }
      .width(24)
      .height(24)
    } else if (icon === 'chevrons-up') {
      Path()
        .width(24)
        .height(24)
        .commands('M7 14 L12 9 L17 14 M7 19 L12 14 L17 19')
        .fillOpacity(0)
        .stroke('#50ECA7')
        .strokeWidth(2)
        .strokeLineCap(LineCapStyle.Round)
        .strokeLineJoin(LineJoinStyle.Round)
    } else if (icon === 'chevrons-down') {
      Path()
        .width(24)
        .height(24)
        .commands('M7 10 L12 15 L17 10 M7 5 L12 10 L17 5')
        .fillOpacity(0)
        .stroke('#50ECA7')
        .strokeWidth(2)
        .strokeLineCap(LineCapStyle.Round)
        .strokeLineJoin(LineJoinStyle.Round)
    } else if (icon === 'core') {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(16)
          .height(16)
          .fillOpacity(0)
          .stroke('#50ECA7')
          .strokeWidth(1.8)
        Circle()
          .width(4.8)
          .height(4.8)
          .fill('#50ECA7')
      }
      .width(24)
      .height(24)
    } else if (icon === 'home') {
      Path()
        .width(24)
        .height(24)
        .commands('M3.5 10.4 L12 3.5 L20.5 10.4 M5.5 9.5 V20 H18.5 V9.5')
        .fillOpacity(0)
        .stroke('#50ECA7')
        .strokeWidth(1.8)
        .strokeLineCap(LineCapStyle.Round)
        .strokeLineJoin(LineJoinStyle.Round)
    } else {
      // heart（HTML i-heart 的绝对坐标近似）
      Path()
        .width(24)
        .height(24)
        .commands('M12 20 C12 20 5 15.7 5 10.8 A4.2 4.2 0 0 1 12 7.5 A4.2 4.2 0 0 1 19 10.8 C19 15.7 12 20 12 20 Z')
        .fillOpacity(0)
        .stroke('#50ECA7')
        .strokeWidth(1.8)
        .strokeLineJoin(LineJoinStyle.Round)
    }
  }
}
