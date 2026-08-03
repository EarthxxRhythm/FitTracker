/** PencilSplashPage 鈥斺€?FitTracker Splash 鍘熷瀷椤点€傚姛鑳?#27 */
import { AppRoutes } from '../../app/AppRoutes'
import SessionManager from '../../common/services/SessionManager'
import { Context } from '@kit.AbilityKit'

@Entry
@Component
struct PencilSplashPage {
  private static readonly VIEWPORT_WIDTH: number = 390
  private static readonly DESIGN_WIDTH: number = 430
  private static readonly SCALE: number = PencilSplashPage.VIEWPORT_WIDTH / PencilSplashPage.DESIGN_WIDTH

  private contextOrNull(): Context | null {
    const host = this.getUIContext().getHostContext()
    return host === undefined || host === null ? null : host as Context
  }

  @Builder
  private buildBrandMark() {
    Stack() {
      Column()
        .width(120 * PencilSplashPage.SCALE)
        .height(120 * PencilSplashPage.SCALE)
        .borderRadius(60 * PencilSplashPage.SCALE)
        .backgroundColor('#0F50ECA7')
        .border({ width: 2 * PencilSplashPage.SCALE, color: '#50ECA7' })

      Column()
        .width(72 * PencilSplashPage.SCALE)
        .height(72 * PencilSplashPage.SCALE)
        .borderRadius(36 * PencilSplashPage.SCALE)
        .backgroundColor('#1A50ECA7')
        .border({ width: 1 * PencilSplashPage.SCALE, color: '#8850ECA7' })

      Column()
        .width(24 * PencilSplashPage.SCALE)
        .height(24 * PencilSplashPage.SCALE)
        .borderRadius(12 * PencilSplashPage.SCALE)
        .backgroundColor('#50ECA7')
        .shadow({
          radius: 18 * PencilSplashPage.SCALE,
          color: '#8850ECA7',
          offsetX: 0,
          offsetY: 0
        })
    }
    .width(120 * PencilSplashPage.SCALE)
    .height(120 * PencilSplashPage.SCALE)
    .position({
      x: 155 * PencilSplashPage.SCALE,
      y: 226 * PencilSplashPage.SCALE
    })
  }

  @Builder
  private buildWelcomeContent() {
    Column({ space: 12 * PencilSplashPage.SCALE }) {
      Text('YOUR DAILY TRAINING COMPANION')
        .fontFamily('Geist Mono')
        .fontSize(10 * PencilSplashPage.SCALE)
        .fontWeight(FontWeight.Medium)
        .letterSpacing(1.4 * PencilSplashPage.SCALE)
        .fontColor('#50ECA7')
        .textAlign(TextAlign.Center)

      Text('FitTracker')
        .width(350 * PencilSplashPage.SCALE)
        .fontFamily('Inter')
        .fontSize(34 * PencilSplashPage.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F5F7FA')
        .textAlign(TextAlign.Center)

      Text('Move better. Feel stronger.\nOne focused session at a time.')
        .width(350 * PencilSplashPage.SCALE)
        .fontFamily('Inter')
        .fontSize(15 * PencilSplashPage.SCALE)
        .fontWeight(FontWeight.Normal)
        .lineHeight(1.45)
        .fontColor('#AAB4BF')
        .textAlign(TextAlign.Center)
    }
    .width(350 * PencilSplashPage.SCALE)
    .position({
      x: 40 * PencilSplashPage.SCALE,
      y: 382 * PencilSplashPage.SCALE
    })
  }

  async aboutToAppear(): Promise<void> {
    const context = this.contextOrNull()
    if (context !== null && await SessionManager.isLoggedIn(context)) {
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
        .width(204 * PencilSplashPage.SCALE)
        .height(204 * PencilSplashPage.SCALE)
        .borderRadius(102 * PencilSplashPage.SCALE)
        .radialGradient({
          center: [102 * PencilSplashPage.SCALE, 102 * PencilSplashPage.SCALE],
          radius: 102 * PencilSplashPage.SCALE,
          colors: [['#0D50ECA7', 0], ['#0050ECA7', 1]]
        })
        .position({
          x: 113 * PencilSplashPage.SCALE,
          y: 184 * PencilSplashPage.SCALE
        })

      this.buildBrandMark()
      this.buildWelcomeContent()

      Text('TRAIN WITH INTENTION  ·  RECOVER WITH PURPOSE')
        .width(350 * PencilSplashPage.SCALE)
        .fontFamily('Geist Mono')
        .fontSize(10 * PencilSplashPage.SCALE)
        .fontWeight(FontWeight.Normal)
        .fontColor('#6F7C87')
        .textAlign(TextAlign.Center)
        .position({
          x: 40 * PencilSplashPage.SCALE,
          y: 786 * PencilSplashPage.SCALE
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#090C11')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}




