/**
 * Index —— 训练Tab首页（应用主页）
 *
 * 功能 #7: 预置计划列表 — 分段控件"预置计划|我的计划"切换；
 * 功能 #9: "我的计划"显示已启用计划。
 * 后续功能 #11: 替换为"今日训练视图"。
 */
import { router } from '@kit.ArkUI'
import { AppCard } from '../components/AppCard'
import TrainingPlanService, { PresetPlan, UserPlan } from '../common/services/TrainingPlanService'
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens } from '../common/styles/DesignTokens'

@Entry
@Component
struct Index {
  @State activeSegment: number = 0 // 0=预置计划, 1=我的计划
  @State myPlans: UserPlan[] = []
  @State myPlansLoaded: boolean = false
  private presetPlans: PresetPlan[] = TrainingPlanService.getAllPresetPlans()

  async onSegmentChange(segment: number): Promise<void> {
    this.activeSegment = segment
    if (segment === 1 && !this.myPlansLoaded) {
      this.myPlans = await TrainingPlanService.getMyPlans(getContext(this))
      this.myPlansLoaded = true
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('FitTracker')
          .fontSize(FontTokens.HEADLINE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.PRIMARY)
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.LG, bottom: SpacingTokens.SM })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      // 分段控件
      Row() {
        // "预置计划" 按钮
        Button() {
          Text('预置计划')
            .fontSize(FontTokens.BODY_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.activeSegment === 0 ? Color.White : ColorTokens.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .height(40)
        .backgroundColor(this.activeSegment === 0 ? ColorTokens.PRIMARY : ColorTokens.SURFACE_SECONDARY)
        .borderRadius(RadiusTokens.FULL)
        .onClick(() => { this.onSegmentChange(0) })

        // "我的计划" 按钮
        Button() {
          Text('我的计划')
            .fontSize(FontTokens.BODY_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.activeSegment === 1 ? Color.White : ColorTokens.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .height(40)
        .backgroundColor(this.activeSegment === 1 ? ColorTokens.PRIMARY : ColorTokens.SURFACE_SECONDARY)
        .borderRadius(RadiusTokens.FULL)
        .margin({ left: SpacingTokens.SM })
        .onClick(() => { this.onSegmentChange(1) })
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.MD, bottom: SpacingTokens.SM })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      // 内容区域
      if (this.activeSegment === 0) {
        // 预置计划列表
        Scroll() {
          Column() {
            ForEach(this.presetPlans, (plan: PresetPlan) => {
              AppCard({ variant: 'outlined', padding: 'compact' }) {
                Row() {
                  // 封面占位
                  Column() {
                    Text(plan.name.charAt(0))
                      .fontSize(24)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Color.White)
                  }
                  .width(64)
                  .height(64)
                  .borderRadius(RadiusTokens.SM)
                  .backgroundColor(plan.coverColor)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)

                  // 计划信息
                  Column() {
                    Text(plan.name)
                      .fontSize(FontTokens.BODY_BOLD_SIZE)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(ColorTokens.TEXT_PRIMARY)
                      .margin({ bottom: SpacingTokens.XS })

                    Row() {
                      Text(plan.targetAudience)
                        .fontSize(FontTokens.SMALL_SIZE)
                        .fontColor(Color.White)
                        .padding({ left: SpacingTokens.SM, right: SpacingTokens.SM, top: 2, bottom: 2 })
                        .backgroundColor(plan.coverColor)
                        .borderRadius(RadiusTokens.SM)

                      Text(plan.weeklyFrequency)
                        .fontSize(FontTokens.CAPTION_SIZE)
                        .fontColor(ColorTokens.TEXT_SECONDARY)
                        .margin({ left: SpacingTokens.SM })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .margin({ left: SpacingTokens.MD })
                  .layoutWeight(1)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
              }
              .onClick(() => {
                router.pushUrl({ url: 'pages/PlanDetailPage', params: { planId: plan.id } })
              })
            }, (plan: PresetPlan) => plan.id)
          }
          .width('100%')
          .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.SM, bottom: SpacingTokens.MD })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      } else {
        // 我的计划
        if (this.myPlans.length === 0) {
          Column() {
            Text('暂无启用计划')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .margin({ bottom: SpacingTokens.SM })

            Text('从预置计划中选择一套开始训练')
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          Scroll() {
            Column() {
              ForEach(this.myPlans, (plan: UserPlan) => {
                AppCard({ variant: 'outlined', padding: 'compact' }) {
                  Row() {
                    Column() {
                      Text(plan.name.charAt(0))
                        .fontSize(24)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Color.White)
                    }
                    .width(64)
                    .height(64)
                    .borderRadius(RadiusTokens.SM)
                    .backgroundColor(plan.coverColor)
                    .justifyContent(FlexAlign.Center)
                    .alignItems(HorizontalAlign.Center)

                    Column() {
                      Text(plan.name)
                        .fontSize(FontTokens.BODY_BOLD_SIZE)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(ColorTokens.TEXT_PRIMARY)
                        .margin({ bottom: SpacingTokens.XS })

                      Row() {
                        Text(plan.targetAudience)
                          .fontSize(FontTokens.SMALL_SIZE)
                          .fontColor(Color.White)
                          .padding({ left: SpacingTokens.SM, right: SpacingTokens.SM, top: 2, bottom: 2 })
                          .backgroundColor(plan.coverColor)
                          .borderRadius(RadiusTokens.SM)

                        Text(plan.weeklyFrequency)
                          .fontSize(FontTokens.CAPTION_SIZE)
                          .fontColor(ColorTokens.TEXT_SECONDARY)
                          .margin({ left: SpacingTokens.SM })
                      }
                    }
                    .alignItems(HorizontalAlign.Start)
                    .margin({ left: SpacingTokens.MD })
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                }
              }, (plan: UserPlan) => plan.id)
            }
            .width('100%')
            .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.SM, bottom: SpacingTokens.MD })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }

      // 底部导航栏占位
      Row() {
        Text('训练')
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.PRIMARY)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('动作库')
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.NEUTRAL_300)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('统计')
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.NEUTRAL_300)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('我的')
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.NEUTRAL_300)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            router.pushUrl({ url: 'pages/ProfilePage' })
          })
      }
      .width('100%')
      .height(56)
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)
      .border({ width: { top: 0.5 }, color: ColorTokens.NEUTRAL_100 })
      .padding({ bottom: SpacingTokens.SM })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
  }
}
