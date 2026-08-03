/**
 * HomeResumeService -- resume-training presentation for the home hero card.
 */
import {
  WorkoutDraftSnapshot,
  hasWorkoutDraftProgress
} from '../../../common/services/WorkoutDraftService'

export interface HomeResumePresentation {
  hasRecoverableDraft: boolean
  summaryText: string
  statusText: string
}

function createPresentation(
  hasRecoverableDraft: boolean,
  summaryText: string,
  statusText: string
): HomeResumePresentation {
  return {
    hasRecoverableDraft: hasRecoverableDraft,
    summaryText: summaryText,
    statusText: statusText
  }
}

class HomeResumeService {
  createPresentation(snapshot: WorkoutDraftSnapshot | null): HomeResumePresentation {
    if (snapshot === null) {
      return createPresentation(false, '', '')
    }

    if (!hasWorkoutDraftProgress(snapshot)) {
      return createPresentation(false, '', '')
    }

    const summaryText: string = snapshot.dayLabel + ' \u00b7 ' +
      snapshot.completedSets.toString() + '/' + snapshot.totalTargetSets.toString() + ' \u7ec4\u5df2\u5b8c\u6210'
    return createPresentation(true, summaryText, '\u53ef\u4ece\u4e0a\u6b21\u8fdb\u5ea6\u7ee7\u7eed')
  }
}

export default new HomeResumeService()
