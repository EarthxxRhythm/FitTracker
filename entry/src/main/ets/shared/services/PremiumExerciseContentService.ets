/**
 * PremiumExerciseContentService -- builds a plus-only coaching enhancement layer for exercise detail.
 *
 * Phase 4: gate richer exercise guidance behind premium_content without blocking the free exercise detail.
 */
import { ExerciseDetailViewModel } from './ContentRepository'
import { MonetizationTier } from '../models/MonetizationModels'

export class PremiumExerciseContentTile {
  tileId: string = ''
  label: string = ''
  value: string = ''
  note: string = ''
}

export class PremiumExerciseContentPresentation {
  locked: boolean = true
  statusLabel: string = 'Free'
  title: string = '高级训练内容'
  description: string = '升级后可查看更完整的训练放置、进阶节奏和替代策略。'
  actionText: string = '查看 Plus 方案'
  supportingText: string = '基础动作说明、步骤、注意事项和替代动作保持免费可用。'
  tiles: PremiumExerciseContentTile[] = []
  checklist: string[] = []
}

class PremiumExerciseContentService {
  createDefaultPresentation(): PremiumExerciseContentPresentation {
    return this.createPresentation(true, 'free', this.createEmptyDetail())
  }

  createPresentation(
    locked: boolean,
    activeTier: MonetizationTier,
    detail: ExerciseDetailViewModel
  ): PremiumExerciseContentPresentation {
    if (locked) {
      return this.createLockedPresentation(detail)
    }
    return this.createUnlockedPresentation(activeTier, detail)
  }

  private createLockedPresentation(detail: ExerciseDetailViewModel): PremiumExerciseContentPresentation {
    const presentation: PremiumExerciseContentPresentation = {
      locked: true,
      statusLabel: 'Free',
      title: '高级训练内容预览',
      description: '当前动作详情已经够你开始训练。升级后，可以继续看这个动作更适合放在训练里的哪个位置、怎么稳步进阶、以及什么时候该切到替代动作。',
      actionText: '查看 Plus 方案',
      supportingText: '不会影响当前免费动作详情和媒体入口。',
      tiles: [
        this.createTile('placement', '训练放置', '主线训练中的位置', this.createLockedPlacementNote(detail)),
        this.createTile('progression', '进阶节奏', '负荷与次数怎么推', this.createLockedProgressionNote(detail)),
        this.createTile('substitution', '替代策略', '什么时候换动作', this.createLockedSubstitutionNote(detail))
      ],
      checklist: [
        '按当前步骤先把动作路径做稳，再考虑升级负荷。',
        '看清常见错误和安全提示，避免把动作做成代偿。',
        '需要更细的进阶节奏和替代建议时再升级。'
      ]
    }
    return presentation
  }

  private createUnlockedPresentation(
    activeTier: MonetizationTier,
    detail: ExerciseDetailViewModel
  ): PremiumExerciseContentPresentation {
    const presentation: PremiumExerciseContentPresentation = {
      locked: false,
      statusLabel: activeTier === 'plus' ? 'Plus 已解锁' : '已解锁',
      title: '高级训练内容',
      description: '这个动作的高级训练内容已开放。你现在可以直接按当前动作特征查看放置建议、进阶焦点和替代策略。',
      actionText: '当前已解锁',
      supportingText: '这部分只增强训练理解，不改动当前免费动作详情。',
      tiles: [
        this.createTile('placement', '训练放置', this.getPlacementValue(detail), this.getPlacementNote(detail)),
        this.createTile('progression', '进阶焦点', this.getProgressionValue(detail), this.getProgressionNote(detail)),
        this.createTile('substitution', '替代策略', this.getSubstitutionValue(detail), this.getSubstitutionNote(detail))
      ],
      checklist: this.createUnlockedChecklist(detail)
    }
    return presentation
  }

  private createUnlockedChecklist(detail: ExerciseDetailViewModel): string[] {
    const checklist: string[] = []
    if (detail.cues.length > 0) {
      checklist.push('本次训练先盯住：' + detail.cues[0])
    } else {
      checklist.push('本次训练先盯住动作路径和发力顺序，再慢慢加重量。')
    }
    if (detail.commonMistakes.length > 0) {
      checklist.push('出现以下代偿就先降难度：' + detail.commonMistakes[0])
    } else {
      checklist.push('一旦动作质量开始散，就优先保质量，不要硬堆组数。')
    }
    if (detail.safetyNotes.length > 0) {
      checklist.push('安全底线：' + detail.safetyNotes[0])
    } else {
      checklist.push('安全底线：在疲劳明显上来前结束本动作，不用追求每组都到极限。')
    }
    return checklist
  }

  private getPlacementValue(detail: ExerciseDetailViewModel): string {
    if (detail.difficultyText.indexOf('高') >= 0 || detail.difficultyText.indexOf('进阶') >= 0) {
      return '安排在主训练前段'
    }
    if (detail.equipmentNames.length > 1) {
      return '安排在主线动作后半段'
    }
    return '安排在主训练中段'
  }

  private getPlacementNote(detail: ExerciseDetailViewModel): string {
    if (detail.primaryMuscleNames.length > 0) {
      return '优先在你还清醒的时候完成它，重点照顾 ' + detail.primaryMuscleNames[0] + ' 的发力质量。'
    }
    return '优先在你还清醒的时候完成它，避免把动作做成纯堆次数。'
  }

  private getProgressionValue(detail: ExerciseDetailViewModel): string {
    if (detail.cues.length > 0) {
      return detail.cues[0]
    }
    if (detail.steps.length > 0) {
      return detail.steps[0]
    }
    return '先稳住动作，再推负荷'
  }

  private getProgressionNote(detail: ExerciseDetailViewModel): string {
    if (detail.steps.length > 1) {
      return '先把前两步动作顺序稳定下来，再考虑提高重量、次数或训练量。'
    }
    return '进阶顺序优先是动作质量、再是次数、最后才是重量。'
  }

  private getSubstitutionValue(detail: ExerciseDetailViewModel): string {
    if (detail.alternativeNames.length > 0) {
      return detail.alternativeNames[0]
    }
    return '先保留当前动作'
  }

  private getSubstitutionNote(detail: ExerciseDetailViewModel): string {
    if (detail.alternativeNames.length > 1) {
      return '当前至少有 ' + detail.alternativeNames.length.toString() + ' 个同类替代动作，可按器械条件和疲劳状态切换。'
    }
    if (detail.alternativeNames.length === 1) {
      return '当器械条件不合适、动作路径一直不稳，或目标肌群感觉不对时，先切到这个替代动作。'
    }
    if (detail.equipmentNames.length > 0) {
      return '当前没有登记替代动作，优先确认 ' + detail.equipmentNames[0] + ' 条件稳定，再继续做当前版本。'
    }
    return '当前没有登记替代动作，训练中优先保动作质量。'
  }

  private createLockedPlacementNote(detail: ExerciseDetailViewModel): string {
    if (detail.difficultyText.length > 0) {
      return '升级后可查看这个 ' + detail.difficultyText + ' 动作更适合放在训练前段、中段还是后段。'
    }
    return '升级后可查看这个动作更适合放在训练前段、中段还是后段。'
  }

  private createLockedProgressionNote(detail: ExerciseDetailViewModel): string {
    if (detail.cues.length > 0) {
      return '升级后会把“' + detail.cues[0] + '”这类关键提示转成更明确的进阶顺序。'
    }
    return '升级后会给出更明确的进阶顺序，先推什么、后推什么。'
  }

  private createLockedSubstitutionNote(detail: ExerciseDetailViewModel): string {
    if (detail.alternativeNames.length > 0) {
      return '升级后会告诉你什么时候该从当前动作切到“' + detail.alternativeNames[0] + '”。'
    }
    return '升级后会补充什么时候该保留当前动作，什么时候该降阶或换动作。'
  }

  private createTile(tileId: string, label: string, value: string, note: string): PremiumExerciseContentTile {
    const tile: PremiumExerciseContentTile = {
      tileId: tileId,
      label: label,
      value: value,
      note: note
    }
    return tile
  }

  private createEmptyDetail(): ExerciseDetailViewModel {
    const detail: ExerciseDetailViewModel = {
      exerciseId: '',
      name: '',
      nameEn: '',
      difficultyText: '',
      primaryMuscleNames: [],
      equipmentNames: [],
      steps: [],
      cues: [],
      commonMistakes: [],
      safetyNotes: [],
      alternativeNames: [],
      coverUrl: '',
      videoUrl: '',
      coverSourceLabel: '',
      videoSourceLabel: '',
      mediaLicenseText: '',
      videoPlaceholder: ''
    }
    return detail
  }
}

export default new PremiumExerciseContentService()
