/** SettingsContent —— 设置二级页界面体（对应 settings.html · screen-settings，390 直绘）。 */
import { MotionTokens } from '../../../common/styles/DesignTokens'

interface SwitchRow {
  key: string
  label: string
  on: boolean
}

function createSwitchRow(key: string, label: string, on: boolean): SwitchRow {
  return {
    key: key,
    label: label,
    on: on
  }
}

@Component
export struct SettingsContent {
  @State private backPressed: boolean = false
  @State private toastVisible: boolean = false
  @State private toastTimer: number = -1
  @State private unitIndex: number = 0
  @State private langIndex: number = 0
  @State private weekStartIndex: number = 0
  @State private switchRows: SwitchRow[] = [
    createSwitchRow('reminder', '训练提醒', true),
    createSwitchRow('achievement', '成就提醒', false),
    createSwitchRow('sound', '声音与震动', true),
    createSwitchRow('keep-on', '训练中屏幕常亮', true),
    createSwitchRow('sync', '训练数据同步', true),
    createSwitchRow('anonymous', '匿名使用数据', false)
  ]

  private handleBack(): void {
    this.getUIContext().getRouter().back()
  }

  private toggleSwitch(key: string): void {
    this.switchRows = this.switchRows.map((row: SwitchRow) => {
      if (row.key === key) {
        const next: SwitchRow = createSwitchRow(row.key, row.label, !row.on)
        return next
      }
      return row
    })
    this.showToast('已保存')
  }

  private showToast(text: string): void {
    this.toastVisible = true
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
    this.toastTimer = setTimeout(() => {
      this.toastVisible = false
    }, 1600)
  }

  private isSwitchOn(key: string): boolean {
    for (let i = 0; i < this.switchRows.length; i++) {
      if (this.switchRows[i].key === key) {
        return this.switchRows[i].on
      }
    }
    return false
  }

  aboutToDisappear(): void {
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Row({ space: 10 }) {
          Row() {
            Path()
              .width(20)
              .height(20)
              .commands('M14 6 L8 12 L14 18')
              .fillOpacity(0)
              .stroke('#B3FFFFFF')
              .strokeWidth(2)
          }
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor('#0CFFFFFF')
          .border({ width: 1, color: '#14FFFFFF' })
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
          Text('设置')
            .fontFamily('Noto Sans SC')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Row()
            .width(44)
            .height(44)
        }
        .width('100%')
        .padding({ top: 50, bottom: 12, left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Column({ space: 14 }) {
            this.generalCard()
            this.dataPrivacyCard()
            this.aboutCard()
            Text('FitTracker 本地优先，训练数据与身体数据默认仅保存在本机。')
              .fontFamily('Noto Sans SC')
              .fontSize(11)
              .fontColor('#8AFFFFFF')
              .lineHeight(18)
              .padding({ left: 6, right: 6, top: 2 })
          }
          .width('100%')
          .padding({ top: 8, left: 16, right: 16, bottom: 30 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      if (this.toastVisible) {
        Text('已保存')
          .fontFamily('Noto Sans SC')
          .fontSize(13)
          .fontColor('#F7FBF8')
          .lineHeight(18)
          .textAlign(TextAlign.Center)
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .constraintSize({ maxWidth: 320 })
          .backgroundColor('#F00D1117')
          .border({ width: 1, color: '#1AFFFFFF' })
          .borderRadius(999)
          .margin({ bottom: 30 })
          .transition(TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 10 }))
            .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION }))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }

  @Builder
  private generalCard() {
    Column() {
      this.sectionTitle('通用', '')
      this.segRow('体重单位', ['千克', '磅'], this.unitIndex, true, (index: number) => {
        this.unitIndex = index
        this.showToast('已保存')
      })
      this.segRow('语言', ['简体中文', 'English'], this.langIndex, false, (index: number) => {
        this.langIndex = index
        this.showToast('已保存')
      })
      this.segRow('周开始日', ['周一', '周日'], this.weekStartIndex, false, (index: number) => {
        this.weekStartIndex = index
        this.showToast('已保存')
      })
      this.switchRow('reminder', '训练提醒', false)
      this.switchRow('achievement', '成就提醒', false)
      this.switchRow('sound', '声音与震动', false)
      this.switchRow('keep-on', '训练中屏幕常亮', false)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private dataPrivacyCard() {
    Column() {
      this.sectionTitle('数据与隐私', '')
      this.chevronRow('健康数据授权', '已授权', true)
      this.switchRow('sync', '训练数据同步', false)
      this.switchRow('anonymous', '匿名使用数据', false)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private aboutCard() {
    Column() {
      Row() {
        Text('关于')
          .fontFamily('Noto Sans SC')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Text('FitTracker')
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#9EFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ bottom: 4 })

      Row() {
        Text('版本')
          .fontFamily('Noto Sans SC')
          .fontSize(14)
          .fontColor('#F7FBF8')
        Text('1.0.0')
          .fontFamily('Noto Sans SC')
          .fontSize(12.5)
          .fontColor('#8AFFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ top: 15, bottom: 15, left: 2, right: 2 })

      this.chevronRow('隐私说明', '', false)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor('#08FFFFFF')
    .border({ width: 1, color: '#1AFFFFFF' })
    .borderRadius(22)
  }

  @Builder
  private sectionTitle(title: string, meta: string) {
    Row() {
      Text(title)
        .fontFamily('Noto Sans SC')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FBF8')
      if (meta.length > 0) {
        Text(meta)
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#9EFFFFFF')
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ bottom: 4 })
  }

  @Builder
  private segRow(label: string, options: string[], selected: number, first: boolean, onChange: (index: number) => void) {
    Row() {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(14)
        .fontColor('#F7FBF8')
      Blank()
      Row({ space: 2 }) {
        ForEach(options, (option: string, index: number) => {
          Button(option)
            .height(30)
            .padding({ left: 16, right: 16 })
            .fontFamily('Noto Sans SC')
            .fontSize(12.5)
            .fontWeight(FontWeight.Bold)
            .fontColor(index === selected ? '#07100B' : '#9EFFFFFF')
            .backgroundColor(index === selected ? '#50ECA7' : Color.Transparent)
            .borderRadius(9)
            .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
            .onClick(() => {
              onChange(index)
            })
        }, (option: string) => option)
      }
      .padding(3)
      .backgroundColor('#0FFFFFFF')
      .border({ width: 1, color: '#1AFFFFFF' })
      .borderRadius(12)
    }
    .width('100%')
    .padding({ top: 15, bottom: 15, left: 2, right: 2 })
    .border({ width: { top: first ? 0 : 1 }, color: '#0FFFFFFF' })
  }

  @Builder
  private switchRow(key: string, label: string, first: boolean) {
    Row() {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(14)
        .fontColor('#F7FBF8')
      Blank()
      Row() {
        Row()
          .width(22)
          .height(22)
          .borderRadius(11)
          .backgroundColor(this.isSwitchOn(key) ? '#07100B' : '#FFFFFF')
          .translate({ x: this.isSwitchOn(key) ? 18 : 0 })
          .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION })
      }
      .width(46)
      .height(28)
      .borderRadius(14)
      .backgroundColor(this.isSwitchOn(key) ? '#50ECA7' : '#1FFFFFFF')
      .border({ width: 1, color: this.isSwitchOn(key) ? '#50ECA7' : '#1AFFFFFF' })
      .padding({ left: 1, top: 1 })
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Top)
      .animation({ duration: MotionTokens.DURATION_COLOR_BASE, curve: MotionTokens.EASE_MOTION })
      .onClick(() => {
        this.toggleSwitch(key)
      })
    }
    .width('100%')
    .padding({ top: 15, bottom: 15, left: 2, right: 2 })
    .border({ width: { top: first ? 0 : 1 }, color: '#0FFFFFFF' })
  }

  @Builder
  private chevronRow(label: string, value: string, first: boolean) {
    Row() {
      Text(label)
        .fontFamily('Noto Sans SC')
        .fontSize(14)
        .fontColor('#F7FBF8')
      Blank()
      if (value.length > 0) {
        Text(value)
          .fontFamily('Noto Sans SC')
          .fontSize(12.5)
          .fontColor('#8AFFFFFF')
      }
      Path()
        .width(18)
        .height(18)
        .commands('M9 6 L15 12 L9 18')
        .fillOpacity(0)
        .stroke('#66FFFFFF')
        .strokeWidth(2)
        .margin({ left: 6 })
    }
    .width('100%')
    .padding({ top: 15, bottom: 15, left: 2, right: 2 })
    .border({ width: { top: first ? 0 : 1 }, color: '#0FFFFFFF' })
  }
}
