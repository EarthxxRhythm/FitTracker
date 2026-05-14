/**
 * AppCard —— 通用卡片组件
 *
 * 变体: elevated（带阴影）| outlined（带边框）
 * 内边距: default（--space-md）| compact（--space-sm）
 *
 * 禁止: 自定义投影、标题不使用 --font-title token、圆角不使用 --radius-md
 */
import { ColorTokens, RadiusTokens, ShadowTokens, SpacingTokens } from '../common/styles/DesignTokens'

@Component
export struct AppCard {
  @Prop variant: 'elevated' | 'outlined' = 'elevated'
  @Prop cardPadding: 'default' | 'compact' = 'default'
  @BuilderParam content: () => void = this.defaultContent

  @Builder
  defaultContent() {
    Text('Card Content')
      .fontSize(14)
      .fontColor(ColorTokens.TEXT_SECONDARY)
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.cardPadding === 'default' ? SpacingTokens.MD : SpacingTokens.SM)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .borderRadius(RadiusTokens.MD)
    .shadow(this.variant === 'elevated' ? ShadowTokens.MD : ShadowTokens.NONE)
    .border(this.variant === 'outlined'
      ? { width: 1, color: ColorTokens.SURFACE_ELEVATED }
      : {})
  }
}
