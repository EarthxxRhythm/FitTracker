/**
 * PlanTabModel 设备侧用例
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
} from '../../../main/ets/common/services/TrainingPlanService'
import {
  PlanDayItem,
  PlanExerciseItem,
  buildPlanDayItemsFromUserPlan,
  createPlanDayItem,
  createPlanExerciseItem,
  dayFocusMuscles,
  daySubtitle,
  positionBadge,
  relativeDayBadge,
  shortDayTag
} from '../../../main/ets/features/pencil/components/PlanTabModel'

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

export default function planTabModelTest(): void {
  describe('PlanTabModel - preset plan day cards', () => {

    it('maps a three-split current plan to day cards and marks the real weekday today', 0, () => {
      const plan: UserPlan = buildCurrentPlan('preset_ppl')
      // 固定注入周一：胸肩三头[1,4]=今日、背后束二头[2,5]=明日、腿[3,6]=后天。
      const items: PlanDayItem[] = buildPlanDayItemsFromUserPlan(plan, 1)

      expect(items.length).assertEqual(plan.days.length)
      expect(items.length).assertEqual(3)
      expect(items[0].title).assertEqual('胸肩三头')
      expect(items[0].tag).assertEqual('胸')
      expect(items[0].badge).assertEqual('今日')
      expect(items[0].today).assertTrue()
      expect(items[1].badge).assertEqual('明日')
      expect(items[1].today).assertFalse()
      expect(items[2].badge).assertEqual('后天')
    })

    it('moves the today badge with the injected weekday instead of the card position', 0, () => {
      const plan: UserPlan = buildCurrentPlan('preset_ppl')
      // 注入周二：「今日」必须落在背后束二头（[2,5]）；胸肩三头覆盖[1,4]，
      // 最近的周四是 2 天后 →「后天」；腿[3,6] 最近周三是 1 天后 →「明日」。
      const items: PlanDayItem[] = buildPlanDayItemsFromUserPlan(plan, 2)

      expect(items[0].badge).assertEqual('后天')
      expect(items[0].today).assertFalse()
      expect(items[1].badge).assertEqual('今日')
      expect(items[1].today).assertTrue()
      expect(items[2].badge).assertEqual('明日')
    })

    it('carries exercise name, muscle, sets and reps into the day card', 0, () => {
      const plan: UserPlan = buildCurrentPlan('preset_ppl')
      const items: PlanDayItem[] = buildPlanDayItemsFromUserPlan(plan, 1)
      const day: TrainingDay = plan.days[0]
      const first: ExerciseRef = day.exercises[0]

      expect(items[0].exercises.length).assertEqual(day.exercises.length)
      expect(items[0].exercises[0].name).assertEqual(first.name)
      expect(items[0].exercises[0].muscle).assertEqual(first.targetMuscle)
      expect(items[0].exercises[0].sets).assertEqual(first.sets.toString())
      expect(items[0].exercises[0].reps).assertEqual(first.reps)
    })

    it('maps a five-split current plan with weekday labels and a distance badge', 0, () => {
      const plan: UserPlan = buildCurrentPlan('preset_bro_split')
      const items: PlanDayItem[] = buildPlanDayItemsFromUserPlan(plan, 1)

      expect(items.length).assertEqual(5)
      expect(items[0].title).assertEqual('周一 胸部')
      expect(items[0].tag).assertEqual('胸')
      expect(items[4].title).assertEqual('周五 手臂')
      expect(items[4].tag).assertEqual('手')
      expect(items[4].badge).assertEqual('4 天后')
      expect(items[4].today).assertFalse()
    })

    it('leaves no empty duration tail for preset plans', 0, () => {
      const plan: UserPlan = buildCurrentPlan('preset_ppl')
      const items: PlanDayItem[] = buildPlanDayItemsFromUserPlan(plan, 1)

      expect(items[0].duration).assertEqual('')
      expect(daySubtitle(items[0]).indexOf('分钟')).assertEqual(-1)
      expect(daySubtitle(items[0])).assertEqual(
        items[0].focus + ' · ' + items[0].exercises.length.toString() + ' 个动作'
      )
    })

    it('falls back to positional badges for plans without weekday info', 0, () => {
      const days: TrainingDay[] = [
        mkDay('上肢A', [mkExercise('a', '胸部', 3, '8')]),
        mkDay('下肢A', [mkExercise('b', '腿部', 3, '8')])
      ]
      const plan: UserPlan = buildCurrentPlan('preset_ppl')
      const noWeekdayPlan: UserPlan = {
        id: plan.id,
        name: plan.name,
        coverColor: plan.coverColor,
        targetAudience: plan.targetAudience,
        weeklyFrequency: plan.weeklyFrequency,
        description: plan.description,
        days: days,
        enabledAt: 1
      }
      const items: PlanDayItem[] = buildPlanDayItemsFromUserPlan(noWeekdayPlan, 3)

      expect(items[0].badge).assertEqual('今日')
      expect(items[0].today).assertTrue()
      expect(items[1].badge).assertEqual('明日')
      expect(items[1].today).assertFalse()
    })
  })

  describe('PlanTabModel - pure helpers', () => {

    it('shortDayTag strips the weekday prefix and falls back to a placeholder', 0, () => {
      expect(shortDayTag('周一 胸部')).assertEqual('胸')
      expect(shortDayTag('上肢A')).assertEqual('上')
      expect(shortDayTag('推日')).assertEqual('推')
      expect(shortDayTag('')).assertEqual('练')
    })

    it('dayFocusMuscles de-duplicates while keeping first-seen order', 0, () => {
      const day: TrainingDay = mkDay('x', [
        mkExercise('a', '胸部', 3, '8'),
        mkExercise('b', '胸部', 3, '8'),
        mkExercise('c', '肩部', 3, '8')
      ])
      expect(dayFocusMuscles(day)).assertEqual('胸部 · 肩部')
    })

    it('daySubtitle appends the session duration only when present', 0, () => {
      const exercises: PlanExerciseItem[] = [createPlanExerciseItem('杠铃卧推', '胸部', '4', '8-12')]
      const presetDay: PlanDayItem = createPlanDayItem('胸', '胸肩三头', '胸部 · 肩部', '', '今日', true, exercises)
      const goalDay: PlanDayItem = createPlanDayItem('胸', '胸部日', '胸部 · 训练', '45 分钟', '今日', true, exercises)

      expect(daySubtitle(presetDay)).assertEqual('胸部 · 肩部 · 1 个动作')
      expect(daySubtitle(goalDay)).assertEqual('胸部 · 训练 · 1 个动作 · 45 分钟')
    })

    it('positionBadge marks the first three days then falls back to index labels', 0, () => {
      expect(positionBadge(0)).assertEqual('今日')
      expect(positionBadge(1)).assertEqual('明日')
      expect(positionBadge(2)).assertEqual('后天')
      expect(positionBadge(3)).assertEqual('第 4 天')
    })

    it('relativeDayBadge maps distances to relative labels and falls back on unknown', 0, () => {
      expect(relativeDayBadge(0, 0)).assertEqual('今日')
      expect(relativeDayBadge(1, 1)).assertEqual('明日')
      expect(relativeDayBadge(2, 2)).assertEqual('后天')
      expect(relativeDayBadge(3, 3)).assertEqual('3 天后')
      expect(relativeDayBadge(6, 6)).assertEqual('6 天后')
      expect(relativeDayBadge(-1, 2)).assertEqual('后天')
    })
  })
}
