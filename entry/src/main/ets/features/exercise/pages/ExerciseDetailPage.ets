/**
 * ExerciseDetailPage -- local exercise detail from the self-owned action library.
 * Function #17: exercise detail with steps, notes, alternatives, and media section.
 */
import { router } from '@kit.ArkUI'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import ContentRepository, { ExerciseDetailViewModel } from '../../../shared/services/ContentRepository'
import ExerciseMediaResolverService, {
  ExerciseMediaAssetInfo,
  ExerciseMediaPresentation
} from '../../../shared/services/ExerciseMediaResolverService'

@Entry
@Component
export struct ExerciseDetailPage {
  mediaPresentation: ExerciseMediaPresentation = ExerciseMediaResolverService.resolve('', '', '')
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
    this.mediaPresentation = ExerciseMediaResolverService.resolve(
      this.coverUrl,
      this.videoUrl,
      this.videoPlaceholder
    )
  }

  copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index: number = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  getMediaToneColor(tone: string): string {
    if (tone === 'primary') {
      return ColorTokens.PRIMARY
    }
    if (tone === 'accent') {
      return ColorTokens.ACCENT
    }
    return ColorTokens.TEXT_DISABLED
  }

  getMediaPreviewLabel(media: ExerciseMediaPresentation): string {
    if (media.cover.canRenderInline) {
      return '封面预览'
    }
    if (media.video.canRenderInline) {
      return '视频就绪'
    }
    if (media.cover.hasReference || media.video.hasReference) {
      return '引用已登记'
    }
    return '媒体待补齐'
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
  buildMediaMetaRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .width(84)

      Text(value)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .layoutWeight(1)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  buildMediaPreview(media: ExerciseMediaPresentation) {
    if (media.cover.canRenderInline) {
      Stack({ alignContent: Alignment.BottomStart }) {
        Image(media.cover.resolvedUrl)
          .width('100%')
          .height(TouchTokens.HERO_HEIGHT)
          .borderRadius(RadiusTokens.SM)
          .objectFit(ImageFit.Cover)

        Column({ space: SpacingTokens.XS }) {
          Text('封面预览')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_ON_PRIMARY)

          Text(media.cover.stateText)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_ON_PRIMARY)
        }
        .padding(SpacingTokens.MD)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(ColorTokens.OVERLAY_PRIMARY)
        .borderRadius(RadiusTokens.SM)
      }
      .width('100%')
      .height(TouchTokens.HERO_HEIGHT)
    } else {
      Column({ space: SpacingTokens.SM }) {
        Text(this.getMediaPreviewLabel(media))
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_ON_PRIMARY)

        Text(media.statusText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_ON_PRIMARY)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height(TouchTokens.HERO_HEIGHT)
      .padding(SpacingTokens.LG)
      .borderRadius(RadiusTokens.SM)
      .backgroundColor(this.getMediaToneColor(media.tone))
      .justifyContent(FlexAlign.Center)
    }
  }

  @Builder
  buildMediaAssetBlock(title: string, asset: ExerciseMediaAssetInfo) {
    Column({ space: SpacingTokens.SM }) {
      Row() {
        Column({ space: SpacingTokens.XS }) {
          Text(title)
            .fontSize(FontTokens.TITLE_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(asset.stateText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(asset.canRenderInline ? '可用' : (asset.hasReference ? '降级' : '缺失'))
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.TEXT_ON_PRIMARY)
          .padding({
            top: SpacingTokens.XS,
            bottom: SpacingTokens.XS,
            left: SpacingTokens.SM,
            right: SpacingTokens.SM
          })
          .backgroundColor(asset.canRenderInline ? ColorTokens.PRIMARY : (asset.hasReference ? ColorTokens.ACCENT : ColorTokens.TEXT_DISABLED))
          .borderRadius(RadiusTokens.FULL)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(asset.primaryText)
        .fontSize(FontTokens.BODY_SIZE)
        .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(asset.secondaryText)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .width('100%')

      if (asset.originalUrl.length > 0) {
        this.buildMediaMetaRow('资源引用', asset.originalUrl)
      }
      this.buildMediaMetaRow('来源说明', asset.sourceLabel)
      this.buildMediaMetaRow('授权口径', asset.licenseLabel)
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.BG_SECONDARY)
    .alignItems(HorizontalAlign.Start)
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

          Text(this.mediaPresentation.statusText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.mediaPresentation.badgeText)
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.TEXT_ON_PRIMARY)
          .padding({
            top: SpacingTokens.XS,
            bottom: SpacingTokens.XS,
            left: SpacingTokens.SM,
            right: SpacingTokens.SM
          })
          .backgroundColor(this.getMediaToneColor(this.mediaPresentation.tone))
          .borderRadius(RadiusTokens.FULL)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.buildMediaPreview(this.mediaPresentation)

      Text(this.mediaPresentation.summaryText)
        .fontSize(FontTokens.BODY_SIZE)
        .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .width('100%')

      Text(this.mediaPresentation.detailText)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .width('100%')

      this.buildMediaMetaRow('统一来源', this.mediaPresentation.sourceNote)
      this.buildMediaMetaRow('统一授权', this.mediaPresentation.licenseNote)

      this.buildMediaAssetBlock('封面', this.mediaPresentation.cover)
      this.buildMediaAssetBlock('视频', this.mediaPresentation.video)
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .borderRadius(RadiusTokens.SM)
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
    .alignItems(HorizontalAlign.Start)
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
