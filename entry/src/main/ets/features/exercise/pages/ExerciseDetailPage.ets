/**
 * ExerciseDetailPage -- local exercise detail from the self-owned action library.
 * Function #17: exercise detail with steps, notes, alternatives, and media section.
 */
import { Context } from '@kit.AbilityKit'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import { AppButton } from '../../../components/AppButton'
import { AppCard } from '../../../components/AppCard'
import ContentRepository, { ExerciseDetailViewModel } from '../../../shared/services/ContentRepository'
import ExerciseMediaResolverService, {
  ExerciseMediaAssetInfo,
  ExerciseMediaMetadata,
  ExerciseMediaPresentation
} from '../../../shared/services/ExerciseMediaResolverService'
import MonetizationGateService from '../../../shared/services/MonetizationGateService'
import PremiumExerciseContentService, {
  PremiumExerciseContentPresentation,
  PremiumExerciseContentTile
} from '../../../shared/services/PremiumExerciseContentService'
import { AppRoutes } from '../../../app/AppRoutes'
import { MonetizationCapability } from '../../../shared/models/MonetizationModels'

function createEmptyExerciseMediaMetadata(): ExerciseMediaMetadata {
  const metadata: ExerciseMediaMetadata = {
    coverSourceLabel: '',
    videoSourceLabel: '',
    mediaLicenseText: ''
  }
  return metadata
}

@Entry
@Component
export struct ExerciseDetailPage {
  mediaPresentation: ExerciseMediaPresentation =
    ExerciseMediaResolverService.resolve('', '', '', createEmptyExerciseMediaMetadata())

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
  @State coverSourceLabel: string = ''
  @State videoSourceLabel: string = ''
  @State mediaLicenseText: string = ''
  @State videoPlaceholder: string = ''
  @State premiumContentPresentation: PremiumExerciseContentPresentation =
    PremiumExerciseContentService.createDefaultPresentation()

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  aboutToAppear(): void {
    this.loadPage()
  }

  async loadPage(): Promise<void> {
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
    await this.loadPremiumContent(detail)
  }

  getRouteExerciseId(): string {
    try {
      const params = this.getUIContext().getRouter().getParams() as Record<string, string>
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
    this.coverSourceLabel = detail.coverSourceLabel
    this.videoSourceLabel = detail.videoSourceLabel
    this.mediaLicenseText = detail.mediaLicenseText
    this.videoPlaceholder = detail.videoPlaceholder
    this.mediaPresentation = ExerciseMediaResolverService.resolve(
      this.coverUrl,
      this.videoUrl,
      this.videoPlaceholder,
      this.createMediaMetadata()
    )
  }

  createMediaMetadata(): ExerciseMediaMetadata {
    const metadata: ExerciseMediaMetadata = {
      coverSourceLabel: this.coverSourceLabel,
      videoSourceLabel: this.videoSourceLabel,
      mediaLicenseText: this.mediaLicenseText
    }
    return metadata
  }

  async loadPremiumContent(detail: ExerciseDetailViewModel): Promise<void> {
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.premiumContentPresentation = PremiumExerciseContentService.createPresentation(true, 'free', detail)
        return
      }
      const gateResult = await MonetizationGateService.getGateResult(context, 'premium_content')
      this.premiumContentPresentation = PremiumExerciseContentService.createPresentation(
        !gateResult.allowed,
        gateResult.activeTier,
        detail
      )
    } catch (e) {
      this.premiumContentPresentation = PremiumExerciseContentService.createPresentation(true, 'free', detail)
    }
  }

  copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index: number = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  getMuscleSummary(): string {
    if (this.primaryMuscleNames.length === 0) {
      return '目标肌群待补充'
    }
    return this.primaryMuscleNames.join(' / ')
  }

  getEquipmentSummary(): string {
    if (this.equipmentNames.length === 0) {
      return '器械要求待补充'
    }
    return this.equipmentNames.join(' / ')
  }

  getHeroSummary(): string {
    const focusText: string = this.getMuscleSummary()
    const equipmentText: string = this.getEquipmentSummary()
    if (this.cues.length > 0) {
      return focusText + ' | ' + equipmentText + ' | ' + this.cues[0]
    }
    if (this.safetyNotes.length > 0) {
      return focusText + ' | ' + equipmentText + ' | ' + this.safetyNotes[0]
    }
    return focusText + ' | ' + equipmentText + ' | 先确认动作路径和发力顺序'
  }

  getHeroEyebrow(): string {
    if (this.mediaPresentation.cover.canRenderInline || this.mediaPresentation.video.canRenderInline) {
      return '动作学习'
    }
    if (this.mediaPresentation.cover.hasReference || this.mediaPresentation.video.hasReference) {
      return '动作资料'
    }
    return '动作详情'
  }

  getMetaSummary(): string {
    if (this.nameEn.length > 0) {
      return this.nameEn
    }
    return '动作编号 ' + this.exerciseId
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

  getMediaToneBackgroundColor(tone: string): string {
    if (tone === 'primary') {
      return ColorTokens.OVERLAY_PRIMARY
    }
    if (tone === 'accent') {
      return ColorTokens.OVERLAY_ACCENT
    }
    return ColorTokens.BORDER_SUBTLE
  }

  getMediaPreviewLabel(media: ExerciseMediaPresentation): string {
    if (media.cover.canRenderInline) {
      return '封面预览'
    }
    if (media.video.canRenderInline) {
      return '视频资源已就绪'
    }
    if (media.cover.hasReference || media.video.hasReference) {
      return '资源引用已登记'
    }
    return '媒体待补充'
  }

  getAssetAvailabilityLabel(asset: ExerciseMediaAssetInfo): string {
    if (asset.canRenderInline) {
      return '可内联'
    }
    if (asset.hasReference) {
      return '仅引用'
    }
    return '缺失'
  }

  getAssetAvailabilityColor(asset: ExerciseMediaAssetInfo): string {
    if (asset.canRenderInline) {
      return ColorTokens.SUCCESS
    }
    if (asset.hasReference) {
      return ColorTokens.ACCENT
    }
    return ColorTokens.TEXT_DISABLED
  }

  getStatusPanelColor(tone: string): string {
    if (tone === 'warning') {
      return ColorTokens.WARNING
    }
    if (tone === 'error') {
      return ColorTokens.ERROR
    }
    return ColorTokens.INFO
  }

  getStatusPanelBackgroundColor(tone: string): string {
    if (tone === 'warning') {
      return ColorTokens.WARNING_BG
    }
    if (tone === 'error') {
      return ColorTokens.ERROR_BG
    }
    return ColorTokens.INFO_BG
  }

  getStatusEmptyText(tone: string): string {
    if (tone === 'warning') {
      return '暂无安全注意'
    }
    if (tone === 'error') {
      return '暂无常见错误'
    }
    return '暂无训练提示'
  }

  openMonetizationHub(capability: MonetizationCapability, sourceLabel: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: AppRoutes.MONETIZATION_HUB,
        params: {
          focusCapability: capability,
          focusSourceLabel: sourceLabel
        }
      })
    } catch (e) {
      // stay on current page
    }
  }

  getMediaCapabilityGuideText(): string {
    if (this.premiumContentPresentation.locked) {
      return '基础演示和动作要点继续保留在免费主链里；更深训练清单和进阶内容再按需要解锁。'
    }
    return '当前权益已经覆盖更深训练清单；基础演示和进阶内容都可以继续直接查看。'
  }

  getPremiumActionText(): string {
    if (this.premiumContentPresentation.locked) {
      return '查看 Plus 权益'
    }
    return '查看当前权益边界'
  }

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        if (!this.hasExercise) {
          AppCard({ variant: 'panel', cardPadding: 'default' }) {
            Column({ space: SpacingTokens.MD }) {
              Text('动作详情')
                .fontSize(FontTokens.MICRO_SIZE)
                .fontWeight(FontTokens.MICRO_WEIGHT)
                .fontColor(ColorTokens.TEXT_TERTIARY)

              Text('未找到动作')
                .fontSize(FontTokens.DISPLAY_SIZE)
                .fontWeight(FontTokens.DISPLAY_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('当前入口没有带上有效的动作信息，请从训练预览页或训练回顾页重新进入。')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
                .lineHeight(FontTokens.BODY_LINE_HEIGHT)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }

        if (this.hasExercise) {
          this.buildHeroSection()
          this.buildDetailLaneHeader('媒体与演示', '先确认媒体资源和演示状态，再决定直接训练还是查看更深内容。')
          this.buildMediaSection()
          this.buildDetailLaneHeader('执行与替代', '把动作步骤、关键提醒和替代动作放在同一段，方便训练前快速过一遍。')
          this.buildTechniqueSection()
          this.buildAlternativeSection()
          this.buildDetailLaneHeader('扩展与资料', '把高级内容预埋和资料元信息收在尾部，不干扰前面的主任务。')
          this.buildPremiumContentSection()
          this.buildMetadataSection()
        }
      }
      .width('100%')
      .padding(SpacingTokens.LG)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }

  @Builder
  buildHeroSection() {
    AppCard({ variant: 'panel', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Row() {
          Column({ space: SpacingTokens.XS }) {
            Text(this.getHeroEyebrow())
              .fontSize(FontTokens.MICRO_SIZE)
              .fontWeight(FontTokens.MICRO_WEIGHT)
              .fontColor(ColorTokens.TEXT_TERTIARY)

            Text(this.name)
              .fontSize(FontTokens.DISPLAY_SIZE)
              .fontWeight(FontTokens.DISPLAY_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.getMetaSummary())
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.mediaPresentation.badgeText)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .padding({
              top: SpacingTokens.XS,
              bottom: SpacingTokens.XS,
              left: SpacingTokens.SM,
              right: SpacingTokens.SM
            })
            .backgroundColor(this.getMediaToneBackgroundColor(this.mediaPresentation.tone))
            .borderRadius(RadiusTokens.FULL)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text(this.getHeroSummary())
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .lineHeight(FontTokens.BODY_LINE_HEIGHT)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Flex({ wrap: FlexWrap.Wrap }) {
          this.buildTag(this.difficultyText, ColorTokens.OVERLAY_ACCENT, ColorTokens.ACCENT)
          ForEach(this.primaryMuscleNames, (muscleName: string) => {
            this.buildTag(muscleName, ColorTokens.OVERLAY_PRIMARY, ColorTokens.PRIMARY)
          }, (muscleName: string) => 'muscle_' + muscleName)
          ForEach(this.equipmentNames, (equipmentName: string) => {
            this.buildTag(equipmentName, ColorTokens.SURFACE_ELEVATED, ColorTokens.TEXT_SECONDARY)
          }, (equipmentName: string) => 'equipment_' + equipmentName)
        }
        .width('100%')

        Row({ space: SpacingTokens.MD }) {
          this.buildMetricTile('步骤', this.steps.length.toString(), '执行序列')
          this.buildMetricTile('提示', this.cues.length.toString(), '关键提醒')
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildMediaSection() {
    AppCard({ variant: 'panel', cardPadding: 'default' }) {
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

          Text(this.getMediaPreviewLabel(this.mediaPresentation))
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .padding({
              top: SpacingTokens.XS,
              bottom: SpacingTokens.XS,
              left: SpacingTokens.SM,
              right: SpacingTokens.SM
            })
            .backgroundColor(this.getMediaToneBackgroundColor(this.mediaPresentation.tone))
            .borderRadius(RadiusTokens.FULL)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        this.buildMediaPreview(this.mediaPresentation)

        Row({ space: SpacingTokens.MD }) {
          this.buildMetricTile('封面', this.getAssetAvailabilityLabel(this.mediaPresentation.cover), '静态预览')
          this.buildMetricTile('视频', this.getAssetAvailabilityLabel(this.mediaPresentation.video), '动态演示')
        }
        .width('100%')

        Text(this.mediaPresentation.summaryText)
          .fontSize(FontTokens.BODY_SIZE)
          .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .width('100%')

        Text(this.mediaPresentation.detailText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
          .width('100%')

        Text(this.getMediaCapabilityGuideText())
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_TERTIARY)
          .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
          .width('100%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .borderRadius(RadiusTokens.MD)
          .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })

        this.buildInfoRow('统一来源', this.mediaPresentation.sourceNote)
        this.buildInfoRow('统一授权', this.mediaPresentation.licenseNote)

        this.buildMediaAssetBlock('封面资源', this.mediaPresentation.cover)
        this.buildMediaAssetBlock('视频资源', this.mediaPresentation.video)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildPremiumContentSection() {
    AppCard({ variant: this.premiumContentPresentation.locked ? 'outlined' : 'panel', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Row() {
          Column({ space: SpacingTokens.XS }) {
            Text(this.premiumContentPresentation.title)
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontTokens.TITLE_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text(this.premiumContentPresentation.description)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.premiumContentPresentation.statusLabel)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .padding({
              top: SpacingTokens.XS,
              bottom: SpacingTokens.XS,
              left: SpacingTokens.SM,
              right: SpacingTokens.SM
            })
            .backgroundColor(
              this.getMediaToneBackgroundColor(this.premiumContentPresentation.locked ? 'accent' : 'primary')
            )
            .borderRadius(RadiusTokens.FULL)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        ForEach(this.premiumContentPresentation.tiles, (tile: PremiumExerciseContentTile) => {
          Column({ space: SpacingTokens.XS }) {
            Text(tile.label)
              .fontSize(FontTokens.SMALL_SIZE)
              .fontColor(ColorTokens.TEXT_TERTIARY)

            Text(tile.value)
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .width('100%')

            Text(tile.note)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
              .width('100%')
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_SECONDARY)
          .borderRadius(RadiusTokens.MD)
          .alignItems(HorizontalAlign.Start)
        }, (tile: PremiumExerciseContentTile) => tile.tileId)

        Column({ space: SpacingTokens.SM }) {
          Text('训练清单')
            .fontSize(FontTokens.BODY_SIZE)
            .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          ForEach(this.premiumContentPresentation.checklist, (item: string, index: number) => {
            Row({ space: SpacingTokens.SM }) {
              Text('路')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(this.premiumContentPresentation.locked ? ColorTokens.ACCENT : ColorTokens.PRIMARY)
                .margin({ top: SpacingTokens.XS })

              Text(item)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .lineHeight(FontTokens.BODY_LINE_HEIGHT)
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }, (item: string, index: number) => 'premium_check_' + index.toString() + '_' + item)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Text(this.premiumContentPresentation.supportingText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
          .width('100%')

        if (this.premiumContentPresentation.locked) {
          AppButton({
            text: this.getPremiumActionText(),
            type: 'primary',
            buttonSize: 'medium',
            block: true,
            onButtonClick: () => {
              this.openMonetizationHub('premium_content', '动作详情')
            }
          })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildTechniqueSection() {
    AppCard({ variant: 'elevated', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Text('执行要点')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        this.buildNumberedSection('动作步骤', this.steps, '暂无动作步骤')
        this.buildDivider()
        this.buildStatusPanel('训练提示', this.cues, 'info')
        this.buildStatusPanel('常见错误', this.commonMistakes, 'error')
        this.buildStatusPanel('安全注意', this.safetyNotes, 'warning')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildAlternativeSection() {
    AppCard({ variant: 'outlined', cardPadding: 'default' }) {
      Column({ space: SpacingTokens.MD }) {
        Text('替代动作')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        Text('如果当前器械条件不匹配，或你想降低动作门槛，可以先从这里选择同目标动作。')
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)

        if (this.alternativeNames.length === 0) {
          Text('当前没有登记替代动作，可先按当前动作完成训练。')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .width('100%')
        }

        ForEach(this.alternativeNames, (alternativeName: string, index: number) => {
          Row({ space: SpacingTokens.SM }) {
            Text((index + 1).toString())
              .fontSize(FontTokens.SMALL_SIZE)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .width(24)
              .height(24)
              .textAlign(TextAlign.Center)
              .backgroundColor(ColorTokens.SURFACE_ELEVATED)
              .borderRadius(RadiusTokens.FULL)

            Text(alternativeName)
              .fontSize(FontTokens.BODY_SIZE)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .layoutWeight(1)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .backgroundColor(ColorTokens.SURFACE_SECONDARY)
          .borderRadius(RadiusTokens.MD)
        }, (alternativeName: string, index: number) => 'alternative_' + alternativeName + '_' + index.toString())
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildMetadataSection() {
    AppCard({ variant: 'outlined', cardPadding: 'compact' }) {
      Column({ space: SpacingTokens.SM }) {
        Text('资料元信息')
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        this.buildInfoRow('动作编号', this.exerciseId)

        if (this.nameEn.length > 0) {
          this.buildInfoRow('英文名称', this.nameEn)
        }

        this.buildInfoRow('目标肌群', this.getMuscleSummary())
        this.buildInfoRow('器械要求', this.getEquipmentSummary())
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildTag(label: string, backgroundColor: string, textColor: string) {
    Text(label)
      .fontSize(FontTokens.CAPTION_SIZE)
      .fontColor(textColor)
      .padding({
        top: SpacingTokens.XS,
        bottom: SpacingTokens.XS,
        left: SpacingTokens.SM,
        right: SpacingTokens.SM
      })
      .backgroundColor(backgroundColor)
      .borderRadius(RadiusTokens.FULL)
      .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
  }

  @Builder
  buildDetailLaneHeader(title: string, description: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(title)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontTokens.TITLE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(description)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildMetricTile(label: string, value: string, note: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)

      Text(value)
        .fontSize(FontTokens.HEADLINE_SIZE)
        .fontWeight(FontTokens.HEADLINE_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(note)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
    }
    .layoutWeight(1)
    .padding(SpacingTokens.MD)
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
    .borderRadius(RadiusTokens.MD)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildInfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)
        .width(72)

      Text(value)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
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
          .borderRadius(RadiusTokens.MD)
          .objectFit(ImageFit.Cover)

        Column({ space: SpacingTokens.XS }) {
          Text('动作预览')
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontWeight(FontTokens.TITLE_WEIGHT)
            .fontColor(ColorTokens.TEXT_PRIMARY)

          Text(media.cover.stateText)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .padding(SpacingTokens.MD)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(ColorTokens.OVERLAY_PRIMARY)
        .borderRadius(RadiusTokens.SM)
        .margin(SpacingTokens.MD)
      }
      .width('100%')
      .height(TouchTokens.HERO_HEIGHT)
    } else {
      Column({ space: SpacingTokens.SM }) {
        Text(this.getMediaPreviewLabel(media))
          .fontSize(FontTokens.TITLE_SIZE)
          .fontWeight(FontTokens.TITLE_WEIGHT)
          .fontColor(ColorTokens.TEXT_PRIMARY)

        Text(media.statusText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height(TouchTokens.HERO_HEIGHT)
      .padding(SpacingTokens.LG)
      .borderRadius(RadiusTokens.MD)
      .backgroundColor(ColorTokens.SURFACE_SECONDARY)
      .justifyContent(FlexAlign.Center)
    }
  }

  @Builder
  buildMediaAssetBlock(title: string, asset: ExerciseMediaAssetInfo) {
    AppCard({ variant: 'outlined', cardPadding: 'compact' }) {
      Column({ space: SpacingTokens.SM }) {
        Row() {
          Column({ space: SpacingTokens.XS }) {
            Text(title)
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text(asset.stateText)
              .fontSize(FontTokens.SMALL_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.getAssetAvailabilityLabel(asset))
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .padding({
              top: SpacingTokens.XS,
              bottom: SpacingTokens.XS,
              left: SpacingTokens.SM,
              right: SpacingTokens.SM
            })
            .backgroundColor(this.getMediaToneBackgroundColor(asset.canRenderInline ? 'primary' : (asset.hasReference ? 'accent' : 'default')))
            .borderRadius(RadiusTokens.FULL)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(asset.primaryText)
          .fontSize(FontTokens.CAPTION_SIZE)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .width('100%')

        Text(asset.secondaryText)
          .fontSize(FontTokens.SMALL_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .width('100%')

        if (asset.originalUrl.length > 0) {
          this.buildInfoRow('资源引用', asset.originalUrl)
        }
        this.buildInfoRow('来源说明', asset.sourceLabel)
        this.buildInfoRow('授权口径', asset.licenseLabel)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  buildNumberedSection(title: string, values: string[], emptyText: string) {
    Column({ space: SpacingTokens.SM }) {
      Text(title)
        .fontSize(FontTokens.BODY_SIZE)
        .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      if (values.length === 0) {
        Text(emptyText)
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .width('100%')
      }

      ForEach(values, (value: string, index: number) => {
        Row({ space: SpacingTokens.SM }) {
          Text((index + 1).toString())
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .width(24)
            .height(24)
            .textAlign(TextAlign.Center)
            .backgroundColor(ColorTokens.PRIMARY)
            .borderRadius(RadiusTokens.FULL)

          Text(value)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .lineHeight(FontTokens.BODY_LINE_HEIGHT)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (value: string, index: number) => title + '_' + value + '_' + index.toString())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildStatusPanel(title: string, values: string[], tone: string) {
    Column({ space: SpacingTokens.SM }) {
      Text(title)
        .fontSize(FontTokens.BODY_SIZE)
        .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      if (values.length === 0) {
        Text(this.getStatusEmptyText(tone))
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_SECONDARY)
          .width('100%')
      }

      ForEach(values, (value: string, index: number) => {
        Row({ space: SpacingTokens.SM }) {
          Text('·')
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(this.getStatusPanelColor(tone))
            .margin({ top: SpacingTokens.XS })

          Text(value)
            .fontSize(FontTokens.BODY_SIZE)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .lineHeight(FontTokens.BODY_LINE_HEIGHT)
            .layoutWeight(1)
        }
        .width('100%')
        .padding(SpacingTokens.MD)
        .backgroundColor(this.getStatusPanelBackgroundColor(tone))
        .borderRadius(RadiusTokens.MD)
        .alignItems(VerticalAlign.Top)
      }, (value: string, index: number) => title + '_' + value + '_' + index.toString())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildDivider() {
    Row()
      .width('100%')
      .height(1)
      .backgroundColor(ColorTokens.DIVIDER)
  }
}
