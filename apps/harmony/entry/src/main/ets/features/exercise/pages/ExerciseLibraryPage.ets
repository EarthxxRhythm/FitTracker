/**
 * ExerciseLibraryPage —— 动作库主页面（视觉主线重写）。
 *
 * GIF 网格 + 部位/肌群两级筛选 + 收藏 + 底部详情弹层。
 * 卡片点击打开底部弹层（不再跳转 ExerciseDetailPage）；
 * 收藏经 FavoriteExerciseService 持久化。
 */
import { MotionTokens } from '../../../common/styles/DesignTokens'
import { PrototypeTokens } from '../../../common/styles/PrototypeTokens'
import FavoriteExerciseService from '../../../common/services/FavoriteExerciseService'
import ContentRepository, { ExerciseLibraryItem, ExerciseDetailViewModel } from '../../../shared/services/ContentRepository'
import ExerciseGifCatalog from '../../../shared/services/ExerciseGifCatalog'
import { window } from '@kit.ArkUI'

// ---------------------------------------------------------------------------
// 配色（Cold Emerald，就地集中声明）
// ---------------------------------------------------------------------------
// 本页私有调色板。**与 PrototypeTokens 同值的成员一律委托**，不重复写值——
// 见下方 `// 委托` 标注。独有值（本页专有的玻璃层/收藏按钮/遮罩等）就地声明。
// 详见 `design/06_prototype_redraw/TOKENS.md` 与 收口计划的 §5。
class LibPalette {
  // ── 与 PrototypeTokens 同值 -> 委托（值一字不改）────────────────────
  static readonly BG_BASE: string = PrototypeTokens.BG_INK              // 委托
  static readonly ACCENT: string = PrototypeTokens.ACCENT               // 委托
  static readonly ON_ACCENT: string = PrototypeTokens.TEXT_ON_ACCENT    // 委托
  static readonly TEXT_HI: string = PrototypeTokens.TEXT_HI             // 委托
  static readonly STROKE: string = PrototypeTokens.WHITE_A10            // 委托
  static readonly WHITE_70: string = PrototypeTokens.WHITE_A70          // 委托
  static readonly WHITE_62: string = PrototypeTokens.WHITE_A62          // 委托
  static readonly WHITE_54: string = PrototypeTokens.WHITE_A54          // 委托
  static readonly WHITE_40: string = PrototypeTokens.WHITE_A40          // 委托
  static readonly WHITE_32: string = PrototypeTokens.WHITE_A32          // 委托
  static readonly HAIRLINE: string = PrototypeTokens.WHITE_A06          // 委托
  // ── 本页独有值（原型中为裸值或本页特例，就地声明）──────────────────
  static readonly SHEET_BG: string = '#0E1316'
  static readonly GLASS_BTN_BG: string = 'rgba(255,255,255,0.047)'
  static readonly GLASS_BTN_BORDER: string = 'rgba(255,255,255,0.08)'
  static readonly GLASS_CLOSE_BG: string = 'rgba(255,255,255,0.06)'
  static readonly CHIP_BG: string = 'rgba(255,255,255,0.04)'
  static readonly CHIP_BORDER: string = 'rgba(255,255,255,0.10)'
  static readonly CHIP_ACTIVE_BG: string = 'rgba(80,236,167,0.15)'
  static readonly CHIP_ACTIVE_BORDER: string = 'rgba(80,236,167,0.45)'
  static readonly CARD_BG: string = 'rgba(255,255,255,0.031)'
  static readonly FAV_BG: string = 'rgba(7,10,12,0.62)'
  static readonly FAV_BG_ACTIVE: string = 'rgba(7,10,12,0.72)'
  static readonly FAV_BORDER: string = 'rgba(255,255,255,0.16)'
  static readonly BACKDROP: string = 'rgba(4,7,9,0.55)'
  static readonly TOAST_BG: string = 'rgba(13,17,23,0.94)'
  static readonly FOCUS_GLOW: string = 'rgba(80,236,167,0.22)'
  static readonly TAG_BG: string = 'rgba(80,236,167,0.12)'
  static readonly TAG_BORDER: string = 'rgba(80,236,167,0.30)'
  static readonly FAV_FILTER_ON_BG: string = 'rgba(80,236,167,0.12)'
  static readonly MEDIA_BG: string = 'rgba(255,255,255,0.04)'

  static readonly MEDIA_BG_SHEET: string = 'rgba(255,255,255,0.045)'
}

// HTML `.lib-fav:active` 按压缩放系数（MotionTokens 无 .9 档，页面级集中声明）。
const PRESS_HEART_SCALE: number = 0.9
// 实拍素材的圆角：实拍照无白底、是矩形实景，须套圆角收敛（线稿素材已烘页底色，圆角对其无感）。
// 取既有卡面口径 14，与该页卡片/弹层既有圆角一致，不引入新视觉值。
const LIB_MEDIA_RADIUS: number = 14

// ---------------------------------------------------------------------------
// 数据模型与动作库常量
// ---------------------------------------------------------------------------
interface ExerciseItem {
  id: string
  name: string
  part: string
  muscle: string
  equipment: string
  level: string
  muscles: string
  tip: string
}

function makeExercise(
  id: string,
  name: string,
  part: string,
  muscle: string,
  equipment: string,
  level: string,
  muscles: string,
  tip: string
): ExerciseItem {
  const item: ExerciseItem = {
    id: id,
    name: name,
    part: part,
    muscle: muscle,
    equipment: equipment,
    level: level,
    muscles: muscles,
    tip: tip
  }
  return item
}

/**
 * 内容库动作 → 页面 `ExerciseItem` 的映射。
 *
 * 内容库的 `primaryMuscleName` 恰好与 [PART_OPTIONS] 同取值（胸部/背部/腿部/肩部/手臂/核心），
 * 故 `part` 直接取该字段；`muscle` 同源（供肌群二级筛选，其候选由 [PART_MUSCLES] 给出）。
 * `muscles` 与 `tip` 由详情能力补充（步骤/要点），此处用主肌群与首条要点合成展示文案。
 */
function toExerciseItem(item: ExerciseLibraryItem, tip: string): ExerciseItem {
  const result: ExerciseItem = {
    id: item.exerciseId,
    name: item.name,
    part: item.primaryMuscleName,
    muscle: item.primaryMuscleName,
    equipment: item.equipmentText,
    level: item.difficultyText,
    muscles: item.primaryMuscleName,
    tip: tip
  }
  return result
}

/**
 * 从内容库装配动作列表（取代此前的 23 条写死常量）。
 *
 * `tip` 取动作详情的首条要点（内容库的 `cues`），无详情时留空。
 */
function loadExercisesFromContent(): ExerciseItem[] {
  const items: ExerciseItem[] = []
  const libraryItems: ExerciseLibraryItem[] = ContentRepository.getExerciseLibraryItems()
  for (let index = 0; index < libraryItems.length; index++) {
    const libraryItem: ExerciseLibraryItem = libraryItems[index]
    const detail: ExerciseDetailViewModel | undefined =
      ContentRepository.getExerciseDetailViewModel(libraryItem.exerciseId)
    let tip: string = ''
    if (detail !== undefined && detail.cues.length > 0) {
      tip = detail.cues[0]
    }
    items.push(toExerciseItem(libraryItem, tip))
  }
  return items
}

const PART_OPTIONS: string[] = ['全部', '胸部', '背部', '肩部', '手臂', '腿部', '核心']

// 单行态 chip 行高（chip 约 34vp：fontSize 13 + padding 8/8 + 1vp 边框）。
const PART_ROW_HEIGHT: number = 36
// 收回后等待单行 List 重建完成再滚动；当帧调用时布局未落定，居中不生效。
const PART_COLLAPSE_SETTLE_MS: number = 50

interface PartMusclesEntry {
  part: string
  muscles: string[]
}

const PART_MUSCLES: PartMusclesEntry[] = [
  { part: '胸部', muscles: ['胸大肌'] },
  { part: '背部', muscles: ['背阔肌', '菱形肌'] },
  { part: '肩部', muscles: ['三角肌前束', '三角肌中束', '三角肌后束'] },
  { part: '手臂', muscles: ['肱二头肌', '肱三头肌'] },
  { part: '腿部', muscles: ['股四头肌', '腘绳肌'] },
  { part: '核心', muscles: ['腹直肌'] }
]

const EQUIPMENT_ORDER: string[] = ['杠铃', '哑铃', '器械', '弹力带', '自重']

function getMusclesForPart(part: string): string[] {
  for (let index = 0; index < PART_MUSCLES.length; index++) {
    if (PART_MUSCLES[index].part === part) {
      return PART_MUSCLES[index].muscles
    }
  }
  return []
}

@Entry
@Component
export struct ExerciseLibraryPage {
  @State private query: string = ''
  /** 动作列表（由内容库装配；取代此前的 23 条写死常量）。 */
  @State private exercises: ExerciseItem[] = []
  @State private selectedPart: string = '全部'
  @State private partExpanded: boolean = false
  @State private selectedMuscle: string = '全部肌群'
  @State private favOnly: boolean = false
  @State private favoriteIds: string[] = []
  @State private sheetVisible: boolean = false
  @State private selectedId: string = ''
  @State private ctaBusy: boolean = false
  @State private toastVisible: boolean = false
  @State private toastMessage: string = ''
  @State private searchFocused: boolean = false
  @State private pressedBack: boolean = false
  @State private pressedFavFilter: boolean = false
  @State private pressedCardId: string = ''
  @State private pressedHeartId: string = ''
  @State private pressedClose: boolean = false
  @State private pressedCta: boolean = false
  @State private topInset: number = 50
  @State private bottomInset: number = 0
  @State private failedGifIds: string[] = []
  private win: window.Window | null = null
  private partScroller: Scroller = new Scroller()
  private partScrollTimer: number = -1
  private toastTimer: number = -1
  private ctaTimer: number = -1

  aboutToAppear(): void {
    this.loadFavorites()
    // 从内容库装配动作列表（内容库是动作数据的唯一事实源）。
    this.exercises = loadExercisesFromContent()
    const host = this.getUIContext().getHostContext()
    if (host === undefined) {
      return
    }
    window.getLastWindow(host).then((win: window.Window) => {
      this.win = win
      win.setWindowLayoutFullScreen(true).then(() => {
        this.readAvoidAreas()
        win.on('avoidAreaChange', this.handleAvoidAreaChange)
      })
    })
  }

  aboutToDisappear(): void {
    if (this.win) {
      this.win.off('avoidAreaChange', this.handleAvoidAreaChange)
      this.win.setWindowLayoutFullScreen(false)
      this.win = null
    }
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
      this.toastTimer = -1
    }
    if (this.ctaTimer >= 0) {
      clearTimeout(this.ctaTimer)
      this.ctaTimer = -1
    }
    if (this.partScrollTimer >= 0) {
      clearTimeout(this.partScrollTimer)
      this.partScrollTimer = -1
    }
  }

  private handleAvoidAreaChange = (data: window.AvoidAreaOptions): void => {
    this.readAvoidAreas()
  }

  private readAvoidAreas(): void {
    if (!this.win) {
      return
    }
    const systemArea: window.AvoidArea = this.win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
    const topPx: number = systemArea.topRect.height
    if (topPx > 0) {
      this.topInset = this.getUIContext().px2vp(topPx)
    }
    const navArea: window.AvoidArea = this.win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
    const bottomPx: number = navArea.bottomRect.height
    if (bottomPx > 0) {
      this.bottomInset = this.getUIContext().px2vp(bottomPx)
    }
  }

  // -------------------------------------------------------------------------
  // 收藏
  // -------------------------------------------------------------------------
  private async loadFavorites(): Promise<void> {
    try {
      await FavoriteExerciseService.load()
    } catch (e) {
      // 持久化失败不影响主流程。
    }
    this.favoriteIds = FavoriteExerciseService.getFavoriteIds()
  }

  private isFav(id: string): boolean {
    return this.favoriteIds.indexOf(id) >= 0
  }

  private toggleFav(id: string): void {
    FavoriteExerciseService.toggleFavorite(id)
    this.favoriteIds = FavoriteExerciseService.getFavoriteIds()
  }

  private markGifFailed(id: string): void {
    if (this.failedGifIds.indexOf(id) === -1) {
      this.failedGifIds.push(id)
    }
  }

  private isGifFailed(id: string): boolean {
    return this.failedGifIds.indexOf(id) !== -1
  }

  // -------------------------------------------------------------------------
  // 筛选
  // -------------------------------------------------------------------------
  private matchesFilters(item: ExerciseItem): boolean {
    if (this.favOnly && this.favoriteIds.indexOf(item.id) < 0) {
      return false
    }
    if (this.selectedPart !== '全部' && item.part !== this.selectedPart) {
      return false
    }
    if (this.selectedMuscle !== '全部肌群' && item.muscle !== this.selectedMuscle) {
      return false
    }
    const normalizedQuery: string = this.query.trim()
    if (normalizedQuery.length > 0) {
      const haystack: string =
        item.name + ' ' + item.part + ' ' + item.muscle + ' ' + item.equipment + ' ' + item.muscles
      if (haystack.indexOf(normalizedQuery) < 0) {
        return false
      }
    }
    return true
  }

  private filteredExercises(): ExerciseItem[] {
    const result: ExerciseItem[] = []
    for (let index = 0; index < this.exercises.length; index++) {
      if (this.matchesFilters(this.exercises[index])) {
        result.push(this.exercises[index])
      }
    }
    return result
  }

  private groupItems(equipment: string): ExerciseItem[] {
    const filtered: ExerciseItem[] = this.filteredExercises()
    const result: ExerciseItem[] = []
    for (let index = 0; index < filtered.length; index++) {
      if (filtered[index].equipment === equipment) {
        result.push(filtered[index])
      }
    }
    return result
  }

  private muscleOptions(): string[] {
    const result: string[] = ['全部肌群']
    const muscles: string[] = getMusclesForPart(this.selectedPart)
    for (let index = 0; index < muscles.length; index++) {
      result.push(muscles[index])
    }
    return result
  }

  private selectPart(part: string, index: number): void {
    this.selectedPart = part
    this.selectedMuscle = '全部肌群'
    this.collapseToPart(part, index)
  }

  private togglePartExpanded(): void {
    this.partExpanded = !this.partExpanded
  }

  private collapseToPart(part: string, index: number): void {
    if (this.partScrollTimer >= 0) {
      clearTimeout(this.partScrollTimer)
      this.partScrollTimer = -1
    }
    this.selectedPart = part
    this.partExpanded = false
    // 收回后等单行 List 重建完成；本帧调用时布局未落定，居中不生效。
    this.partScrollTimer = setTimeout(() => {
      this.partScrollTimer = -1
      // 收回会销毁网格、重建单行 List；Scroller 重新绑定前调用可能抛错，不得影响主流程。
      try {
        this.partScroller.scrollToIndex(index, true, ScrollAlign.CENTER)
      } catch (e) {
        // 居中失败不阻塞收回；下次选中会再次尝试。
      }
    }, PART_COLLAPSE_SETTLE_MS)
  }

  private selectMuscle(muscle: string): void {
    this.selectedMuscle = muscle
  }

  private toggleFavOnly(): void {
    this.favOnly = !this.favOnly
  }

  // -------------------------------------------------------------------------
  // 弹层 / toast
  // -------------------------------------------------------------------------
  private currentExercise(): ExerciseItem | undefined {
    const selectedId: string = this.selectedId
    for (let index = 0; index < this.exercises.length; index++) {
      if (this.exercises[index].id === selectedId) {
        return this.exercises[index]
      }
    }
    // 内容库为空或 id 失配时返回 undefined（调用方渲染空态，不再回落写死样例行）。
    return this.exercises.length > 0 ? this.exercises[0] : undefined
  }

  /**
   * 供 @Builder 使用的非空便捷口：无动作时返回一个空壳（字段全空串），
   * 使弹层在内容库为空时不崩、渲染为空白（弹层本身仅在选中动作后才可见）。
   */
  private sheetExercise(): ExerciseItem {
    const exercise: ExerciseItem | undefined = this.currentExercise()
    if (exercise !== undefined) {
      return exercise
    }
    return makeExercise('', '', '', '', '', '', '', '')
  }

  private openSheet(id: string): void {
    this.ctaBusy = false
    // geometryTransition 只认 animateTo 驱动；动效时长/曲线取自此处配置。
    this.getUIContext().animateTo({
      duration: MotionTokens.DURATION_MODAL_POP,
      curve: MotionTokens.EASE_PANEL
    }, () => {
      this.selectedId = id
      this.sheetVisible = true
    })
  }

  private closeSheet(): void {
    if (!this.sheetVisible) {
      return
    }
    this.getUIContext().animateTo({
      duration: MotionTokens.DURATION_MODAL_POP,
      curve: MotionTokens.EASE_PANEL
    }, () => {
      this.sheetVisible = false
    })
    try {
      this.getUIContext().getFocusController().requestFocus('lib-card-' + this.selectedId)
    } catch (e) {
      // 焦点还原失败不影响主流程。
    }
  }

  private showToast(message: string): void {
    this.toastMessage = message
    this.toastVisible = true
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
    this.toastTimer = setTimeout(() => {
      this.toastVisible = false
    }, 1900)
  }

  private addToPlan(): void {
    if (this.ctaBusy) {
      return
    }
    this.ctaBusy = true
    const name: string = this.sheetExercise().name
    if (this.ctaTimer >= 0) {
      clearTimeout(this.ctaTimer)
    }
    this.ctaTimer = setTimeout(() => {
      this.ctaBusy = false
      this.showToast('已把「' + name + '」加入今日计划')
    }, 1600)
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back()
    } catch (e) {
      // 无历史栈时留在当前页。
    }
  }

  // -------------------------------------------------------------------------
  // 构建
  // -------------------------------------------------------------------------
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(LibPalette.BG_BASE)

      Column() {
        this.buildTopBar()

        Scroll() {
          Column({ space: 14 }) {
            this.buildSearch()

            this.buildPartChips()

            if (this.selectedPart !== '全部') {
              this.buildMuscleChips()
            }

            ForEach(EQUIPMENT_ORDER, (equipment: string) => {
              if (this.groupItems(equipment).length > 0) {
                this.buildGroupSection(equipment)
              }
            }, (equipment: string) => equipment)

            if (this.filteredExercises().length === 0) {
              this.buildEmptyState()
            }

            Text('动作数据为演示内容；点击卡片查看动作要点，点右上角心形可收藏。')
              .width('100%')
              .fontSize(11)
              .fontColor(LibPalette.WHITE_54)
              .textAlign(TextAlign.Center)
              .lineHeight(18)
              .padding({ left: 6, right: 6, top: 2, bottom: 0 })
          }
          .width('100%')
          .padding({
            left: 16,
            right: 16,
            top: 8,
            bottom: 30 + this.bottomInset
          })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')

      if (this.sheetVisible) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(LibPalette.BACKDROP)
          .transition(TransitionEffect.OPACITY.animation({
            duration: MotionTokens.DURATION_OVERLAY,
            curve: MotionTokens.EASE_MOTION
          }))
          .onClick(() => {
            this.closeSheet()
          })
      }

      if (this.sheetVisible) {
        // 居中承载层：面板由卡片原位放大到屏幕中央；自身不拦截命中，点空白仍可关闭。
        Column() {
          this.buildSheet()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 16, right: 16 })
        .hitTestBehavior(HitTestMode.None)
      }

      if (this.toastVisible) {
        Row() {
          Text(this.toastMessage)
            .fontSize(13)
            .lineHeight(18)
            .fontColor(LibPalette.TEXT_HI)
            .textAlign(TextAlign.Center)
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .constraintSize({ maxWidth: 320 })
        .backgroundColor(LibPalette.TOAST_BG)
        .borderRadius(999)
        .border({ width: 1, color: LibPalette.CHIP_BORDER })
        .margin({ bottom: 30 + this.bottomInset })
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.translate({ y: 10 }))
          .animation({
            duration: MotionTokens.DURATION_COLOR_BASE,
            curve: MotionTokens.EASE_MOTION
          }))
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildTopBar() {
    Row() {
      Column() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([LibPalette.WHITE_70])
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(LibPalette.GLASS_BTN_BG)
      .border({ width: 1, color: LibPalette.GLASS_BTN_BORDER })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressedBack = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedBack = false
        }
      })
      .scale({
        x: this.pressedBack ? MotionTokens.PRESS_BACK : 1,
        y: this.pressedBack ? MotionTokens.PRESS_BACK : 1
      })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
      .onClick(() => {
        this.goBack()
      })

      Text('动作库')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(LibPalette.TEXT_HI)

      Column() {
        if (this.favOnly) {
          SymbolGlyph($r('sys.symbol.heart_fill'))
            .fontSize(20)
            .fontColor([LibPalette.ACCENT])
        } else {
          SymbolGlyph($r('sys.symbol.heart'))
            .fontSize(20)
            .fontColor([LibPalette.WHITE_70])
        }
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.favOnly ? LibPalette.FAV_FILTER_ON_BG : LibPalette.GLASS_BTN_BG)
      .border({ width: 1, color: this.favOnly ? LibPalette.CHIP_ACTIVE_BORDER : LibPalette.GLASS_BTN_BORDER })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressedFavFilter = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedFavFilter = false
        }
      })
      .scale({
        x: this.pressedFavFilter ? MotionTokens.PRESS_BACK : 1,
        y: this.pressedFavFilter ? MotionTokens.PRESS_BACK : 1
      })
      .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
      .onClick(() => {
        this.toggleFavOnly()
      })
    }
    .width('100%')
    .padding({ top: this.topInset, left: 16, right: 16, bottom: 12 })
  }

  @Builder
  private buildSearch() {
    Row({ space: 9 }) {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(17)
        .fontColor([LibPalette.WHITE_40])

      TextInput({ text: this.query, placeholder: '搜索动作、肌群或器械' })
        .layoutWeight(1)
        .height(44)
        .fontSize(14)
        .fontColor(LibPalette.TEXT_HI)
        .placeholderColor(LibPalette.WHITE_40)
        .placeholderFont({ size: 14 })
        .caretColor(LibPalette.ACCENT)
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0 })
        .onChange((value: string) => {
          this.query = value
        })
        .onFocus(() => {
          this.searchFocused = true
        })
        .onBlur(() => {
          this.searchFocused = false
        })
    }
    .width('100%')
    .height(44)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.searchFocused ? 'rgba(255,255,255,0.055)' : LibPalette.CHIP_BG)
    .borderRadius(14)
    .border({ width: 1, color: this.searchFocused ? LibPalette.ACCENT : LibPalette.CHIP_BORDER })
    .outline({ width: this.searchFocused ? 3 : 0, color: LibPalette.FOCUS_GLOW })
    .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
  }

  @Builder
  private buildChip(label: string, active: boolean) {
    Text(label)
      .fontSize(13)
      .fontWeight(active ? 600 : 500)
      .fontColor(active ? LibPalette.ACCENT : LibPalette.WHITE_70)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(active ? LibPalette.CHIP_ACTIVE_BG : LibPalette.CHIP_BG)
      .borderRadius(999)
      .border({ width: 1, color: active ? LibPalette.CHIP_ACTIVE_BORDER : LibPalette.CHIP_BORDER })
      .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
  }

  @Builder
  private buildSmallChip(label: string, active: boolean) {
    Text(label)
      .fontSize(12)
      .fontWeight(active ? 600 : 500)
      .fontColor(active ? LibPalette.ACCENT : LibPalette.WHITE_70)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(active ? LibPalette.CHIP_ACTIVE_BG : LibPalette.CHIP_BG)
      .borderRadius(999)
      .border({ width: 1, color: active ? LibPalette.CHIP_ACTIVE_BORDER : LibPalette.CHIP_BORDER })
      .animation({ duration: MotionTokens.DURATION_COLOR_FAST, curve: MotionTokens.EASE_MOTION })
  }

  @Builder
  private buildPartChips() {
    if (this.partExpanded) {
      this.buildPartGrid()
    } else {
      this.buildPartRow()
    }
  }

  @Builder
  private buildPartRow() {
    Row() {
      List({ scroller: this.partScroller }) {
        ForEach(PART_OPTIONS, (part: string, index: number) => {
          ListItem() {
            this.buildChip(part, this.selectedPart === part)
          }
          .onClick(() => {
            this.selectPart(part, index)
          })
        }, (part: string) => part)
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .height(PART_ROW_HEIGHT)
      .layoutWeight(1)

      this.buildExpandKey(false)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private buildExpandKey(up: boolean) {
    Column() {
      SymbolGlyph(up ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
        .fontSize(14)
        .fontColor([LibPalette.ACCENT])
    }
    .width(32)
    .height(PART_ROW_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .borderRadius(999)
    .backgroundColor(LibPalette.CHIP_ACTIVE_BG)
    .border({ width: 1, color: LibPalette.CHIP_ACTIVE_BORDER })
    .key('lib-part-expand-key')
    .focusable(true)
    .onClick(() => {
      this.togglePartExpanded()
    })
  }

  @Builder
  private buildPartGrid() {
    Column() {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(PART_OPTIONS, (part: string, index: number) => {
          Column() {
            this.buildChip(part, this.selectedPart === part)
          }
          .margin({ right: 8, bottom: 8 })
          .key('lib-part-grid-' + index)
          .onClick(() => {
            this.collapseToPart(part, index)
          })
        }, (part: string) => part)
      }
      .width('100%')

      Row() {
        Text('收起')
          .fontSize(12)
          .fontColor(LibPalette.WHITE_62)
        SymbolGlyph($r('sys.symbol.chevron_up'))
          .fontSize(13)
          .fontColor([LibPalette.WHITE_62])
          .margin({ left: 4 })
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(999)
      .backgroundColor(LibPalette.CHIP_BG)
      .border({ width: 1, color: LibPalette.CHIP_BORDER })
      .key('lib-part-collapse-key')
      .focusable(true)
      .onClick(() => {
        this.togglePartExpanded()
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildMuscleChips() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.muscleOptions(), (muscle: string) => {
          Column() {
            this.buildSmallChip(muscle, this.selectedMuscle === muscle)
          }
          .onClick(() => {
            this.selectMuscle(muscle)
          })
        }, (muscle: string) => muscle)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .margin({ top: -6 })
  }

  @Builder
  private buildHeartIcon(fav: boolean, size: number) {
    if (fav) {
      SymbolGlyph($r('sys.symbol.heart_fill'))
        .fontSize(size)
        .fontColor([LibPalette.ACCENT])
    } else {
      SymbolGlyph($r('sys.symbol.heart'))
        .fontSize(size)
        .fontColor([LibPalette.WHITE_70])
    }
  }

  @Builder
  private buildCard(item: ExerciseItem) {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        if (this.isGifFailed(item.id)) {
          Column() {
            Image($rawfile('pencil-lucide-dumbbell.svg'))
              .width(30)
              .height(30)
              .fillColor(LibPalette.WHITE_32)
          }
          .width('100%')
          .aspectRatio(4 / 3)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(LibPalette.MEDIA_BG)
        } else {
          // 素材路径经 ExerciseGifCatalog 解析：动作库已改读内容库，item.id 是内容库 id
          // （ex_barbell_bench_press），而素材文件名是 kebab（barbell-bench-press），
          // 直接拼接会全部落空（实测命中 0/102）。解析器内部做 id 归一化与两套目录的分派。
          // 实拍素材无白底，是矩形实景，须套圆角卡片收敛；线稿素材已烘页底色，圆角对其无感。
          if (ExerciseGifCatalog.usesPhotoStyleByExerciseId(item.id)) {
            Image($rawfile(ExerciseGifCatalog.resolveDemoSourceByExerciseId(item.id)))
              .width('100%')
              .aspectRatio(4 / 3)
              .objectFit(ImageFit.Cover)
              .borderRadius(LIB_MEDIA_RADIUS)
              .clip(true)
              .alt(item.name + ' 动作演示')
              .onError(() => {
                this.markGifFailed(item.id)
              })
          } else {
            Image($rawfile(ExerciseGifCatalog.resolveDemoSourceByExerciseId(item.id)))
              .width('100%')
              .aspectRatio(4 / 3)
              .objectFit(ImageFit.Cover)
              .alt(item.name + ' 动作演示')
              .onError(() => {
                this.markGifFailed(item.id)
              })
          }
        }

        Column() {
          this.buildHeartIcon(this.isFav(item.id), 16)
        }
        .width(30)
        .height(30)
        .borderRadius(15)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.isFav(item.id) ? LibPalette.FAV_BG_ACTIVE : LibPalette.FAV_BG)
        .border({ width: 1, color: LibPalette.FAV_BORDER })
        .margin({ top: 8, right: 8 })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.pressedHeartId = item.id
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.pressedHeartId = ''
          }
        })
        .scale({
          x: this.pressedHeartId === item.id ? PRESS_HEART_SCALE : 1,
          y: this.pressedHeartId === item.id ? PRESS_HEART_SCALE : 1
        })
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
        .onClick(() => {
          this.toggleFav(item.id)
        })
      }
      .width('100%')

      Column() {
        Text(item.name)
          .width('100%')
          .fontSize(12)
          .fontWeight(600)
          .fontColor(LibPalette.TEXT_HI)
          .lineHeight(15)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 8, bottom: 9 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .borderRadius(this.sheetVisible && this.selectedId === item.id ? 0 : 14)
    .backgroundColor(LibPalette.CARD_BG)
    .border({ width: 1, color: LibPalette.STROKE })
    .clip(true)
    .key('lib-card-' + item.id)
    .focusable(true)
    .geometryTransition('lib-card-' + item.id)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedCardId = item.id
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedCardId = ''
      }
    })
    .scale({
      x: this.pressedCardId === item.id ? MotionTokens.PRESS_PRIMARY : 1,
      y: this.pressedCardId === item.id ? MotionTokens.PRESS_PRIMARY : 1
    })
    .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
    .onClick(() => {
      this.openSheet(item.id)
    })
  }

  @Builder
  private buildGroupSection(equipment: string) {
    Column({ space: 10 }) {
      Row() {
        Text(equipment)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(LibPalette.TEXT_HI)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Grid() {
        ForEach(this.groupItems(equipment), (item: ExerciseItem) => {
          GridItem() {
            this.buildCard(item)
          }
        }, (item: ExerciseItem) => item.id)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private buildEmptyState() {
    Column({ space: 6 }) {
      Column() {
        Column({ space: 2 }) {
          Row({ space: 2 }) {
            Rect({ width: 7, height: 7, radius: 2 })
              .fillOpacity(0)
              .stroke(LibPalette.WHITE_40)
              .strokeWidth(1.6)
            Rect({ width: 7, height: 7, radius: 2 })
              .fillOpacity(0)
              .stroke(LibPalette.WHITE_40)
              .strokeWidth(1.6)
          }
          Row({ space: 2 }) {
            Rect({ width: 7, height: 7, radius: 2 })
              .fillOpacity(0)
              .stroke(LibPalette.WHITE_40)
              .strokeWidth(1.6)
            Rect({ width: 7, height: 7, radius: 2 })
              .fillOpacity(0)
              .stroke(LibPalette.WHITE_40)
              .strokeWidth(1.6)
          }
        }
      }
      .width(46)
      .height(46)
      .borderRadius(23)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('rgba(255,255,255,0.05)')
      .border({ width: 1, color: LibPalette.CHIP_BORDER })
      .margin({ bottom: 6 })

      Text(this.emptyTitle())
        .fontSize(14)
        .fontWeight(600)
        .fontColor(LibPalette.TEXT_HI)

      Text(this.emptyHint())
        .fontSize(12)
        .lineHeight(18)
        .fontColor(LibPalette.WHITE_54)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 38, bottom: 34, left: 20, right: 20 })
  }

  @Builder
  private buildSheetRow(key: string, value: string) {
    Row() {
      Text(key)
        .fontSize(13)
        .fontColor(LibPalette.WHITE_54)

      Text(value)
        .layoutWeight(1)
        .fontSize(13)
        .fontWeight(600)
        .fontColor(LibPalette.TEXT_HI)
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
    .border({ width: { bottom: 1 }, color: LibPalette.HAIRLINE })
  }

  @Builder
  private buildSheet() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.isGifFailed(this.sheetExercise().id)) {
          Column() {
            Image($rawfile('pencil-lucide-dumbbell.svg'))
              .width(36)
              .height(36)
              .fillColor(LibPalette.WHITE_32)
          }
          .width('100%')
          .aspectRatio(16 / 9)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(14)
        } else {
          // 与网格卡片同源：路径经 ExerciseGifCatalog 解析（内容库 id -> kebab 素材名），
          // 实拍素材套圆角收敛。此处容器已是 16:9 圆角，故实拍分支沿用同一圆角值。
          Image($rawfile(ExerciseGifCatalog.resolveDemoSourceByExerciseId(this.sheetExercise().id)))
            .width('100%')
            .aspectRatio(16 / 9)
            .objectFit(ImageFit.Contain)
            .borderRadius(14)
            .alt(this.sheetExercise().name + ' 动作演示')
            .onError(() => {
              this.markGifFailed(this.sheetExercise().id)
            })
        }

        Text('动作演示')
          .fontSize(11)
          .fontWeight(600)
          .fontColor(LibPalette.TEXT_HI)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(LibPalette.FAV_BG)
          .borderRadius(999)
          .border({ width: 1, color: LibPalette.FAV_BORDER })
          .margin({ left: 10, top: 10 })
      }
      .width('100%')
      .backgroundColor(LibPalette.MEDIA_BG_SHEET)
      .borderRadius(14)
      .clip(true)
      .margin({ bottom: 16 })

      Row({ space: 12 }) {
        Text(this.sheetExercise().name)
          .layoutWeight(1)
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(LibPalette.TEXT_HI)
          .lineHeight(25)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Column() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(18)
            .fontColor([LibPalette.WHITE_70])
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(LibPalette.GLASS_CLOSE_BG)
        .border({ width: 1, color: LibPalette.CHIP_BORDER })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.pressedClose = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.pressedClose = false
          }
        })
        .scale({
          x: this.pressedClose ? MotionTokens.PRESS_ICON : 1,
          y: this.pressedClose ? MotionTokens.PRESS_ICON : 1
        })
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
        .onClick(() => {
          this.closeSheet()
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.sheetTags(), (tag: string) => {
          Text(tag)
            .fontSize(11.5)
            .fontWeight(600)
            .fontColor(LibPalette.ACCENT)
            .padding({ left: 11, right: 11, top: 4, bottom: 4 })
            .backgroundColor(LibPalette.TAG_BG)
            .borderRadius(999)
            .border({ width: 1, color: LibPalette.TAG_BORDER })
            .margin({ right: 7, bottom: 7 })
        }, (tag: string) => tag)
      }
      .width('100%')
      .margin({ top: 12, bottom: -7 })

      Column() {
        this.buildSheetRow('目标肌群', this.sheetExercise().muscles)
        this.buildSheetRow('器械', this.sheetExercise().equipment)
        this.buildSheetRow('难度', this.sheetExercise().level)
      }
      .width('100%')
      .margin({ top: 6 })

      Text(this.sheetExercise().tip)
        .width('100%')
        .fontSize(13)
        .lineHeight(22)
        .fontColor(LibPalette.WHITE_62)
        .margin({ top: 14 })

      Button(this.ctaBusy ? '已加入今日计划' : '加入训练计划')
        .type(ButtonType.Normal)
        .width('100%')
        .height(52)
        .margin({ top: 18 })
        .borderRadius(16)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(LibPalette.ON_ACCENT)
        .backgroundColor(LibPalette.ACCENT)
        .opacity(this.ctaBusy ? 0.92 : 1)
        .enabled(!this.ctaBusy)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.pressedCta = true
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.pressedCta = false
          }
        })
        .scale({
          x: this.pressedCta ? MotionTokens.PRESS_PRIMARY : 1,
          y: this.pressedCta ? MotionTokens.PRESS_PRIMARY : 1
        })
        .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
        .onClick(() => {
          this.addToPlan()
        })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 20, bottom: 20 })
    .constraintSize({ maxHeight: '84%' })
    .backgroundColor(LibPalette.SHEET_BG)
    .borderRadius(26)
    .border({ width: 1, color: LibPalette.CHIP_BORDER })
    // 共享元素转场：与 buildCard 外层同一 id，由卡片原位放大到居中；离场时反向缩回。
    .geometryTransition('lib-card-' + this.selectedId)
    .transition(TransitionEffect.OPACITY.animation({
      duration: MotionTokens.DURATION_MODAL_SCRIM,
      curve: MotionTokens.EASE_MOTION
    }))
  }

  private sheetTags(): string[] {
    const exercise: ExerciseItem | undefined = this.currentExercise()
    const tags: string[] = []
    if (exercise === undefined) {
      return tags
    }
    tags.push(exercise.part)
    tags.push(exercise.equipment)
    tags.push(exercise.level)
    return tags
  }

  private emptyTitle(): string {
    if (this.favOnly) {
      return '暂无收藏'
    }
    if (this.query.trim().length > 0) {
      return '没有匹配的动作'
    }
    return '该部位暂无动作'
  }

  private emptyHint(): string {
    if (this.favOnly) {
      return '点右上角心形，收藏常用动作'
    }
    if (this.query.trim().length > 0) {
      return '换个关键词试试'
    }
    return '换个部位或肌群筛选试试'
  }
}
