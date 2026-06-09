import { describe, expect, it } from '@ohos/hypium'
import { ExerciseDetailViewModel } from '../../../main/ets/shared/services/ContentRepository'
import PremiumExerciseContentService from '../../../main/ets/shared/services/PremiumExerciseContentService'

function createDetail(): ExerciseDetailViewModel {
  const detail: ExerciseDetailViewModel = {
    exerciseId: 'ex_barbell_bench_press',
    name: '杠铃卧推',
    nameEn: 'Barbell Bench Press',
    difficultyText: '进阶',
    primaryMuscleNames: ['胸部'],
    equipmentNames: ['杠铃', '卧推凳'],
    steps: ['收紧肩胛并稳定躯干', '下放到胸中段', '沿原路推回起始位'],
    cues: ['下放要稳，推起时保持肩胛稳定'],
    commonMistakes: ['肘部外翻过大导致肩前顶'],
    safetyNotes: ['腰背保持稳定，不要为了借力抬臀'],
    alternativeNames: ['哑铃卧推', '俯卧撑'],
    coverUrl: '',
    videoUrl: '',
    coverSourceLabel: '',
    videoSourceLabel: '',
    mediaLicenseText: '',
    videoPlaceholder: '本地占位'
  }
  return detail
}

export default function premiumExerciseContentServiceTest(): void {
  describe('PremiumExerciseContentService', () => {
    it('creates a locked premium teaser for free users', 0, () => {
      const presentation = PremiumExerciseContentService.createPresentation(true, 'free', createDetail())

      expect(presentation.locked).assertTrue()
      expect(presentation.statusLabel).assertEqual('Free')
      expect(presentation.title).assertEqual('高级训练内容预览')
      expect(presentation.tiles.length).assertEqual(3)
      expect(presentation.actionText).assertEqual('查看 Plus 方案')
    })

    it('creates an unlocked premium coaching panel for plus users', 0, () => {
      const presentation = PremiumExerciseContentService.createPresentation(false, 'plus', createDetail())

      expect(presentation.locked).assertFalse()
      expect(presentation.statusLabel).assertEqual('Plus 已解锁')
      expect(presentation.description).assertContain('Plus 权益')
      expect(presentation.actionText).assertEqual('查看当前权益')
      expect(presentation.tiles[0].label).assertEqual('训练放置')
      expect(presentation.tiles[0].value).assertEqual('安排在主训练前段')
      expect(presentation.tiles[1].value).assertEqual('下放要稳，推起时保持肩胛稳定')
      expect(presentation.tiles[2].value).assertEqual('哑铃卧推')
      expect(presentation.checklist.length).assertEqual(3)
    })

    it('falls back gracefully when no alternatives or cues are present', 0, () => {
      const detail = createDetail()
      detail.cues = []
      detail.alternativeNames = []
      detail.commonMistakes = []
      detail.safetyNotes = []

      const presentation = PremiumExerciseContentService.createPresentation(false, 'plus', detail)

      expect(presentation.tiles[1].value).assertEqual('收紧肩胛并稳定躯干')
      expect(presentation.tiles[2].value).assertEqual('先保留当前动作')
      expect(presentation.checklist.length).assertEqual(3)
    })
  })
}
