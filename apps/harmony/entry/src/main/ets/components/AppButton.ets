/**
 * AppButton —— 通用按钮组件
 * 功能 #26
 *
 * ── Duolingo 皮肤元素（C1 档）──────────────────────────────────
 * 主操作（type='primary'）采用 Duolingo 的**硬边厚底 + 按下位移**反馈：
 *   常态：底部 4vp 实心深绿厚边（`DuTokens.PRESS_DEPTH`），无模糊光晕；
 *   按下：厚边收平至 0，整体下沉 2vp（`DuTokens.PRESS_SHIFT`），松开回弹。
 * 这与原型的 `transform: scale(.985)` 是**两种不同语汇**——Duolingo 的按钮
 * 靠"被按进面板"传达物理感，不靠缩放。故 `primary` 不再叠加 scale（避免
 * 位移与缩放在同一帧叠加导致观感发虚）；`secondary` / `ghost` / `quiet`
 * 没有厚底，保留 scale 按压。
 *
 * **为什么用 `border` 而不是 `shadow`**：ArkUI 的 `.shadow({radius})` 无法表达
 * 4vp 无模糊硬边（`ShadowTokens` 的 radius 最小也有 12），而 Duolingo 原版就是
 * CSS `border-bottom: 4px solid`。故主操作同时取消模糊阴影——厚边本身提供浮起感。
 *
 * **配色保持原型基线**：厚底取同色系深阶 `ColorTokens.PRIMARY_PRESSED`
 * （`#45C9A1`），与按钮面 `ColorTokens.PRIMARY`（`#50ECA7`）配对。
 * Duolingo 的「可按的 3D 按钮」本质是**形态**，亮绿只是它的配色选型；
 * 本项目已有经 13 屏原型对齐验证的配色基线，故只借形态、不动配色。
 */
import {
  ColorTokens,
  FontTokens,
  MotionTokens,
  RadiusTokens,
  ShadowConfig,
  ShadowTokens,
  SpacingTokens,
  TouchTokens
} from '../common/styles/DesignTokens'
import { DuTokens } from '../common/styles/DuTokens'

@Component
export struct AppButton {
  @Prop text: string = ''
  @Prop type: 'primary' | 'secondary' | 'ghost' | 'quiet' = 'primary'
  @Prop buttonSize: 'hero' | 'large' | 'medium' | 'small' = 'medium'
  @Prop disabled: boolean = false
  @Prop loading: boolean = false
  @Prop block: boolean = false
  onButtonClick?: () => void
  @State private pressed: boolean = false

  private getHeight(): number {
    if (this.buttonSize === 'hero') {
      return TouchTokens.BUTTON_HEIGHT_HERO
    }
    if (this.buttonSize === 'large') {
      return TouchTokens.BUTTON_HEIGHT_LARGE
    }
    if (this.buttonSize === 'small') {
      return TouchTokens.BUTTON_HEIGHT_SMALL
    }
    return TouchTokens.BUTTON_HEIGHT_DEFAULT
  }

  private getHorizontalPadding(): number {
    if (this.buttonSize === 'hero') {
      return SpacingTokens.LG
    }
    if (this.buttonSize === 'small') {
      return SpacingTokens.MD
    }
    if (this.buttonSize === 'large') {
      return SpacingTokens.LG
    }
    return SpacingTokens.MD
  }

  private getFontSize(): number {
    if (this.buttonSize === 'hero') {
      return FontTokens.TITLE_SIZE
    }
    if (this.buttonSize === 'large') {
      return FontTokens.TITLE_SIZE
    }
    if (this.buttonSize === 'small') {
      return FontTokens.CAPTION_SIZE
    }
    return FontTokens.BODY_SIZE
  }

  private getTextColor(): string {
    if (this.type === 'primary') {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    if (this.disabled) {
      return ColorTokens.TEXT_DISABLED
    }
    if (this.type === 'quiet') {
      return ColorTokens.TEXT_ON_DARK_SECONDARY
    }
    if (this.type === 'ghost') {
      return ColorTokens.TEXT_SECONDARY
    }
    return ColorTokens.TEXT_PRIMARY
  }

  private getIndicatorColor(): string {
    if (this.type === 'primary') {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    return ColorTokens.PRIMARY
  }

  /**
   * 是否走 Duolingo 硬边厚底语汇：只有主操作、且未禁用/加载时。
   * 禁用态用 `PRIMARY_DISABLED` 平色，不需要厚度；加载态不应有可按的错觉。
   */
  private usesPressDepth(): boolean {
    return this.type === 'primary' && !this.disabled && !this.loading
  }

  private getBackgroundColor(): string {
    if (this.type === 'primary') {
      if (this.disabled) {
        return ColorTokens.PRIMARY_DISABLED
      }
      return ColorTokens.PRIMARY
    }
    if (this.type === 'quiet') {
      if (this.disabled) {
        return ColorTokens.SURFACE_DISABLED
      }
      return ColorTokens.CTA_SECONDARY_BG
    }
    if (this.type === 'secondary') {
      if (this.disabled) {
        return ColorTokens.SURFACE_DISABLED
      }
      return ColorTokens.SURFACE_BUTTON_SECONDARY
    }
    return 'rgba(0,0,0,0)'
  }

  private getBorderWidth(): number {
    if (this.type === 'ghost') {
      return 0
    }
    return 1
  }

  private getBorderColor(): string {
    if (this.disabled) {
      return ColorTokens.BORDER_SUBTLE
    }
    if (this.type === 'ghost') {
      return 'rgba(0,0,0,0)'
    }
    if (this.type === 'quiet') {
      return ColorTokens.CTA_SECONDARY_BORDER
    }
    if (this.type === 'primary') {
      // 主操作的外框与厚底同色系，用原型的强调色深阶
      return ColorTokens.PRIMARY_PRESSED
    }
    return ColorTokens.BORDER_DEFAULT
  }

  private getShadow(): ShadowConfig {
    // 主操作有硬边厚底，模糊光晕会同时出现"硬边 + 软影"两套深度线索，故取消。
    if (this.usesPressDepth()) {
      return ShadowTokens.NONE
    }
    if (this.type === 'quiet' && !this.disabled) {
      return ShadowTokens.SM
    }
    if (this.type === 'secondary' && !this.disabled) {
      return ShadowTokens.SM
    }
    return ShadowTokens.NONE
  }

  /** 底部厚边的当前厚度：按下时收平为 0，其余时间为主体厚度 */
  private getBottomWidth(): number {
    if (this.usesPressDepth()) {
      return this.pressed ? 0 : DuTokens.PRESS_DEPTH
    }
    return this.getBorderWidth()
  }

  /** 底部厚边的颜色：主操作用深绿，其余沿用统一描边色 */
  private getBottomColor(): string {
    if (this.usesPressDepth()) {
      return ColorTokens.PRIMARY_PRESSED
    }
    return this.getBorderColor()
  }

  build() {
    Button({ type: ButtonType.Normal }) {
      if (this.loading) {
        LoadingProgress()
          .width(20)
          .height(20)
          .color(this.getIndicatorColor())
      } else {
        Text(this.text)
          .fontSize(this.getFontSize())
          .fontColor(this.getTextColor())
          .fontWeight(this.type === 'primary' ? FontWeight.Bold : FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width(this.block ? '100%' : 'auto')
    .height(this.getHeight())
    .padding({ left: this.getHorizontalPadding(), right: this.getHorizontalPadding() })
    .backgroundColor(this.getBackgroundColor())
    .border({
      width: {
        top: this.getBorderWidth(),
        right: this.getBorderWidth(),
        bottom: this.getBottomWidth(),
        left: this.getBorderWidth()
      },
      color: {
        top: this.getBorderColor(),
        right: this.getBorderColor(),
        bottom: this.getBottomColor(),
        left: this.getBorderColor()
      }
    })
    .borderRadius(this.buttonSize === 'hero' ? RadiusTokens.CONTROL : RadiusTokens.MD)
    .shadow(this.getShadow())
    .constraintSize({ minHeight: TouchTokens.MIN_TARGET })
    // 按下位移：只在有厚底时启用，与厚边收平在同一帧完成，形成"按进面板"
    .translate({ y: this.usesPressDepth() && this.pressed ? DuTokens.PRESS_SHIFT : 0 })
    .scale({
      x: this.usesPressDepth() ? 1 : (this.pressed && !this.disabled ? MotionTokens.PRESS_PRIMARY : 1),
      y: this.usesPressDepth() ? 1 : (this.pressed && !this.disabled ? MotionTokens.PRESS_PRIMARY : 1)
    })
    .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
    .onTouch((event: TouchEvent) => {
      if (this.disabled || this.loading) {
        return
      }
      if (event.type === TouchType.Down) {
        this.pressed = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false
      }
    })
    .opacity(this.disabled ? 0.72 : 1)
    .enabled(!this.disabled && !this.loading)
    .onClick(() => {
      if (!this.disabled && !this.loading) {
        this.onButtonClick?.()
      }
    })
  }
}
