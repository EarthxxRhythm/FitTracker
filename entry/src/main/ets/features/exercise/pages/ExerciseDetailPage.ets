/**
 * ExerciseDetailPage -- local exercise detail from the self-owned action library.
 * Function #13: local exercise detail for MVP.
 */
import { router } from '@kit.ArkUI'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens } from '../../../common/styles/DesignTokens'
import { ExerciseContent } from '../../../shared/models/TrainingModels'
import ContentRepository from '../../../shared/services/ContentRepository'

@Entry
@Component
export struct ExerciseDetailPage {
  @State hasExercise: boolean = false
  @State exerciseId: string = ''
  @State name: string = ''
  @State difficulty: string = ''
  @State primaryMuscleNames: string[] = []
  @State equipmentNames: string[] = []
  @State steps: string[] = []
  @State cues: string[] = []
  @State commonMistakes: string[] = []
  @State safetyNotes: string[] = []
  @State videoStatusText: string = ''

  aboutToAppear(): void {
    const routeExerciseId: string = this.getRouteExerciseId()
    if (routeExerciseId.length === 0) {
      this.hasExercise = false
      return
    }

    const exercise: ExerciseContent | undefined = ContentRepository.getExerciseById(routeExerciseId)
    if (exercise === undefined) {
      this.hasExercise = false
      return
    }
    this.applyExercise(exercise)
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

  applyExercise(exercise: ExerciseContent): void {
    this.hasExercise = true
    this.exerciseId = exercise.exerciseId
    this.name = exercise.nameZh
    this.difficulty = exercise.difficulty
    this.primaryMuscleNames = this.mapMuscleNames(exercise.primaryMuscleIds)
    this.equipmentNames = this.mapEquipmentNames(exercise.equipmentIds)
    this.steps = this.copyStringArray(exercise.steps)
    this.cues = this.copyStringArray(exercise.cues)
    this.commonMistakes = this.copyStringArray(exercise.commonMistakes)
    this.safetyNotes = this.copyStringArray(exercise.safetyNotes)
    this.videoStatusText = ContentRepository.hasVideoAsset(exercise) ? '视频素材已接入本地动作库' : '视频素材待接入自建数据库'
  }

  mapMuscleNames(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(ContentRepository.getMuscleName(source[index]))
    }
    return values
  }

  mapEquipmentNames(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(ContentRepository.getEquipmentName(source[index]))
    }
    return values
  }

  copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
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
  buildListSection(title: string, values: string[]) {
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

            Flex({ wrap: FlexWrap.Wrap }) {
              this.buildTag(this.difficulty)
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

          this.buildListSection('动作步骤', this.steps)
          this.buildListSection('训练提示', this.cues)
          this.buildListSection('常见错误', this.commonMistakes)
          this.buildListSection('安全注意', this.safetyNotes)

          Text(this.videoStatusText)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontColor(ColorTokens.TEXT_SECONDARY)
            .width('100%')
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.SURFACE_PRIMARY)
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
