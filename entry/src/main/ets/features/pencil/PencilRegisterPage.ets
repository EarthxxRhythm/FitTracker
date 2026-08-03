/** PencilRegisterPage —— FitTracker Register 视觉页。功能 #27 */
import { AppRoutes } from '../../app/AppRoutes'
import AuthService from '../../common/services/AuthService'
import { Context } from '@kit.AbilityKit'

@Entry
@Component
struct PencilRegisterPage {
  private static readonly VIEWPORT_WIDTH: number = 390
  private static readonly DESIGN_WIDTH: number = 430
  private static readonly SCALE: number = PencilRegisterPage.VIEWPORT_WIDTH / PencilRegisterPage.DESIGN_WIDTH
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
    if (this.phone.length === 0 || this.password.length < 6 || this.password !== this.confirmPassword) {
      this.message = '请检查手机号、密码和确认密码'
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

  build() {
    Column({ space: 24 * PencilRegisterPage.SCALE }) {
      Column({ space: 6 * PencilRegisterPage.SCALE }) {
        Text('FITTRACKER').fontFamily('Geist').fontSize(14 * PencilRegisterPage.SCALE).fontWeight(FontWeight.Bold).letterSpacing(2.4 * PencilRegisterPage.SCALE).fontColor('#F7FBF8')
        Text('创建账户').fontFamily('Geist').fontSize(28 * PencilRegisterPage.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
        Text('建立你的 FitTracker 账户，开始今天的训练。').fontFamily('Inter').fontSize(13 * PencilRegisterPage.SCALE).fontColor('#8FFFFFFF')
      }.width('100%').alignItems(HorizontalAlign.Start)
      Column({ space: 14 * PencilRegisterPage.SCALE }) {
        Text('本地注册').fontFamily('Inter').fontSize(16 * PencilRegisterPage.SCALE).fontWeight(FontWeight.Bold).fontColor('#F7FBF8')
        TextInput({ text: this.phone, placeholder: '手机号' }).type(InputType.Number).height(52 * PencilRegisterPage.SCALE).fontFamily('Inter').fontSize(14 * PencilRegisterPage.SCALE).fontColor('#F7FBF8').placeholderColor('#8FFFFFFF').backgroundColor('#08FFFFFF').borderRadius(18 * PencilRegisterPage.SCALE).padding({ left: 16 * PencilRegisterPage.SCALE, right: 16 * PencilRegisterPage.SCALE }).border({ width: 1 * PencilRegisterPage.SCALE, color: '#10FFFFFF' }).onChange((value: string) => { this.phone = value })
        TextInput({ text: this.password, placeholder: '密码（至少 6 位）' }).type(InputType.Password).height(52 * PencilRegisterPage.SCALE).fontFamily('Inter').fontSize(14 * PencilRegisterPage.SCALE).fontColor('#F7FBF8').placeholderColor('#8FFFFFFF').backgroundColor('#08FFFFFF').borderRadius(18 * PencilRegisterPage.SCALE).padding({ left: 16 * PencilRegisterPage.SCALE, right: 16 * PencilRegisterPage.SCALE }).border({ width: 1 * PencilRegisterPage.SCALE, color: '#10FFFFFF' }).onChange((value: string) => { this.password = value })
        TextInput({ text: this.confirmPassword, placeholder: '再次输入密码' }).type(InputType.Password).height(52 * PencilRegisterPage.SCALE).fontFamily('Inter').fontSize(14 * PencilRegisterPage.SCALE).fontColor('#F7FBF8').placeholderColor('#8FFFFFFF').backgroundColor('#08FFFFFF').borderRadius(18 * PencilRegisterPage.SCALE).padding({ left: 16 * PencilRegisterPage.SCALE, right: 16 * PencilRegisterPage.SCALE }).border({ width: 1 * PencilRegisterPage.SCALE, color: '#10FFFFFF' }).onChange((value: string) => { this.confirmPassword = value })
        if (this.message.length > 0) { Text(this.message).fontFamily('Inter').fontSize(12 * PencilRegisterPage.SCALE).fontColor('#FFFFB4A8').width('100%') }
        Button(this.loading ? '注册中…' : '注册').width('100%').height(56 * PencilRegisterPage.SCALE).fontFamily('Inter').fontSize(15 * PencilRegisterPage.SCALE).fontWeight(FontWeight.Bold).fontColor('#08110D').borderRadius(18 * PencilRegisterPage.SCALE).linearGradient({ angle: 180, colors: [['#47D994', 0], ['#53E7A5', 1]] }).onClick(() => { this.register() })
      }.width('100%').padding(18 * PencilRegisterPage.SCALE).backgroundColor('#08FFFFFF').borderRadius(24 * PencilRegisterPage.SCALE).border({ width: 1 * PencilRegisterPage.SCALE, color: '#14FFFFFF' })
      Row({ space: 6 * PencilRegisterPage.SCALE }) {
        Text('已有账户？').fontFamily('Inter').fontSize(12 * PencilRegisterPage.SCALE).fontColor('#8FFFFFFF')
        Text('返回登录').fontFamily('Inter').fontSize(12 * PencilRegisterPage.SCALE).fontWeight(FontWeight.Bold).fontColor('#50ECA7').onClick(() => { this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.LOGIN }) })
      }.width('100%').height(24 * PencilRegisterPage.SCALE).justifyContent(FlexAlign.Center)
    }.width('100%').height('100%').justifyContent(FlexAlign.SpaceBetween).padding({ left: 18 * PencilRegisterPage.SCALE, right: 18 * PencilRegisterPage.SCALE, top: 0, bottom: 28 * PencilRegisterPage.SCALE }).backgroundColor('#0A0D12')
  }
}
