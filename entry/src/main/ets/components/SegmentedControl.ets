/**
 * SegmentedControl —— 分段控制器
 */
import { ColorTokens, FontTokens, TouchTokens, RadiusTokens, SpacingTokens } from '../common/styles/DesignTokens'

@Component
export struct SegmentedControl {
  @Link selectedIndex: number
  @Prop options: string[] = []
  @Prop segmentSize: string = 'medium'

  build() {
    // DESIGN: Segmented control with pill-shaped buttons. Selected = solid PRIMARY, unselected = muted SURFACE_SECONDARY.
    // Height: SEGMENT_HEIGHT (40vp) for medium, BUTTON_HEIGHT_SMALL (36vp) for small.
    Row() {
      ForEach(this.options.slice(0, 5), (label: string, index: number) => {
        Column() {
          Text(label)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(this.selectedIndex === index ? ColorTokens.TEXT_ON_PRIMARY : ColorTokens.TEXT_SECONDARY)
            .fontWeight(this.selectedIndex === index ? FontWeight.Medium : FontWeight.Normal)
            .textAlign(TextAlign.Center)
            .width('100%')
        }
        .height(this.segmentSize === 'small' ? TouchTokens.BUTTON_HEIGHT_SMALL : TouchTokens.SEGMENT_HEIGHT)
        .backgroundColor(this.selectedIndex === index ? ColorTokens.PRIMARY : ColorTokens.SURFACE_SECONDARY)
        .borderRadius(RadiusTokens.FULL)
        .justifyContent(FlexAlign.Center)
        .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
        .flexGrow(1)
        .onClick(() => { this.selectedIndex = index })
      })
    }
    .backgroundColor(ColorTokens.BG_SECONDARY)
    .borderRadius(RadiusTokens.FULL)
    .padding(SpacingTokens.XS)
  }
}
