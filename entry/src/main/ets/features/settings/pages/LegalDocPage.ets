/** LegalDocPage —— 法律文档查看页（隐私政策 / 用户协议）。
 *  路由参数：{ kind: 'privacy' | 'agreement' }（缺失/非法时回退 'privacy'）。
 *  内容源：resources/rawfile/legal/{privacy-policy,user-agreement}.txt
 *  （由 docs/legal/*.md 逐字转换，转换脚本与对账见 docs/legal/README.md）。
 *  入口：登录页 / 注册页协议勾选行、设置页「隐私说明」行（AppRoutes.LEGAL_DOC）。 */
import { Context } from '@kit.AbilityKit'
import { buffer } from '@kit.ArkTS'
import { window } from '@kit.ArkUI'
import { MotionTokens } from '../../../common/styles/DesignTokens'

interface LegalDocParams {
  kind?: string
}

@Entry
@Component
struct LegalDocPage {
  @State private docTitle: string = '隐私政策'
  @State private docText: string = ''
  @State private loadFailed: boolean = false
  @State private backPressed: boolean = false
  // 系统状态栏高度（vp）。顶栏顶距 = 52vp 设计值 - 状态栏高度，避免双计。
  @State private topInsetVp: number = 0

  aboutToAppear(): void {
    const kind: string = this.resolveKind()
    this.docTitle = kind === 'agreement' ? '用户协议' : '隐私政策'
    this.loadDoc(kind)
    this.resolveTopInset()
  }

  private resolveKind(): string {
    try {
      const params = this.getUIContext().getRouter().getParams() as LegalDocParams
      if (params !== undefined && params.kind === 'agreement') {
        return 'agreement'
      }
    } catch (err) {
      // 参数缺失或类型不符：回退隐私政策。
    }
    return 'privacy'
  }

  private async resolveTopInset(): Promise<void> {
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      return
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(hostContext)
      const avoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topInsetVp = this.getUIContext().px2vp(avoidArea.topRect.height)
    } catch (e) {
      // 取不到安全区时按 0 处理，顶距回退为 52vp。
      this.topInsetVp = 0
    }
  }

  private async loadDoc(kind: string): Promise<void> {
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      this.loadFailed = true
      return
    }
    const file: string = kind === 'agreement' ? 'legal/user-agreement.txt' : 'legal/privacy-policy.txt'
    try {
      const raw: Uint8Array = hostContext.resourceManager.getRawFileContentSync(file)
      this.docText = buffer.from(raw.buffer).toString()
      this.loadFailed = false
    } catch (error) {
      this.loadFailed = true
      this.docText = ''
    }
  }

  private handleBack(): void {
    this.getUIContext().getRouter().back()
  }

  build() {
    Column() {
      this.topBar()
      if (this.loadFailed) {
        this.emptyState()
      } else {
        Scroll() {
          Text(this.docText)
            .fontFamily('Noto Sans SC')
            .fontSize(13.5)
            .fontColor('#C9FFFFFF')
            .lineHeight(22)
            .width('100%')
            .padding({ top: 20, bottom: 40, left: 20, right: 20 })
            .textAlign(TextAlign.Start)
        }
        .width('100%')
        .layoutWeight(1)
        // 同 PlansContent / PlanGroupDetailContent：layoutWeight 限高后内容不足一屏会居中，
        // align(Top) 拉回顶部。
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }

  @Builder
  private topBar() {
    Row({ space: 8 }) {
      Row() {
        Image($rawfile('pencil-plan-nav-chevron-left.svg'))
          .width(22)
          .height(22)
          .opacity(0.7)
      }
      .width(44)
      .height(44)
      .borderRadius(14)
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

      Text(this.docTitle)
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row()
        .width(44)
        .height(44)
    }
    .width('100%')
    .padding({ top: Math.max(52 - this.topInsetVp, 0), bottom: 10, left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#D10A0D12')
    .border({ width: { bottom: 1 }, color: '#0FFFFFFF' })
  }

  @Builder
  private emptyState() {
    Column({ space: 10 }) {
      Text('文档加载失败')
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
      Text('未能读取本地文档，请返回重试。')
        .fontFamily('Noto Sans SC')
        .fontSize(13)
        .fontColor('#9EFFFFFF')
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 16, right: 16 })
  }
}
