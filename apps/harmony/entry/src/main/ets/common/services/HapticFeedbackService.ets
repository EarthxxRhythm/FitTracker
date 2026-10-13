/**
 * HapticFeedbackService — 训练触觉反馈服务。
 *
 * 受设置页「声音与震动」门控：开关关闭时不调用本对象；开关开启时，训练执行屏在
 * **完成一组**时给一次短促确认震动。本期只做震动——音效素材缺失，与 Android
 * Haptics.kt 同口径（见计划《设置模块功能实现》的非目标表）。
 * 归属边界：本服务只管「震动一次」，不读设置、不判断时机；门控与调用时机在调用方。
 * 失败语义：全链静默——设备无震动器（模拟器 / 部分平板）、权限或触觉能力缺失，
 * 都不得影响训练记录推进。
 */
import { vibrator } from '@kit.SensorServiceKit'

/** 确认震动时长（ms）——短促一击，不打断训练节奏。 */
const VIBRATION_MS: number = 30

class HapticFeedbackService {
  /**
   * 完成一组：短促确认震动（VIBRATION_MS）。
   *
   * 调用方须已确认设置页「声音与震动」开关为开；本方法自身不做门控。
   */
  async confirm(): Promise<void> {
    try {
      await vibrator.startVibration({
        type: 'time',
        duration: VIBRATION_MS
      }, {
        id: 0,
        usage: 'physicalFeedback'
      })
    } catch (error) {
      // 静默：触觉反馈缺失不应影响训练流程
    }
  }
}

export default new HapticFeedbackService()
