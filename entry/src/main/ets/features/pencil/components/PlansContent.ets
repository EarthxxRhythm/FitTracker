/** PlansContent —— 计划组列表页界面体（对应 plan-detail.html · screen-plan-detail）。
 *  数据源：TrainingPlanService 的预置计划（按分化数成套：二/三/四/五分化）；
 *  顶部「当前计划」由宿主页在 onPageShow 时读取 getCurrentPlan 后经 @Prop 注入。 */
import { AppRoutes } from '../../../app/AppRoutes'
import { MotionTokens } from '../../../common/styles/DesignTokens'
import TrainingPlanService, { PresetPlan } from '../../../common/services/TrainingPlanService'
import { Context } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'

interface GroupCard {
  planId: string
  name: string
  audience: string
  freq: string
  days: number
  examples: string
  icon: string
}

/** 计划 id → 封面 icon 键（与 `coverIcon` 内的分支一一对应）。 */
function iconForPlan(planId: string): string {
  if (planId === 'preset_upper_lower') {
    return 'layers'
  }
  if (planId === 'preset_ppl') {
    return 'activity'
  }
  if (planId === 'preset_split_4') {
    return 'target'
  }
  if (planId === 'preset_bro_split') {
    return 'dumbbell'
  }
  return 'layers'
}

/** 取首个训练日前 3 个动作名，作为卡片上的「示例」行。 */
function buildExamples(plan: PresetPlan): string {
  if (plan.days.length === 0) {
    return ''
  }
  const exercises = plan.days[0].exercises
  const names: string[] = []
  const limit: number = exercises.length < 3 ? exercises.length : 3
  for (let index = 0; index < limit; index++) {
    names.push(exercises[index].name)
  }
  return names.join(' · ')
}

function createGroupCard(plan: PresetPlan): GroupCard {
  const card: GroupCard = {
    planId: plan.id,
    name: plan.name,
    audience: plan.targetAudience,
    freq: plan.weeklyFrequency,
    days: plan.days.length,
    examples: buildExamples(plan),
    icon: iconForPlan(plan.id)
  }
  return card
}

function buildGroupCards(): GroupCard[] {
  const plans: PresetPlan[] = TrainingPlanService.getAllPresetPlans()
  const cards: GroupCard[] = []
  for (let index = 0; index < plans.length; index++) {
    cards.push(createGroupCard(plans[index]))
  }
  return cards
}

@Component
export struct PlansContent {
  // 当前计划（由 PencilPlansPage 在 onPageShow 刷新后注入）。
  @Prop currentPlanName: string = ''
  @Prop currentPlanMeta: string = ''
  @Prop hasCurrentPlan: boolean = false

  @State private backPressed: boolean = false
  @State private pressedCardKey: string = ''
  @State private groups: GroupCard[] = []
  // 系统状态栏高度（vp）。页面区本身落在状态栏之下，原型顶距须扣掉它才不会双计。
  @State private topInsetVp: number = 0

  aboutToAppear(): void {
    // 列表数据先就绪（首帧不闪空列表），安全区异步到达后仅重算顶栏 padding。
    // 原型 .pd-top 的 padding-top: 52px 以屏幕顶为原点（已把状态栏含在内）；设备侧页面区本身
    // 落在状态栏之下，若原样使用 52 就与系统避让重复计数，顶栏下移一个状态栏高度（同
    // PlanGroupDetailContent / PencilPreviewPage 的局部补偿口径）。
    this.groups = buildGroupCards()
    this.resolveTopInset()
  }

  private async resolveTopInset(): Promise<void> {
    const hostContext: Context | undefined = this.getUIContext().getHostContext()
    if (hostContext === undefined) {
      return
    }
    try {
      const mainWindow: window.Window = await window.getLastWindow(hostContext)
      const avoidArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topInsetVp = this.getUIContext().px2vp(avoidArea.topRect.height)
    } catch (e) {
      // 取不到安全区时按 0 处理，顶距回退为原型的 52vp
      this.topInsetVp = 0
    }
  }

  private handleBack(): void {
    this.getUIContext().getRouter().back()
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#0B0F13', 0], ['#0A0D12', 1]] })

      Column() {
        Row({ space: 8 }) {
          Row() {
            // 不用 ArkUI Path——其 commands 坐标按物理像素解释（width/height 却是 vp），
            // 在 3.38 密度下 22vp 的箭头只画出约 4.4×6.5vp 且贴在容器左上；改用 SVG 资源。
            Image($rawfile('pencil-plan-nav-chevron-left.svg'))
              .width(22)
              .height(22)
              .opacity(0.7)
          }
          .width(40)
          .height(40)
          .borderRadius(12)
          .justifyContent(FlexAlign.Center)
          .scale({ x: this.backPressed ? MotionTokens.PRESS_BACK : 1, y: this.backPressed ? MotionTokens.PRESS_BACK : 1 })
          .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.backPressed = true
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.backPressed = false
            }
          })
          .onClick(() => {
            this.handleBack()
          })
          Text('计划组')
            .fontFamily('Noto Sans SC')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBF8')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Row()
            .width(40)
            .height(40)
        }
        .width('100%')
        .padding({ top: Math.max(52 - this.topInsetVp, 0), bottom: 10, left: 12, right: 12 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor('#F50A0D12')
        .border({ width: { bottom: 1 }, color: '#0FFFFFFF' })

        Scroll() {
          Column({ space: 20 }) {
            this.currentCard()

            Column() {
              Text('计划组')
                .fontFamily('Noto Sans SC')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#8AFFFFFF')
                .width('100%')
              Column({ space: 10 }) {
                ForEach(this.groups, (group: GroupCard) => {
                  this.groupCard(group)
                }, (group: GroupCard) => group.planId)
              }
              .width('100%')
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 28 })
        }
        .width('100%')
        .layoutWeight(1)
        // Scroll 一旦设了 layoutWeight（高度受限），内容不足一屏时会居中排布（HarmonyOS FAQ
        // faqs-arkui-725），把首张卡片推到屏幕中部、顶栏标题与正文之间空出一大块；align(Top)
        // 强制内容从顶部排布，内容超长时仍正常滚动。
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0F13')
  }

  @Builder
  private currentCard() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 0 }) {
        Text('当前计划')
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#50ECA7')
        Text(this.hasCurrentPlan ? this.currentPlanName : '尚未启用计划')
          .fontFamily('Noto Sans SC')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
          .lineHeight(23)
          .margin({ top: 9 })
          .padding({ right: 76 })
        Text(this.hasCurrentPlan ? this.currentPlanMeta : '从下方选择一个训练计划开始')
          .fontFamily('Noto Sans SC')
          .fontSize(12)
          .fontColor('#9EFFFFFF')
          .margin({ top: 6 })
      }
      .width('100%')
      .padding({ top: 16, right: 16, bottom: 15, left: 16 })
      .alignItems(HorizontalAlign.Start)

      if (this.hasCurrentPlan) {
        Text('当前使用')
          .fontFamily('Noto Sans SC')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#07100B')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor('#50ECA7')
          .borderRadius(999)
          .margin({ top: 14, right: 14 })
      }
    }
    .width('100%')
    .backgroundColor('#1450ECA7')
    .border({ width: 1, color: '#6680ECA7' })
    .borderRadius(20)
    .shadow({ radius: 28, color: '#33000000', offsetX: 0, offsetY: 14 })
  }

  @Builder
  private groupCard(group: GroupCard) {
    Row({ space: 13 }) {
      Row() {
        this.coverIcon(group.icon)
      }
      .width(52)
      .height(52)
      .borderRadius(14)
      .backgroundColor('#1A50ECA7')
      .border({ width: 1, color: '#3850ECA7' })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      Column({ space: 5 }) {
        Text(group.name)
          .fontFamily('Noto Sans SC')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FBF8')
        Row({ space: 8 }) {
          Text(group.audience)
            .fontFamily('Noto Sans SC')
            .fontSize(11)
            .fontColor('#9EFFFFFF')
            .padding({ left: 9, right: 9, top: 3, bottom: 3 })
            .backgroundColor('#0FFFFFFF')
            .border({ width: 1, color: '#0FFFFFFF' })
            .borderRadius(999)
          Text(group.freq)
            .fontFamily('Noto Sans SC')
            .fontSize(11)
            .fontColor('#8AFFFFFF')
          Text(group.days.toString() + ' 个训练日')
            .fontFamily('Inter')
            .fontSize(11)
            .fontColor('#8AFFFFFF')
        }
        Text('示例 ' + group.examples)
          .fontFamily('Noto Sans SC')
          .fontSize(11)
          .fontColor('#8AFFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Image($rawfile('pencil-plan-nav-chevron-right.svg'))
        .width(20)
        .height(20)
        .opacity(0.4)
    }
    .width('100%')
    .padding({ top: 13, right: 14, bottom: 13, left: 14 })
    .backgroundColor('#151B20')
    .border({ width: 1, color: '#14FFFFFF' })
    .borderRadius(18)
    .constraintSize({ minHeight: 92 })
    .scale({ x: this.pressedCardKey === group.planId ? MotionTokens.PRESS_PRIMARY : 1, y: this.pressedCardKey === group.planId ? MotionTokens.PRESS_PRIMARY : 1 })
    .animation({ duration: MotionTokens.DURATION_PRESS, curve: MotionTokens.EASE_MOTION })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedCardKey = group.planId
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedCardKey = ''
      }
    })
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({
        url: AppRoutes.PLAN_GROUP_DETAIL,
        params: {
          planId: group.planId
        }
      })
    })
  }

  @Builder
  private coverIcon(icon: string) {
    if (icon === 'layers') {
      Image($rawfile('pencil-plan-cover-layers.svg'))
        .width(24)
        .height(24)
    } else if (icon === 'activity') {
      Image($rawfile('pencil-plan-cover-activity.svg'))
        .width(24)
        .height(24)
    } else if (icon === 'zap') {
      Image($rawfile('pencil-plan-cover-zap.svg'))
        .width(24)
        .height(24)
    } else if (icon === 'dumbbell') {
      Image($rawfile('pencil-plan-cover-dumbbell.svg'))
        .width(24)
        .height(24)
    } else if (icon === 'target') {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(16)
          .height(16)
          .fillOpacity(0)
          .stroke('#50ECA7')
          .strokeWidth(1.8)
        Circle()
          .width(6)
          .height(6)
          .fillOpacity(0)
          .stroke('#50ECA7')
          .strokeWidth(1.8)
        Circle()
          .width(1.2)
          .height(1.2)
          .fill('#50ECA7')
      }
      .width(24)
      .height(24)
    } else if (icon === 'chevrons-up') {
      Image($rawfile('pencil-plan-cover-chevrons-up.svg'))
        .width(24)
        .height(24)
    } else if (icon === 'chevrons-down') {
      Image($rawfile('pencil-plan-cover-chevrons-down.svg'))
        .width(24)
        .height(24)
    } else if (icon === 'core') {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width(16)
          .height(16)
          .fillOpacity(0)
          .stroke('#50ECA7')
          .strokeWidth(1.8)
        Circle()
          .width(4.8)
          .height(4.8)
          .fill('#50ECA7')
      }
      .width(24)
      .height(24)
    } else if (icon === 'home') {
      Image($rawfile('pencil-plan-cover-home.svg'))
        .width(24)
        .height(24)
    } else {
      // heart（HTML i-heart 的绝对坐标近似）
      Image($rawfile('pencil-plan-cover-heart.svg'))
        .width(24)
        .height(24)
    }
  }
}
