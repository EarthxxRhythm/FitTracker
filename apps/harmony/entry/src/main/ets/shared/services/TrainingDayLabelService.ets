/**
 * TrainingDayLabelService -- formats internal training-day ids into stable Simplified Chinese labels.
 *
 * Function #14: keep workout loop and review surfaces aligned on user-facing day labels.
 */
class TrainingDayLabelService {
  formatCompact(dayId: string, fallbackLabel: string = ''): string {
    const normalizedDayId: string = dayId.trim().toLowerCase()
    const currentPlanNumber: string = this.getCurrentPlanDayNumber(normalizedDayId)
    if (currentPlanNumber.length > 0) {
      return '第 ' + currentPlanNumber + ' 天'
    }

    const generatedDayNumber: string = this.getGeneratedDayNumber(normalizedDayId)
    if (generatedDayNumber.length > 0) {
      return '第 ' + generatedDayNumber + ' 天'
    }

    const namedLabel: string = this.getNamedDayLabel(normalizedDayId)
    if (namedLabel.length > 0) {
      return namedLabel
    }

    if (fallbackLabel.length > 0) {
      return fallbackLabel
    }
    return dayId
  }

  formatLoopBadge(dayId: string, fallbackLabel: string = ''): string {
    return this.formatCompact(dayId, fallbackLabel)
  }

  formatSummary(dayId: string, fallbackLabel: string = ''): string {
    const normalizedDayId: string = dayId.trim().toLowerCase()
    const currentPlanNumber: string = this.getCurrentPlanDayNumber(normalizedDayId)
    if (currentPlanNumber.length > 0) {
      return '当前计划 第 ' + currentPlanNumber + ' 天'
    }

    const generatedDayNumber: string = this.getGeneratedDayNumber(normalizedDayId)
    if (generatedDayNumber.length > 0) {
      return '训练日 第 ' + generatedDayNumber + ' 天'
    }

    return this.formatCompact(dayId, fallbackLabel)
  }

  private getCurrentPlanDayNumber(normalizedDayId: string): string {
    const match: RegExpMatchArray | null = normalizedDayId.match(/^current_plan_day_(\d+)$/)
    if (match === null) {
      return ''
    }
    return match[1]
  }

  private getGeneratedDayNumber(normalizedDayId: string): string {
    const match: RegExpMatchArray | null = normalizedDayId.match(/^day_(\d+)$/)
    if (match === null) {
      return ''
    }
    return match[1]
  }

  private getNamedDayLabel(normalizedDayId: string): string {
    let key: string = normalizedDayId
    if (normalizedDayId.indexOf('day_') === 0) {
      key = normalizedDayId.substring(4)
    } else if (normalizedDayId.lastIndexOf('_day') === normalizedDayId.length - 4) {
      key = normalizedDayId.substring(0, normalizedDayId.length - 4)
    }

    if (key === 'push') {
      return '推日'
    }
    if (key === 'pull') {
      return '拉日'
    }
    if (key === 'leg' || key === 'legs' || key === 'lower') {
      return '下肢日'
    }
    if (key === 'upper') {
      return '上肢日'
    }
    if (key === 'core') {
      return '核心日'
    }
    if (key === 'full_body' || key === 'fullbody') {
      return '全身日'
    }
    if (key === 'recovery') {
      return '恢复日'
    }
    if (key === 'rest') {
      return '休息日'
    }
    if (key === 'chest') {
      return '胸部日'
    }
    if (key === 'back') {
      return '背部日'
    }
    if (key === 'shoulder' || key === 'shoulders') {
      return '肩部日'
    }
    if (key === 'arm' || key === 'arms') {
      return '手臂日'
    }
    if (key === 'glute' || key === 'glutes') {
      return '臀部日'
    }
    if (key === 'monday') {
      return '周一'
    }
    if (key === 'tuesday') {
      return '周二'
    }
    if (key === 'wednesday') {
      return '周三'
    }
    if (key === 'thursday') {
      return '周四'
    }
    if (key === 'friday') {
      return '周五'
    }
    if (key === 'saturday') {
      return '周六'
    }
    if (key === 'sunday') {
      return '周日'
    }
    return ''
  }
}

export default new TrainingDayLabelService()
