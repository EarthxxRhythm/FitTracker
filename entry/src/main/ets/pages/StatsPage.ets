/**
 * StatsPage —— 训练记录历史 (原型 4)
 * 深色主题 | 训练会话卡片列表 | 时长/动作数/热量指标
 */
import { router } from '@kit.ArkUI'
import WorkoutSessionService, { WorkoutSession } from '../common/services/WorkoutSessionService'
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens } from '../common/styles/DesignTokens'
import { CustomTabBar } from '../components/MainTabBar'

@Entry
@Component
struct StatsPage {
  @State currentTab: string = 'stats'
  @State sessions: WorkoutSession[] = []

  async aboutToAppear(): Promise<void> {
    try {
      this.sessions = await WorkoutSessionService.getSessions(getContext(this))
    } catch (e) {
      // empty
    }
  }

  build() {
    Column() {
      // ═══ HEADER ═══
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .padding({ right: SpacingTokens.SM })
          .onClick(() => { router.back() })
        Text('训练记录')
          .fontSize(FontTokens.HEADLINE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.TEXT_PRIMARY)
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.LG, bottom: SpacingTokens.MD })

      // ═══ 会话列表 ═══
      if (this.sessions.length === 0) {
        Column() {
          Text('暂无训练记录')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.sessions, (session: WorkoutSession) => {
              this.SessionCard(session)
            }, (session: WorkoutSession) => session.id)
          }
          .width('100%')
          .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.XXL })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      CustomTabBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }

  @Builder
  SessionCard(session: WorkoutSession) {
    Column() {
      // ── 标题行 ──
      Row() {
        // 图标
        Column() {
          Text('🏋')
            .fontSize(20)
        }
        .width(40)
        .height(40)
        .borderRadius(RadiusTokens.FULL)
        .backgroundColor(ColorTokens.OVERLAY_PRIMARY)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        // 标题 + 日期
        Column() {
          Text(session.planName)
            .fontSize(FontTokens.BODY_BOLD_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(session.createdAt)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .margin({ top: SpacingTokens.XXXS })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: SpacingTokens.SM })

        Text('查看详情 ›')
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.PRIMARY)
      }
      .width('100%')
      .margin({ bottom: SpacingTokens.SM })

      // ── 指标行 ──
      Row() {
        // 时长
        Row() {
          Text('⏱ ')
            .fontSize(12)
            .fontColor(ColorTokens.TEXT_SECONDARY)
          Text(`${Math.round(session.durationSeconds / 60)}分钟`)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .margin({ right: SpacingTokens.MD })

        // 动作数
        Row() {
          Text('📋 ')
            .fontSize(12)
            .fontColor(ColorTokens.TEXT_SECONDARY)
          Text(`${session.totalSets}个动作`)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .margin({ right: SpacingTokens.MD })

        // 热量
        Row() {
          Text('🔥 ')
            .fontSize(12)
            .fontColor(ColorTokens.ACCENT)
          Text(`${Math.round(session.totalVolume * 0.1)}千卡`)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .borderRadius(RadiusTokens.LG)
    .margin({ bottom: SpacingTokens.SM })
  }
}
