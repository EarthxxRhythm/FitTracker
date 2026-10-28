import { ColorTokens, MediaTokens, MotionTokens } from '../common/styles/DesignTokens'

/**
 * ExerciseDemoImage —— 动作演示媒体的统一渲染壳。
 *
 * 背景：四个消费点（动作库列表卡 / 动作库 sheet / 训练执行页 demoVisual / 动作详情封面）
 * 此前各写一份几乎相同的分支，其中只有列表卡做了 onError 回退，训练执行页与详情页
 * 加载失败就是一块空白方框；四处也都没有加载态，GIF 首帧解码前卡片会「跳」一下。
 *
 * 素材已收敛为 free-exercise-db 实拍单一来源（rawfile/exercise-gifs-photo/）：全彩矩形
 * 实景、无白底，须靠圆角收敛，否则在深色页上是一块亮矩形。旧线稿套系因授权问题移除，
 * 其圆角豁免分支已无素材可作用，photoStyle 保留只是为了消费端的迁移成本。
 *
 * 尺寸有两种形态，用 fixedSize 区分（0 = 流体）：
 * - 流体（fixedSize = 0）：宽度撑满、按 aspect 定高 —— 列表卡与详情封面用；
 * - 固定（fixedSize > 0）：正方形定尺寸 —— 训练执行页的 demoVisual 用。
 * 两形态各自一个 @Builder 而不是三目传 undefined 给 aspectRatio ——
 * ArkTS strict 下把 undefined 喂给布局属性会在编译期被拒。
 */
@Component
export struct ExerciseDemoImage {
  /** rawfile 相对路径，如 exercise-gifs-photo/romanian-deadlift.gif。 */
  @Prop source: string = ''
  /** true = 实拍素材（加圆角收敛）。素材已收敛为实拍单一来源，消费端恒定传 true。 */
  @Prop photoStyle: boolean = true
  /** 实拍素材的圆角半径。 */
  @Prop radius: number = MediaTokens.RADIUS_GRID
  /** 图片适配方式：列表卡用 Cover，sheet/详情用 Contain。 */
  @Prop fit: ImageFit = ImageFit.Cover
  /** 流体形态的宽高比。 */
  @Prop aspect: number = MediaTokens.ASPECT_CARD
  /** 固定形态的边长；0 表示走流体形态。 */
  @Prop fixedSize: number = 0
  /** 无障碍替代文本。 */
  @Prop label: string = ''
  /**
   * 加载失败回调。
   *
   * 组件内的 failed 只覆盖「本次挂载」；页面级失败集合（如动作库的 isGifFailed）
   * 用于记住失败过的 id、避免重绘时反复重试，故需要这个出口把失败上报回去。
   */
  onFailed?: () => void

  @State private loaded: boolean = false
  @State private failed: boolean = false

  /** 失败或路径为空时都落到占位，避免 $rawfile('') 抛错。 */
  private isPlaceholder(): boolean {
    return this.failed || this.source.length === 0
  }

  @Builder
  private buildMedia() {
    if (this.isPlaceholder()) {
      Image($rawfile('pencil-lucide-dumbbell.svg'))
        .width(MediaTokens.PLACEHOLDER_ICON)
        .height(MediaTokens.PLACEHOLDER_ICON)
        .fillColor(MediaTokens.PLACEHOLDER_ICON_COLOR)
    } else {
      Image($rawfile(this.source))
        .width('100%')
        .height('100%')
        .objectFit(this.fit)
        .alt(this.label)
        .opacity(this.loaded ? 1 : 0)
        .animation({ duration: MediaTokens.FADE_DURATION, curve: MotionTokens.EASE_MOTION })
        .onComplete(() => {
          this.loaded = true
        })
        .onError(() => {
          this.failed = true
          if (this.onFailed !== undefined) {
            this.onFailed()
          }
        })
    }
  }

  @Builder
  private buildFluid() {
    Stack({ alignContent: Alignment.Center }) {
      this.buildMedia()
    }
    .width('100%')
    .aspectRatio(this.aspect)
    .backgroundColor(this.isPlaceholder() ? MediaTokens.PLACEHOLDER_BG : Color.Transparent)
    .borderRadius(this.photoStyle ? this.radius : 0)
    .clip(true)
  }

  @Builder
  private buildFixed() {
    Stack({ alignContent: Alignment.Center }) {
      this.buildMedia()
    }
    .width(this.fixedSize)
    .height(this.fixedSize)
    .backgroundColor(this.isPlaceholder() ? MediaTokens.PLACEHOLDER_BG : Color.Transparent)
    .borderRadius(this.photoStyle ? this.radius : 0)
    .clip(true)
  }

  build() {
    if (this.fixedSize > 0) {
      this.buildFixed()
    } else {
      this.buildFluid()
    }
  }
}
