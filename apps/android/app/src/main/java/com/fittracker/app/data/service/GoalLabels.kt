package com.fittracker.app.data.service

/**
 * 训练目标类型 → 中文标签。
 *
 * 与鸿蒙 `common/utils/GoalLabels.ets` 保持同一映射；个人页副标题与计划页共用同一套标签。
 */
fun goalTypeLabel(goalType: String): String = when (goalType) {
    "hypertrophy" -> "增肌"
    "strength" -> "力量"
    "fat_loss" -> "减脂"
    "posture" -> "体态"
    else -> goalType
}
