/** PencilWelcomePage —— Pencil MCP FitTracker Welcome reproduction. 功能 #27 */

import { AppRoutes } from '../../../app/AppRoutes'

@Entry
@Component
struct PencilWelcomePage {
  private static readonly VIEWPORT_WIDTH: number = 390
  private static readonly VIEWPORT_HEIGHT: number = 844
  private static readonly DESIGN_WIDTH: number = 430
  private static readonly DESIGN_HEIGHT: number = 900
  private static readonly SCALE: number = PencilWelcomePage.VIEWPORT_WIDTH / PencilWelcomePage.DESIGN_WIDTH
  private static readonly FRAME_HEIGHT: number = PencilWelcomePage.DESIGN_HEIGHT * PencilWelcomePage.SCALE

  @Builder
  private buildBrandLockup() {
    Row({ space: 10 * PencilWelcomePage.SCALE }) {
      Stack() {
        Image($rawfile('fittracker-logo-pulse.svg'))
          .width(18 * PencilWelcomePage.SCALE)
          .height(18 * PencilWelcomePage.SCALE)
          .objectFit(ImageFit.Contain)
          .position({
            x: 8 * PencilWelcomePage.SCALE,
            y: 8 * PencilWelcomePage.SCALE
          })
      }
      .width(34 * PencilWelcomePage.SCALE)
      .height(34 * PencilWelcomePage.SCALE)
      .borderRadius(12 * PencilWelcomePage.SCALE)
      .backgroundColor('#1A50ECA7')
      .border({
        width: 1,
        color: '#4D50ECA7'
      })

      Text('FITTRACKER')
        .width(107 * PencilWelcomePage.SCALE)
        .height(17 * PencilWelcomePage.SCALE)
        .fontFamily('Inter')
        .fontSize(14 * PencilWelcomePage.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .letterSpacing(1.8 * PencilWelcomePage.SCALE)
    }
    .width(382 * PencilWelcomePage.SCALE)
    .height(42 * PencilWelcomePage.SCALE)
    .alignItems(VerticalAlign.Center)
    .position({
      x: 24 * PencilWelcomePage.SCALE,
      y: 118 * PencilWelcomePage.SCALE
    })
  }

  @Builder
  private buildTrainingVisual() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(382 * PencilWelcomePage.SCALE)
        .height(208 * PencilWelcomePage.SCALE)
        .borderRadius(30 * PencilWelcomePage.SCALE)
        .linearGradient({
          angle: 180,
          colors: [['#14241F', 0], ['#0D1616', 1]]
        })

      Column()
        .width(382 * PencilWelcomePage.SCALE)
        .height(208 * PencilWelcomePage.SCALE)
        .borderRadius(30 * PencilWelcomePage.SCALE)
        .radialGradient({
          center: [191 * PencilWelcomePage.SCALE, 62.4 * PencilWelcomePage.SCALE],
          radius: 124.8 * PencilWelcomePage.SCALE,
          colors: [['#1F50ECA7', 0], ['#0050ECA7', 1]]
        })

      Column()
        .width(150 * PencilWelcomePage.SCALE)
        .height(150 * PencilWelcomePage.SCALE)
        .borderRadius(75 * PencilWelcomePage.SCALE)
        .backgroundColor('#0850ECA7')
        .border({
          width: 1,
          color: '#3350ECA7'
        })
        .position({
          x: 190 * PencilWelcomePage.SCALE,
          y: 10 * PencilWelcomePage.SCALE
        })

      Column()
        .width(90 * PencilWelcomePage.SCALE)
        .height(90 * PencilWelcomePage.SCALE)
        .borderRadius(45 * PencilWelcomePage.SCALE)
        .backgroundColor('#1250ECA7')
        .border({
          width: 1,
          color: '#6650ECA7'
        })
        .position({
          x: 220 * PencilWelcomePage.SCALE,
          y: 40 * PencilWelcomePage.SCALE
        })

      Image($rawfile('pencil-lucide-person-standing.svg'))
        .width(92 * PencilWelcomePage.SCALE)
        .height(92 * PencilWelcomePage.SCALE)
        .objectFit(ImageFit.Contain)
        .shadow({
          radius: 18,
          color: '#66000000',
          offsetX: 0,
          offsetY: 8
        })
        .position({
          x: 156 * PencilWelcomePage.SCALE,
          y: 26 * PencilWelcomePage.SCALE
        })

      Image($rawfile('pencil-lucide-dumbbell.svg'))
        .width(44 * PencilWelcomePage.SCALE)
        .height(44 * PencilWelcomePage.SCALE)
        .objectFit(ImageFit.Contain)
        .position({
          x: 42 * PencilWelcomePage.SCALE,
          y: 92 * PencilWelcomePage.SCALE
        })

      Image($rawfile('pencil-lucide-sparkles.svg'))
        .width(28 * PencilWelcomePage.SCALE)
        .height(28 * PencilWelcomePage.SCALE)
        .objectFit(ImageFit.Contain)
        .position({
          x: 300 * PencilWelcomePage.SCALE,
          y: 118 * PencilWelcomePage.SCALE
        })

      Text('CONSISTENCY > INTENSITY')
        .width(142 * PencilWelcomePage.SCALE)
        .height(13 * PencilWelcomePage.SCALE)
        .fontFamily('Geist Mono')
        .fontSize(10 * PencilWelcomePage.SCALE)
        .fontWeight(600)
        .fontColor('#66FFFFFF')
        .lineHeight(10 * PencilWelcomePage.SCALE)
        .letterSpacing(1.1 * PencilWelcomePage.SCALE)
        .translate({ x: 0, y: 1 })
        .position({
          x: 24 * PencilWelcomePage.SCALE,
          y: 168 * PencilWelcomePage.SCALE
        })
    }
    .width(382 * PencilWelcomePage.SCALE)
    .height(208 * PencilWelcomePage.SCALE)
    .clip(true)
    .borderRadius(30 * PencilWelcomePage.SCALE)
    .border({
      width: 1,
      color: '#14FFFFFF'
    })
    .shadow({
      radius: 36,
      color: '#57000000',
      offsetX: 0,
      offsetY: 18
    })
    .position({
      x: 24 * PencilWelcomePage.SCALE,
      y: 420 * PencilWelcomePage.SCALE
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Column()
          .width(PencilWelcomePage.VIEWPORT_WIDTH)
          .height(PencilWelcomePage.FRAME_HEIGHT)
          .linearGradient({
            angle: 180,
            colors: [['#10171B', 0], ['#0A0D12', 1]]
          })

        Column()
          .width(PencilWelcomePage.VIEWPORT_WIDTH)
          .height(PencilWelcomePage.FRAME_HEIGHT)
          .radialGradient({
            center: [77.4 * PencilWelcomePage.SCALE, 108 * PencilWelcomePage.SCALE],
            radius: 360 * PencilWelcomePage.SCALE,
            colors: [['#2B50ECA7', 0], ['#0050ECA7', 1]]
          })

        this.buildBrandLockup()

        Text('TRAIN SMARTER. LIVE STRONGER.')
          .width(182 * PencilWelcomePage.SCALE)
          .height(14 * PencilWelcomePage.SCALE)
          .fontFamily('Geist Mono')
          .fontSize(11 * PencilWelcomePage.SCALE)
          .fontWeight(600)
          .fontColor('#50ECA7')
          .lineHeight(11 * PencilWelcomePage.SCALE)
          .letterSpacing(1.3 * PencilWelcomePage.SCALE)
          .translate({ x: 0, y: 1 })
          .position({
            x: 24 * PencilWelcomePage.SCALE,
            y: 196 * PencilWelcomePage.SCALE
          })

        Text('把训练，变成\n看得见的进步。')
          .width(382 * PencilWelcomePage.SCALE)
          .height(82 * PencilWelcomePage.SCALE)
          .fontFamily('Noto Sans SC')
          .fontSize(42 * PencilWelcomePage.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
          .lineHeight(0.98 * 42 * PencilWelcomePage.SCALE)
          .translate({ x: 0, y: 4 })
          .position({
            x: 24 * PencilWelcomePage.SCALE,
            y: 224 * PencilWelcomePage.SCALE
          })

        Text('记录每一次训练，读懂身体反馈。\n用更聪明的方式，持续变强。')
          .width(346 * PencilWelcomePage.SCALE)
          .height(46 * PencilWelcomePage.SCALE)
          .fontFamily('Noto Sans SC')
          .fontSize(16 * PencilWelcomePage.SCALE)
          .fontWeight(FontWeight.Normal)
          .fontColor('#A6FFFFFF')
          .lineHeight(1.45 * 16 * PencilWelcomePage.SCALE)
          .translate({ x: 0, y: -1 })
          .position({
            x: 24 * PencilWelcomePage.SCALE,
            y: 336 * PencilWelcomePage.SCALE
          })

        this.buildTrainingVisual()

        Column({ space: 12 * PencilWelcomePage.SCALE }) {
          Stack({ alignContent: Alignment.Center }) {
            Text('开始使用')
              .width(65 * PencilWelcomePage.SCALE)
              .height(23 * PencilWelcomePage.SCALE)
              .fontFamily('Noto Sans SC')
              .fontSize(16 * PencilWelcomePage.SCALE)
              .fontWeight(FontWeight.Bold)
              .fontColor('#07100B')
              .lineHeight(1.4 * 16 * PencilWelcomePage.SCALE)
              .textAlign(TextAlign.Center)
              .translate({ x: 0, y: -2 })
          }
          .width(382 * PencilWelcomePage.SCALE)
          .height(52 * PencilWelcomePage.SCALE)
          .linearGradient({
            angle: 90,
            colors: [['#47D994', 0], ['#53E7A5', 1]]
          })
          .borderRadius(18 * PencilWelcomePage.SCALE)
          .shadow({
            radius: 24,
            color: '#66000000',
            offsetX: 0,
            offsetY: 10
          })
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: AppRoutes.LOGIN })
          })
        }
        .width(382 * PencilWelcomePage.SCALE)
        .height(52 * PencilWelcomePage.SCALE)
        .position({
          x: 24 * PencilWelcomePage.SCALE,
          y: 684 * PencilWelcomePage.SCALE
        })

        Text('本地记录 · 无需注册 · 随时开始')
          .width(382 * PencilWelcomePage.SCALE)
          .height(16 * PencilWelcomePage.SCALE)
        .fontFamily('Noto Sans SC')
          .fontSize(11 * PencilWelcomePage.SCALE)
          .fontWeight(FontWeight.Normal)
          .fontColor('#52FFFFFF')
          .lineHeight(1.45 * 11 * PencilWelcomePage.SCALE)
          .textAlign(TextAlign.Center)
          .translate({ x: 0, y: -2 })
          .position({
            x: 24 * PencilWelcomePage.SCALE,
            y: 852 * PencilWelcomePage.SCALE
          })
      }
      .width(PencilWelcomePage.VIEWPORT_WIDTH)
      .height(PencilWelcomePage.FRAME_HEIGHT)
      .clip(true)
      .position({ x: 0, y: 0 })
    }
    .width(PencilWelcomePage.VIEWPORT_WIDTH)
    .height(PencilWelcomePage.VIEWPORT_HEIGHT)
    .backgroundColor('#000000')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
