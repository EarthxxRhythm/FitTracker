/** PencilWelcomePage —— Pencil MCP FitTracker Welcome reproduction. 功能 #27 */

import { AppRoutes } from '../../../app/AppRoutes'
import { MotionTokens } from '../../../common/styles/DesignTokens'

@Entry
@Component
struct PencilWelcomePage {

  @State private ctaPressed: boolean = false

  @Builder
  private buildBrandLockup() {
    Row({ space: 10 }) {
      Stack() {
        Image($rawfile('fittracker-logo-pulse.svg'))
          .width(18)
          .height(18)
          .objectFit(ImageFit.Contain)
          .position({
            x: 8,
            y: 8
          })
      }
      .width(34)
      .height(34)
      .borderRadius(12)
      .backgroundColor('#1A50ECA7')
      .border({
        width: 1,
        color: '#4D50ECA7'
      })

      Text('FITTRACKER')
        .width(107)
        .height(17)
        .fontFamily('Inter')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
        .letterSpacing(1.8)
    }
    .width(382)
    .height(42)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildTrainingVisual() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height(208)
        .borderRadius(30)
        .linearGradient({
          angle: 180,
          colors: [['#14241F', 0], ['#0D1616', 1]]
        })

      Column()
        .width('100%')
        .height(208)
        .borderRadius(30)
        .radialGradient({
          center: [191, 62.4],
          radius: 124.8,
          colors: [['#1F50ECA7', 0], ['#0050ECA7', 1]]
        })

      Column()
        .width(150)
        .height(150)
        .borderRadius(75)
        .backgroundColor('#0850ECA7')
        .border({
          width: 1,
          color: '#3350ECA7'
        })
        .position({
          x: 190,
          y: 10
        })

      Column()
        .width(90)
        .height(90)
        .borderRadius(45)
        .backgroundColor('#1250ECA7')
        .border({
          width: 1,
          color: '#6650ECA7'
        })
        .position({
          x: 220,
          y: 40
        })

      // 原型 .w-visual 卡片容器：382×208、圆角 30、背景 var(--visual-a)=#14241F、
      // 边框 var(--line-14)=rgba(255,255,255,.078)。app 侧此前完全缺失这个容器 ——
      // 它才是 welcome band8（mean diff 104.92）的真正来源：大面积色块缺失；
      // 下面的同心圆与图标都只是卡片内部的装饰。
      Column()
        .width(347)
        .height(189)
        .borderRadius(30)
        .backgroundColor('#14241F')
        .border({ width: 1, color: '#145FFFFFF' })
        .shadow({ radius: 36, color: '#57000000', offsetX: 0, offsetY: 18 })
        .position({ x: 0, y: 0 })

      // 原型 w-visual 的 3 个同心圆（SVG viewBox 坐标 cx=265 cy=85, r=80/58/38，
      // 转左上角坐标 = cx-r, cy-r）。此前 app 侧完全缺失，是 welcome band8 差异主因。
      Circle({ width: 160, height: 160 })
        .fill(Color.Transparent)
        .stroke('#50ECA7')
        .strokeOpacity(0.10)
        .strokeWidth(1.5)
        .position({ x: 185, y: 5 })

      Circle({ width: 116, height: 116 })
        .fill(Color.Transparent)
        .stroke('#50ECA7')
        .strokeOpacity(0.17)
        .strokeWidth(1.5)
        .position({ x: 207, y: 27 })

      Circle({ width: 76, height: 76 })
        .fill(Color.Transparent)
        .stroke('#50ECA7')
        .strokeOpacity(0.14)
        .strokeWidth(1.5)
        .position({ x: 227, y: 47 })

      Image($rawfile('pencil-lucide-person-standing.svg'))
        .width(92)
        .height(92)
        .objectFit(ImageFit.Contain)
        .shadow({
          radius: 18,
          color: '#66000000',
          offsetX: 0,
          offsetY: 8
        })
        .position({
          x: 156,
          y: 26
        })

      Image($rawfile('pencil-lucide-dumbbell.svg'))
        .width(44)
        .height(44)
        .objectFit(ImageFit.Contain)
        .position({
          x: 42,
          y: 92
        })

      Image($rawfile('pencil-lucide-sparkles.svg'))
        .width(28)
        .height(28)
        .objectFit(ImageFit.Contain)
        .position({
          x: 300,
          y: 118
        })

      Text('CONSISTENCY > INTENSITY')
        .width(142)
        .height(13)
        .fontFamily('Geist Mono')
        .fontSize(10)
        .fontWeight(600)
        .fontColor('#66FFFFFF')
        .lineHeight(10)
        .letterSpacing(1.1)
        .translate({ x: 0, y: 1 })
        .position({
          x: 24,
          y: 168
        })
    }
    .width('100%')
    .height(208)
    .constraintSize({ maxWidth: 382 })
    .clip(true)
    .borderRadius(30)
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
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#10171B', 0], ['#0A0D12', 1]]
        })

      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [77.4, 108],
          radius: 360,
          colors: [['#2B50ECA7', 0], ['#0050ECA7', 1]]
        })

      Column() {
        Row() {
          this.buildBrandLockup()
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        // 原型 .w-logo top:118（画布）×0.90698 = vp 107，实测偏上 19vp
        .margin({ top: 95 })

        Text('TRAIN SMARTER. LIVE STRONGER.')
          .width(182)
          .height(14)
          .fontFamily('Geist Mono')
          .fontSize(11)
          .fontWeight(600)
          .fontColor('#50ECA7')
          .lineHeight(11)
          .letterSpacing(1.3)
          .translate({ x: 0, y: 1 })
          .margin({ top: 36 })

        Text('把训练，变成\n看得见的进步。')
          .width(382)
          .fontFamily('Noto Sans SC')
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
          .lineHeight(0.98 * 42)
          .translate({ x: 0, y: 4 })
          .margin({ top: 14 })

        Text('记录每一次训练，读懂身体反馈。\n用更聪明的方式，持续变强。')
          .width(346)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontWeight(FontWeight.Normal)
          .fontColor('#A6FFFFFF')
          .lineHeight(1.45 * 16)
          .translate({ x: 0, y: -1 })
          .margin({ top: 14 })

        Column() {
          this.buildTrainingVisual()
        }
        .width('100%')
        .height(189)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 0, bottom: 0 })

        Column({ space: 12 }) {
          Stack({ alignContent: Alignment.Center }) {
            Text('开始使用')
              .width(65)
              .height(23)
              .fontFamily('Noto Sans SC')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#07100B')
              .lineHeight(1.4 * 16)
              .textAlign(TextAlign.Center)
              .translate({ x: 0, y: -2 })
          }
          .width('100%')
          .height(52)
          .linearGradient({
            angle: 90,
            colors: [['#47D994', 0], ['#53E7A5', 1]]
          })
          .borderRadius(18)
          .shadow({
            radius: 24,
            color: '#66000000',
            offsetX: 0,
            offsetY: 10
          })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.ctaPressed = true
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.ctaPressed = false
            }
          })
          .scale({ x: this.ctaPressed ? MotionTokens.PRESS_PRIMARY : 1, y: this.ctaPressed ? MotionTokens.PRESS_PRIMARY : 1 })
          .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: AppRoutes.LOGIN })
          })
        }
        .width('100%')
        .constraintSize({ maxWidth: 382 })
        .height(52)
        // 原型 .w-cta top:684（画布）×0.90698 = vp 620.4；补偿 flex 布局累积的偏移
        // （logo 下移 19 后同步减 19，保持 CTA 停在 vp 620）
        .margin({ top: 75 })

        Text('本地记录 · 无需注册 · 随时开始')
          .width('100%')
          .height(16)
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontWeight(FontWeight.Normal)
          .fontColor('#52FFFFFF')
          .lineHeight(1.45 * 11)
          .textAlign(TextAlign.Center)
          .translate({ x: 0, y: -2 })
          .margin({ top: 116, bottom: 8 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
