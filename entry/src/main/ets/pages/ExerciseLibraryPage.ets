/**
 * ExerciseLibraryPage -- local action library list.
 *
 * 功能 #13: 动作库列表（搜索框、肌群筛选栏、卡片网格、分页加载）
 * 功能 #14: 动作搜索（按名称/别名模糊匹配）
 * 功能 #15: 肌群筛选（胸/背/腿/肩/臂/腹/全部）
 * 功能 #16: 本地维护动作数据展示，不依赖 MuscleWiki 官方 API
 */
import { router } from '@kit.ArkUI'
import { AppCard } from '../components/AppCard'
import { Chip } from '../components/Chip'
import { EmptyState } from '../components/EmptyState'
import { ColorTokens, FontTokens, MuscleColorMap, RadiusTokens, SpacingTokens, TouchTokens } from '../common/styles/DesignTokens'
import { EquipmentItem, MuscleGroup } from '../shared/models/TrainingModels'
import ContentRepository, { ExerciseLibraryItem } from '../shared/services/ContentRepository'

const ALL_FILTER_LABEL: string = '全部'
const PAGE_SIZE: number = 20

@Entry
@Component
export struct ExerciseLibraryPage {
  @State searchQuery: string = ''
  @State activeMuscleId: string = ''
  @State activeEquipmentId: string = ''
  @State muscles: MuscleGroup[] = []
  @State equipmentItems: EquipmentItem[] = []
  @State exercises: ExerciseLibraryItem[] = []
  @State page: number = 1
  @State hasMore: boolean = true
  @State loading: boolean = false

  aboutToAppear(): void {
    this.muscles = ContentRepository.getMuscles()
    this.equipmentItems = ContentRepository.getEquipment()
    this.filterAndSearch()
  }

  filterAndSearch(): void {
    this.page = 1
    const result: ExerciseLibraryItem[] = this.getFilteredItems()
    this.exercises = this.getPage(result, 1)
    this.hasMore = this.hasMorePage(result, 1)
  }

  loadMore(): void {
    if (!this.hasMore || this.loading) {
      return
    }
    this.loading = true
    const nextPage: number = this.page + 1
    const result: ExerciseLibraryItem[] = this.getFilteredItems()
    const more: ExerciseLibraryItem[] = this.getPage(result, nextPage)
    if (more.length > 0) {
      this.exercises = this.exercises.concat(more)
      this.page = nextPage
      this.hasMore = this.hasMorePage(result, nextPage)
    } else {
      this.hasMore = false
    }
    this.loading = false
  }

  getFilteredItems(): ExerciseLibraryItem[] {
    const allItems: ExerciseLibraryItem[] = ContentRepository.getExerciseLibraryItems()
    const normalizedQuery: string = this.searchQuery.trim().toLowerCase()
    const result: ExerciseLibraryItem[] = []
    for (let index = 0; index < allItems.length; index++) {
      const item: ExerciseLibraryItem = allItems[index]
      if (this.matchesItem(item, normalizedQuery)) {
        result.push(item)
      }
    }
    return result
  }

  matchesItem(item: ExerciseLibraryItem, normalizedQuery: string): boolean {
    if (this.activeMuscleId.length > 0 && item.primaryMuscleId !== this.activeMuscleId) {
      return false
    }
    if (this.activeEquipmentId.length > 0 && !this.containsValue(item.equipmentIds, this.activeEquipmentId)) {
      return false
    }
    if (normalizedQuery.length === 0) {
      return true
    }
    if (item.name.toLowerCase().indexOf(normalizedQuery) >= 0) {
      return true
    }
    if (item.nameEn.toLowerCase().indexOf(normalizedQuery) >= 0) {
      return true
    }
    for (let index = 0; index < item.aliases.length; index++) {
      if (item.aliases[index].toLowerCase().indexOf(normalizedQuery) >= 0) {
        return true
      }
    }
    return false
  }

  getPage(items: ExerciseLibraryItem[], page: number): ExerciseLibraryItem[] {
    const result: ExerciseLibraryItem[] = []
    const start: number = (page - 1) * PAGE_SIZE
    const end: number = start + PAGE_SIZE
    for (let index = start; index < end && index < items.length; index++) {
      result.push(items[index])
    }
    return result
  }

  hasMorePage(items: ExerciseLibraryItem[], page: number): boolean {
    return page * PAGE_SIZE < items.length
  }

  containsValue(values: string[], targetValue: string): boolean {
    for (let index = 0; index < values.length; index++) {
      if (values[index] === targetValue) {
        return true
      }
    }
    return false
  }

  getMuscleShortName(item: ExerciseLibraryItem): string {
    if (item.primaryMuscleName === '胸部') {
      return '胸'
    }
    if (item.primaryMuscleName === '背部') {
      return '背'
    }
    if (item.primaryMuscleName === '腿部') {
      return '腿'
    }
    if (item.primaryMuscleName === '肩部') {
      return '肩'
    }
    if (item.primaryMuscleName === '手臂') {
      return '臂'
    }
    if (item.primaryMuscleName === '核心') {
      return '腹'
    }
    return item.primaryMuscleName
  }

  @Builder
  buildHeader() {
    Row() {
      Row() {
        Text('←')
          .fontSize(FontTokens.TITLE_SIZE)
          .fontColor(ColorTokens.PRIMARY)
          .padding({ right: SpacingTokens.SM })
        Text('动作库')
          .fontSize(FontTokens.HEADLINE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorTokens.TEXT_PRIMARY)
      }
      .onClick(() => {
        router.back()
      })
      Blank()
    }
    .width('100%')
    .padding({
      left: SpacingTokens.MD,
      right: SpacingTokens.MD,
      top: SpacingTokens.LG,
      bottom: SpacingTokens.SM
    })
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
  }

  @Builder
  buildMuscleFilters() {
    Row() {
      Scroll() {
        Row() {
          Chip({
            label: ALL_FILTER_LABEL,
            color: this.activeMuscleId.length === 0 ? ColorTokens.PRIMARY : ColorTokens.MUSCLE_DEFAULT,
            chipSize: 'md'
          })
          .onClick(() => {
            this.activeMuscleId = ''
            this.filterAndSearch()
          })

          ForEach(this.muscles, (muscle: MuscleGroup) => {
            Chip({
              label: muscle.nameZh,
              color: this.activeMuscleId === muscle.muscleId ? ColorTokens.PRIMARY : MuscleColorMap.getColor(this.getMuscleShortNameFromName(muscle.nameZh)),
              chipSize: 'md'
            })
            .onClick(() => {
              this.activeMuscleId = muscle.muscleId
              this.filterAndSearch()
            })
          }, (muscle: MuscleGroup) => muscle.muscleId)
        }
      }
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .padding({
      left: SpacingTokens.MD,
      right: SpacingTokens.MD,
      top: SpacingTokens.SM,
      bottom: SpacingTokens.SM
    })
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
  }

  getMuscleShortNameFromName(name: string): string {
    if (name === '胸部') {
      return '胸'
    }
    if (name === '背部') {
      return '背'
    }
    if (name === '腿部') {
      return '腿'
    }
    if (name === '肩部') {
      return '肩'
    }
    if (name === '手臂') {
      return '臂'
    }
    if (name === '核心') {
      return '腹'
    }
    return name
  }

  @Builder
  buildEquipmentFilters() {
    Row() {
      Scroll() {
        Row() {
          ForEach(this.equipmentItems, (equipment: EquipmentItem) => {
            Text(equipment.nameZh)
              .fontSize(FontTokens.SMALL_SIZE)
              .fontColor(this.activeEquipmentId === equipment.equipmentId ? ColorTokens.TEXT_ON_PRIMARY : ColorTokens.TEXT_SECONDARY)
              .padding({
                left: SpacingTokens.MD,
                right: SpacingTokens.MD,
                top: SpacingTokens.XS,
                bottom: SpacingTokens.XS
              })
              .backgroundColor(this.activeEquipmentId === equipment.equipmentId ? ColorTokens.NEUTRAL_400 : ColorTokens.SURFACE_SECONDARY)
              .borderRadius(RadiusTokens.FULL)
              .margin({ right: SpacingTokens.SM })
              .onClick(() => {
                this.activeEquipmentId = this.activeEquipmentId === equipment.equipmentId ? '' : equipment.equipmentId
                this.filterAndSearch()
              })
          }, (equipment: EquipmentItem) => equipment.equipmentId)
        }
      }
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.SM })
    .backgroundColor(ColorTokens.SURFACE_PRIMARY)
  }

  build() {
    Column() {
      this.buildHeader()

      Row() {
        TextInput({ text: this.searchQuery, placeholder: '搜索动作名称...' })
          .fontSize(FontTokens.BODY_SIZE)
          .fontColor(ColorTokens.TEXT_PRIMARY)
          .placeholderColor(ColorTokens.TEXT_DISABLED)
          .backgroundColor(ColorTokens.SURFACE_PRIMARY)
          .height('100%')
          .layoutWeight(1)
          .onChange((value: string) => {
            this.searchQuery = value
            this.filterAndSearch()
          })
      }
      .width('100%')
      .height(TouchTokens.INPUT_HEIGHT)
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)
      .border({ width: { bottom: 0.5 }, color: ColorTokens.NEUTRAL_100 })
      .padding({ bottom: SpacingTokens.SM })

      this.buildMuscleFilters()
      this.buildEquipmentFilters()

      Scroll() {
        Column() {
          if (this.exercises.length > 0) {
            Row() {
              ForEach(this.exercises, (exercise: ExerciseLibraryItem, index: number) => {
                if (index % 2 === 0) {
                  Column() {
                    this.exerciseCard(exercise)
                    if (index + 1 < this.exercises.length) {
                      Blank()
                        .height(SpacingTokens.SM)
                      this.exerciseCard(this.exercises[index + 1])
                    } else {
                      Blank()
                        .height(SpacingTokens.SM)
                    }
                  }
                  .layoutWeight(1)
                }
              }, (exercise: ExerciseLibraryItem) => exercise.exerciseId)
            }
            .width('100%')

            if (this.hasMore) {
              Row() {
                Text('加载更多...')
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(ColorTokens.TEXT_DISABLED)
              }
              .width('100%')
              .height(TouchTokens.MIN_TARGET)
              .justifyContent(FlexAlign.Center)
              .onClick(() => {
                this.loadMore()
              })
            }
          } else {
            Column() {
              EmptyState({ icon: '🔍', title: '未找到匹配动作' })
            }
            .width('100%')
            .padding(SpacingTokens.XXL)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .padding({
          left: SpacingTokens.MD,
          right: SpacingTokens.MD,
          top: SpacingTokens.MD,
          bottom: SpacingTokens.MD
        })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .onReachEnd(() => {
        this.loadMore()
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
  }

  @Builder
  exerciseCard(exercise: ExerciseLibraryItem) {
    Stack() {
      AppCard({ variant: 'outlined', cardPadding: 'compact' }) {
        Column() {
          Column() {
            Text(exercise.name.charAt(0))
              .fontSize(FontTokens.TITLE_SIZE)
              .fontWeight(FontWeight.Bold)
              .fontColor(ColorTokens.TEXT_ON_PRIMARY)
          }
          .width('100%')
          .height(TouchTokens.CARD_MEDIA_HEIGHT)
          .borderRadius({ topLeft: RadiusTokens.SM, topRight: RadiusTokens.SM, bottomLeft: 0, bottomRight: 0 })
          .backgroundColor(MuscleColorMap.getColor(this.getMuscleShortName(exercise)))
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text(exercise.name)
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorTokens.TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')

            Chip({
              label: exercise.primaryMuscleName,
              color: MuscleColorMap.getColor(this.getMuscleShortName(exercise)),
              chipSize: 'sm'
            })
            .margin({ top: SpacingTokens.XS })

            Text(exercise.equipmentText + ' · ' + exercise.difficultyText)
              .fontSize(FontTokens.SMALL_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .margin({ top: SpacingTokens.XS })
          }
          .width('100%')
          .padding({
            left: SpacingTokens.SM,
            right: SpacingTokens.SM,
            top: SpacingTokens.SM,
            bottom: SpacingTokens.SM
          })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
      }
    }
    .width('100%')
    .onClick(() => {
      router.pushUrl({ url: 'features/exercise/pages/ExerciseDetailPage', params: { exerciseId: exercise.exerciseId } })
    })
  }
}
