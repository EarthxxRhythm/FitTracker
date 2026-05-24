/**
 * ProfilePage -- personal center
 * Feature #23: save and reload nickname, avatar, and weight-unit preference.
 */
import { promptAction, router } from '@kit.ArkUI'
import UserProfileService, { UserProfile, WeightUnit } from '../common/services/UserProfileService'
import SessionManager from '../common/services/SessionManager'
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens, TouchTokens } from '../common/styles/DesignTokens'

interface AchievementItem {
  title: string
  icon: string
  locked: boolean
}

@Entry
@Component
export struct ProfilePage {
  @State currentTab: string = 'profile'
  @State nickname: string = '\u5065\u8eab\u8fbe\u4eba'
  @State avatar: string = ''
  @State weightUnit: WeightUnit = 'kg'
  @State streakDays: number = 128
  @State achievements: AchievementItem[] = [
    { title: '\u9996\u6b21\u8bad\u7ec3', icon: '\u5956', locked: false },
    { title: '\u8fde\u7eed3\u5929', icon: '\u71c3', locked: false },
    { title: '10\u6b21\u8bad\u7ec3', icon: '\u529b', locked: false },
    { title: '\u65b0\u624b\u5165\u95e8', icon: '\u661f', locked: false },
    { title: '\u6668\u7ec3\u8fbe\u4eba', icon: '\u6668', locked: false },
    { title: '\u5168\u8eab\u8bad\u7ec3', icon: '\u5168', locked: false },
    { title: '\u51cf\u8102\u5148\u950b', icon: '\u8102', locked: false },
    { title: '\u529b\u91cf\u7a81\u7834', icon: '\u7834', locked: true }
  ]

  async aboutToAppear(): Promise<void> {
    try {
      const profile: UserProfile = await UserProfileService.loadProfile(getContext(this))
      if (profile.nickname.length > 0) {
        this.nickname = profile.nickname
      }
      this.avatar = profile.avatar
      this.weightUnit = profile.weightUnit
    } catch (e) {
      // Keep visible defaults when profile storage is unavailable.
    }
  }

  async saveProfile(): Promise<void> {
    const profile: UserProfile = {
      nickname: this.nickname,
      avatar: this.avatar,
      weightUnit: this.weightUnit
    }
    await UserProfileService.saveProfile(getContext(this), profile)
    if (UserProfileService.getLastPersistenceError().length > 0) {
      promptAction.showToast({ message: '\u4fdd\u5b58\u5931\u8d25\uff0c\u5df2\u4fdd\u7559\u5f53\u524d\u8d44\u6599' })
      return
    }
    promptAction.showToast({ message: '\u4e2a\u4eba\u8d44\u6599\u5df2\u4fdd\u5b58' })
  }

  async logout(): Promise<void> {
    await SessionManager.clearToken(getContext(this))
    router.replaceUrl({ url: 'pages/LoginPage' })
  }

  getAvatarDisplay(): string {
    if (this.avatar.length > 0) {
      return this.avatar
    }
    return '\u5934\u50cf'
  }

  build() {
    Column() {
      Row() {
        Text('\u4e2a\u4eba\u4e2d\u5fc3')
          .fontSize(FontTokens.HEADLINE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.TEXT_PRIMARY)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: SpacingTokens.LG, bottom: SpacingTokens.MD })

      Scroll() {
        Column() {
          Row() {
            Column() {
              Text(this.getAvatarDisplay())
                .fontSize(this.avatar.length > 0 ? FontTokens.SMALL_SIZE : FontTokens.CAPTION_SIZE)
                .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                .maxLines(1)
            }
            .width(TouchTokens.AVATAR_SIZE)
            .height(TouchTokens.AVATAR_SIZE)
            .borderRadius(RadiusTokens.FULL)
            .backgroundColor(ColorTokens.SURFACE_ELEVATED)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)

            Column() {
              Text(this.nickname)
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .margin({ bottom: SpacingTokens.XS })
                .maxLines(1)

              Row() {
                Text('\u5df2\u575a\u6301\u8bad\u7ec3 ')
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
                Text(`${this.streakDays}`)
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ColorTokens.ACCENT)
                Text(' \u5929')
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
              }
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: SpacingTokens.MD })
            .layoutWeight(1)

            Column() {
              Button('\u4fdd\u5b58')
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                .backgroundColor(ColorTokens.PRIMARY)
                .borderRadius(RadiusTokens.FULL)
                .height(TouchTokens.BUTTON_HEIGHT_SMALL)
                .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
                .margin({ bottom: SpacingTokens.SM })
                .onClick(() => {
                  this.saveProfile()
                })

              Text(this.weightUnit)
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
            }
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.LG)
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })

          Column() {
            Text('\u8d44\u6599\u504f\u597d')
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .width('100%')
              .margin({ bottom: SpacingTokens.MD })

            this.ProfileField('\u6635\u79f0', this.nickname, '\u8bf7\u8f93\u5165\u6635\u79f0', (value: string) => {
              this.nickname = value
            })
            this.ProfileField('\u5934\u50cf', this.avatar, '\u8bf7\u8f93\u5165\u5934\u50cf\u6807\u8bc6', (value: string) => {
              this.avatar = value
            })

            Text('\u4f53\u91cd\u5355\u4f4d')
              .fontSize(FontTokens.SMALL_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .width('100%')
              .margin({ top: SpacingTokens.MD, bottom: SpacingTokens.SM })

            Row() {
              this.WeightUnitOption('kg', 'kg')
              Column().width(SpacingTokens.SM)
              this.WeightUnitOption('lbs', 'lbs')
            }
            .width('100%')
            .margin({ bottom: SpacingTokens.MD })

            Button('\u4fdd\u5b58\u8d44\u6599')
              .width('100%')
              .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
              .backgroundColor(ColorTokens.PRIMARY)
              .borderRadius(RadiusTokens.FULL)
              .onClick(() => {
                this.saveProfile()
              })
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.LG)
          .margin({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.LG })

          Column() {
            Row() {
              Text('\u6211\u7684\u6210\u5c31')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(ColorTokens.TEXT_PRIMARY)
              Blank()
              Text('\u67e5\u770b\u5168\u90e8')
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.PRIMARY)
            }
            .width('100%')
            .margin({ bottom: SpacingTokens.MD })

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

          Row() {
            this.ActionPanel('\u6570', '\u6570\u636e\u7edf\u8ba1', () => {
              router.pushUrl({ url: 'pages/StatsPage' })
            })
            Column().width(SpacingTokens.MD)
            this.ActionPanel('\u9000', '\u9000\u51fa\u767b\u5f55', () => {
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }

  @Builder
  ProfileField(label: string, value: string, placeholder: string, onChange: (value: string) => void) {
    Column() {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .width('100%')
        .margin({ bottom: SpacingTokens.SM })

      TextInput({ text: value, placeholder: placeholder })
        .height(TouchTokens.INPUT_HEIGHT)
        .width('100%')
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .placeholderColor(ColorTokens.TEXT_DISABLED)
        .backgroundColor(ColorTokens.SURFACE_SECONDARY)
        .borderRadius(RadiusTokens.SM)
        .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
        .onChange(onChange)
    }
    .width('100%')
    .margin({ bottom: SpacingTokens.MD })
  }

  @Builder
  WeightUnitOption(unit: WeightUnit, label: string) {
    Button(label)
      .layoutWeight(1)
      .height(TouchTokens.SEGMENT_HEIGHT)
      .fontSize(FontTokens.BODY_SIZE)
      .fontColor(this.weightUnit === unit ? ColorTokens.TEXT_ON_PRIMARY : ColorTokens.TEXT_SECONDARY)
      .backgroundColor(this.weightUnit === unit ? ColorTokens.PRIMARY : ColorTokens.SURFACE_SECONDARY)
      .borderRadius(RadiusTokens.SM)
      .onClick(() => {
        this.weightUnit = unit
      })
  }

  @Builder
  AchievementTile(item: AchievementItem) {
    Column() {
      Column() {
        Text(item.icon)
          .fontSize(28)
          .fontColor(item.locked ? ColorTokens.TEXT_DISABLED : ColorTokens.TEXT_PRIMARY)
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
          .fontColor(ColorTokens.TEXT_PRIMARY)
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
