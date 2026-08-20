/** PencilProfilePage - FitTracker profile prototype page. Function #27 */
@Component
export struct PencilProfileContent {
  private static readonly VIEWPORT_WIDTH: number = 390
  private static readonly DESIGN_WIDTH: number = 430
  private static readonly SCALE: number = PencilProfileContent.VIEWPORT_WIDTH / PencilProfileContent.DESIGN_WIDTH

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#0B0F13', 0], ['#0D1117', 0.52], ['#0A0D12', 1]]
        })

      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [215 * PencilProfileContent.SCALE, -67.2],
          radius: 180 * PencilProfileContent.SCALE,
          colors: [['#1550ECA7', 0], ['#0050ECA7', 1]]
        })

      Column() {
        Scroll() {
          Column({ space: 16 * PencilProfileContent.SCALE }) {
            this.buildProfileHeader()
            this.buildWeeklyOverview()
            this.buildStreak()
            this.buildAchievements()
            this.buildShortcuts()
          }
          .width('100%')
          .padding({ left: 18 * PencilProfileContent.SCALE, right: 18 * PencilProfileContent.SCALE, top: 58 * PencilProfileContent.SCALE, bottom: 28 * PencilProfileContent.SCALE })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0A0D12')
  }

  @Builder
  private buildProfileHeader() {
    Row({ space: 12 * PencilProfileContent.SCALE }) {
      Stack() {
        Column()
          .width(56 * PencilProfileContent.SCALE)
          .height(56 * PencilProfileContent.SCALE)
          .borderRadius(28 * PencilProfileContent.SCALE)
          .backgroundColor('#1A50ECA7')
          .border({ width: 1 * PencilProfileContent.SCALE, color: '#4A50ECA7' })
        Text('\u6797')
          .fontFamily('Inter')
          .fontSize(24 * PencilProfileContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .width(56 * PencilProfileContent.SCALE)
      .height(56 * PencilProfileContent.SCALE)
      Column({ space: 3 * PencilProfileContent.SCALE }) {
        Text('\u6797\u9ed8')
          .fontFamily('Inter')
          .fontSize(22 * PencilProfileContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('\u589e\u808c\u7b2c 42 \u5929 \u00b7 \u4fdd\u6301\u8282\u594f')
          .fontFamily('Inter')
          .fontSize(13 * PencilProfileContent.SCALE)
          .fontColor('#7AFFFFFF')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Stack() {
        Column()
          .width(42 * PencilProfileContent.SCALE)
          .height(42 * PencilProfileContent.SCALE)
          .borderRadius(21 * PencilProfileContent.SCALE)
          .backgroundColor('#0CFFFFFF')
          .border({ width: 1 * PencilProfileContent.SCALE, color: '#14FFFFFF' })
        Image($rawfile('pencil-lucide-settings-2.svg'))
          .width(20 * PencilProfileContent.SCALE)
          .height(20 * PencilProfileContent.SCALE)
      }
      .width(42 * PencilProfileContent.SCALE)
      .height(42 * PencilProfileContent.SCALE)
    }
    .width('100%')
    .padding({ top: 18 * PencilProfileContent.SCALE, bottom: 4 * PencilProfileContent.SCALE })
  }

  @Builder
  private buildWeeklyOverview() {
    Column({ space: 14 * PencilProfileContent.SCALE }) {
      Row() {
        Text('\u672c\u5468\u6982\u89c8')
          .fontFamily('Inter')
          .fontSize(18 * PencilProfileContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('7 \u6708 21 \u2013 27 \u65e5')
          .fontFamily('Inter')
          .fontSize(12 * PencilProfileContent.SCALE)
          .fontColor('#7AFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      Row({ space: 6 * PencilProfileContent.SCALE }) {
        Text('186')
          .fontFamily('Geist Mono')
          .fontSize(40 * PencilProfileContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
        Text('分钟')
          .fontFamily('Inter')
          .fontSize(14 * PencilProfileContent.SCALE)
          .fontColor('#7AFFFFFF')
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Text('本周训练时长')
        .fontFamily('Inter')
        .fontSize(11 * PencilProfileContent.SCALE)
        .fontColor('#66FFFFFF')

      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#0FFFFFFF')

      Row({ space: 10 * PencilProfileContent.SCALE }) {
        this.buildFocusMeta('训练', '4', '次')
        this.buildFocusMeta('消耗', '1,240', '千卡')
      }
      .width('100%')
    }
    .width('100%')
    .padding(18 * PencilProfileContent.SCALE)
    .backgroundColor('#08FFFFFF')
    .borderRadius(28 * PencilProfileContent.SCALE)
    .border({ width: 1 * PencilProfileContent.SCALE, color: '#10FFFFFF' })
  }

  @Builder
  private buildFocusMeta(label: string, value: string, unit: string) {
    Column({ space: 2 * PencilProfileContent.SCALE }) {
      Text(label)
        .fontFamily('Inter')
        .fontSize(11 * PencilProfileContent.SCALE)
        .fontWeight(FontWeight.Medium)
        .fontColor('#66FFFFFF')
      Row({ space: 3 * PencilProfileContent.SCALE }) {
        Text(value)
          .fontFamily('Geist Mono')
          .fontSize(20 * PencilProfileContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text(unit)
          .fontFamily('Inter')
          .fontSize(11 * PencilProfileContent.SCALE)
          .fontColor('#66FFFFFF')
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildStreak() {
    Column({ space: 12 * PencilProfileContent.SCALE }) {
      Row() {
        Text('\u8bad\u7ec3\u8fde\u7eed\u8bb0\u5f55')
          .fontFamily('Inter')
          .fontSize(18 * PencilProfileContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('\u8fde\u7eed 6 \u5929')
          .fontFamily('Geist Mono')
          .fontSize(13 * PencilProfileContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      Row({ space: 8 * PencilProfileContent.SCALE }) {
        this.buildStreakDay('\u4e00', true)
        this.buildStreakDay('\u4e8c', true)
        this.buildStreakDay('\u4e09', true)
        this.buildStreakDay('\u56db', true)
        this.buildStreakDay('\u4e94', true)
        this.buildStreakDay('\u516d', true)
        this.buildStreakDay('\u65e5', false)
      }
      .width('100%')
      .height(50 * PencilProfileContent.SCALE)
    }
    .width('100%')
    .height(124 * PencilProfileContent.SCALE)
    .padding(18 * PencilProfileContent.SCALE)
    .backgroundColor('#171C23')
    .borderRadius(28 * PencilProfileContent.SCALE)
    .border({ width: 1 * PencilProfileContent.SCALE, color: '#14FFFFFF' })
  }

  @Builder
  private buildStreakDay(label: string, active: boolean) {
    Column({ space: 6 * PencilProfileContent.SCALE }) {
      Column()
        .width(28 * PencilProfileContent.SCALE)
        .height(28 * PencilProfileContent.SCALE)
        .borderRadius(14 * PencilProfileContent.SCALE)
        .backgroundColor(active ? '#50ECA7' : '#14FFFFFF')
      Text(label)
        .fontFamily('Inter')
        .fontSize(11 * PencilProfileContent.SCALE)
        .fontWeight(FontWeight.Medium)
        .fontColor(active ? '#50ECA7' : '#7AFFFFFF')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildAchievements() {
    Column({ space: 12 * PencilProfileContent.SCALE }) {
      Text('\u6700\u8fd1\u6210\u5c31')
        .fontFamily('Inter')
        .fontSize(18 * PencilProfileContent.SCALE)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
      this.buildAchievement('\u7a33\u5b9a\u8f93\u51fa', '\u8fde\u7eed\u8bad\u7ec3 7 \u5929', '\u672c\u5468\u5b8c\u6210\u5ea6 86%', 'flame')
      this.buildAchievement('\u91cd\u91cf\u7a81\u7834', '\u6df1\u8e72\u8fbe\u5230 80 kg', '\u5237\u65b0\u4e2a\u4eba\u6700\u4f73', 'trophy')
    }
    .width('100%')
    .height(206 * PencilProfileContent.SCALE)
    .padding(18 * PencilProfileContent.SCALE)
    .backgroundColor('#08FFFFFF')
    .borderRadius(28 * PencilProfileContent.SCALE)
    .border({ width: 1 * PencilProfileContent.SCALE, color: '#10FFFFFF' })
  }

  @Builder
  private buildAchievement(title: string, note: string, value: string, icon: string) {
    Row({ space: 12 * PencilProfileContent.SCALE }) {
      Stack() {
        Column()
          .width(40 * PencilProfileContent.SCALE)
          .height(40 * PencilProfileContent.SCALE)
          .borderRadius(14 * PencilProfileContent.SCALE)
          .backgroundColor(icon === 'trophy' ? '#1FD3B487' : '#1A50ECA7')
        if (icon === 'flame') {
          Image($rawfile('pencil-lucide-flame.svg'))
            .width(20 * PencilProfileContent.SCALE)
            .height(20 * PencilProfileContent.SCALE)
            .fillColor('#50ECA7')
        } else {
          Image($rawfile('pencil-lucide-trophy.svg'))
            .width(20 * PencilProfileContent.SCALE)
            .height(20 * PencilProfileContent.SCALE)
            .fillColor('#D3B487')
        }
      }
      .width(40 * PencilProfileContent.SCALE)
      .height(40 * PencilProfileContent.SCALE)
      Column({ space: 3 * PencilProfileContent.SCALE }) {
        Text(title)
          .fontFamily('Inter')
          .fontSize(14 * PencilProfileContent.SCALE)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text(note)
          .fontFamily('Inter')
          .fontSize(12 * PencilProfileContent.SCALE)
          .fontColor('#8FFFFFFF')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(value)
        .fontFamily('Inter')
        .fontSize(11 * PencilProfileContent.SCALE)
        .fontColor(icon === 'trophy' ? '#D3B487' : '#50ECA7')
    }
    .width('100%')
    .height(60 * PencilProfileContent.SCALE)
    .padding({ top: 10 * PencilProfileContent.SCALE, bottom: 10 * PencilProfileContent.SCALE })
  }

  @Builder
  private buildShortcuts() {
    Row({ space: 10 * PencilProfileContent.SCALE }) {
      this.buildShortcut('\u8eab\u4f53\u6570\u636e', 'scale')
      this.buildShortcut('\u8bad\u7ec3\u504f\u597d', 'sliders')
    }
    .width('100%')
    .height(47 * PencilProfileContent.SCALE)
  }

  @Builder
  private buildShortcut(label: string, icon: string) {
    Row({ space: 8 * PencilProfileContent.SCALE }) {
      if (icon === 'scale') {
        Image($rawfile('pencil-lucide-scale-balance.svg')).width(18 * PencilProfileContent.SCALE).height(18 * PencilProfileContent.SCALE)
      } else {
        Image($rawfile('pencil-lucide-sliders.svg')).width(18 * PencilProfileContent.SCALE).height(18 * PencilProfileContent.SCALE)
      }
      Text(label)
        .fontFamily('Inter')
        .fontSize(13 * PencilProfileContent.SCALE)
        .fontWeight(FontWeight.Medium)
        .fontColor('#B3FFFFFF')
        .layoutWeight(1)
      Text('\u203a')
        .fontFamily('Inter')
        .fontSize(18 * PencilProfileContent.SCALE)
        .fontColor('#7AFFFFFF')
    }
    .layoutWeight(1)
    .height(47 * PencilProfileContent.SCALE)
    .padding({ left: 12 * PencilProfileContent.SCALE, right: 12 * PencilProfileContent.SCALE, top: 14 * PencilProfileContent.SCALE, bottom: 14 * PencilProfileContent.SCALE })
    .backgroundColor('#0CFFFFFF')
    .borderRadius(18 * PencilProfileContent.SCALE)
    .border({ width: 1 * PencilProfileContent.SCALE, color: '#10FFFFFF' })
    .justifyContent(FlexAlign.SpaceBetween)
  }

}

@Entry
@Component
struct PencilProfilePage {
  build() {
    Column() {
      PencilProfileContent()
    }
  }
}







