/**
 * ExerciseDetailPage -- local exercise detail from the self-owned action library.
 * Function #17: exercise detail with steps, notes, alternatives, and media section.
 */
import { router } from '@kit.ArkUI'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import ContentRepository, { ExerciseDetailViewModel } from '../../../shared/services/ContentRepository'

@Entry
@Component
export struct ExerciseDetailPage {
  @State hasExercise: boolean = false
  @State exerciseId: string = ''
  @State name: string = ''
  @State nameEn: string = ''
  @State difficultyText: string = ''
  @State primaryMuscleNames: string[] = []
  @State equipmentNames: string[] = []
  @State steps: string[] = []
  @State cues: string[] = []
  @State commonMistakes: string[] = []
  @State safetyNotes: string[] = []
  @State alternativeNames: string[] = []
  @State coverUrl: string = ''
  @State videoUrl: string = ''
  @State videoPlaceholder: string = ''

  aboutToAppear(): void {
    const routeExerciseId: string = this.getRouteExerciseId()
    if (routeExerciseId.length === 0) {
      this.hasExercise = false
      return
    }

    const detail: ExerciseDetailViewModel | undefined = ContentRepository.getExerciseDetailViewModel(routeExerciseId)
    if (detail === undefined) {
      this.hasExercise = false
      return
    }
    this.applyDetail(detail)
  }

  getRouteExerciseId(): string {
    try {
      const params = router.getParams() as Record<string, string>
      if (params.exerciseId !== undefined) {
        return params.exerciseId
      }
    } catch (e) {
      return ''
    }
    return ''
  }

  applyDetail(detail: ExerciseDetailViewModel): void {
    this.hasExercise = true
    this.exerciseId = detail.exerciseId
    this.name = detail.name
    this.nameEn = detail.nameEn
    this.difficultyText = detail.difficultyText
    this.primaryMuscleNames = this.copyStringArray(detail.primaryMuscleNames)
    this.equipmentNames = this.copyStringArray(detail.equipmentNames)
    this.steps = this.copyStringArray(detail.steps)
    this.cues = this.copyStringArray(detail.cues)
    this.commonMistakes = this.copyStringArray(detail.commonMistakes)
    this.safetyNotes = this.copyStringArray(detail.safetyNotes)
    this.alternativeNames = this.copyStringArray(detail.alternativeNames)
    this.coverUrl = detail.coverUrl
    this.videoUrl = detail.videoUrl
    this.videoPlaceholder = detail.videoPlaceholder
  }

  copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  hasCoverAsset(): boolean {
    return this.coverUrl.trim().length > 0
  }

  hasVideoAsset(): boolean {
    return this.videoUrl.trim().length > 0
  }

  hasMediaMetadata(): boolean {
    return this.hasCoverAsset() || this.hasVideoAsset()
  }

  getMediaState(): string {
    if (this.hasMediaMetadata()) {
      return 'ready'
    }
    if (this.videoPlaceholder.trim().length > 0) {
      return 'placeholder'
    }
    return 'empty'
  }

  getMediaStatusText(): string {
    if (this.hasCoverAsset() && this.hasVideoAsset()) {
      return '已具备封面与视频元数据'
    }
    if (this.hasVideoAsset()) {
      return '已具备视频元数据'
    }
    if (this.hasCoverAsset()) {
      return '已具备封面元数据'
    }
    if (this.videoPlaceholder.trim().length > 0) {
      return '媒体能力预留中'
    }
    return '暂无可展示媒体'
  }

  getMediaPrimaryText(): string {
    if (this.hasCoverAsset()) {
      return '封面素材已关联'
    }
    if (this.hasVideoAsset()) {
      return '动作演示待接入播放器'
    }
    if (this.videoPlaceholder.trim().length > 0) {
      return '媒体位已预留'
    }
    return '暂时没有媒体素材'
  }

  getMediaSecondaryText(): string {
    if (this.hasCoverAsset() && this.hasVideoAsset()) {
      return '当前先展示素材状态与路径，后续可直接接入封面加载和视频播放。'
    }
    if (this.hasMediaMetadata()) {
      return '当前素材信息已可用，待播放器和资源映射补齐后可升级为真实预览。'
    }
    if (this.videoPlaceholder.trim().length > 0) {
      return this.videoPlaceholder
    }
    return '内容库暂未提供封面、视频或占位说明。'
  }

  getMediaToneColor(): string {
    if (this.hasMediaMetadata()) {
      return ColorTokens.PRIMARY
    }
    if (this.videoPlaceholder.trim().length > 0) {
      return ColorTokens.ACCENT
    }
    return ColorTokens.TEXT_DISABLED
  }

  @Builder
  buildMediaMetaRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .width(72)

      Text(value)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  buildMediaSection() {
    Column({ space: SpacingTokens.MD }) {
      Row() {
        Column({ space: SpacingTokens.XS }) {
          Text('动作演示')
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(this.getMediaStatusText())
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.hasVideoAsset() ? '视频' : (this.hasCoverAsset() ? '封面' : '待补充'))
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.TEXT_ON_PRIMARY)
          .padding({
            top: SpacingTokens.XS,
            bottom: SpacingTokens.XS,
            left: SpacingTokens.SM,
            right: SpacingTokens.SM
          })
          .backgroundColor(this.getMediaToneColor())
          .borderRadius(RadiusTokens.FULL)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: SpacingTokens.MD }) {
        Column({ space: SpacingTokens.SM }) {
          Text(this.hasCoverAsset() ? 'MEDIA' : 'INFO')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_ON_PRIMARY)

          Text(this.hasCoverAsset() ? '封面' : (this.hasVideoAsset() ? '视频' : '占位'))
            .fontSize(FontTokens.HEADLINE_SIZE)
            .fontWeight(FontTokens.HEADLINE_WEIGHT)
            .fontColor(ColorTokens.TEXT_ON_PRIMARY)
        }
        .width(96)
        .height(TouchTokens.HERO_HEIGHT)
        .padding(SpacingTokens.MD)
        .borderRadius(RadiusTokens.SM)
        .backgroundColor(this.getMediaToneColor())
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.End)

        Column({ space: SpacingTokens.SM }) {
          Text(this.getMediaPrimaryText())
            .fontSize(FontTokens.BODY_SIZE)
            .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(this.getMediaSecondaryText())
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .width('100%')

          if (this.getMediaState() === 'ready') {
            Column({ space: SpacingTokens.XS }) {
              if (this.hasCoverAsset()) {
                this.buildMediaMetaRow('封面路径', this.coverUrl)
              }
              if (this.hasVideoAsset()) {
                this.buildMediaMetaRow('视频路径', this.videoUrl)
              }
            }
            .width('100%')
            .padding(SpacingTokens.SM)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.BG_SECONDARY)
          }

          if (this.getMediaState() === 'placeholder') {
            Column({ space: SpacingTokens.XS }) {
              Text('当前页面保留媒体承载区，便于后续平滑接入真实封面、缓冲态和播放控件。')
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .width('100%')
            }
            .width('100%')
            .padding(SpacingTokens.SM)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.BG_SECONDARY)
          }

          if (this.getMediaState() === 'empty') {
            Column({ space: SpacingTokens.XS }) {
              Text('可先补齐 coverUrl 或 videoUrl，再接入真实媒体组件。')
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .width('100%')
            }
            .width('100%')
            .padding(SpacingTokens.SM)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.BG_SECONDARY)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildTag(label: string) {
    Text(label)
      .fontSize(FontTokens.CAPTION_SIZE)
      .fontColor(ColorTokens.TEXT_ON_PRIMARY)
      .padding({
        top: SpacingTokens.XS,
        bottom: SpacingTokens.XS,
        left: SpacingTokens.SM,
        right: SpacingTokens.SM
      })
      .backgroundColor(ColorTokens.SURFACE_ELEVATED)
      .borderRadius(RadiusTokens.FULL)
      .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
  }

  @Builder
  buildNumberedSection(title: string, values: string[]) {
    Column({ space: SpacingTokens.SM }) {
      Text(title)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      ForEach(values, (value: string, index: number) => {
        Row() {
          Text((index + 1).toString())
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_ON_PRIMARY)
            .width(24)
            .height(24)
            .textAlign(TextAlign.Center)
            .backgroundColor(ColorTokens.PRIMARY)
            .borderRadius(RadiusTokens.FULL)

          Text(value)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .layoutWeight(1)
            .margin({ left: SpacingTokens.SM })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (value: string, index: number) => title + value + index.toString())
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildPlainSection(title: string, values: string[], emptyText: string) {
    Column({ space: SpacingTokens.SM }) {
      Text(title)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      if (values.length === 0) {
        Text(emptyText)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
      }

      ForEach(values, (value: string) => {
        Text(value)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .width('100%')
      }, (value: string) => title + value)
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        if (!this.hasExercise) {
          Column({ space: SpacingTokens.SM }) {
            Text('动作详情')
              .fontSize(FontTokens.DISPLAY_SIZE)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text('没有找到这个动作，请从训练预览页重新进入。')
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)
          .alignItems(HorizontalAlign.Start)
        }

        if (this.hasExercise) {
          Column({ space: SpacingTokens.SM }) {
            Text(this.name)
              .fontSize(FontTokens.DISPLAY_SIZE)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text(this.exerciseId)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)

            Text(this.nameEn)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)

            Flex({ wrap: FlexWrap.Wrap }) {
              this.buildTag(this.difficultyText)
              ForEach(this.primaryMuscleNames, (muscleName: string) => {
                this.buildTag(muscleName)
              }, (muscleName: string) => muscleName)
              ForEach(this.equipmentNames, (equipmentName: string) => {
                this.buildTag(equipmentName)
              }, (equipmentName: string) => equipmentName)
            }
            .width('100%')
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)
          .alignItems(HorizontalAlign.Start)

          this.buildNumberedSection('动作步骤', this.steps)
          this.buildPlainSection('注意事项', this.safetyNotes, '暂无额外注意事项')
          this.buildPlainSection('替代动作', this.alternativeNames, '暂无替代动作')
          this.buildPlainSection('训练提示', this.cues, '暂无训练提示')
          this.buildPlainSection('常见错误', this.commonMistakes, '暂无常见错误记录')

          this.buildMediaSection()
        }
      }
      .width('100%')
      .padding(SpacingTokens.LG)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
