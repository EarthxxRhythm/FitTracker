/**
 * ExerciseLibraryPage —— 动作库列表页
 *
 * 功能 #13: 动作库列表（搜索框、肌群筛选栏、卡片网格、分页加载）
 * 功能 #14: 动作搜索（按名称/别名模糊匹配）
 * 功能 #15: 肌群筛选（胸/背/腿/肩/臂/腹/全部）
 * 功能 #16: 器械筛选（杠铃/哑铃/绳索/固定器械/自重）
 */
import { router } from '@kit.ArkUI'
import { AppCard } from '../components/AppCard'
import ExerciseService, { Exercise } from '../common/services/ExerciseService'
import { ColorTokens, FontTokens, SpacingTokens, RadiusTokens } from '../common/styles/DesignTokens'

const MUSCLE_GROUPS = ['全部', '胸', '背', '腿', '肩', '臂', '腹']
const EQUIPMENT_TYPES = ['杠铃', '哑铃', '绳索', '固定器械', '自重']
const MUSCLE_COLORS: Record<string, string> = {
  '胸': '#1E88E5', '背': '#43A047', '腿': '#FB8C00',
  '肩': '#8E24AA', '臂': '#E53935', '腹': '#00897B'
}

@Entry
@Component
struct ExerciseLibraryPage {
  @State searchQuery: string = ''
  @State activeMuscle: string = '全部'
  @State activeEquipment: string = ''
  @State exercises: Exercise[] = []
  @State page: number = 1
  @State hasMore: boolean = true
  @State loading: boolean = false

  async aboutToAppear(): Promise<void> {
    this.filterAndSearch()
  }

  filterAndSearch(): void {
    this.page = 1
    let result = ExerciseService.search(this.searchQuery)
    if (this.activeMuscle !== '全部') {
      result = ExerciseService.filterByMuscle(this.activeMuscle)
      if (this.searchQuery.trim()) {
        result = result.filter(e =>
          e.name.toLowerCase().includes(this.searchQuery.trim().toLowerCase()) ||
          e.aliases.some(a => a.toLowerCase().includes(this.searchQuery.trim().toLowerCase()))
        )
      }
    }
    if (this.activeEquipment) {
      result = result.filter(e => e.equipment === this.activeEquipment)
    }
    this.exercises = ExerciseService.getPage(result, 1)
    this.hasMore = ExerciseService.hasMore(result, 1)
  }

  loadMore(): void {
    if (!this.hasMore || this.loading) {
      return
    }
    this.loading = true
    const nextPage = this.page + 1
    let result = ExerciseService.search(this.searchQuery)
    if (this.activeMuscle !== '全部') {
      result = ExerciseService.filterByMuscle(this.activeMuscle)
      if (this.searchQuery.trim()) {
        result = result.filter(e =>
          e.name.toLowerCase().includes(this.searchQuery.trim().toLowerCase()) ||
          e.aliases.some(a => a.toLowerCase().includes(this.searchQuery.trim().toLowerCase()))
        )
      }
    }
    if (this.activeEquipment) {
      result = result.filter(e => e.equipment === this.activeEquipment)
    }
    const more = ExerciseService.getPage(result, nextPage)
    if (more.length > 0) {
      this.exercises = this.exercises.concat(more)
      this.page = nextPage
      this.hasMore = ExerciseService.hasMore(result, nextPage)
    } else {
      this.hasMore = false
    }
    this.loading = false
  }

  build() {
    Column() {
      // 顶部导航栏
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
        .onClick(() => { router.back() })
        Blank()
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.LG, bottom: SpacingTokens.SM })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      // 搜索框
      Row() {
        TextInput({ text: $$this.searchQuery, placeholder: '搜索动作名称...' })
          .fontSize(FontTokens.BODY_SIZE)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .height(44)
          .onChange(() => { this.filterAndSearch() })
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)
      .border({ width: { bottom: 0.5 }, color: ColorTokens.NEUTRAL_100 })
      .padding({ bottom: SpacingTokens.SM })

      // 肌群筛选栏
      Row() {
        Scroll() {
          Row() {
            ForEach(MUSCLE_GROUPS, (muscle: string) => {
              Text(muscle)
                .fontSize(FontTokens.CAPTION_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.activeMuscle === muscle ? Color.White : ColorTokens.TEXT_SECONDARY)
                .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.SM, bottom: SpacingTokens.SM })
                .backgroundColor(this.activeMuscle === muscle ? ColorTokens.PRIMARY : ColorTokens.SURFACE_SECONDARY)
                .borderRadius(RadiusTokens.FULL)
                .margin({ right: SpacingTokens.SM })
                .onClick(() => {
                  this.activeMuscle = muscle
                  this.filterAndSearch()
                })
            })
          }
        }
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.SM, bottom: SpacingTokens.SM })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      // 器械筛选栏
      Row() {
        Scroll() {
          Row() {
            ForEach(EQUIPMENT_TYPES, (equip: string) => {
              Text(equip)
                .fontSize(FontTokens.SMALL_SIZE)
                .fontColor(this.activeEquipment === equip ? Color.White : ColorTokens.TEXT_SECONDARY)
                .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.XS, bottom: SpacingTokens.XS })
                .backgroundColor(this.activeEquipment === equip ? ColorTokens.NEUTRAL_400 : ColorTokens.SURFACE_SECONDARY)
                .borderRadius(RadiusTokens.FULL)
                .margin({ right: SpacingTokens.SM })
                .onClick(() => {
                  this.activeEquipment = this.activeEquipment === equip ? '' : equip
                  this.filterAndSearch()
                })
            })
          }
        }
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, bottom: SpacingTokens.SM })
      .backgroundColor(ColorTokens.SURFACE_PRIMARY)

      // 动作列表（两列网格）
      Scroll() {
        Column() {
          if (this.exercises.length > 0) {
            // 两列网格
            Row() {
              ForEach(this.exercises, (exercise: Exercise, index: number) => {
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
              }, (exercise: Exercise) => exercise.id)
            }
            .width('100%')

            // 加载更多指示
            if (this.hasMore) {
              Row() {
                Text('加载更多...')
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontColor(ColorTokens.TEXT_DISABLED)
              }
              .width('100%')
              .height(48)
              .justifyContent(FlexAlign.Center)
              .onClick(() => { this.loadMore() })
            }
          } else {
            Column() {
              Text('未找到匹配动作')
                .fontSize(FontTokens.BODY_SIZE)
                .fontColor(ColorTokens.TEXT_SECONDARY)
            }
            .width('100%')
            .padding(SpacingTokens.XXL)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .padding({ left: SpacingTokens.MD, right: SpacingTokens.MD, top: SpacingTokens.MD, bottom: SpacingTokens.MD })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .onReachEnd(() => { this.loadMore() })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorTokens.SURFACE_SECONDARY)
  }

  @Builder
  exerciseCard(exercise: Exercise) {
    AppCard({ variant: 'outlined', padding: 'compact' }) {
      Column() {
        // 缩略图占位
        Column() {
          Text(exercise.name.charAt(0))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width('100%')
        .height(72)
        .borderRadius({ topLeft: RadiusTokens.SM, topRight: RadiusTokens.SM, bottomLeft: 0, bottomRight: 0 })
        .backgroundColor(MUSCLE_COLORS[exercise.primaryMuscle] || '#999')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        // 动作信息
        Column() {
          Text(exercise.name)
            .fontSize(FontTokens.CAPTION_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ColorTokens.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(exercise.primaryMuscle)
            .fontSize(FontTokens.SMALL_SIZE)
            .fontColor(MUSCLE_COLORS[exercise.primaryMuscle] || '#999')
            .fontWeight(FontWeight.Medium)
            .margin({ top: SpacingTokens.XS })
        }
        .width('100%')
        .padding({ left: SpacingTokens.SM, right: SpacingTokens.SM, top: SpacingTokens.SM, bottom: SpacingTokens.SM })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .onClick(() => {
      router.pushUrl({ url: 'pages/ExerciseDetailPage', params: { exerciseId: exercise.id } })
    })
  }
}
