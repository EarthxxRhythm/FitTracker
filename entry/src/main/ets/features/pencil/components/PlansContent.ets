/** PlansContent —— 计划组列表页界面体（对应 plan-detail.html · screen-plan-detail）。 */
import { MotionTokens } from '../../../common/styles/DesignTokens'
import { AppRoutes } from '../../../app/AppRoutes'

interface GroupCard {
  name: string
  audience: string
  freq: string
  days: number
  examples: string
}

function createGroupCard(name: string, audience: string, freq: string, days: number, examples: string): GroupCard {
  return {
    name: name,
    audience: audience,
    freq: freq,
    days: days,
    examples: examples
  }
}

@Component
export struct PlansContent {
  @State private backPressed: boolean = false
  @State private pressedCardKey: string = ''
  @State private toastVisible: boolean = false
  @State private toastText: string = ''
  @State private toastTimer: number = -1

  private readonly groups: GroupCard[] = [
    createGroupCard('上下肢分裂', '初中级健身者', '4 天 / 周', 4, '杠铃卧推 · 杠铃深蹲 · 引体向上'),
    createGroupCard('推拉腿分裂', '初中高级通用', '3-6 天 / 周', 3, '杠铃卧推 · 引体向上 · 杠铃深蹲'),
    createGroupCard('全身训练 3x', '初级健身者', '3 天 / 周', 3, '杠铃深蹲 · 杠铃卧推 · 杠铃划船'),
    createGroupCard('力量举基础', '力量举入门', '3-4 天 / 周', 4, '杠铃深蹲 · 杠铃卧推 · 杠铃硬拉'),
    createGroupCard('胸背分化', '中高级健身者', '4 天 / 周', 4, '杠铃卧推 · 引体向上 · 高位下拉'),
    createGroupCard('肩臂强化', '初中级健身者', '3 天 / 周', 3, '哑铃侧平举 · 哑铃弯举 · 绳索下压'),
    createGroupCard('下肢力量', '初中高级通用', '3 天 / 周', 3, '杠铃深蹲 · 杠铃硬拉 · 提踵'),
    createGroupCard('核心腰腹', '初级健身者', '3 天 / 周', 3, '卷腹 · 平板支撑 · 悬垂举腿'),
    createGroupCard('家庭自重', '初级健身者', '3 天 / 周', 3, '俯卧撑 · 自重深蹲 · 平板支撑'),
    createGroupCard('有氧燃脂', '通用', '3-5 天 / 周', 3, '开合跳 · 高抬腿 · 波比跳')
  ]

  private handleBack(): void {
    this.getUIContext().getRouter().back()
  }

  private showCardToast(name: string): void {
    this.toastText = '原型：查看「' + name + '」计划详情'
    this.toastVisible = true
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
    this.toastTimer = setTimeout(() => {
      this.toastVisible = false
    }, 1800)
  }

  aboutToDisappear(): void {
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#0B0F13', 0], ['#0A0D12', 1]] })

      Column() {
        Row({ space: 10 }) {
          Row() {
            Path()
              .width(20)
              .height(20)
              .commands('M14 6 L8 12 L14 18')
              .fillOpacity(0)
              .stroke('#B3FFFFFF')
              .strokeWidth(2)
          }
          .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor('#0CFFFFFF')
            .border({ width: 1, color: '#14FFFFFF' })
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
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Row()
            .width(44)
            .height(44)
        }
        .width('100%')
        .padding({ top: 50, bottom: 12, left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Column({ space: 14 }) {
            this.currentCard()

            Column() {
              Text('计划组')
                .fontFamily('Noto Sans SC')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#8AFFFFFF')
                .width('100%')
              Column({ space: 10 }) {
                ForEach(this.groups, (group: GroupCard) => {
                  this.groupCard(group)
                }, (group: GroupCard) => group.name)
              }
              .width('100%')
              .margin({ top: 10 })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 30 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      if (this.toastVisible) {
        Text(this.toastText)
          .fontFamily('Noto Sans SC')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#07100B')
          .backgroundColor('#50ECA7')
          .borderRadius(999)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .position({ x: '50%', y: '86%' })
          .translate({ x: -110 })
          .transition(TransitionEffect.OPACITY.animation({ duration: MotionTokens.DURATION_OVERLAY, curve: MotionTokens.EASE_MOTION }))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }

  @Builder
  private currentCard() {
    Row() {
      Column({ space: 6 }) {
        Text('当前计划')
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
        Text('五日增肌计划')
          .fontFamily('Noto Sans SC')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('增肌 · 5 练分化 · 6 周推进')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor('#9EFFFFFF')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('当前使用')
        .fontFamily('Noto Sans SC')
        .fontSize(10.5)
        .fontWeight(FontWeight.Bold)
        .fontColor('#07100B')
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor('#50ECA7')
        .borderRadius(999)
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#0F50ECA7')
    .border({ width: 1, color: '#3850ECA7' })
    .borderRadius(24)
    .shadow({ radius: 32, color: '#33000000', offsetX: 0, offsetY: 16 })
  }

  @Builder
  private groupCard(group: GroupCard) {
    Row({ space: 12 }) {
      Row() {
        Image($rawfile('pencil-lucide-dumbbell.svg'))
          .width(20)
          .height(20)
          .fillColor('#50ECA7')
      }
      .width(46)
      .height(46)
      .borderRadius(15)
      .backgroundColor('#1A50ECA7')
      .border({ width: 1, color: '#4050ECA7' })
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
            .fontSize(10.5)
            .fontColor('#8AFFFFFF')
          Text(group.freq)
            .fontFamily('Inter')
            .fontSize(10.5)
            .fontColor('#8AFFFFFF')
          Text(group.days.toString() + ' 个训练日')
            .fontFamily('Noto Sans SC')
            .fontSize(10.5)
            .fontColor('#8AFFFFFF')
        }
        Text('示例 ' + group.examples)
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#66FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Path()
        .width(18)
        .height(18)
        .commands('M9 6 L15 12 L9 18')
        .fillOpacity(0)
        .stroke('#8AFFFFFF')
        .strokeWidth(2)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(20)
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
      this.getUIContext().getRouter().pushUrl({ url: AppRoutes.PLAN_GROUP_DETAIL })
    })
  }
}
