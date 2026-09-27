/**
 * PlanTabModel 单元测试
 *
 * 覆盖「计划 Tab」数据源切换后新增的映射逻辑：由计划组已启用的预置计划
 * （UserPlan）构建日卡片，以及短标签 / 焦点肌群 / 副标题 / 位置徽标的口径。
 * 对齐真实预置数据（preset_ppl 三分化 · 谭成义 / preset_bro_split 五分化）。
 */
import { describe, it, expect } from '@ohos/hypium'
import TrainingPlanService, {
  ExerciseRef,
  PresetPlan,
  TrainingDay,
  UserPlan
} from '../main/ets/common/services/TrainingPlanService'
import {
  PlanDayItem,
  PlanExerciseItem,
  buildPlanDayItemsFromUserPlan,
  createPlanDayItem,
  createPlanExerciseItem,
  dayFocusMuscles,
  daySubtitle,
  positionBadge,
  shortDayTag
} from '../main/ets/features/pencil/components/PlanTabModel'

function buildCurrentPlan(id: string): UserPlan {
  const preset: PresetPlan | undefined = TrainingPlanService.getPresetPlanById(id)
  if (preset === undefined) {
    throw new Error('preset not found: ' + id)
  }
  const plan: UserPlan = {
    id: preset.id,
    name: preset.name,
    coverColor: preset.coverColor,
    targetAudience: preset.targetAudience,
    weeklyFrequency: preset.weeklyFrequency,
    description: preset.description,
    days: preset.days,
    enabledAt: 1
  }
  return plan
}

function mkExercise(name: string, targetMuscle: string, sets: number, reps: string): ExerciseRef {
  const exercise: ExerciseRef = {
    name: name,
    targetMuscle: targetMuscle,
    sets: sets,
    reps: reps
  }
  return exercise
}

function mkDay(dayLabel: string, exercises: ExerciseRef[]): TrainingDay {
  const day: TrainingDay = {
    dayLabel: dayLabel,
    exercises: exercises
  }
  return day
}

export default function planTabModelTest() {
  describe('PlanTabModel — 预置计划日卡映射', () => {

    it('三分化：日卡与训练日一一对应，首日标记今日', 0, () => {
      const plan: UserPlan = buildCurrentPlan('preset_ppl')
      const items: PlanDayItem[] = buildPlanDayItemsFromUserPlan(plan)

      expect(items.length).assertEqual(plan.days.length)
      expect(items.length).assertEqual(3)
      expect(items[0].title).assertEqual(plan.days[0].dayLabel)
      expect(items[0].title).assertEqual('胸肩三头')
      expect(items[0].tag).assertEqual('胸')
      expect(items[0].badge).assertEqual('今日')
      expect(items[0].today).assertTrue()
      expect(items[1].badge).assertEqual('明日')
      expect(items[1].today).assertFalse()
      expect(items[2].badge).assertEqual('后天')
    })

    it('预置计划动作按名称/肌群/组次/次数映射到日卡', 0, () => {
      const plan: UserPlan = buildCurrentPlan('preset_ppl')
      const items: PlanDayItem[] = buildPlanDayItemsFromUserPlan(plan)
      const day: TrainingDay = plan.days[0]
      const first: ExerciseRef = day.exercises[0]

      expect(items[0].exercises.length).assertEqual(day.exercises.length)
      expect(items[0].exercises[0].name).assertEqual(first.name)
      expect(items[0].exercises[0].muscle).assertEqual(first.targetMuscle)
      expect(items[0].exercises[0].sets).assertEqual(first.sets.toString())
      expect(items[0].exercises[0].reps).assertEqual(first.reps)
    })

    it('五分化：周内日标签取首字，第五天徽标为「第 5 天」', 0, () => {
      const plan: UserPlan = buildCurrentPlan('preset_bro_split')
      const items: PlanDayItem[] = buildPlanDayItemsFromUserPlan(plan)

      expect(items.length).assertEqual(5)
      expect(items[0].title).assertEqual('周一 胸部')
      expect(items[0].tag).assertEqual('胸')
      expect(items[4].title).assertEqual('周五 手臂')
      expect(items[4].tag).assertEqual('手')
      expect(items[4].badge).assertEqual('第 5 天')
      expect(items[4].today).assertFalse()
    })

    it('预置计划日卡不带单次时长（副标题不留空尾段）', 0, () => {
      const plan: UserPlan = buildCurrentPlan('preset_ppl')
      const items: PlanDayItem[] = buildPlanDayItemsFromUserPlan(plan)

      expect(items[0].duration).assertEqual('')
      expect(daySubtitle(items[0]).indexOf(' · 分钟')).assertEqual(-1)
      expect(daySubtitle(items[0])).assertEqual(items[0].focus + ' · ' + items[0].exercises.length.toString() + ' 个动作')
    })
  })

  describe('PlanTabModel — 纯函数口径', () => {

    it('shortDayTag：去「周X」前缀取首字，空标签回退「练」', 0, () => {
      expect(shortDayTag('周一 胸部')).assertEqual('胸')
      expect(shortDayTag('上肢A')).assertEqual('上')
      expect(shortDayTag('推日')).assertEqual('推')
      expect(shortDayTag('')).assertEqual('练')
    })

    it('dayFocusMuscles：去重且保持出现顺序', 0, () => {
      const day: TrainingDay = mkDay('x', [
        mkExercise('a', '胸部', 3, '8'),
        mkExercise('b', '胸部', 3, '8'),
        mkExercise('c', '肩部', 3, '8')
      ])
      expect(dayFocusMuscles(day)).assertEqual('胸部 · 肩部')
    })

    it('daySubtitle：有单次时长时追加，缺时长时不留空段', 0, () => {
      const exercises: PlanExerciseItem[] = [createPlanExerciseItem('杠铃卧推', '胸部', '4', '8-12')]
      const presetDay: PlanDayItem = createPlanDayItem('胸', '胸肩三头', '胸部 · 肩部', '', '今日', true, exercises)
      const goalDay: PlanDayItem = createPlanDayItem('胸', '胸部日', '胸部 · 训练', '45 分钟', '今日', true, exercises)

      expect(daySubtitle(presetDay)).assertEqual('胸部 · 肩部 · 1 个动作')
      expect(daySubtitle(goalDay)).assertEqual('胸部 · 训练 · 1 个动作 · 45 分钟')
    })

    it('positionBadge：前三天为相对日，其余「第 N 天」', 0, () => {
      expect(positionBadge(0)).assertEqual('今日')
      expect(positionBadge(1)).assertEqual('明日')
      expect(positionBadge(2)).assertEqual('后天')
      expect(positionBadge(3)).assertEqual('第 4 天')
    })
  })
}
