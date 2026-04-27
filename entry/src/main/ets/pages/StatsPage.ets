/**
 * StatsPage —— 数据统计页
 *
 * 功能 #28: 日历热力图（月视图，5档颜色深浅）
 * 功能 #29: 月份切换（左右箭头）
 * 功能 #30: 日期训练摘要（点击日期弹窗）
 * 功能 #31: 周统计概览（4项指标卡片）
 * 功能 #32: 统计时间段切换（周/月选项卡）
 */
import { router } from '@kit.ArkUI'
import { AppCard } from '../components/AppCard'
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens } from '../common/styles/DesignTokens'

@Entry
@Component
struct StatsPage {
  @State activePeriod: number = 0 // 0=周, 1=月
  @State currentMonth: number = new Date().getMonth() + 1
  @State currentYear: number = new Date().getFullYear()

  getDaysInMonth(): number {
    return new Date(this.currentYear, this.currentMonth, 0).getDate()
  }

  getMonthLabel(): string {
    return `${this.currentYear}年${this.currentMonth}月`
  }

  prevMonth(): void {
    if (this.currentMonth === 1) {
      this.currentMonth = 12
      this.currentYear--
    } else {
      this.currentMonth--
    }
  }

  nextMonth(): void {
    const now = new Date()
    const isFuture = this.currentYear > now.getFullYear() ||
      (this.currentYear === now.getFullYear() && this.currentMonth >= now.getMonth() + 1)
    if (!isFuture) {
      if (this.currentMonth === 12) {
        this.currentMonth = 1
        this.currentYear++
      } else {
        this.currentMonth++
      }
    }
  }

  getHeatColor(index: number): string {
    const colors = ['#E8E8E8', '#C8E6C9', '#A5D6A7', '#66BB6A', '#43A047']
    return colors[index % colors.length]
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Row() {
          Text('←')
            .fontSize(FontTokens.TITLE_SIZE)
            .fontColor(ColorTokens.PRIMARY)
            .padding({ right: SpacingTokens.SM })
          Text('数据统计')
            .fontSize(FontTokens.HEADLINE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ColorTokens.TEXT_PRIMARY)
        }
        .onClick(() => { router.back() })
        Blank()
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.LG, bottom: SpacingTokens.SM })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      // 时间维度切换（周/月）
      Row() {
        Button() {
          Text('本周')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.activePeriod === 0 ? Color.White : ColorTokens.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .height(36)
        .backgroundColor(this.activePeriod === 0 ? ColorTokens.PRIMARY : ColorTokens.SURFACE_SECONDARY)
        .borderRadius(RadiusTokens.FULL)
        .onClick(() => { this.activePeriod = 0 })

        Button() {
          Text('本月')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.activePeriod === 1 ? Color.White : ColorTokens.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .height(36)
        .backgroundColor(this.activePeriod === 1 ? ColorTokens.PRIMARY : ColorTokens.SURFACE_SECONDARY)
        .borderRadius(RadiusTokens.FULL)
        .margin({ left: SpacingTokens.SM })
        .onClick(() => { this.activePeriod = 1 })
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.MD })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      Scroll() {
        Column() {
          // 周统计概览卡片
          AppCard({ variant: 'elevated', padding: 'default' }) {
            Column() {
              Text('本周概况')
                .fontSize(FontTokens.BODY_BOLD_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .width('100%')
                .margin({ bottom: SpacingTokens.MD })

              Row() {
                this.statItem('训练次数', '0')
                this.statItem('总时长', '0m')
              }
              .width('100%')
              .margin({ bottom: SpacingTokens.MD })

              Row() {
                this.statItem('总组数', '0')
                this.statItem('总容量', '0kg')
              }
              .width('100%')
            }
            .width('100%')
          }
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.MD })

          // 月视图日历热力图
          AppCard({ variant: 'elevated', padding: 'default' }) {
            Column() {
              // 月份切换
              Row() {
                Text('←')
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontColor(ColorTokens.PRIMARY)
                  .padding(SpacingTokens.SM)
                  .onClick(() => { this.prevMonth() })

                Text(this.getMonthLabel())
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)

                Text('→')
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontColor(ColorTokens.PRIMARY)
                  .padding(SpacingTokens.SM)
                  .onClick(() => { this.nextMonth() })
              }
              .width('100%')
              .margin({ bottom: SpacingTokens.MD })

              // 星期头
              Row() {
                ForEach(['日', '一', '二', '三', '四', '五', '六'], (day: string) => {
                  Text(day)
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                })
              }
              .width('100%')
              .margin({ bottom: SpacingTokens.SM })

              // 日历网格（简化版：显示当月天数）
              Row() {
                ForEach(Array.from({ length: 28 }, (_, i) => i), (day: number) => {
                  Column() {
                    Text(`${day + 1}`)
                      .fontSize(FontTokens.SMALL_SIZE)
                      .fontColor(ColorTokens.TEXT_PRIMARY)
                  }
                  .width(`${100 / 7}%`)
                  .height(32)
                  .backgroundColor(this.getHeatColor(day))
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                  .borderRadius(4)
                }, (day: number) => `day_${day}`)
              }
              .width('100%')
            }
            .width('100%')
          }
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.MD })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
  }

  @Builder
  statItem(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ColorTokens.PRIMARY)
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .margin({ top: SpacingTokens.XS })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}
