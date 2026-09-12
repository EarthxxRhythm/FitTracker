/** PencilWelcomePage —— Pencil MCP FitTracker Welcome reproduction. 功能 #27 */

import { AppRoutes } from '../../../app/AppRoutes'
import { MotionTokens } from '../../../common/styles/DesignTokens'

/**
 * 还原说明（2026-09-12 重构 · 第二轮）
 *
 * 原型 fittracker-welcome-home.html 的 welcome 屏是「430×900 设计空间 × scale(0.90698)」
 * 画布（.w-frame），屏内元素全部 .w-abs 绝对定位：
 *   .w-logo     left 24  top 118  382×42
 *   .w-eyebrow  left 24  top 196
 *   .w-headline left 24  top 224  width 382  font 42 / line-height 1.3
 *   .w-sub      left 24  top 336  width 346  font 16 / line-height 1.6
 *   .w-visual   left 24  top 420  382×208
 *   .w-cta      left 24  top 684  width 382  (按钮 h 52)
 *   .w-foot     left 24  top 852  width 382
 *
 * 第二轮清理（对照原型源码后确认「原型没有、实现自加」的元素）：
 *   1. 顶层背景：原型 .w-frame 是 background: var(--ink-welcome-0) = #10171B **纯色**；
 *      实现曾挂 linearGradient(#10171B→#0A0D12) + radialGradient(center [77.4,108])。
 *      后者圆心正落在顶部左侧，是 band 0 差异的来源。已改回纯色。
 *   2. .w-visual 卡片：原型是 background: var(--visual-a) = #14241F **纯色**；
 *      实现曾挂 linearGradient + radialGradient，已改回纯色。
 *   3. 删除原型不存在的三处：150×150 与 90×90 两个实心圆、以及 347×189 的重复卡片
 *      （外层 Stack 已是 382×208 的卡片本体，与原型 .w-visual 同尺寸）。
 *      原型 SVG 里只有 3 个**描边**圆（r 80/58/38，stroke 无 fill），对应下方 3 个 Circle。
 */
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
      // 卡片底：原型 background: var(--visual-a) = #14241F（纯色）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#14241F')

      // 原型 w-visual 的 3 个同心圆（SVG viewBox cx=265 cy=85, r=80/58/38，
      // 转左上角坐标 = cx-r, cy-r），均为描边、无填充。
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
        .fontFamily('Geist Mono')
        .fontSize(10)
        .fontWeight(600)
        .fontColor('#66FFFFFF')
        .lineHeight(10)
        .letterSpacing(1.1)
        .position({
          x: 24,
          y: 168
        })
    }
    .width(382)
    .height(208)
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

  @Builder
  private buildCta() {
    Stack({ alignContent: Alignment.Center }) {
      Text('开始使用')
        .fontFamily('Noto Sans SC')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#07100B')
        .textAlign(TextAlign.Center)
    }
    .width(382)
    .height(52)
    .backgroundColor('#50ECA7')
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

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 背景：原型 .w-frame background: var(--ink-welcome-0) = #10171B（纯色，无渐变）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#10171B')

      // 430×900 设计空间（对齐原型 .w-frame：430×900 × scale(0.90698)）
      Stack({ alignContent: Alignment.TopStart }) {
        Row() {
          this.buildBrandLockup()
        }
        .position({ x: 24, y: 118 })

        Text('TRAIN SMARTER. LIVE STRONGER.')
          .fontFamily('Geist Mono')
          .fontSize(11)
          .fontWeight(600)
          .fontColor('#50ECA7')
          .lineHeight(11)
          .letterSpacing(1.3)
          .position({ x: 24, y: 196 })

        Text('把训练，变成\n看得见的进步。')
          .width(382)
          .fontFamily('Noto Sans SC')
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
          .lineHeight(1.3 * 42)
          .position({ x: 24, y: 224 })

        Text('记录每一次训练，读懂身体反馈。\n用更聪明的方式，持续变强。')
          .width(346)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontWeight(FontWeight.Normal)
          .fontColor('#A6FFFFFF')
          .lineHeight(1.6 * 16)
          .position({ x: 24, y: 336 })

        Column() {
          this.buildTrainingVisual()
        }
        .position({ x: 24, y: 420 })

        Column() {
          this.buildCta()
        }
        .position({ x: 24, y: 684 })

        Text('本地记录 · 无需注册 · 随时开始')
          .width(382)
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontWeight(FontWeight.Normal)
          .fontColor('#52FFFFFF')
          .lineHeight(1.45 * 11)
          .textAlign(TextAlign.Center)
          .position({ x: 24, y: 852 })
      }
      .width(430)
      .height(900)
      .scale({ x: 0.90698, y: 0.90698, centerX: 0, centerY: 0 })
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor('#10171B')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
