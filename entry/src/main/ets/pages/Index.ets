/**
 * Index —— 主页 (原型 1)
 * 深色主题 | 蓝色主色 #1E88E5 | 问候语 | 训练卡 | 进度 | 统计 | 趋势图
 */
import { router } from '@kit.ArkUI'
import TrainingPlanService, { UserPlan, TrainingDay, ExerciseRef } from '../common/services/TrainingPlanService'
import WorkoutSessionService from '../common/services/WorkoutSessionService'
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens, TouchTokens } from '../common/styles/DesignTokens'
import { CustomTabBar } from '../components/MainTabBar'

interface WeekStat {
  label: string
  value: string
  unit: string
}

interface BarData {
  day: string
  height: number
}


@Component
export struct Index {
  @State currentTab: string = 'home'
  @State todayLabel: string = ''
  @State timeLabel: string = ''
  @State currentPlan: UserPlan | null = null
  @State todayTraining: TrainingDay | null = null
  @State weeklyTrainCount: number = 3
  @State weeklyMinutes: number = 120
  @State weeklyCalories: number = 1800
  @State planProgress: number = 12
  @State planTotal: number = 30
  private barData: BarData[] = [
    { day: '一', height: 60 }, { day: '二', height: 90 }, { day: '三', height: 40 },
    { day: '四', height: 80 }, { day: '五', height: 50 }, { day: '六', height: 70 }, { day: '日', height: 30 }
  ]
  private stats: WeekStat[] = [
    { label: '本周训练', value: '3', unit: '次' },
    { label: '累计时长', value: '120', unit: '分钟' },
    { label: '消耗热量', value: '1800', unit: '千卡' }
  ]

  async aboutToAppear(): Promise<void> {
    this.todayLabel = TrainingPlanService.getTodayLabel()
    const now = new Date()
    this.timeLabel = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`

    try {
      const plan = await TrainingPlanService.getCurrentPlan(getContext(this))
      if (plan) {
        this.currentPlan = plan
        this.todayTraining = TrainingPlanService.getTodayTraining(plan)
      }
      const weeklyStats = await WorkoutSessionService.getWeeklyStats(getContext(this))
      this.weeklyTrainCount = weeklyStats.count
      this.weeklyMinutes = Math.round(weeklyStats.duration / 60)
      this.weeklyCalories = Math.round(weeklyStats.volume * 0.1)
    } catch (e) {
      // use defaults
    }
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          // ═══ 问候语 ═══
          Text('下午好，训练者')
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .margin({
              left: SpacingTokens.MD,
              right: SpacingTokens.MD,
              bottom: SpacingTokens.MD,
              top: SpacingTokens.MD
            })
            .align(Alignment.Start)
            .width('100%')

          // ═══ 训练卡 ═══
          Column() {
            Row() {
              Column() {
                Text('上肢力量训练')
                  .fontSize(FontTokens.FAMILY_BASE)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ColorTokens.TEXT_PRIMARY)
                  .margin({ bottom: SpacingTokens.XS })
                Row({space: 3}){
                  Image($rawfile('时间表.svg'))
                    .width(15)
                  Text('30 分钟')
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                  Text(' · ')
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                  Image($rawfile('哑铃.svg'))
                    .width(20)
                  Text('4个动作')
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                }

              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Button(){
                Row({ space: 3 }){
                  Image($rawfile('开始1.svg'))
                    .width(15)
                  Text('开始训练')
                    .fontColor(Color.White)
                }
              }
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                .backgroundColor(ColorTokens.ACCENT)
                .borderRadius(RadiusTokens.SM)
                .height(TouchTokens.BUTTON_HEIGHT_SMALL)
                .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
                .onClick(() => {
                  if (this.currentPlan && this.todayTraining) {
                    router.pushUrl({
                      url: 'pages/WorkoutRecorderPage',
                      params: { days: [this.todayTraining], planId: this.currentPlan.id, planName: this.currentPlan.name, dayLabel: this.todayTraining.dayLabel }
                    })
                  }
                })
            }
            .width('100%')
            .margin({ bottom: SpacingTokens.MD })

            // ── 动作列表 ──
            Column({ space: 10 }){
              this.ExerciseRow('哑铃卧推', '3组 x 12次')
              this.ExerciseRow('坐姿肩推', '3组 x 10次')
              this.ExerciseRow('俯身划船', '3组 x 12次')
              this.ExerciseRow('二头弯举', '3组 x 15次')
            }
          }
          .width('95%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.LG)
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })

          // ═══ 当前计划 ═══
          Column() {
            Row() {
              Text('当前计划')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_PRIMARY)
              Text('查看详情 ›')
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.PRIMARY)
            }
            .width('100%')
            .margin({ bottom: SpacingTokens.MD })
            .justifyContent(FlexAlign.SpaceBetween)

            Row() {
              Column({ space: 5 }) {
                Row(){
                  Text('减脂塑形挑战')
                    .fontSize(FontTokens.BODY_BOLD_SIZE)
                    .fontColor(ColorTokens.TEXT_PRIMARY)
                    .margin({ bottom: SpacingTokens.XS })


                  Text(`已完成 ${this.planProgress}/${this.planTotal} 天`)
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                    .margin({ bottom: SpacingTokens.SM })

                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                // 进度条
                Row() {
                  Row()
                    .width(`${(this.planProgress / this.planTotal) * 100}%`)
                    .height(TouchTokens.PROGRESS_BAR_HEIGHT)
                    .backgroundColor(ColorTokens.SUCCESS)
                    .borderRadius(RadiusTokens.FULL)
                }
                .width('100%')
                .height(TouchTokens.PROGRESS_BAR_HEIGHT)
                .backgroundColor(ColorTokens.BG_SECONDARY)
                .borderRadius(RadiusTokens.FULL)
                .margin({ bottom: SpacingTokens.XS })

                Row() {
                  Text(`剩余 ${this.planTotal - this.planProgress} 天`)
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                    .width('100%')
                    .textAlign(TextAlign.End)
                }
                .width('100%')
              }
              .layoutWeight(1)
            }
            .width('100%')
          }
          .width('95%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.LG)
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })

          // ═══ 训练统计 ═══
          Column() {
            Row() {
              Text('训练统计')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_PRIMARY)
              Blank()
              Text('查看全部 ›')
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.PRIMARY)
            }
            .width('100%')
            .margin({ bottom: SpacingTokens.MD })

            Row() {
              ForEach(this.stats, (stat: WeekStat) => {
                Column() {
                  Text(stat.value)
                    .fontSize(FontTokens.DISPLAY_SIZE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(ColorTokens.ACCENT)
                    .margin({ bottom: SpacingTokens.XS })
                  Text(stat.label)
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
              }, (stat: WeekStat) => stat.label)
            }
            .width('100%')
          }
          .width('95%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.LG)
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })

          // ═══ 训练趋势 ═══
          Column() {
            Row() {
              Text('训练趋势')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_PRIMARY)
            }
            .width('100%')
            .margin({ bottom: SpacingTokens.MD })

            Row() {
              ForEach(this.barData, (bar: BarData) => {
                Column() {
                  Column()
                    .width(24)
                    .height(bar.height)
                    .backgroundColor(ColorTokens.PRIMARY)
                    .borderRadius({ topLeft: RadiusTokens.XS, topRight: RadiusTokens.XS })
                  Text(bar.day)
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                    .margin({ top: SpacingTokens.XS })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
                .justifyContent(FlexAlign.End)
              }, (bar: BarData) => bar.day)
            }
            .width('100%')
            .height(120)
            .alignItems(VerticalAlign.Bottom)
          }
          .width('95%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.LG)
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })
        }
        .width('100%')
        .backgroundColor('#1a1a1a')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // ═══ 底部导航 ═══
      // CustomTabBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }

  @Builder
  ExerciseRow(name: string, detail: string) {
    Row() {
      Image($rawfile('Up.svg'))
        .width(20)
        .margin({
          left: SpacingTokens.MD,
          right: SpacingTokens.MD,
          bottom: SpacingTokens.MD,
          top: SpacingTokens.MD
        })
      Column() {
        Text(name)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_PRIMARY)
        Text(detail)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image($rawfile('Arrow Right.svg'))
        .width(24)
        .margin({
          left: SpacingTokens.MD,
          right: SpacingTokens.MD
        })
        .fillColor('#808084')
    }
    .width('100%')
    .padding({ top: SpacingTokens.SM, bottom: SpacingTokens.SM })
    .borderRadius('20')
    .backgroundColor('#191919')
  }
}
