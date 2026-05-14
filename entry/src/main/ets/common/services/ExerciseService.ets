/**
 * ExerciseService —— 动作库数据服务
 *
 * 功能 #13-16: 提供动作库数据，支持搜索、肌群筛选、器械筛选、分页加载。
 */
export interface Exercise {
  id: string
  name: string
  aliases: string[]
  primaryMuscle: string
  secondaryMuscle: string
  equipment: string
  description: string
  instructions: string
}

// Builder — ensures all object literals have explicit type (arkts-no-untyped-obj-literals)
function mkExercise(
  id: string,
  name: string,
  aliases: string[],
  primaryMuscle: string,
  secondaryMuscle: string,
  equipment: string,
): Exercise {
  const ex: Exercise = {
    id: id,
    name: name,
    aliases: aliases,
    primaryMuscle: primaryMuscle,
    secondaryMuscle: secondaryMuscle,
    equipment: equipment,
    description: '',
    instructions: ''
  }
  return ex
}

const EXERCISES: Exercise[] = [
  // 胸部
  mkExercise('e1', '杠铃平板卧推', ['卧推', '平板卧推'], '胸', '肩', '杠铃'),
  mkExercise('e2', '上斜哑铃卧推', ['上斜卧推'], '胸', '肩', '哑铃'),
  mkExercise('e3', '哑铃飞鸟', ['飞鸟'], '胸', '肩', '哑铃'),
  mkExercise('e4', '绳索夹胸', ['夹胸', '龙门架夹胸'], '胸', '肩', '绳索'),
  mkExercise('e5', '双杠臂屈伸', ['臂屈伸', '双杠'], '胸', '臂', '自重'),
  mkExercise('e6', '俯卧撑', ['push up'], '胸', '臂', '自重'),
  mkExercise('e7', '下斜杠铃卧推', ['下斜卧推'], '胸', '臂', '杠铃'),
  // 背部
  mkExercise('e8', '引体向上', ['pull up', '引体'], '背', '臂', '自重'),
  mkExercise('e9', '杠铃划船', ['划船', '俯身划船'], '背', '臂', '杠铃'),
  mkExercise('e10', '高位下拉', ['lat pulldown', '下拉'], '背', '臂', '绳索'),
  mkExercise('e11', '坐姿划船', ['seated row'], '背', '臂', '绳索'),
  mkExercise('e12', '哑铃单臂划船', ['单臂划船'], '背', '臂', '哑铃'),
  mkExercise('e13', '杠铃硬拉', ['硬拉', 'deadlift'], '背', '腿', '杠铃'),
  mkExercise('e14', '面拉', ['face pull'], '背', '肩', '绳索'),
  // 腿部
  mkExercise('e15', '杠铃深蹲', ['深蹲', 'squat'], '腿', '背', '杠铃'),
  mkExercise('e16', '罗马尼亚硬拉', ['RDL'], '腿', '背', '杠铃'),
  mkExercise('e17', '腿举', ['leg press', '倒蹬'], '腿', '腿', '固定器械'),
  mkExercise('e18', '腿弯举', ['leg curl'], '腿', '腿', '固定器械'),
  mkExercise('e19', '腿伸展', ['leg extension'], '腿', '腿', '固定器械'),
  mkExercise('e20', '保加利亚分腿蹲', ['保加利亚蹲'], '腿', '腿', '哑铃'),
  mkExercise('e21', '提踵', ['calf raise'], '腿', '腿', '固定器械'),
  // 肩部
  mkExercise('e22', '杠铃推举', ['推举', '杠铃肩推'], '肩', '臂', '杠铃'),
  mkExercise('e23', '哑铃侧平举', ['侧平举'], '肩', '肩', '哑铃'),
  mkExercise('e24', '前平举', ['front raise'], '肩', '肩', '哑铃'),
  mkExercise('e25', '俯身飞鸟', ['后束飞鸟'], '肩', '背', '哑铃'),
  mkExercise('e26', '杠铃耸肩', ['耸肩', 'shrug'], '肩', '背', '杠铃'),
  mkExercise('e27', '阿诺德推举', ['阿诺德推'], '肩', '臂', '哑铃'),
  // 手臂
  mkExercise('e28', '杠铃弯举', ['弯举', 'barbell curl'], '臂', '臂', '杠铃'),
  mkExercise('e29', '哑铃锤式弯举', ['锤式弯举'], '臂', '臂', '哑铃'),
  mkExercise('e30', '窄距卧推', ['窄推'], '臂', '胸', '杠铃'),
  mkExercise('e31', '绳索下压', ['tricep pushdown'], '臂', '臂', '绳索'),
  mkExercise('e32', '集中弯举', ['concentration curl'], '臂', '臂', '哑铃'),
  mkExercise('e33', '过头臂屈伸', ['overhead extension'], '臂', '肩', '哑铃'),
  mkExercise('e34', 'EZ杠弯举', ['EZ curl'], '臂', '臂', '杠铃'),
  // 腹部
  mkExercise('e35', '卷腹', ['crunch'], '腹', '腹', '自重'),
  mkExercise('e36', '平板支撑', ['plank'], '腹', '背', '自重'),
  mkExercise('e37', '悬垂举腿', ['hanging leg raise'], '腹', '臂', '自重'),
  mkExercise('e38', '俄罗斯转体', ['russian twist'], '腹', '腹', '自重'),
  mkExercise('e39', '哑铃腹肌卷腹', ['decline crunch'], '腹', '腹', '哑铃'),
  mkExercise('e40', '山羊挺身', ['back extension'], '背', '腿', '固定器械'),
  mkExercise('e41', '前蹲', ['front squat'], '腿', '背', '杠铃'),
  mkExercise('e42', '史密斯机深蹲', ['smith squat'], '腿', '腿', '固定器械'),
  mkExercise('e43', '直臂下拉', ['straight arm pulldown'], '背', '肩', '绳索'),
  mkExercise('e44', 'T杠划船', ['T bar row'], '背', '臂', '杠铃'),
  mkExercise('e45', '器械推胸', ['machine chest press'], '胸', '肩', '固定器械'),
]

const PAGE_SIZE = 20

class ExerciseService {
  getAll(): Exercise[] {
    return EXERCISES
  }

  search(query: string): Exercise[] {
    if (!query || query.trim().length === 0) {
      return EXERCISES
    }
    const q = query.trim().toLowerCase()
    return EXERCISES.filter(e =>
      e.name.toLowerCase().includes(q) ||
      e.aliases.some(a => a.toLowerCase().includes(q))
    )
  }

  filterByMuscle(muscle: string): Exercise[] {
    if (!muscle || muscle === '全部') {
      return EXERCISES
    }
    return EXERCISES.filter(e => e.primaryMuscle === muscle)
  }

  filterByEquipment(equipment: string): Exercise[] {
    if (!equipment || equipment === '全部') {
      return EXERCISES
    }
    return EXERCISES.filter(e => e.equipment === equipment)
  }

  getPage(items: Exercise[], page: number): Exercise[] {
    const start = (page - 1) * PAGE_SIZE
    return items.slice(start, start + PAGE_SIZE)
  }

  hasMore(items: Exercise[], page: number): boolean {
    return page * PAGE_SIZE < items.length
  }

  getById(id: string): Exercise | undefined {
    return EXERCISES.find(e => e.id === id)
  }

  getMuscleGroups(): string[] {
    const groups: string[] = ['全部', '胸', '背', '腿', '肩', '臂', '腹']
    return groups
  }

  getEquipmentTypes(): string[] {
    const types: string[] = ['杠铃', '哑铃', '绳索', '固定器械', '自重']
    return types
  }

  getTotalCount(): number {
    return EXERCISES.length
  }
}

export default new ExerciseService()
