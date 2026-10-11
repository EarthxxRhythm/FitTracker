package com.fittracker.app.data.model

import kotlinx.serialization.Serializable

/**
 * 单条体重记录（原型完整实现 Wave 3 · W3-1）。
 *
 * [dateMillis] 为**本地日零点**的 epoch 毫秒（日粒度）：同一自然日重复记录按「覆盖」处理
 * （见 `BodyRecordService.addRecord`）。口径与仓内时间约定一致——统一用 epoch 毫秒
 * （`UserGoal.createdAt` / `WorkoutSession.startedAt` / `System.currentTimeMillis()`），
 * 不引入 `java.time`（`minSdk = 24`，避免 desugaring 依赖；同 `StatsDashboardService` 头注）。
 *
 * [kg] 恒以**千克**为基准存储（与 `FtBodyModel` 全屏质量基准一致）；展示时按设置项
 * 「体重单位」换算（`FtBodyModel.toDisplay` / `toKilograms`）。
 */
@Serializable
data class WeightRecord(
    val dateMillis: Long,
    val kg: Double,
)
