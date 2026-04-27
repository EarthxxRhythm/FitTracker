/**
 * TrainingPlanService — 训练计划服务
 *
 * 功能 #7: 提供5套预置训练计划数据，每套包含训练日及动作清单。
 * 预置计划为只读模板，启用时通过克隆生成用户计划（功能 #9）。
 */

export interface ExerciseRef {
  name: string
  targetMuscle: string
  sets: number
  reps: string
}

export interface TrainingDay {
  dayLabel: string
  exercises: ExerciseRef[]
}

export interface PresetPlan {
  id: string
  name: string
  coverColor: string
  targetAudience: string
  weeklyFrequency: string
  days: TrainingDay[]
}

const PRESET_PLANS: PresetPlan[] = [
  {
    id: 'preset_bro_split',
    name: '五分化训练',
    coverColor: '#1E88E5',
    targetAudience: '中高级健身者',
    weeklyFrequency: '5天/周',
    days: [
      {
        dayLabel: '周一 胸部',
        exercises: [
          { name: '杠铃平板卧推', targetMuscle: '胸', sets: 4, reps: '8-12' },
          { name: '上斜哑铃卧推', targetMuscle: '胸', sets: 3, reps: '8-12' },
          { name: '哑铃飞鸟', targetMuscle: '胸', sets: 3, reps: '12-15' },
          { name: '绳索夹胸', targetMuscle: '胸', sets: 3, reps: '12-15' },
          { name: '双杠臂屈伸', targetMuscle: '胸', sets: 3, reps: '8-12' }
        ]
      },
      {
        dayLabel: '周二 背部',
        exercises: [
          { name: '引体向上', targetMuscle: '背', sets: 4, reps: '8-12' },
          { name: '杠铃划船', targetMuscle: '背', sets: 4, reps: '8-12' },
          { name: '高位下拉', targetMuscle: '背', sets: 3, reps: '10-12' },
          { name: '坐姿划船', targetMuscle: '背', sets: 3, reps: '10-12' },
          { name: '面拉', targetMuscle: '背', sets: 3, reps: '12-15' }
        ]
      },
      {
        dayLabel: '周三 腿部',
        exercises: [
          { name: '杠铃深蹲', targetMuscle: '腿', sets: 4, reps: '8-12' },
          { name: '罗马尼亚硬拉', targetMuscle: '腿', sets: 3, reps: '8-12' },
          { name: '腿举', targetMuscle: '腿', sets: 3, reps: '10-12' },
          { name: '腿弯举', targetMuscle: '腿', sets: 3, reps: '12-15' },
          { name: '提踵', targetMuscle: '腿', sets: 4, reps: '15-20' }
        ]
      },
      {
        dayLabel: '周四 肩部',
        exercises: [
          { name: '杠铃推举', targetMuscle: '肩', sets: 4, reps: '8-12' },
          { name: '哑铃侧平举', targetMuscle: '肩', sets: 3, reps: '12-15' },
          { name: '前平举', targetMuscle: '肩', sets: 3, reps: '12-15' },
          { name: '俯身飞鸟', targetMuscle: '肩', sets: 3, reps: '12-15' },
          { name: '耸肩', targetMuscle: '肩', sets: 3, reps: '12-15' }
        ]
      },
      {
        dayLabel: '周五 手臂',
        exercises: [
          { name: '杠铃弯举', targetMuscle: '臂', sets: 4, reps: '8-12' },
          { name: '哑铃锤式弯举', targetMuscle: '臂', sets: 3, reps: '10-12' },
          { name: '窄距卧推', targetMuscle: '臂', sets: 4, reps: '8-12' },
          { name: '绳索下压', targetMuscle: '臂', sets: 3, reps: '12-15' },
          { name: '集中弯举', targetMuscle: '臂', sets: 3, reps: '12-15' }
        ]
      }
    ]
  },
  {
    id: 'preset_upper_lower',
    name: '上下肢分化',
    coverColor: '#43A047',
    targetAudience: '初中级健身者',
    weeklyFrequency: '4天/周',
    days: [
      {
        dayLabel: '周一 上肢推',
        exercises: [
          { name: '杠铃平板卧推', targetMuscle: '胸', sets: 4, reps: '8-12' },
          { name: '哑铃推举', targetMuscle: '肩', sets: 3, reps: '8-12' },
          { name: '上斜哑铃飞鸟', targetMuscle: '胸', sets: 3, reps: '10-15' },
          { name: '侧平举', targetMuscle: '肩', sets: 3, reps: '12-15' },
          { name: '绳索下压', targetMuscle: '臂', sets: 3, reps: '12-15' }
        ]
      },
      {
        dayLabel: '周二 下肢',
        exercises: [
          { name: '杠铃深蹲', targetMuscle: '腿', sets: 4, reps: '8-12' },
          { name: '罗马尼亚硬拉', targetMuscle: '腿', sets: 3, reps: '8-12' },
          { name: '保加利亚分腿蹲', targetMuscle: '腿', sets: 3, reps: '10-12' },
          { name: '腿弯举', targetMuscle: '腿', sets: 3, reps: '12-15' },
          { name: '提踵', targetMuscle: '腿', sets: 3, reps: '15-20' }
        ]
      },
      {
        dayLabel: '周四 上肢拉',
        exercises: [
          { name: '引体向上', targetMuscle: '背', sets: 4, reps: '8-12' },
          { name: '杠铃划船', targetMuscle: '背', sets: 3, reps: '8-12' },
          { name: '高位下拉', targetMuscle: '背', sets: 3, reps: '10-12' },
          { name: '面拉', targetMuscle: '背', sets: 3, reps: '12-15' },
          { name: '杠铃弯举', targetMuscle: '臂', sets: 3, reps: '10-12' }
        ]
      },
      {
        dayLabel: '周五 下肢',
        exercises: [
          { name: '杠铃深蹲', targetMuscle: '腿', sets: 4, reps: '6-10' },
          { name: '腿举', targetMuscle: '腿', sets: 3, reps: '10-12' },
          { name: '腿弯举', targetMuscle: '腿', sets: 3, reps: '12-15' },
          { name: '腿伸展', targetMuscle: '腿', sets: 3, reps: '12-15' },
          { name: '提踵', targetMuscle: '腿', sets: 3, reps: '15-20' }
        ]
      }
    ]
  },
  {
    id: 'preset_ppl',
    name: '推拉腿分化',
    coverColor: '#FB8C00',
    targetAudience: '初中高级通用',
    weeklyFrequency: '3-6天/周',
    days: [
      {
        dayLabel: '推日',
        exercises: [
          { name: '杠铃平板卧推', targetMuscle: '胸', sets: 4, reps: '8-12' },
          { name: '哑铃推举', targetMuscle: '肩', sets: 3, reps: '8-12' },
          { name: '上斜哑铃卧推', targetMuscle: '胸', sets: 3, reps: '8-12' },
          { name: '侧平举', targetMuscle: '肩', sets: 3, reps: '12-15' },
          { name: '窄距卧推', targetMuscle: '臂', sets: 3, reps: '8-12' }
        ]
      },
      {
        dayLabel: '拉日',
        exercises: [
          { name: '引体向上', targetMuscle: '背', sets: 4, reps: '8-12' },
          { name: '杠铃划船', targetMuscle: '背', sets: 4, reps: '8-12' },
          { name: '坐姿划船', targetMuscle: '背', sets: 3, reps: '10-12' },
          { name: '面拉', targetMuscle: '背', sets: 3, reps: '12-15' },
          { name: '杠铃弯举', targetMuscle: '臂', sets: 3, reps: '10-12' }
        ]
      },
      {
        dayLabel: '腿日',
        exercises: [
          { name: '杠铃深蹲', targetMuscle: '腿', sets: 4, reps: '8-12' },
          { name: '罗马尼亚硬拉', targetMuscle: '腿', sets: 3, reps: '8-12' },
          { name: '腿举', targetMuscle: '腿', sets: 3, reps: '10-12' },
          { name: '腿弯举', targetMuscle: '腿', sets: 3, reps: '12-15' },
          { name: '提踵', targetMuscle: '腿', sets: 4, reps: '15-20' }
        ]
      }
    ]
  },
  {
    id: 'preset_fullbody_3x',
    name: '全身训练 3x',
    coverColor: '#8E24AA',
    targetAudience: '初级健身者',
    weeklyFrequency: '3天/周',
    days: [
      {
        dayLabel: '周一 全身',
        exercises: [
          { name: '杠铃深蹲', targetMuscle: '腿', sets: 3, reps: '8-12' },
          { name: '杠铃平板卧推', targetMuscle: '胸', sets: 3, reps: '8-12' },
          { name: '杠铃划船', targetMuscle: '背', sets: 3, reps: '8-12' },
          { name: '杠铃推举', targetMuscle: '肩', sets: 3, reps: '8-12' },
          { name: '杠铃弯举', targetMuscle: '臂', sets: 2, reps: '10-12' },
          { name: '平板支撑', targetMuscle: '腹', sets: 3, reps: '30秒' }
        ]
      },
      {
        dayLabel: '周三 全身',
        exercises: [
          { name: '罗马尼亚硬拉', targetMuscle: '腿', sets: 3, reps: '8-12' },
          { name: '哑铃卧推', targetMuscle: '胸', sets: 3, reps: '8-12' },
          { name: '高位下拉', targetMuscle: '背', sets: 3, reps: '8-12' },
          { name: '侧平举', targetMuscle: '肩', sets: 3, reps: '12-15' },
          { name: '绳索下压', targetMuscle: '臂', sets: 2, reps: '12-15' },
          { name: '卷腹', targetMuscle: '腹', sets: 3, reps: '15-20' }
        ]
      },
      {
        dayLabel: '周五 全身',
        exercises: [
          { name: '杠铃深蹲', targetMuscle: '腿', sets: 3, reps: '8-12' },
          { name: '上斜哑铃卧推', targetMuscle: '胸', sets: 3, reps: '8-12' },
          { name: '坐姿划船', targetMuscle: '背', sets: 3, reps: '10-12' },
          { name: '哑铃推举', targetMuscle: '肩', sets: 3, reps: '8-12' },
          { name: '锤式弯举', targetMuscle: '臂', sets: 2, reps: '10-12' },
          { name: '悬垂举腿', targetMuscle: '腹', sets: 3, reps: '12-15' }
        ]
      }
    ]
  },
  {
    id: 'preset_powerlifting',
    name: '力量举基础',
    coverColor: '#E53935',
    targetAudience: '力量举入门',
    weeklyFrequency: '3-4天/周',
    days: [
      {
        dayLabel: '深蹲日',
        exercises: [
          { name: '杠铃深蹲', targetMuscle: '腿', sets: 5, reps: '5' },
          { name: '前蹲', targetMuscle: '腿', sets: 3, reps: '6-8' },
          { name: '腿弯举', targetMuscle: '腿', sets: 3, reps: '8-12' },
          { name: '提踵', targetMuscle: '腿', sets: 3, reps: '12-15' },
          { name: '平板支撑', targetMuscle: '腹', sets: 3, reps: '30秒' }
        ]
      },
      {
        dayLabel: '卧推日',
        exercises: [
          { name: '杠铃平板卧推', targetMuscle: '胸', sets: 5, reps: '5' },
          { name: '窄距卧推', targetMuscle: '臂', sets: 3, reps: '6-8' },
          { name: '哑铃推举', targetMuscle: '肩', sets: 3, reps: '8-12' },
          { name: '绳索下压', targetMuscle: '臂', sets: 3, reps: '10-12' },
          { name: '面拉', targetMuscle: '背', sets: 3, reps: '12-15' }
        ]
      },
      {
        dayLabel: '硬拉日',
        exercises: [
          { name: '杠铃硬拉', targetMuscle: '背', sets: 5, reps: '5' },
          { name: '杠铃划船', targetMuscle: '背', sets: 3, reps: '6-8' },
          { name: '引体向上', targetMuscle: '背', sets: 3, reps: '6-8' },
          { name: '杠铃弯举', targetMuscle: '臂', sets: 3, reps: '8-12' },
          { name: '卷腹', targetMuscle: '腹', sets: 3, reps: '12-15' }
        ]
      },
      {
        dayLabel: '辅助日（可选）',
        exercises: [
          { name: '腿举', targetMuscle: '腿', sets: 3, reps: '8-12' },
          { name: '坐姿划船', targetMuscle: '背', sets: 3, reps: '10-12' },
          { name: '侧平举', targetMuscle: '肩', sets: 3, reps: '12-15' },
          { name: '锤式弯举', targetMuscle: '臂', sets: 3, reps: '10-12' },
          { name: '提踵', targetMuscle: '腿', sets: 3, reps: '15-20' }
        ]
      }
    ]
  }
]

class TrainingPlanService {
  getAllPresetPlans(): PresetPlan[] {
    return PRESET_PLANS
  }

  getPresetPlanById(id: string): PresetPlan | undefined {
    return PRESET_PLANS.find(p => p.id === id)
  }

  getPlanCount(): number {
    return PRESET_PLANS.length
  }
}

export default new TrainingPlanService()
