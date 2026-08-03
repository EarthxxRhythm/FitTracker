/**
 * GoalSetupPage -- target training goal questionnaire.
 * Function #7: real goal setup questionnaire.
 */
import { Context } from '@kit.AbilityKit'
import { AppRoutes } from '../../../app/AppRoutes'
import { ColorTokens, FontTokens, RadiusTokens, SpacingTokens, TouchTokens } from '../../../common/styles/DesignTokens'
import { AppButton } from '../../../components/AppButton'
import { AppCard } from '../../../components/AppCard'
import { createStageRailItem, StageRail, StageRailItem } from '../../../components/StageRail'
import { UserGoal } from '../../../shared/models/TrainingModels'
import GoalRepository from '../../../shared/services/GoalRepository'
import GoalSetupService, { GoalSetupPrefill } from '../../../shared/services/GoalSetupService'

interface GoalOption {
  id: string
  label: string
}

function createGoalOption(id: string, label: string): GoalOption {
  const option: GoalOption = {
    id: id,
    label: label
  }
  return option
}

const GOAL_OPTIONS: GoalOption[] = [
  createGoalOption('hypertrophy', '增肌'),
  createGoalOption('strength', '力量'),
  createGoalOption('fat_loss', '减脂')
]

const LEVEL_OPTIONS: GoalOption[] = [
  createGoalOption('beginner', '新手'),
  createGoalOption('intermediate', '进阶'),
  createGoalOption('advanced', '熟练')
]

const DAY_OPTIONS: number[] = [2, 3, 4, 5]
const MINUTE_OPTIONS: number[] = [30, 45, 60, 75]

const EQUIPMENT_OPTIONS: GoalOption[] = [
  createGoalOption('eq_bodyweight', '自重'),
  createGoalOption('eq_dumbbell', '哑铃'),
  createGoalOption('eq_barbell', '杠铃'),
  createGoalOption('eq_cable', '绳索')
]

const RESTRICTED_MUSCLE_OPTIONS: GoalOption[] = [
  createGoalOption('muscle_chest', '胸部'),
  createGoalOption('muscle_back', '背部'),
  createGoalOption('muscle_legs', '腿部'),
  createGoalOption('muscle_shoulders', '肩部'),
  createGoalOption('muscle_arms', '手臂'),
  createGoalOption('muscle_core', '核心')
]

@Entry
@Component
export struct GoalSetupPage {
  @State saving: boolean = false
  @State hasExistingGoal: boolean = false
  @State existingGoal: UserGoal | undefined = undefined
  @State selectedGoalType: string = 'hypertrophy'
  @State selectedLevel: string = 'beginner'
  @State weeklyDays: number = 3
  @State sessionMinutes: number = 45
  @State selectedEquipmentIds: string[] = ['eq_bodyweight', 'eq_dumbbell']
  @State selectedRestrictedMuscleIds: string[] = []

  private getHostContextOrNull(): Context | null {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      return null
    }
    return hostContext as Context
  }

  async aboutToAppear(): Promise<void> {
    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.hasExistingGoal = false
        return
      }
      const goal: UserGoal | undefined = await GoalRepository.loadGoal(context)
      if (goal !== undefined) {
        const prefill: GoalSetupPrefill = GoalSetupService.createPrefillFromGoal(goal)
        this.hasExistingGoal = true
        this.existingGoal = goal
        this.selectedGoalType = prefill.goalType
        this.selectedLevel = prefill.level
        this.weeklyDays = prefill.weeklyDays
        this.sessionMinutes = prefill.sessionMinutes
        this.selectedEquipmentIds = prefill.equipmentIds
        this.selectedRestrictedMuscleIds = prefill.restrictedMuscleIds
      }
    } catch (e) {
      this.hasExistingGoal = false
    }
  }

  async saveSelectedGoal(): Promise<void> {
    if (this.saving) {
      return
    }
    this.saving = true
    const equipmentIds: string[] = this.getSelectedEquipmentIds()
    const restrictedMuscleIds: string[] = this.copyStringArray(this.selectedRestrictedMuscleIds)
    const now: number = Date.now()
    let goal: UserGoal
    if (this.existingGoal !== undefined) {
      goal = GoalSetupService.createGoalFromExistingSelection(
        this.existingGoal,
        this.selectedGoalType,
        this.selectedLevel,
        this.weeklyDays,
        this.sessionMinutes,
        equipmentIds,
        restrictedMuscleIds,
        now
      )
    } else {
      goal = GoalSetupService.createCurrentGoalFromSelection(
        this.selectedGoalType,
        this.selectedLevel,
        this.weeklyDays,
        this.sessionMinutes,
        equipmentIds,
        restrictedMuscleIds,
        now
      )
    }

    try {
      const context: Context | null = this.getHostContextOrNull()
      if (context === null) {
        this.saving = false
        return
      }
      await GoalRepository.saveGoal(context, goal)
      this.getUIContext().getRouter().replaceUrl({ url: AppRoutes.APP_SHELL })
    } catch (e) {
      this.saving = false
    }
  }

  toggleEquipment(equipmentId: string): void {
    const values: string[] = []
    const exists: boolean = this.containsValue(this.selectedEquipmentIds, equipmentId)
    for (let index = 0; index < this.selectedEquipmentIds.length; index++) {
      const value: string = this.selectedEquipmentIds[index]
      if (value !== equipmentId) {
        values.push(value)
      }
    }
    if (!exists) {
      values.push(equipmentId)
    }
    this.selectedEquipmentIds = values
  }

  toggleRestrictedMuscle(muscleId: string): void {
    const values: string[] = []
    const exists: boolean = this.containsValue(this.selectedRestrictedMuscleIds, muscleId)
    for (let index = 0; index < this.selectedRestrictedMuscleIds.length; index++) {
      const value: string = this.selectedRestrictedMuscleIds[index]
      if (value !== muscleId) {
        values.push(value)
      }
    }
    if (!exists) {
      values.push(muscleId)
    }
    this.selectedRestrictedMuscleIds = values
  }

  getSelectedEquipmentIds(): string[] {
    if (this.selectedEquipmentIds.length === 0) {
      const fallback: string[] = ['eq_bodyweight']
      return fallback
    }

    const values: string[] = []
    for (let index = 0; index < this.selectedEquipmentIds.length; index++) {
      values.push(this.selectedEquipmentIds[index])
    }
    return values
  }

  containsValue(values: string[], targetValue: string): boolean {
    for (let index = 0; index < values.length; index++) {
      if (values[index] === targetValue) {
        return true
      }
    }
    return false
  }

  copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }

  selectedBg(isSelected: boolean): string {
    if (isSelected) {
      return ColorTokens.PRIMARY
    }
    return ColorTokens.BG_ELEVATED
  }

  selectedTextColor(isSelected: boolean): string {
    if (isSelected) {
      return ColorTokens.TEXT_ON_PRIMARY
    }
    return ColorTokens.TEXT_SECONDARY
  }

  selectedBorderColor(isSelected: boolean): string {
    if (isSelected) {
      return ColorTokens.PRIMARY
    }
    return ColorTokens.BORDER_SUBTLE
  }

  getOptionLabel(options: GoalOption[], id: string): string {
    for (let index = 0; index < options.length; index++) {
      if (options[index].id === id) {
        return options[index].label
      }
    }
    return id
  }

  appendSummaryLabel(summary: string, label: string): string {
    if (summary.length === 0) {
      return label
    }
    return summary + '、' + label
  }

  getEquipmentSummaryText(): string {
    const selectedIds: string[] = this.getSelectedEquipmentIds()
    let summary: string = ''
    for (let index = 0; index < EQUIPMENT_OPTIONS.length; index++) {
      if (this.containsValue(selectedIds, EQUIPMENT_OPTIONS[index].id)) {
        summary = this.appendSummaryLabel(summary, EQUIPMENT_OPTIONS[index].label)
      }
    }
    return summary
  }

  getRestrictionSummaryText(): string {
    if (this.selectedRestrictedMuscleIds.length === 0) {
      return '无特别限制'
    }
    let summary: string = ''
    for (let index = 0; index < RESTRICTED_MUSCLE_OPTIONS.length; index++) {
      if (this.containsValue(this.selectedRestrictedMuscleIds, RESTRICTED_MUSCLE_OPTIONS[index].id)) {
        summary = this.appendSummaryLabel(summary, RESTRICTED_MUSCLE_OPTIONS[index].label)
      }
    }
    return summary
  }

  getStageRailItems(): StageRailItem[] {
    const items: StageRailItem[] = []
    items.push(createStageRailItem('目标', true, false))
    items.push(createStageRailItem('预览', false, false))
    items.push(createStageRailItem('执行', false, false))
    items.push(createStageRailItem('回顾', false, false))
    return items
  }

  @Builder
  buildSetupMetricTile(label: string, value: string, note: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(label)
        .fontSize(FontTokens.SMALL_SIZE)
        .fontColor(ColorTokens.TEXT_TERTIARY)

      Text(value)
        .fontSize(FontTokens.TITLE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ColorTokens.TEXT_PRIMARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(note)
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding(SpacingTokens.MD)
    .backgroundColor(ColorTokens.BG_ELEVATED)
    .borderRadius(RadiusTokens.MD)
    .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildChoiceButton(label: string, widthValue: string, isSelected: boolean, onTap: () => void) {
    Button(label)
      .width(widthValue)
      .height(TouchTokens.BUTTON_HEIGHT_DEFAULT)
      .fontSize(FontTokens.BODY_SIZE)
      .fontColor(this.selectedTextColor(isSelected))
      .backgroundColor(this.selectedBg(isSelected))
      .borderRadius(RadiusTokens.SM)
      .border({
        width: 1,
        color: this.selectedBorderColor(isSelected)
      })
      .margin({ right: SpacingTokens.SM, bottom: SpacingTokens.SM })
      .onClick(onTap)
  }

  @Builder
  buildSummaryPanel() {
    Column({ space: SpacingTokens.SM }) {
      Text('当前配置摘要')
        .fontSize(FontTokens.BODY_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ColorTokens.TEXT_PRIMARY)

      Text(this.getEquipmentSummaryText())
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
        .width('100%')

      Text(this.getRestrictionSummaryText())
        .fontSize(FontTokens.CAPTION_SIZE)
        .fontColor(ColorTokens.TEXT_SECONDARY)
        .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
        .width('100%')
    }
    .width('100%')
    .padding(SpacingTokens.MD)
    .backgroundColor(ColorTokens.BG_ELEVATED)
    .borderRadius(RadiusTokens.SM)
    .border({ width: 1, color: ColorTokens.BORDER_SUBTLE })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildLaneHeader(eyebrow: string, title: string, description: string) {
    Column({ space: SpacingTokens.XS }) {
      Text(eyebrow)
        .fontSize(FontTokens.MICRO_SIZE)
        .fontWeight(FontTokens.MICRO_WEIGHT)
        .fontColor(ColorTokens.TEXT_TERTIARY)

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

  build() {
    Scroll() {
      Column({ space: SpacingTokens.LG }) {
        AppCard({ variant: 'panel', cardPadding: 'default' }) {
          Column({ space: SpacingTokens.MD }) {
            Row() {
              Column({ space: SpacingTokens.XS }) {
                Text(this.hasExistingGoal ? '更新训练目标' : '训练目标')
                  .fontSize(FontTokens.DISPLAY_SIZE)
                  .fontWeight(FontTokens.DISPLAY_WEIGHT)
                  .fontColor(ColorTokens.TEXT_PRIMARY)

                Text('先建立目标，后续计划会围绕你的目标、经验和器械生成。')
                  .fontSize(FontTokens.BODY_SIZE)
                  .fontColor(ColorTokens.TEXT_SECONDARY)
                  .lineHeight(FontTokens.BODY_LINE_HEIGHT)
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              if (this.hasExistingGoal) {
                Text('已有配置')
                  .fontSize(FontTokens.SMALL_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ColorTokens.SUCCESS)
                  .padding({
                    top: SpacingTokens.XS,
                    bottom: SpacingTokens.XS,
                    left: SpacingTokens.SM,
                    right: SpacingTokens.SM
                  })
                  .backgroundColor(ColorTokens.OVERLAY_SUCCESS)
                  .borderRadius(RadiusTokens.FULL)
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)

            StageRail({ items: this.getStageRailItems() })

            Row({ space: SpacingTokens.MD }) {
              this.buildSetupMetricTile('目标', this.getOptionLabel(GOAL_OPTIONS, this.selectedGoalType), '计划主方向')
              this.buildSetupMetricTile('频率', this.weeklyDays.toString() + ' 天/周', '训练节奏')
            }
            .width('100%')

            Row({ space: SpacingTokens.MD }) {
              this.buildSetupMetricTile('经验', this.getOptionLabel(LEVEL_OPTIONS, this.selectedLevel), '动作复杂度')
              this.buildSetupMetricTile('时长', this.sessionMinutes.toString() + ' 分钟', '单次预算')
            }
            .width('100%')

            this.buildSummaryPanel()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        this.buildLaneHeader('目标方向', '训练目标', '先确定主方向，后续计划会围绕目标、经验和器械生成。')
        AppCard({ variant: 'outlined', cardPadding: 'default' }) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(GOAL_OPTIONS, (option: GoalOption) => {
              this.buildChoiceButton(option.label, '31%', this.selectedGoalType === option.id, () => {
                this.selectedGoalType = option.id
              })
            }, (option: GoalOption) => option.id)
          }
          .width('100%')
        }

        this.buildLaneHeader('动作复杂度', '训练经验', '经验会影响动作难度、训练密度和恢复节奏。')
        AppCard({ variant: 'outlined', cardPadding: 'default' }) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(LEVEL_OPTIONS, (option: GoalOption) => {
              this.buildChoiceButton(option.label, '31%', this.selectedLevel === option.id, () => {
                this.selectedLevel = option.id
              })
            }, (option: GoalOption) => option.id)
          }
          .width('100%')
        }

        this.buildLaneHeader('训练节奏', '每周训练天数', '先定每周节奏，再让后续计划去分配训练日。')
        AppCard({ variant: 'outlined', cardPadding: 'default' }) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(DAY_OPTIONS, (day: number) => {
              this.buildChoiceButton(day.toString() + ' 天', '23%', this.weeklyDays === day, () => {
                this.weeklyDays = day
              })
            }, (day: number) => day.toString())
          }
          .width('100%')
        }

        this.buildLaneHeader('单次预算', '单次训练时长', '控制每次训练的时间预算，避免计划密度失衡。')
        AppCard({ variant: 'outlined', cardPadding: 'default' }) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(MINUTE_OPTIONS, (minute: number) => {
              this.buildChoiceButton(minute.toString() + ' 分钟', '47%', this.sessionMinutes === minute, () => {
                this.sessionMinutes = minute
              })
            }, (minute: number) => minute.toString())
          }
          .width('100%')
        }

        this.buildLaneHeader('器械范围', '可用器械', '勾选当前真实可用的器械，计划会据此筛动作。')
        AppCard({ variant: 'outlined', cardPadding: 'default' }) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(EQUIPMENT_OPTIONS, (option: GoalOption) => {
              this.buildChoiceButton(
                option.label,
                '47%',
                this.containsValue(this.selectedEquipmentIds, option.id),
                () => {
                  this.toggleEquipment(option.id)
                }
              )
            }, (option: GoalOption) => option.id)
          }
          .width('100%')
        }

        this.buildLaneHeader('恢复约束', '限制肌群', '选中后计划会尽量避开相关肌群，适合疼痛、恢复期或临时限制。')
        AppCard({ variant: 'outlined', cardPadding: 'default' }) {
          Column({ space: SpacingTokens.MD }) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(RESTRICTED_MUSCLE_OPTIONS, (option: GoalOption) => {
                this.buildChoiceButton(
                  option.label,
                  '31%',
                  this.containsValue(this.selectedRestrictedMuscleIds, option.id),
                  () => {
                    this.toggleRestrictedMuscle(option.id)
                  }
                )
              }, (option: GoalOption) => option.id)
            }
            .width('100%')
          }
          .width('100%')
        }

        AppCard({ variant: 'panel', cardPadding: 'default' }) {
          Column({ space: SpacingTokens.MD }) {
            Text(this.hasExistingGoal ? '更新当前训练安排' : '生成当前训练计划')
              .fontSize(FontTokens.BODY_SIZE)
              .fontWeight(FontTokens.BODY_BOLD_WEIGHT)
              .fontColor(ColorTokens.TEXT_PRIMARY)

            Text(this.hasExistingGoal
              ? '保存后会带着新目标和条件回到今日训练首页。'
              : '保存后会生成本地训练计划，并进入今日训练首页。')
              .fontSize(FontTokens.CAPTION_SIZE)
              .fontColor(ColorTokens.TEXT_SECONDARY)
              .lineHeight(FontTokens.CAPTION_LINE_HEIGHT)
              .width('100%')

            AppButton({
              text: this.saving ? '保存中' : '生成训练计划',
              type: 'primary',
              buttonSize: 'large',
              block: true,
              loading: this.saving,
              onButtonClick: () => {
                this.saveSelectedGoal()
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
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
