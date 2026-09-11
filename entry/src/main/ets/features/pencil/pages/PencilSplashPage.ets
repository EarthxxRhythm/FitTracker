/** PencilSplashPage 鈥斺€?FitTracker Splash 鍘熷瀷椤点€傚姛鑳?#27 */
import { AppRoutes } from '../../../app/AppRoutes'
import LaunchRequestStore from '../../../app/LaunchRequestStore'
import SessionManager from '../../../common/services/SessionManager'
import { Context } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { text } from '@kit.ArkGraphics2D'
import DeviceSeedService from '../../../shared/services/DeviceSeedService'

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

  @Builder
  private buildBrandMark() {
    Stack() {
      Column()
        .width(120)
        .height(120)
        .borderRadius(60)
        .backgroundColor('#0F50ECA7')
        .border({ width: 2, color: '#50ECA7' })

      Column()
        .width(72)
        .height(72)
        .borderRadius(36)
        .backgroundColor('#1A50ECA7')
        .border({ width: 1, color: '#8850ECA7' })

      Column()
        .width(24)
        .height(24)
        .borderRadius(12)
        .backgroundColor('#50ECA7')
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
        .fontColor('#50ECA7')
        .textAlign(TextAlign.Center)

      Text('FitTracker')
        .width(350)
        .fontFamily('Inter')
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
    if (context !== null) {
      const seedKey: string = await LaunchRequestStore.consumePendingDebugSeedKey(context)
      if (seedKey.length > 0) {
        await DeviceSeedService.applyNamedSeed(context, seedKey)
      }
    }
    if (context !== null && await SessionManager.isLoggedIn(context)) {
      await this.useSafeWindowLayout(context)
      this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.APP_SHELL })
      return
    }
    setTimeout(() => {
      this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.WELCOME })
    }, 700)
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#0B0F13', 0], ['#0D1117', 0.5], ['#090C11', 1]]
        })

      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [195, 202.56],
          radius: 280,
          colors: [['#1850ECA7', 0], ['#0050ECA7', 1]]
        })

      Column()
        .width(204)
        .height(204)
        .borderRadius(102)
        .radialGradient({
          center: [102, 102],
          radius: 102,
          colors: [['#0D50ECA7', 0], ['#0050ECA7', 1]]
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




