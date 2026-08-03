import { describe, expect, it } from '@ohos/hypium'
import {
  WorkoutDraftSnapshot,
  createEmptyWorkoutDraftSnapshot
} from '../../../main/ets/common/services/WorkoutDraftService'
import HomeResumeService, {
  HomeResumePresentation
} from '../../../main/ets/features/home/services/HomeResumeService'

function createDraftSnapshot(): WorkoutDraftSnapshot {
  const snapshot: WorkoutDraftSnapshot = createEmptyWorkoutDraftSnapshot(1000)
  snapshot.planId = 'draft_plan'
  snapshot.planName = '\u63a8\u62c9\u817f\u5206\u88c2'
  snapshot.dayLabel = '\u63a8\u65e5'
  snapshot.totalTargetSets = 12
  snapshot.completedSets = 5
  snapshot.currentExerciseName = '\u6760\u94c3\u5367\u63a8'
  snapshot.currentExerciseProgress = '2/4'
  snapshot.updatedAt = 1500
  return snapshot
}

export default function homeResumeServiceTest(): void {
  describe('HomeResumeService', () => {
    it('creates a recoverable resume state when draft progress exists', 0, () => {
      const snapshot: WorkoutDraftSnapshot = createDraftSnapshot()

      const presentation: HomeResumePresentation = HomeResumeService.createPresentation(snapshot)

      expect(presentation.hasRecoverableDraft).assertTrue()
      expect(presentation.summaryText).assertEqual('\u63a8\u65e5 \u00b7 5/12 \u7ec4\u5df2\u5b8c\u6210')
      expect(presentation.statusText).assertEqual('\u53ef\u4ece\u4e0a\u6b21\u8fdb\u5ea6\u7ee7\u7eed')
    })

    it('returns non-recoverable state for an empty draft snapshot', 0, () => {
      const snapshot: WorkoutDraftSnapshot = createEmptyWorkoutDraftSnapshot(1000)

      const presentation: HomeResumePresentation = HomeResumeService.createPresentation(snapshot)

      expect(presentation.hasRecoverableDraft).assertFalse()
      expect(presentation.summaryText).assertEqual('')
    })

    it('returns non-recoverable state when draft is missing', 0, () => {
      const presentation: HomeResumePresentation = HomeResumeService.createPresentation(null)

      expect(presentation.hasRecoverableDraft).assertFalse()
      expect(presentation.summaryText).assertEqual('')
      expect(presentation.statusText).assertEqual('')
    })
  })
}
