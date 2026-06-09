/**
 * ReviewUpgradeEntryService -- maps monetization gate results into review entry presentations.
 *
 * Phase 4: wire the first monetization-facing review entry without breaking the free workout loop.
 */
import { MonetizationGateResult } from '../models/MonetizationModels'

export class ReviewUpgradeEntryPresentation {
  statusLabel: string = 'Free'
  title: string = '解锁高级洞察'
  description: string = '升级后可查看更长周期趋势、动作 PR 细节与后续增强回顾能力。'
  actionText: string = '查看 Pro 方案'
  supportingText: string = '购买入口会在正式发布链路稳定后开放。'
  locked: boolean = true
  featureBullets: string[] = []
}

class ReviewUpgradeEntryService {
  createDefaultAdvancedInsightsPresentation(): ReviewUpgradeEntryPresentation {
    return this.createPresentation(
      'Free',
      '解锁高级洞察',
      '升级后可查看更长周期趋势、动作 PR 细节与后续增强回顾能力。',
      '查看 Pro 方案',
      '购买入口会在正式发布链路稳定后开放。',
      true,
      [
        '更长历史周期趋势',
        '按动作查看更深 PR 细节',
        '后续增强周报与目标调整建议'
      ]
    )
  }

  createAdvancedInsightsPresentation(
    gateResult: MonetizationGateResult,
    sessionCount: number,
    weeklySessionCount: number
  ): ReviewUpgradeEntryPresentation {
    if (gateResult.allowed) {
      const statusLabel: string = gateResult.activeTier === 'plus' ? 'Plus 已覆盖' : 'Pro 已解锁'
      const description: string = this.createUnlockedDescription(gateResult.activeTier, weeklySessionCount)
      const actionText: string = '查看当前权益'
      return this.createPresentation(
        statusLabel,
        '高级洞察已解锁',
        description,
        actionText,
        '后续更深的周报和 PR 解释会优先接到这里。',
        false,
        [
          '更长周期趋势已预留接入位',
          '深度 PR 细节将优先落在回顾页',
          '不影响当前免费训练闭环'
        ]
      )
    }

    return this.createPresentation(
      'Free',
      '解锁高级洞察',
      this.createLockedDescription(sessionCount),
      '查看 Pro 方案',
      '先保持当前训练节奏，回顾页会继续累积可升级的历史价值。',
      true,
      [
        '更长历史周期趋势',
        '动作 PR 深度细节',
        '增强版目标调整建议'
      ]
    )
  }

  private createUnlockedDescription(activeTier: string, weeklySessionCount: number): string {
    if (weeklySessionCount > 0) {
      return '本周已完成 ' + weeklySessionCount.toString() + ' 次训练，高级洞察入口已为后续更深分析能力预留。'
    }
    if (activeTier === 'plus') {
      return '当前 Plus 权益已覆盖高级洞察与后续扩展回顾能力。'
    }
    return '当前 Pro 权益已解锁高级洞察入口，后续增强分析会优先接到这里。'
  }

  private createLockedDescription(sessionCount: number): string {
    if (sessionCount > 0) {
      return '你已累计 ' + sessionCount.toString() + ' 次训练记录，升级后可查看更长周期趋势与动作 PR 深度细节。'
    }
    return '完成更多训练记录后，这里会提供更长周期趋势和动作 PR 深度分析。'
  }

  private createPresentation(
    statusLabel: string,
    title: string,
    description: string,
    actionText: string,
    supportingText: string,
    locked: boolean,
    featureBullets: string[]
  ): ReviewUpgradeEntryPresentation {
    const presentation: ReviewUpgradeEntryPresentation = {
      statusLabel: statusLabel,
      title: title,
      description: description,
      actionText: actionText,
      supportingText: supportingText,
      locked: locked,
      featureBullets: this.copyStringArray(featureBullets)
    }
    return presentation
  }

  private copyStringArray(source: string[]): string[] {
    const values: string[] = []
    for (let index = 0; index < source.length; index++) {
      values.push(source[index])
    }
    return values
  }
}

export default new ReviewUpgradeEntryService()
