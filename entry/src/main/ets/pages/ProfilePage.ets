/**
 * ProfilePage —— 个人中心 (原型 5)
 * 深色主题 | 头像卡片 | 成就网格 4x2 | 操作面板
 */
import { router } from '@kit.ArkUI'
import UserProfileService from '../common/services/UserProfileService'
import SessionManager from '../common/services/SessionManager'
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens, TouchTokens } from '../common/styles/DesignTokens'
import { CustomTabBar } from '../components/MainTabBar'

interface AchievementItem {
  title: string
  icon: string
  locked: boolean
}

@Component
export struct ProfilePage {
  @State currentTab: string = 'profile'
  @State nickname: string = '健身达人'
  @State streakDays: number = 128
  @State achievements: AchievementItem[] = [
    { title: '首次训练', icon: '🎯', locked: false },
    { title: '连续3天', icon: '🔥', locked: false },
    { title: '10次训练', icon: '💪', locked: false },
    { title: '新手入门', icon: '🌟', locked: false },
    { title: '晨练达人', icon: '🌅', locked: false },
    { title: '全身训练', icon: '🏋', locked: false },
    { title: '减脂先锋', icon: '⚡', locked: false },
    { title: '力量突破', icon: '🔒', locked: true }
  ]

  async aboutToAppear(): Promise<void> {
    try {
      const profile = await UserProfileService.loadProfile(getContext(this))
      if (profile.nickname) {
        this.nickname = profile.nickname
      }
    } catch (e) {
      // use defaults
    }
  }

  async logout(): Promise<void> {
    await SessionManager.clearToken(getContext(this))
    router.replaceUrl({ url: 'pages/LoginPage' })
  }

  build() {
    Column() {
      // ═══ HEADER ═══
      Row() {
        Text('个人中心')
          .fontSize(FontTokens.HEADLINE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.TEXT_PRIMARY)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: SpacingTokens.LG, bottom: SpacingTokens.MD })

      Scroll() {
        Column() {
          // ═══ 头像卡片 ═══
          Row() {
            // 头像
            Column() {
              Text('👤')
                .fontSize(32)
                .fontColor(ColorTokens.TEXT_ON_PRIMARY)
            }
            .width(TouchTokens.AVATAR_SIZE)
            .height(TouchTokens.AVATAR_SIZE)
            .borderRadius(RadiusTokens.FULL)
            .backgroundColor(ColorTokens.SURFACE_ELEVATED)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)

            // 名称 + 天数
            Column() {
              Text(this.nickname)
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .margin({ bottom: SpacingTokens.XS })

              Row() {
                Text('已坚持训练 ')
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
                Text(`${this.streakDays}`)
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ColorTokens.ACCENT)
                Text(' 天')
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
              }
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: SpacingTokens.MD })
            .layoutWeight(1)

            // 编辑 + 设置
            Column() {
              Button('✎ 编辑')
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                .backgroundColor(ColorTokens.PRIMARY)
                .borderRadius(RadiusTokens.FULL)
                .height(TouchTokens.BUTTON_HEIGHT_SMALL)
                .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
                .margin({ bottom: SpacingTokens.SM })

              Row() {
                Text('⚙')
                  .fontSize(16)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
                Text(' 设置')
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
              }
            }
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.LG)
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })

          // ═══ 我的成就 ═══
          Column() {
            Row() {
              Text('我的成就')
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

            // 4x2 网格
            Column() {
              Row() {
                ForEach(this.achievements.slice(0, 4), (item: AchievementItem) => {
                  this.AchievementTile(item)
                }, (item: AchievementItem) => item.title)
              }
              .width('100%')
              .margin({ bottom: SpacingTokens.SM })

              Row() {
                ForEach(this.achievements.slice(4, 8), (item: AchievementItem) => {
                  this.AchievementTile(item)
                }, (item: AchievementItem) => item.title)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.LG)
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })

          // ═══ 操作面板 ═══
          Row() {
            this.ActionPanel('📊', '数据统计', () => {
              router.pushUrl({ url: 'pages/StatsPage' })
            })
            Column().width(SpacingTokens.MD)
            this.ActionPanel('⚙', '系统设置', () => {
              this.logout()
            })
          }
          .width('100%')
          .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.XXL })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // CustomTabBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }

  @Builder
  AchievementTile(item: AchievementItem) {
    Column() {
      Column() {
        Text(item.icon)
          .fontSize(28)
          .opacity(item.locked ? 0.3 : 1.0)
      }
      .width(60)
      .height(60)
      .borderRadius(RadiusTokens.LG)
      .backgroundColor(item.locked ? ColorTokens.SURFACE_SECONDARY : ColorTokens.SURFACE_ELEVATED)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text(item.title)
        .fontSize(FontTokens.MICRO_SIZE)
        .fontColor(item.locked ? ColorTokens.TEXT_DISABLED : ColorTokens.TEXT_SECONDARY)
        .margin({ top: SpacingTokens.XS })
        .maxLines(1)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ActionPanel(icon: string, label: string, onClick: () => void) {
    Row() {
      Column() {
        Text(icon)
          .fontSize(24)
      }
      .width(48)
      .height(48)
      .borderRadius(RadiusTokens.FULL)
      .backgroundColor(ColorTokens.OVERLAY_PRIMARY)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text(label)
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .margin({ left: SpacingTokens.MD })
    }
    .layoutWeight(1)
    .height(72)
    .padding(SpacingTokens.MD)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .borderRadius(RadiusTokens.LG)
    .onClick(onClick)
  }
}
