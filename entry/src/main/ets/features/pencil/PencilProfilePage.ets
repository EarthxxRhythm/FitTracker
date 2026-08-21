/** PencilProfilePage - FitTracker profile prototype page. Function #27 */
@Component
export struct PencilProfileContent {

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
          center: [195, -67.2],
          radius: 163.3,
          colors: [['#1550ECA7', 0], ['#0050ECA7', 1]]
        })

      Column() {
        Column() {
          this.buildProfileHeader()
        }
        .width('100%')
        .padding({ left: 16.3, right: 16.3, top: 52.6, bottom: 0 })

        Scroll() {
          Column({ space: 14.5 }) {
            this.buildWeeklyOverview()
            this.buildStreak()
            this.buildAchievements()
            this.buildShortcuts()
          }
          .width('100%')
          .padding({ left: 16.3, right: 16.3, top: 14.5, bottom: 25.4 })
        }
        .layoutWeight(1)
        .width('100%')
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
    Row({ space: 10.9 }) {
      Stack() {
        Column()
          .width(50.8)
          .height(50.8)
          .borderRadius(25.4)
          .backgroundColor('#1A50ECA7')
          .border({ width: 0.9, color: '#4A50ECA7' })
        Text('\u6797')
          .fontFamily('Inter')
          .fontSize(21.8)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .width(50.8)
      .height(50.8)
      Column({ space: 2.7 }) {
        Text('\u6797\u9ed8')
          .fontFamily('Inter')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('\u589e\u808c\u7b2c 42 \u5929 \u00b7 \u4fdd\u6301\u8282\u594f')
          .fontFamily('Inter')
          .fontSize(11.8)
          .fontColor('#7AFFFFFF')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Stack() {
        Column()
          .width(38.1)
          .height(38.1)
          .borderRadius(19)
          .backgroundColor('#0CFFFFFF')
          .border({ width: 0.9, color: '#14FFFFFF' })
        Image($rawfile('pencil-lucide-settings-2.svg'))
          .width(18.1)
          .height(18.1)
      }
      .width(38.1)
      .height(38.1)
    }
    .width('100%')
    .padding({ top: 16.3, bottom: 3.6 })
  }

  @Builder
  private buildWeeklyOverview() {
    Column({ space: 12.7 }) {
      Row() {
        Text('\u672c\u5468\u6982\u89c8')
          .fontFamily('Inter')
          .fontSize(16.3)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('7 \u6708 21 \u2013 27 \u65e5')
          .fontFamily('Inter')
          .fontSize(10.9)
          .fontColor('#7AFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      Row({ space: 5.4 }) {
        Text('186')
          .fontFamily('Geist Mono')
          .fontSize(36.3)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
        Text('分钟')
          .fontFamily('Inter')
          .fontSize(12.7)
          .fontColor('#7AFFFFFF')
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Text('本周训练时长')
        .fontFamily('Inter')
        .fontSize(10)
        .fontColor('#66FFFFFF')

      Row()
        .width('100%')
        .height(1)
        .backgroundColor('#0FFFFFFF')

      Row({ space: 9.1 }) {
        this.buildFocusMeta('训练', '4', '次')
        this.buildFocusMeta('消耗', '1,240', '千卡')
      }
      .width('100%')
    }
    .width('100%')
    .padding(16.3)
    .backgroundColor('#08FFFFFF')
    .borderRadius(25.4)
    .border({ width: 0.9, color: '#10FFFFFF' })
  }

  @Builder
  private buildFocusMeta(label: string, value: string, unit: string) {
    Column({ space: 1.8 }) {
      Text(label)
        .fontFamily('Inter')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor('#66FFFFFF')
      Row({ space: 2.7 }) {
        Text(value)
          .fontFamily('Geist Mono')
          .fontSize(18.1)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text(unit)
          .fontFamily('Inter')
          .fontSize(10)
          .fontColor('#66FFFFFF')
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildStreak() {
    Column({ space: 10.9 }) {
      Row() {
        Text('\u8bad\u7ec3\u8fde\u7eed\u8bb0\u5f55')
          .fontFamily('Inter')
          .fontSize(16.3)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('\u8fde\u7eed 6 \u5929')
          .fontFamily('Geist Mono')
          .fontSize(11.8)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      Row({ space: 7.3 }) {
        this.buildStreakDay('\u4e00', true)
        this.buildStreakDay('\u4e8c', true)
        this.buildStreakDay('\u4e09', true)
        this.buildStreakDay('\u56db', true)
        this.buildStreakDay('\u4e94', true)
        this.buildStreakDay('\u516d', true)
        this.buildStreakDay('\u65e5', false)
      }
      .width('100%')
      .height(45.3)
    }
    .width('100%')
    .height(112.5)
    .padding(16.3)
    .backgroundColor('#171C23')
    .borderRadius(25.4)
    .border({ width: 0.9, color: '#14FFFFFF' })
  }

  @Builder
  private buildStreakDay(label: string, active: boolean) {
    Column({ space: 5.4 }) {
      Column()
        .width(25.4)
        .height(25.4)
        .borderRadius(12.7)
        .backgroundColor(active ? '#50ECA7' : '#14FFFFFF')
      Text(label)
        .fontFamily('Inter')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(active ? '#50ECA7' : '#7AFFFFFF')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildAchievements() {
    Column({ space: 10.9 }) {
      Text('\u6700\u8fd1\u6210\u5c31')
        .fontFamily('Inter')
        .fontSize(16.3)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
      this.buildAchievement('\u7a33\u5b9a\u8f93\u51fa', '\u8fde\u7eed\u8bad\u7ec3 7 \u5929', '\u672c\u5468\u5b8c\u6210\u5ea6 86%', 'flame')
      this.buildAchievement('\u91cd\u91cf\u7a81\u7834', '\u6df1\u8e72\u8fbe\u5230 80 kg', '\u5237\u65b0\u4e2a\u4eba\u6700\u4f73', 'trophy')
    }
    .width('100%')
    .height(186.8)
    .padding(16.3)
    .backgroundColor('#08FFFFFF')
    .borderRadius(25.4)
    .border({ width: 0.9, color: '#10FFFFFF' })
  }

  @Builder
  private buildAchievement(title: string, note: string, value: string, icon: string) {
    Row({ space: 10.9 }) {
      Stack() {
        Column()
          .width(36.3)
          .height(36.3)
          .borderRadius(12.7)
          .backgroundColor(icon === 'trophy' ? '#1FD3B487' : '#1A50ECA7')
        if (icon === 'flame') {
          Image($rawfile('pencil-lucide-flame.svg'))
            .width(18.1)
            .height(18.1)
            .fillColor('#50ECA7')
        } else {
          Image($rawfile('pencil-lucide-trophy.svg'))
            .width(18.1)
            .height(18.1)
            .fillColor('#D3B487')
        }
      }
      .width(36.3)
      .height(36.3)
      Column({ space: 2.7 }) {
        Text(title)
          .fontFamily('Inter')
          .fontSize(12.7)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text(note)
          .fontFamily('Inter')
          .fontSize(10.9)
          .fontColor('#8FFFFFFF')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(value)
        .fontFamily('Inter')
        .fontSize(10)
        .fontColor(icon === 'trophy' ? '#D3B487' : '#50ECA7')
    }
    .width('100%')
    .height(54.4)
    .padding({ top: 9.1, bottom: 9.1 })
  }

  @Builder
  private buildShortcuts() {
    Row({ space: 9.1 }) {
      this.buildShortcut('\u8eab\u4f53\u6570\u636e', 'scale')
      this.buildShortcut('\u8bad\u7ec3\u504f\u597d', 'sliders')
    }
    .width('100%')
    .height(42.6)
  }

  @Builder
  private buildShortcut(label: string, icon: string) {
    Row({ space: 7.3 }) {
      if (icon === 'scale') {
        Image($rawfile('pencil-lucide-scale-balance.svg')).width(16.3).height(16.3)
      } else {
        Image($rawfile('pencil-lucide-sliders.svg')).width(16.3).height(16.3)
      }
      Text(label)
        .fontFamily('Inter')
        .fontSize(11.8)
        .fontWeight(FontWeight.Medium)
        .fontColor('#B3FFFFFF')
        .layoutWeight(1)
      Text('\u203a')
        .fontFamily('Inter')
        .fontSize(16.3)
        .fontColor('#7AFFFFFF')
    }
    .layoutWeight(1)
    .height(42.6)
    .padding({ left: 10.9, right: 10.9, top: 12.7, bottom: 12.7 })
    .backgroundColor('#0CFFFFFF')
    .borderRadius(16.3)
    .border({ width: 0.9, color: '#10FFFFFF' })
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







