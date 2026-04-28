/**
 * ProfilePage —— 个人资料页
 *
 * 功能 #5: 用户可在"我的"Tab查看和编辑昵称、头像占位、体重单位偏好（kg/lbs），
 *          修改后即时保存并全局生效。
 * 功能 #6: 底部"退出登录"按钮，二次确认后清除Token和缓存，跳回登录页。
 */
import { router } from '@kit.ArkUI'
import { AppCard } from '../components/AppCard'
import UserProfileService from '../common/services/UserProfileService'
import SessionManager from '../common/services/SessionManager'
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens, TouchTokens } from '../common/styles/DesignTokens'

@Entry
@Component
struct ProfilePage {
  @State nickname: string = ''
  @State avatar: string = ''
  @State weightUnit: string = 'kg'

  async aboutToAppear(): Promise<void> {
    try {
      const profile = await UserProfileService.loadProfile(getContext(this))
      this.nickname = profile.nickname
      this.avatar = profile.avatar
      this.weightUnit = profile.weightUnit
    } catch (e) {
      const defaults = UserProfileService.getDefaultProfile()
      this.nickname = defaults.nickname
      this.avatar = defaults.avatar
      this.weightUnit = defaults.weightUnit
    }
  }

  async saveNickname(): Promise<void> {
    await UserProfileService.saveNickname(getContext(this), this.nickname)
  }

  async onWeightUnitChange(unit: string): Promise<void> {
    this.weightUnit = unit
    await UserProfileService.saveWeightUnit(getContext(this), unit as 'kg' | 'lbs')
  }

  handleLogout(): void {
    AlertDialog.show({
      title: '退出登录',
      message: '确定要退出登录吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确定',
        fontColor: ColorTokens.ERROR,
        action: async () => {
          try {
            await SessionManager.clearToken(getContext(this))
            await UserProfileService.clearProfile(getContext(this))
            router.replaceUrl({ url: 'pages/LoginPage' })
          } catch (e) {
            router.replaceUrl({ url: 'pages/LoginPage' })
          }
        }
      }
    })
  }

  getAvatarInitial(): string {
    if (this.nickname.length > 0) {
      return this.nickname.charAt(0).toUpperCase()
    }
    return '?'
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
          Text('个人资料')
            .fontSize(FontTokens.HEADLINE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ColorTokens.TEXT_PRIMARY)
        }
        .onClick(() => {
          router.back()
        })

        Blank()
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.LG, bottom: SpacingTokens.MD })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      // 头像区域
      Column() {
        Stack() {
          Circle()
            .width(80)
            .height(80)
            .fill(ColorTokens.SURFACE_SECONDARY)
            .stroke(ColorTokens.NEUTRAL_100)
            .strokeWidth(1)

          Text(this.getAvatarInitial())
            .fontSize(32)
            .fontWeight(FontWeight.Medium)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .width(80)
        .height(80)

        Text('点击更换头像')
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.PRIMARY)
          .margin({ top: SpacingTokens.SM })
      }
      .width('100%')
      .padding({ top: SpacingTokens.XL, bottom: SpacingTokens.LG })
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      // 昵称区域
      AppCard({ variant: 'outlined', padding: 'default' }) {
        Row() {
          Text('昵称')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .fontWeight(FontWeight.Medium)
            .width(60)

          TextInput({ text: $$this.nickname, placeholder: '请输入昵称' })
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .placeholderColor(ColorTokens.TEXT_DISABLED)
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .maxLength(20)
            .onChange((value: string) => {
              this.nickname = value
            })
            .onBlur(() => {
              this.saveNickname()
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }

      // 体重单位区域
      AppCard({ variant: 'outlined', padding: 'default' }) {
        Column() {
          Text('体重单位')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ bottom: SpacingTokens.MD })

          Row() {
            Button('kg (公斤)') {
              Text('kg (公斤)')
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(this.weightUnit === 'kg' ? Color.White : ColorTokens.TEXT_PRIMARY)
                .fontWeight(FontWeight.Medium)
            }
            .height(40)
            .layoutWeight(1)
            .backgroundColor(this.weightUnit === 'kg' ? ColorTokens.PRIMARY : ColorTokens.SURFACE_SECONDARY)
            .borderRadius(RadiusTokens.FULL)
            .onClick(() => {
              this.onWeightUnitChange('kg')
            })

            Button('lbs (磅)') {
              Text('lbs (磅)')
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontColor(this.weightUnit === 'lbs' ? Color.White : ColorTokens.TEXT_PRIMARY)
                .fontWeight(FontWeight.Medium)
            }
            .height(40)
            .layoutWeight(1)
            .backgroundColor(this.weightUnit === 'lbs' ? ColorTokens.PRIMARY : ColorTokens.SURFACE_SECONDARY)
            .borderRadius(RadiusTokens.FULL)
            .margin({ left: SpacingTokens.MD })
            .onClick(() => {
              this.onWeightUnitChange('lbs')
            })
          }
          .width('100%')
        }
        .width('100%')
      }

      Blank()

      // 退出登录按钮
      Row() {
        Text('退出登录')
          .fontSize(FontTokens.BODY_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ColorTokens.ERROR)
      }
      .width('100%')
      .height(TouchTokens.MIN_TARGET)
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: SpacingTokens.XXL })
      .onClick(() => {
        this.handleLogout()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
  }
}
