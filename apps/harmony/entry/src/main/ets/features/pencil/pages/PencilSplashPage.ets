/** PencilSplashPage —— FitTracker Splash 原型页。功能 #27 */
import { AppRoutes } from '../../../app/AppRoutes'
import { StartupDecision } from '../../../app/AppState'
import LaunchRequestStore from '../../../app/LaunchRequestStore'
import SessionManager from '../../../common/services/SessionManager'
import GoalRepository from '../../../shared/services/GoalRepository'
import { bundleManager, Context } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { text } from '@kit.ArkGraphics2D'
import DeviceSeedService from '../../../shared/services/DeviceSeedService'
import CloudEnvironment from '../../../common/services/CloudEnvironment'
import { PrototypeTokens } from '../../../common/styles/PrototypeTokens'

@Entry
@Component
struct PencilSplashPage {

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  private loadDesignFonts(): void {
    const fontCollection: text.FontCollection = text.FontCollection.getGlobalInstance()
    fontCollection.loadFontSync('Noto Sans SC', $rawfile('fonts/NotoSansSC-Variable.ttf'))
    fontCollection.loadFontSync('Inter', $rawfile('fonts/Inter-Variable.ttf'))
    fontCollection.loadFontSync('Geist Mono', $rawfile('fonts/GeistMono-Variable.ttf'))
  }

  private async useSafeWindowLayout(context: Context): Promise<void> {
    const mainWindow: window.Window = await window.getLastWindow(context)
    await mainWindow.setWindowLayoutFullScreen(false)
  }

  /** 测试模式门禁：仅 debug 构建（appInfo.debug=true）的包接受测试启动参数；release 包忽略。 */
  private isDebuggablePackage(): boolean {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      return info.appInfo.debug
    } catch (e) {
      return false
    }
  }

  @Builder
  private buildBrandMark() {
    Stack() {
      Column()
        .width(120)
        .height(120)
        .borderRadius(60)
        .backgroundColor('#0F50ECA7')
        .border({ width: 2, color: PrototypeTokens.ACCENT })

      Column()
        .width(72)
        .height(72)
        .borderRadius(36)
        .backgroundColor(PrototypeTokens.ACCENT_A10)
        .border({ width: 1, color: '#8850ECA7' })

      Column()
        .width(24)
        .height(24)
        .borderRadius(12)
        .backgroundColor(PrototypeTokens.ACCENT)
        .shadow({
          radius: 18,
          color: '#8850ECA7',
          offsetX: 0,
          offsetY: 0
        })
    }
    .width(120)
    .height(120)
    .position({
      x: 155,
      y: 226
    })
  }

  @Builder
  private buildWelcomeContent() {
    Column({ space: 12 }) {
      Text('YOUR DAILY TRAINING COMPANION')
        .fontFamily('Geist Mono')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .letterSpacing(1.4)
        .fontColor(PrototypeTokens.ACCENT)
        .textAlign(TextAlign.Center)

      Text('菲特')
        .width(350)
        .fontFamily('Noto Sans SC')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F5F7FA')
        .textAlign(TextAlign.Center)

      Text('Move better. Feel stronger.\nOne focused session at a time.')
        .width(350)
        .fontFamily('Inter')
        .fontSize(15)
        .fontWeight(FontWeight.Normal)
        .lineHeight(1.45)
        .fontColor('#AAB4BF')
        .textAlign(TextAlign.Center)
    }
    .width(350)
    .position({
      x: 40,
      y: 382
    })
  }

  async aboutToAppear(): Promise<void> {
    this.loadDesignFonts()
    const context = this.contextOrNull()
    try {
      if (context !== null) {
        // 测试模式（`--ps testMode=sandbox`，仅 debug 包）：跳过真实登录验证，整体切沙盒模式
        const testMode: string = await LaunchRequestStore.consumePendingTestMode(context)
        if (testMode === 'sandbox' && this.isDebuggablePackage()) {
          CloudEnvironment.setModeForTesting(testMode)
        }
        const seedKey: string = await LaunchRequestStore.consumePendingDebugSeedKey(context)
        if (seedKey.length > 0) {
          await DeviceSeedService.applyNamedSeed(context, seedKey)
        }
      }
      // 强制登录门槛（PRD 3.1）：未登录 → 登录页；已登录按目标状态分流主壳/目标设置。
      if (context !== null) {
        await this.useSafeWindowLayout(context)
        const hasValidSession: boolean = await SessionManager.isLoggedIn(context)
        const hasGoal: boolean = hasValidSession ? await GoalRepository.hasSavedGoal(context) : false
        this.getUIContext().getRouter().replaceUrl({
          url: StartupDecision.getInitialRoute(hasValidSession, hasGoal)
        })
        return
      }
      setTimeout(() => {
        this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.WELCOME })
      }, 700)
    } catch (error) {
      // 启动链任一环节失败都必须完成一次路由，否则启动页会永久停留（白屏）。
      // 登录态无法确认时按「未登录」处理落到登录页：登录页的 aboutToAppear 会重新初始化
      // 云环境、并按需续跑被中断的第三方登录（resumeThirdPartyIfPending）。
      this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.LOGIN })
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [[PrototypeTokens.BG_INK, 0], [PrototypeTokens.BG_RING_INNER, 0.5], ['#090C11', 1]]
        })

      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [195, 202.56],
          radius: 280,
          colors: [['#1850ECA7', 0], [PrototypeTokens.ACCENT_A00, 1]]
        })

      Column()
        .width(204)
        .height(204)
        .borderRadius(102)
        .radialGradient({
          center: [102, 102],
          radius: 102,
          colors: [[PrototypeTokens.ACCENT_A05, 0], [PrototypeTokens.ACCENT_A00, 1]]
        })
        .position({
          x: 113,
          y: 184
        })

      this.buildBrandMark()
      this.buildWelcomeContent()

      Text('TRAIN WITH INTENTION  ·  RECOVER WITH PURPOSE')
        .width(350)
        .fontFamily('Geist Mono')
        .fontSize(10)
        .fontWeight(FontWeight.Normal)
        .fontColor('#6F7C87')
        .textAlign(TextAlign.Center)
        .position({
          x: 40,
          y: 786
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#090C11')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}




