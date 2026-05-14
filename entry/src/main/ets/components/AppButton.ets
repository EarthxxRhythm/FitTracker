/**
 * AppButton —— 通用按钮组件
 *
 * 变体: primary | secondary | ghost
 * 尺寸: large | medium | small
 * 状态: default | loading | disabled
 * 宽度: block (全宽) | auto (自适应)
 *
 * 禁止: 修改主按钮背景色、给 ghost 添加投影
 * 最小触摸热区: 48vp × 48vp
 */
import { ColorTokens, FontTokens, RadiusTokens, TouchTokens } from '../common/styles/DesignTokens'

@Component
export struct AppButton {
  @Prop text: string = ''
  @Prop type: 'primary' | 'secondary' | 'ghost' = 'primary'
  @Prop buttonSize: 'large' | 'medium' | 'small' = 'medium'
  @Prop disabled: boolean = false
  @Prop loading: boolean = false
  @Prop block: boolean = false
  onButtonClick?: () => void

  build() {
    Button({ type: this.type === 'ghost' ? ButtonType.Normal : ButtonType.Capsule }) {
      if (this.loading) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(this.type === 'primary' ? Color.White : ColorTokens.PRIMARY)
      } else {
        Text(this.text)
          .fontSize(this.buttonSize === 'large' ? 18 : this.buttonSize === 'small' ? 14 : FontTokens.BODY_SIZE)
          .fontColor(this.type === 'primary' ? Color.White : ColorTokens.PRIMARY)
          .fontWeight(this.type === 'ghost' ? FontWeight.Normal : FontWeight.Medium)
      }
    }
    .width(this.block ? '100%' : 'auto')
    .height(this.buttonSize === 'small' ? TouchTokens.BUTTON_HEIGHT_SMALL : TouchTokens.BUTTON_HEIGHT_DEFAULT)
    .backgroundColor(this.type === 'primary'
      ? (this.disabled ? ColorTokens.PRIMARY_DISABLED : ColorTokens.PRIMARY)
      : Color.Transparent)
    .border({
      width: this.type === 'ghost' ? 1 : 0,
      color: this.disabled ? ColorTokens.PRIMARY_DISABLED : ColorTokens.PRIMARY
    })
    .borderRadius(RadiusTokens.FULL)
    .constraintSize({ minHeight: TouchTokens.MIN_TARGET })
    .enabled(!this.disabled && !this.loading)
    .onClick(() => {
      if (!this.disabled && !this.loading) {
        this.onButtonClick?.()
      }
    })
  }
}
