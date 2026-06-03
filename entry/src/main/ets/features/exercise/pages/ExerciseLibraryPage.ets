/**
 * ExerciseLibraryPage -- exercise library main entry with search and filters.
 * Function #13-17: exercise list, search, muscle filter, equipment filter, detail navigation.
 */
import { router } from '@kit.ArkUI'
import { AppRoutes } from '../../../app/AppRoutes'
import { SearchBar } from '../../../components/SearchBar'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import { EquipmentItem, MuscleGroup } from '../../../shared/models/TrainingModels'
import ContentRepository, { ExerciseLibraryItem } from '../../../shared/services/ContentRepository'

interface ExerciseFilterOption {
  id: string
  label: string
}

function createExerciseFilterOption(id: string, label: string): ExerciseFilterOption {
  const option: ExerciseFilterOption = {
    id: id,
    label: label
  }
  return option
}

function copyStringArray(values: string[]): string[] {
  const nextValues: string[] = []
  for (let index = 0; index < values.length; index++) {
    nextValues.push(values[index])
  }
  return nextValues
}

function copyLibraryItem(item: ExerciseLibraryItem): ExerciseLibraryItem {
  const nextItem: ExerciseLibraryItem = {
    exerciseId: item.exerciseId,
    name: item.name,
    nameEn: item.nameEn,
    aliases: copyStringArray(item.aliases),
    primaryMuscleName: item.primaryMuscleName,
    equipmentText: item.equipmentText,
    difficultyText: item.difficultyText,
    difficulty: item.difficulty,
    goalTags: copyStringArray(item.goalTags),
    primaryMuscleId: item.primaryMuscleId,
    equipmentIds: copyStringArray(item.equipmentIds)
  }
  return nextItem
}

@Entry
@Component
export struct ExerciseLibraryPage {
  @State @Watch('onQueryChanged') query: string = ''
  @State selectedMuscleId: string = ''
  @State selectedEquipmentId: string = ''
  @State allExercises: ExerciseLibraryItem[] = []
  @State filteredExercises: ExerciseLibraryItem[] = []
  @State muscleOptions: ExerciseFilterOption[] = []
  @State equipmentOptions: ExerciseFilterOption[] = []

  aboutToAppear(): void {
    this.allExercises = this.copyLibraryItems(ContentRepository.getExerciseLibraryItems())
    this.filteredExercises = this.copyLibraryItems(this.allExercises)
    this.muscleOptions = this.createMuscleOptions(ContentRepository.getMuscles())
    this.equipmentOptions = this.createEquipmentOptions(ContentRepository.getEquipment())
  }

  onQueryChanged(): void {
    this.applyFilters()
  }

  createMuscleOptions(muscles: MuscleGroup[]): ExerciseFilterOption[] {
    const options: ExerciseFilterOption[] = []
    options.push(createExerciseFilterOption('', '\u5168\u90e8\u808c\u7fa4'))
    for (let index = 0; index < muscles.length; index++) {
      const muscle: MuscleGroup = muscles[index]
      options.push(createExerciseFilterOption(muscle.muscleId, muscle.nameZh))
    }
    return options
  }

  createEquipmentOptions(equipmentItems: EquipmentItem[]): ExerciseFilterOption[] {
    const options: ExerciseFilterOption[] = []
    options.push(createExerciseFilterOption('', '\u5168\u90e8\u5668\u68b0'))
    for (let index = 0; index < equipmentItems.length; index++) {
      const equipment: EquipmentItem = equipmentItems[index]
      options.push(createExerciseFilterOption(equipment.equipmentId, equipment.nameZh))
    }
    return options
  }

  copyLibraryItems(items: ExerciseLibraryItem[]): ExerciseLibraryItem[] {
    const nextItems: ExerciseLibraryItem[] = []
    for (let index = 0; index < items.length; index++) {
      nextItems.push(copyLibraryItem(items[index]))
    }
    return nextItems
  }

  matchesQuery(exercise: ExerciseLibraryItem, normalizedQuery: string): boolean {
    if (normalizedQuery.length === 0) {
      return true
    }
    if (exercise.name.toLowerCase().indexOf(normalizedQuery) >= 0) {
      return true
    }
    if (exercise.nameEn.toLowerCase().indexOf(normalizedQuery) >= 0) {
      return true
    }
    for (let index = 0; index < exercise.aliases.length; index++) {
      if (exercise.aliases[index].toLowerCase().indexOf(normalizedQuery) >= 0) {
        return true
      }
    }
    return false
  }

  applyFilters(): void {
    const filteredSource: ExerciseLibraryItem[] = this.getFilteredSource()
    const filtered: ExerciseLibraryItem[] = []
    const normalizedQuery: string = this.query.trim().toLowerCase()
    for (let index = 0; index < filteredSource.length; index++) {
      const exercise: ExerciseLibraryItem = filteredSource[index]
      if (!this.matchesQuery(exercise, normalizedQuery)) {
        continue
      }
      filtered.push(copyLibraryItem(exercise))
    }
    this.filteredExercises = filtered
  }

  getFilteredSource(): ExerciseLibraryItem[] {
    if (this.selectedMuscleId.length === 0 && this.selectedEquipmentId.length === 0) {
      return this.copyLibraryItems(this.allExercises)
    }
    return this.copyLibraryItems(ContentRepository.filterExerciseLibraryItems(
      '',
      this.selectedEquipmentId,
      this.selectedMuscleId,
      ''
    ))
  }

  selectMuscle(muscleId: string): void {
    if (this.selectedMuscleId === muscleId) {
      this.selectedMuscleId = ''
    } else {
      this.selectedMuscleId = muscleId
    }
    this.applyFilters()
  }

  selectEquipment(equipmentId: string): void {
    if (this.selectedEquipmentId === equipmentId) {
      this.selectedEquipmentId = ''
    } else {
      this.selectedEquipmentId = equipmentId
    }
    this.applyFilters()
  }

  clearFilters(): void {
    this.query = ''
    this.selectedMuscleId = ''
    this.selectedEquipmentId = ''
    this.applyFilters()
  }

  openExerciseDetail(exerciseId: string): void {
    try {
      router.pushUrl({ url: AppRoutes.EXERCISE_DETAIL, params: { exerciseId: exerciseId } })
    } catch (e) {
      // stay on current page
    }
  }

  getFilterButtonColor(isSelected: boolean): string {
    if (isSelected) {
      return ColorTokens.PRIMARY
    }
    return ColorTokens.SURFACE_ELEVATED
  }

  getFilterTextColor(isSelected: boolean): string {
    if (isSelected) {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    return ColorTokens.TEXT_PRIMARY
  }

  getAliasText(aliases: string[]): string {
    let text: string = ''
    for (let index = 0; index < aliases.length; index++) {
      if (index > 0) {
        text += ' / '
      }
      text += aliases[index]
    }
    return text
  }

  hasActiveFilter(): boolean {
    if (this.query.trim().length > 0) {
      return true
    }
    if (this.selectedMuscleId.length > 0) {
      return true
    }
    return this.selectedEquipmentId.length > 0
  }

  @Builder
  buildFilterSectionTitle(title: string) {
    Text(title)
      .fontSize(FontTokens.CAPTION_SIZE)
      .fontColor(ColorTokens.TEXT_SECONDARY)
      .width('100%')
  }

  @Builder
  buildTitle() {
    Column({ space: SpacingTokens.XS }) {
      Text('\u52a8\u4f5c\u5e93')
        .fontSize(FontTokens.DISPLAY_SIZE)
        .fontWeight(FontTokens.DISPLAY_WEIGHT)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text('\u641c\u7d22\u52a8\u4f5c\u3001\u6309\u808c\u7fa4\u4e0e\u5668\u68b0\u7b5b\u9009\uff0c\u76f4\u63a5\u8df3\u8f6c\u5230\u8be6\u60c5\u9875')
        .fontSize(FontTokens.BODY_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Row() {
        Text('\u8fd4\u56de')
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.PRIMARY)
          .onClick(() => {
            router.back()
          })

        Blank()
      }
      .width('100%')
      .padding({
        left: SpacingTokens.LG,
        right: SpacingTokens.LG,
        top: SpacingTokens.LG,
        bottom: SpacingTokens.SM
      })

      Scroll() {
        Column({ space: SpacingTokens.LG }) {
          this.buildTitle()

          Column({ space: SpacingTokens.MD }) {
            SearchBar({ query: this.query, placeholder: '\u641c\u7d22\u52a8\u4f5c\u540d\u79f0\u3001\u82f1\u6587\u540d\u6216\u522b\u540d' })

            Column({ space: SpacingTokens.SM }) {
              this.buildFilterSectionTitle('\u808c\u7fa4')

              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.muscleOptions, (option: ExerciseFilterOption) => {
                  Button(option.label)
                    .height(TouchTokens.BUTTON_HEIGHT_SMALL)
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontColor(this.getFilterTextColor(this.selectedMuscleId === option.id))
                    .backgroundColor(this.getFilterButtonColor(this.selectedMuscleId === option.id))
                    .borderRadius(RadiusTokens.FULL)
                    .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
                    .onClick(() => {
                      this.selectMuscle(option.id)
                    })
                }, (option: ExerciseFilterOption) => option.id + option.label)
              }
              .width('100%')
            }
            .width('100%')

            Column({ space: SpacingTokens.SM }) {
              this.buildFilterSectionTitle('\u5668\u68b0')

              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.equipmentOptions, (option: ExerciseFilterOption) => {
                  Button(option.label)
                    .height(TouchTokens.BUTTON_HEIGHT_SMALL)
                    .fontSize(FontTokens.SMALL_SIZE)
                    .fontColor(this.getFilterTextColor(this.selectedEquipmentId === option.id))
                    .backgroundColor(this.getFilterButtonColor(this.selectedEquipmentId === option.id))
                    .borderRadius(RadiusTokens.FULL)
                    .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
                    .onClick(() => {
                      this.selectEquipment(option.id)
                    })
                }, (option: ExerciseFilterOption) => option.id + option.label)
              }
              .width('100%')
            }
            .width('100%')
          }
          .width('100%')
          .padding(SpacingTokens.MD)
          .borderRadius(RadiusTokens.SM)
          .backgroundColor(ColorTokens.BG_SECONDARY)

          Row() {
            Text('\u5171 ' + this.filteredExercises.length.toString() + ' \u4e2a\u52a8\u4f5c')
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)

            Blank()

            if (this.hasActiveFilter()) {
              Button('\u6e05\u7a7a\u7b5b\u9009')
                .height(TouchTokens.BUTTON_HEIGHT_SMALL)
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                .borderRadius(RadiusTokens.FULL)
                .onClick(() => {
                  this.clearFilters()
                })
            }
          }
          .width('100%')

          if (this.filteredExercises.length === 0) {
            Column({ space: SpacingTokens.SM }) {
              Text('\u6ca1\u6709\u627e\u5230\u5339\u914d\u52a8\u4f5c')
                .fontSize(FontTokens.TITLE_SIZE)
                .fontWeight(FontTokens.TITLE_WEIGHT)
                .fontColor(ColorTokens.TEXT_PRIMARY)

              Text('\u8bd5\u8bd5\u66f4\u77ed\u7684\u5173\u952e\u8bcd\uff0c\u6216\u79fb\u9664\u90e8\u5206\u7b5b\u9009\u6761\u4ef6\u3002')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
            }
            .width('100%')
            .padding(SpacingTokens.LG)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.BG_SECONDARY)
            .alignItems(HorizontalAlign.Center)
          }

          ForEach(this.filteredExercises, (exercise: ExerciseLibraryItem) => {
            Column({ space: SpacingTokens.SM }) {
              Row() {
                Column({ space: SpacingTokens.XS }) {
                  Text(exercise.name)
                    .fontSize(FontTokens.TITLE_SIZE)
                    .fontWeight(FontTokens.TITLE_WEIGHT)
                    .fontColor(ColorTokens.TEXT_PRIMARY)
                    .width('100%')

                  Text(exercise.nameEn)
                    .fontSize(FontTokens.CAPTION_SIZE)
                    .fontColor(ColorTokens.TEXT_SECONDARY)
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text(exercise.difficultyText)
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(ColorTokens.TEXT_ON_PRIMARY)
                  .padding({
                    left: SpacingTokens.SM,
                    right: SpacingTokens.SM,
                    top: SpacingTokens.XS,
                    bottom: SpacingTokens.XS
                  })
                  .backgroundColor(ColorTokens.ACCENT)
                  .borderRadius(RadiusTokens.FULL)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)

              Text(exercise.primaryMuscleName + ' | ' + exercise.equipmentText)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .width('100%')

              if (exercise.aliases.length > 0) {
                Text('\u522b\u540d\uff1a' + this.getAliasText(exercise.aliases))
                  .fontSize(FontTokens.CAPTION_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
                  .width('100%')
              }

              Button('\u67e5\u770b\u52a8\u4f5c\u8be6\u60c5')
                .width('100%')
                .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_PRIMARY)
                .backgroundColor(ColorTokens.SURFACE_ELEVATED)
                .borderRadius(RadiusTokens.FULL)
                .onClick(() => {
                  this.openExerciseDetail(exercise.exerciseId)
                })
            }
            .width('100%')
            .padding(SpacingTokens.MD)
            .borderRadius(RadiusTokens.SM)
            .backgroundColor(ColorTokens.BG_SECONDARY)
          }, (exercise: ExerciseLibraryItem) => exercise.exerciseId)
        }
        .width('100%')
        .padding({
          left: SpacingTokens.LG,
          right: SpacingTokens.LG,
          bottom: SpacingTokens.LG
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.BG_PRIMARY)
  }
}
