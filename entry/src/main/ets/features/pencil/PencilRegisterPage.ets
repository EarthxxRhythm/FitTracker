/** PencilRegisterPage - FitTracker Register prototype page. */
import { AppRoutes } from '../../app/AppRoutes'
import AuthService from '../../common/services/AuthService'
import { Context } from '@kit.AbilityKit'
import { ColorTokens } from '../../common/styles/DesignTokens'

@Entry
@Component
struct PencilRegisterPage {
  private static readonly VIEWPORT_WIDTH: number = 390
  private static readonly DESIGN_WIDTH: number = 430
  private static readonly SCALE: number = PencilRegisterPage.VIEWPORT_WIDTH / PencilRegisterPage.DESIGN_WIDTH

  @State nickname: string = ''
  @State phone: string = ''
  @State password: string = ''
  @State confirmPassword: string = ''
  @State message: string = ''
  @State loading: boolean = false

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  private async register(): Promise<void> {
    if (this.nickname.length === 0) {
      this.message = '请输入昵称'
      return
    }
    if (this.phone.length === 0) {
      this.message = '请输入手机号'
      return
    }
    if (this.password.length < 8) {
      this.message = '密码至少 8 位'
      return
    }
    if (this.password !== this.confirmPassword) {
      this.message = '两次输入的密码不一致'
      return
    }
    const context = this.contextOrNull()
    if (context === null) {
      this.message = '当前页面不可用，请重试'
      return
    }
    this.loading = true
    const result = await AuthService.registerLocal(context, this.phone, this.password)
    this.loading = false
    if (!result.success) {
      this.message = result.message
      return
    }
    this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.LOGIN })
  }

  @Builder
  private buildBrandHeader() {
    Column({ space: 12 * PencilRegisterPage.SCALE }) {
      Row() {
        Image($rawfile('fittracker-logo-pulse.svg'))
          .width(26 * PencilRegisterPage.SCALE)
          .height(26 * PencilRegisterPage.SCALE)
      }
      .width(48 * PencilRegisterPage.SCALE)
      .height(48 * PencilRegisterPage.SCALE)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#1A50ECA7')
      .borderRadius(16 * PencilRegisterPage.SCALE)
      .border({ width: 1, color: '#4D50ECA7' })
      Text('FITTRACKER')
        .fontFamily('Inter')
        .fontSize(13 * PencilRegisterPage.SCALE)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(2.4 * PencilRegisterPage.SCALE)
        .fontColor('#F7FBF8')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildField(label: string, placeholder: string, isPassword: boolean, currentValue: string, onChange: (value: string) => void) {
    Column({ space: 8 * PencilRegisterPage.SCALE }) {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(13 * PencilRegisterPage.SCALE)
        .fontColor('#9EFFFFFF')
        .width('100%')
      Row({ space: 12 * PencilRegisterPage.SCALE }) {
        TextInput({ text: currentValue, placeholder: placeholder })
          .type(isPassword ? InputType.Password : InputType.Normal)
          .showPasswordIcon(false)
          .layoutWeight(1)
          .fontFamily('Noto Sans SC')
          .fontSize(16 * PencilRegisterPage.SCALE)
          .fontColor('#F7FBF8')
          .placeholderColor('#66FFFFFF')
          .padding(0)
          .onChange((value: string) => {
            onChange(value)
          })
        if (isPassword) {
          Image($rawfile('pencil-lucide-eye.svg'))
            .width(20 * PencilRegisterPage.SCALE)
            .height(20 * PencilRegisterPage.SCALE)
            .fillColor('#8FFFFFFF')
        }
      }
      .width('100%')
      .height(52 * PencilRegisterPage.SCALE)
      .padding({ left: 16 * PencilRegisterPage.SCALE, right: 16 * PencilRegisterPage.SCALE })
      .backgroundColor('#05FFFFFF')
      .borderRadius(18 * PencilRegisterPage.SCALE)
      .border({ width: 1 * PencilRegisterPage.SCALE, color: '#14FFFFFF' })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#0B0F13', 0], ['#0A0D12', 1]] })

      Column() {
        Scroll() {
          Column({ space: 20 * PencilRegisterPage.SCALE }) {
            this.buildBrandHeader()
            Column({ space: 10 * PencilRegisterPage.SCALE }) {
              Text('CREATE ACCOUNT')
                .fontFamily('Geist Mono')
                .fontSize(11 * PencilRegisterPage.SCALE)
                .fontColor('#50ECA7')
              Text('创建账号')
                .fontFamily('Noto Sans SC')
                .fontSize(34 * PencilRegisterPage.SCALE)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F7FBF8')
              Text('开始记录每一次训练，见证看得见的进步')
                .fontFamily('Noto Sans SC')
                .fontSize(15 * PencilRegisterPage.SCALE)
                .fontColor('#A6FFFFFF')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)

            Column({ space: 14 * PencilRegisterPage.SCALE }) {
              this.buildField('昵称', '给自己起个名字', false, this.nickname, (value: string) => {
                this.nickname = value
              })
              this.buildField('手机号', '请输入手机号', false, this.phone, (value: string) => {
                this.phone = value
              })
              this.buildField('密码', '设置 8 位以上密码', true, this.password, (value: string) => {
                this.password = value
              })
              this.buildField('确认密码', '再次输入密码', true, this.confirmPassword, (value: string) => {
                this.confirmPassword = value
              })
            }
            .width('100%')

            Row({ space: 8 * PencilRegisterPage.SCALE }) {
              Text('□')
                .fontFamily('HarmonyOS Sans')
                .fontSize(18 * PencilRegisterPage.SCALE)
                .fontColor('#8FFFFFFF')
              Text('我已阅读并同意《用户协议》与《隐私政策》')
                .fontFamily('Noto Sans SC')
                .fontSize(12 * PencilRegisterPage.SCALE)
                .fontColor('#8FFFFFFF')
            }
            .width('100%')

            if (this.message.length > 0) {
              Text(this.message)
                .fontFamily('Noto Sans SC')
                .fontSize(13 * PencilRegisterPage.SCALE)
                .fontColor('#FFD7C5')
                .width('100%')
            }

            Button(this.loading ? '注册中…' : '注册')
              .width('100%')
              .height(52 * PencilRegisterPage.SCALE)
              .padding(0)
              .fontFamily('Noto Sans SC')
              .fontSize(16 * PencilRegisterPage.SCALE)
              .fontWeight(FontWeight.Bold)
              .fontColor('#07100B')
              .linearGradient({ angle: 90, colors: [['#47D994', 0], ['#53E7A5', 1]] })
              .borderRadius(18 * PencilRegisterPage.SCALE)
              .shadow({ radius: 24, color: '#66000000', offsetX: 0, offsetY: 10 })
              .onClick(() => {
                this.register()
              })
          }
          .width('100%')
          .padding({ top: 76 * PencilRegisterPage.SCALE, bottom: 28 * PencilRegisterPage.SCALE })
        }
        .layoutWeight(1)
        .width('100%')

        Row({ space: 6 * PencilRegisterPage.SCALE }) {
          Text('已有账号？')
            .fontFamily('Noto Sans SC')
            .fontSize(14 * PencilRegisterPage.SCALE)
            .fontColor('#99FFFFFF')
          Text('直接登录')
            .fontFamily('Noto Sans SC')
            .fontSize(14 * PencilRegisterPage.SCALE)
            .fontWeight(FontWeight.Bold)
            .fontColor('#50ECA7')
            .onClick(() => {
              this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.LOGIN })
            })
        }
        .width('100%')
        .height(24 * PencilRegisterPage.SCALE)
        .justifyContent(FlexAlign.Center)
        .padding({ bottom: 28 * PencilRegisterPage.SCALE })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24 * PencilRegisterPage.SCALE, right: 24 * PencilRegisterPage.SCALE })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
