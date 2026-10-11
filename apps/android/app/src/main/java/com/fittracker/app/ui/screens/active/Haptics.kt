package com.fittracker.app.ui.screens.active

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * 训练触觉反馈——受设置项「声音与震动」控制。
 *
 * 音效素材缺失，本期只做震动（见计划《设置模块功能实现》的非目标表）：设置屏该开关
 * 落盘后，训练执行屏在**完成一组**时给一次短促确认震动；开关关闭时不调用本对象。
 *
 * 权限：`android.permission.VIBRATE`（普通权限，Manifest 已声明，运行时无需申请）。
 */
object Haptics {

    /** 确认震动时长（ms）——短促一击，不打断训练节奏。 */
    const val VIBRATION_MS: Long = 30L

    /**
     * 完成一组：短促确认震动（[VIBRATION_MS]）。
     *
     * 取震动器分两条路：API 31+（S）经 [VibratorManager.defaultVibrator]，此前走
     * [Context.VIBRATOR_SERVICE] 上的 [Vibrator]。设备无震动器时静默返回
     * （模拟器 / 部分平板）——触觉反馈缺失不应影响训练记录推进。
     */
    fun confirm(context: Context) {
        val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            manager?.defaultVibrator ?: return
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        }
        if (!vibrator.hasVibrator()) return
        vibrate(vibrator)
    }

    /** API 26+ 走 [VibrationEffect.createOneShot]；24-25 只有旧 [Vibrator.vibrate] 的时长重载。 */
    private fun vibrate(vibrator: Vibrator) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(VIBRATION_MS, VibrationEffect.DEFAULT_AMPLITUDE),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(VIBRATION_MS)
        }
    }
}
