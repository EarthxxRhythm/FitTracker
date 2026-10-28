/**
 * ExerciseGifCatalog -- 训练演示 GIF 的解析目录。
 *
 * ## 素材来源
 *
 * 唯一素材源为 rawfile/exercise-gifs-photo/<gifId>.gif（180×180，三段乒乓 GIF）：
 * 由 tools/content/build-exercise-gifs-photo.mjs 从 free-exercise-db（Unlicense）的
 * 实拍照合成，色板 192 色、Bayer 抖动。
 *
 * 旧「线稿」套系（Gym Visual，© gymvisual.com，经第三方数据集转授权）授权链条不成立，
 * 已于 2026-10-28 从仓库移除、不再分发（详见 ASSETS.md）。线稿映射组也随之停用：
 * 若保留「线稿优先」解析，它会返回 exercise-gifs-photo/<线稿id>.gif —— 该文件不存在，
 * 于是连本可用的实拍素材也被跳过，动作库卡片退化成占位图标。
 *
 * 现解析规则与 Android 端 PhotoGifCatalog 完全一致：只查实拍组，命中即用，
 * 未命中回退 DEFAULT_EXERCISE_GIF_ID（该文件在 photo 目录中真实存在）。
 *
 * ## 命名
 *
 * gifId 沿用动作库 exerciseId 的 kebab 归一化（ex_barbell_bench_press -> barbell-bench-press），
 * 故动作库按 id 可直接命中；训练执行页拿到的是动作中文名（内容库 nameZh），
 * 中文名 -> GIF 文件名 -> rawfile 路径 在此收敛。
 */

/**
 * 未命中映射时的默认演示素材。
 *
 * 必须指向 photo 目录中真实存在的文件，否则回退会二次落空、只剩占位图标。
 */
export const DEFAULT_EXERCISE_GIF_ID: string = 'barbell-deadlift'

/**
 * 演示素材目录（导出供单测与消费端复用，避免改目录时多处同步）。
 *
 * 与 PHOTO_GIF_DIRECTORY 同值：线稿目录已随版权清理撤下，两套目录收敛为一套。
 */
export const DEMO_GIF_DIRECTORY: string = 'exercise-gifs-photo/'

/** 实拍素材目录（free-exercise-db 实拍照合成，全彩矩形实景、无白底，须圆角容器收敛）。 */
export const PHOTO_GIF_DIRECTORY: string = 'exercise-gifs-photo/'
const GIF_SUFFIX: string = '.gif'

/** 内容库 exerciseId（ex_barbell_bench_press）-> kebab GIF 名（barbell-bench-press）。 */
export function gifIdOfExerciseId(exerciseId: string): string {
  const trimmed: string = exerciseId.trim()
  if (trimmed.length === 0) {
    return DEFAULT_EXERCISE_GIF_ID
  }
  let body: string = trimmed
  if (body.indexOf('ex_') === 0) {
    body = body.substring(3)
  }
  return body.replace(/_/g, '-')
}

interface ExerciseGifGroup {
  gifId: string
  names: string[]
}

/**
 * 实拍素材组：gifId 与内容库 exerciseId 归一化名一一对应，names 收中文名与常见别名。
 *
 * 数据来源：tools/content/exercise-photo-sources.json（人工逐条核对，101 条）。
 * 内容库 102 个动作中仅「鸟狗式」在源库无对应动作，保持占位（见 ASSETS.md 1.3）。
 */
const EXERCISE_PHOTO_GIF_GROUPS: ExerciseGifGroup[] = [
  {
    gifId: 'dead-bug',
    names: ['死虫式', 'dead bug']
  },
  {
    gifId: 'romanian-deadlift',
    names: ['罗马尼亚硬拉', 'rdl']
  },
  {
    gifId: 'pallof-press',
    names: ['帕洛夫抗旋推', 'pallof']
  },
  {
    gifId: 'dumbbell-pullover',
    names: ['哑铃上拉', 'pullover']
  },
  {
    gifId: 'single-leg-romanian-deadlift',
    names: ['单腿罗马尼亚硬拉', 'single leg rdl']
  },
  {
    gifId: 'assisted-dip',
    names: ['辅助双杠臂屈伸', 'assisted dip']
  },
  {
    gifId: 'farmers-carry',
    names: ['农夫走', 'farmer carry']
  },
  {
    gifId: 'mountain-climber',
    names: ['登山者', 'mountain climber']
  },
  {
    gifId: 'kettlebell-swing-placeholder',
    names: ['髋铰链摆动', 'swing pattern']
  },
  {
    gifId: 'bodyweight-glute-bridge',
    names: ['臀桥', 'glute bridge']
  },
  {
    gifId: 'barbell-incline-bench-press',
    names: ['上斜杠铃卧推', '上斜卧推', 'incline bench press']
  },
  {
    gifId: 'decline-barbell-bench-press',
    names: ['下斜杠铃卧推', '下斜卧推', 'decline bench press']
  },
  {
    gifId: 'decline-dumbbell-bench-press',
    names: ['下斜哑铃卧推', '下斜哑铃推胸', 'decline dumbbell press']
  },
  {
    gifId: 'incline-dumbbell-flyes',
    names: ['上斜哑铃飞鸟', '上斜飞鸟', 'incline dumbbell fly']
  },
  {
    gifId: 'machine-chest-fly',
    names: ['蝴蝶机夹胸', '蝴蝶机', 'butterfly', 'pec deck']
  },
  {
    gifId: 'cable-crossover',
    names: ['龙门架交叉夹胸', '龙门架夹胸', 'cable crossover']
  },
  {
    gifId: 'wide-push-up',
    names: ['宽距俯卧撑', '宽距俯卧撑', 'wide push up']
  },
  {
    gifId: 'incline-push-up',
    names: ['上斜俯卧撑', '高位俯卧撑', 'incline push up']
  },
  {
    gifId: 'chin-up',
    names: ['反握引体向上', '反握引体', 'chin up']
  },
  {
    gifId: 'barbell-deadlift',
    names: ['杠铃硬拉', '硬拉', 'deadlift']
  },
  {
    gifId: 'bent-over-barbell-row',
    names: ['俯身杠铃划船', '杠铃划船', 'barbell row']
  },
  {
    gifId: 'close-grip-lat-pulldown',
    names: ['窄距高位下拉', '窄距下拉', 'close grip pulldown']
  },
  {
    gifId: 'dumbbell-shrug',
    names: ['哑铃耸肩', '耸肩', 'dumbbell shrug']
  },
  {
    gifId: 'barbell-shrug',
    names: ['杠铃耸肩', '杠铃耸肩', 'barbell shrug']
  },
  {
    gifId: 'rack-pull',
    names: ['架上硬拉', '架上拉', 'rack pull']
  },
  {
    gifId: 'straight-arm-pulldown',
    names: ['直臂下压', '直臂下拉', 'straight arm pulldown']
  },
  {
    gifId: 'standing-dumbbell-upright-row',
    names: ['站姿哑铃直立划船', '哑铃直立划船', 'dumbbell upright row']
  },
  {
    gifId: 'one-arm-kettlebell-row',
    names: ['单臂壶铃划船', '壶铃划船', 'kettlebell row']
  },
  {
    gifId: 'barbell-full-squat',
    names: ['杠铃全蹲', '全蹲', 'full squat']
  },
  {
    gifId: 'barbell-lunge',
    names: ['杠铃箭步蹲', '杠铃弓步', 'barbell lunge']
  },
  {
    gifId: 'dumbbell-lunges',
    names: ['哑铃箭步蹲', '哑铃弓步', 'dumbbell lunge']
  },
  {
    gifId: 'leg-extensions',
    names: ['坐姿腿屈伸', '腿屈伸', 'leg extension']
  },
  {
    gifId: 'lying-leg-curls',
    names: ['俯卧腿弯举', '腿弯举', 'lying leg curl']
  },
  {
    gifId: 'seated-calf-raise',
    names: ['坐姿提踵', '坐姿提踵', 'seated calf raise']
  },
  {
    gifId: 'standing-calf-raises',
    names: ['站姿提踵', '站姿提踵', 'standing calf raise']
  },
  {
    gifId: 'deficit-romanian-deadlift',
    names: ['垫高罗马尼亚硬拉', '垫高 RDL', 'deficit RDL']
  },
  {
    gifId: 'dumbbell-step-ups',
    names: ['哑铃登阶', '登阶', 'step up']
  },
  {
    gifId: 'smith-machine-squat',
    names: ['史密斯机深蹲', '史密斯深蹲', 'smith squat']
  },
  {
    gifId: 'barbell-hip-thrust',
    names: ['杠铃臀推', '臀推', 'hip thrust']
  },
  {
    gifId: 'seated-barbell-shoulder-press',
    names: ['坐姿杠铃肩推', '坐姿推举', 'seated shoulder press']
  },
  {
    gifId: 'front-dumbbell-raise',
    names: ['哑铃前平举', '前平举', 'front raise']
  },
  {
    gifId: 'reverse-flyes',
    names: ['俯卧上斜哑铃飞鸟', '后束飞鸟', 'reverse fly']
  },
  {
    gifId: 'arnold-dumbbell-press',
    names: ['阿诺德推举', '阿诺德推', 'arnold press']
  },
  {
    gifId: 'upright-barbell-row',
    names: ['杠铃直立划船', '直立划船', 'upright row']
  },
  {
    gifId: 'seated-rear-delt-raise',
    names: ['坐姿俯身后束飞鸟', '坐姿后束飞鸟', 'rear delt raise']
  },
  {
    gifId: 'cable-shoulder-press',
    names: ['绳索肩推', '龙门架肩推', 'cable shoulder press']
  },
  {
    gifId: 'alternate-hammer-curl',
    names: ['交替锤式弯举', '锤式弯举', 'hammer curl']
  },
  {
    gifId: 'preacher-curl',
    names: ['牧师凳弯举', '牧师凳弯举', 'preacher curl']
  },
  {
    gifId: 'concentration-curls',
    names: ['集中弯举', '集中弯举', 'concentration curl']
  },
  {
    gifId: 'close-grip-barbell-bench-press',
    names: ['窄距杠铃卧推', '窄距卧推', 'close grip bench press']
  },
  {
    gifId: 'triceps-dip',
    names: ['双杠臂屈伸（三头）', '双杠臂屈伸', 'triceps dip']
  },
  {
    gifId: 'standing-dumbbell-triceps-extension',
    names: ['站姿哑铃臂屈伸', '哑铃颈后臂屈伸', 'overhead triceps extension']
  },
  {
    gifId: 'bench-dips',
    names: ['凳上臂屈伸', '凳上臂屈伸', 'bench dip']
  },
  {
    gifId: 'lying-triceps-press',
    names: ['仰卧杠铃臂屈伸', '仰卧臂屈伸', 'lying triceps extension', '碎颅式']
  },
  {
    gifId: 'three-quarter-sit-up',
    names: ['四分之三卷腹', '3/4 卷腹', 'three quarter sit up']
  },
  {
    gifId: 'russian-twist',
    names: ['俄罗斯转体', '俄罗斯转体', 'russian twist']
  },
  {
    gifId: 'cable-crunch',
    names: ['绳索卷腹', '绳索卷腹', 'cable crunch']
  },
  {
    gifId: 'alternating-kettlebell-press',
    names: ['壶铃交替推举', '壶铃交替推举', 'kettlebell press']
  },
  {
    gifId: 'flutter-kicks',
    names: ['俯卧剪刀腿', '剪刀腿', 'flutter kicks']
  },
  {
    gifId: 'barbell-bench-press',
    names: ['杠铃卧推', 'barbell bench press']
  },
  {
    gifId: 'dumbbell-bench-press',
    names: ['哑铃卧推', 'dumbbell bench press']
  },
  {
    gifId: 'push-up',
    names: ['俯卧撑', 'push up', 'pushup']
  },
  {
    gifId: 'pull-up',
    names: ['引体向上', 'pull up', 'pullup']
  },
  {
    gifId: 'dumbbell-row',
    names: ['单臂哑铃划船', '哑铃划船', 'one arm dumbbell row']
  },
  {
    gifId: 'lat-pulldown',
    names: ['高位下拉', '弹力带高位下拉', 'lat pulldown']
  },
  {
    gifId: 'barbell-squat',
    names: ['杠铃深蹲', '深蹲', 'barbell squat']
  },
  {
    gifId: 'goblet-squat',
    names: ['高脚杯深蹲', 'goblet squat']
  },
  {
    gifId: 'machine-leg-press',
    names: ['腿举', 'leg press']
  },
  {
    gifId: 'dumbbell-shoulder-press',
    names: ['哑铃肩推', '哑铃推举', 'dumbbell shoulder press']
  },
  {
    gifId: 'band-lateral-raise',
    names: ['弹力带侧平举', 'band lateral raise']
  },
  {
    gifId: 'cable-triceps-pressdown',
    names: ['绳索下压', '三头下压', 'cable triceps pushdown']
  },
  {
    gifId: 'dumbbell-curl',
    names: ['哑铃弯举', '二头弯举', 'dumbbell curl']
  },
  {
    gifId: 'plank',
    names: ['平板支撑', 'plank']
  },
  {
    gifId: 'incline-dumbbell-press',
    names: ['上斜哑铃卧推', '上斜哑铃推胸', 'incline dumbbell press']
  },
  {
    gifId: 'cable-chest-fly',
    names: ['绳索夹胸', '绳索飞鸟', 'cable chest fly']
  },
  {
    gifId: 'chest-supported-row',
    names: ['胸托划船', 'chest supported row']
  },
  {
    gifId: 'seated-cable-row',
    names: ['坐姿绳索划船', '坐姿划船', 'seated cable row']
  },
  {
    gifId: 'walking-lunge',
    names: ['行进弓步', '弓步蹲', 'walking lunge']
  },
  {
    gifId: 'band-squat',
    names: ['弹力带深蹲', 'band squat']
  },
  {
    gifId: 'barbell-overhead-press',
    names: ['杠铃推举', '站姿推举', 'barbell overhead press']
  },
  {
    gifId: 'machine-shoulder-press',
    names: ['器械推肩', 'machine shoulder press']
  },
  {
    gifId: 'face-pull',
    names: ['面拉', 'face pull']
  },
  {
    gifId: 'cable-lateral-raise',
    names: ['绳索侧平举', 'cable lateral raise']
  },
  {
    gifId: 'close-grip-push-up',
    names: ['窄距俯卧撑', 'close grip push up']
  },
  {
    gifId: 'barbell-curl',
    names: ['杠铃弯举', 'barbell curl']
  },
  {
    gifId: 'band-triceps-extension',
    names: ['弹力带臂屈伸', '弹力带下压', 'band triceps extension']
  },
  {
    gifId: 'hanging-knee-raise',
    names: ['悬垂提膝', 'hanging knee raise']
  },
  {
    gifId: 'side-plank',
    names: ['侧桥', '侧平板', 'side plank']
  },
  {
    gifId: 'incline-machine-press',
    names: ['上斜器械推胸', 'incline machine press']
  },
  {
    gifId: 'band-chest-fly',
    names: ['弹力带夹胸', 'band chest fly']
  },
  {
    gifId: 'reverse-grip-lat-pulldown',
    names: ['反握高位下拉', 'reverse grip lat pulldown']
  },
  {
    gifId: 'leg-press-single',
    names: ['单腿腿举', 'single leg press']
  },
  {
    gifId: 'hack-squat-machine',
    names: ['哈克深蹲', 'hack squat']
  },
  {
    gifId: 'dumbbell-lateral-raise',
    names: ['哑铃侧平举', '侧平举', 'dumbbell lateral raise']
  },
  {
    gifId: 'cable-upright-row',
    names: ['绳索直立划船', 'cable upright row']
  },
  {
    gifId: 'dumbbell-skullcrusher',
    names: ['哑铃仰卧臂屈伸', 'dumbbell skullcrusher']
  },
  {
    gifId: 'hammer-curl-cable',
    names: ['绳索锤式弯举', 'cable hammer curl']
  },
  {
    gifId: 'machine-chest-press',
    names: ['器械推胸', 'machine chest press']
  },
  {
    gifId: 'dumbbell-flyes',
    names: ['哑铃飞鸟', 'dumbbell fly']
  },
  {
    gifId: 'crunches',
    names: ['卷腹', 'crunch']
  },
  {
    gifId: 'hanging-leg-raise',
    names: ['悬垂举腿', 'hanging leg raise']
  }
]

class ExerciseGifCatalogImpl {
  /** 动作中文名 -> GIF 文件名；未命中回退默认演示动作。 */
  resolveGifId(exerciseName: string): string {
    const name: string = exerciseName.trim()
    if (name.length === 0) {
      return DEFAULT_EXERCISE_GIF_ID
    }
    const gifId: string = this.findGifId(name)
    return gifId.length > 0 ? gifId : DEFAULT_EXERCISE_GIF_ID
  }

  /** 动作中文名 -> 素材路径，可直接交给 $rawfile。 */
  resolveDemoSource(exerciseName: string): string {
    return PHOTO_GIF_DIRECTORY + this.resolveGifId(exerciseName) + GIF_SUFFIX
  }

  /**
   * 动作中文名是否命中实拍素材。
   *
   * 素材已收敛为实拍单一来源（未命中时的默认回退图也是实拍），故所有演示图都应
   * 交给圆角容器收敛；保留此方法是为了让消费端不必感知素材来源的迁移历史。
   */
  usesPhotoStyle(exerciseName: string): boolean {
    return true
  }

  /** GIF 文件名 -> 素材路径。 */
  demoSourceOfGifId(gifId: string): string {
    return PHOTO_GIF_DIRECTORY + gifId + GIF_SUFFIX
  }

  /**
   * 内容库 exerciseId（ex_barbell_bench_press）-> 素材路径，可直接交给 $rawfile。
   *
   * 动作库页拿到的是内容库 id 而非中文名：gifIdOfExerciseId 先归一化（去 ex_ 前缀、
   * 下划线转连字符），与实拍组的 gifId 命名一致，故可直接按 id 命中。
   */
  resolveDemoSourceByExerciseId(exerciseId: string): string {
    const gifId: string = gifIdOfExerciseId(exerciseId)
    if (this.hasGifId(gifId)) {
      return PHOTO_GIF_DIRECTORY + gifId + GIF_SUFFIX
    }
    return DEMO_GIF_DIRECTORY + DEFAULT_EXERCISE_GIF_ID + GIF_SUFFIX
  }

  /** 按 exerciseId 判断是否命中实拍素材；素材已收敛为实拍单一来源，故恒为 true。 */
  usesPhotoStyleByExerciseId(exerciseId: string): boolean {
    return true
  }

  /** 在实拍组里按中文名精确查找；未命中返回空串。 */
  private findGifId(name: string): string {
    for (let groupIndex = 0; groupIndex < EXERCISE_PHOTO_GIF_GROUPS.length; groupIndex++) {
      const group: ExerciseGifGroup = EXERCISE_PHOTO_GIF_GROUPS[groupIndex]
      for (let nameIndex = 0; nameIndex < group.names.length; nameIndex++) {
        if (group.names[nameIndex] === name) {
          return group.gifId
        }
      }
    }
    return ''
  }

  private hasGifId(gifId: string): boolean {
    if (gifId.length === 0) {
      return false
    }
    for (let index = 0; index < EXERCISE_PHOTO_GIF_GROUPS.length; index++) {
      if (EXERCISE_PHOTO_GIF_GROUPS[index].gifId === gifId) {
        return true
      }
    }
    return false
  }
}

export default new ExerciseGifCatalogImpl()
