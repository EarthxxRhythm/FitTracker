package com.fittracker.app.ui.screens.body

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.fittracker.app.data.model.BodyMeasurement
import com.fittracker.app.data.model.WeightRecord
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.BodyMeasurementService
import com.fittracker.app.data.service.BodyRecordService
import com.fittracker.app.data.service.Gender
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.WeightUnit
import kotlinx.coroutines.launch

/**
 * 身体数据屏的状态持有者。
 *
 * 数据态与写路径从 [BodyScreen] 迁入——`viewModel()` 取 NavBackStackEntry 作用域实例，
 * 返回本屏时取回同一实例、数据与录入结果存活，装载只跑一次。
 *
 * **迁移边界**：
 * - 迁入：`weightUnit`/`records`/`weekStart`/`measurements`/`profile` + 装载 + 三条写路径
 *   （体重 / 测量 / 档案），写后直接刷新 VM 状态（原 `measurementReload` 的 bump 重读语义
 *   收敛为「写方法内显式重读」）。
 * - 留屏内：`period`（趋势周期）、`sheetMode`（录入面板）、各派生值（`weight`/`deltaLabel`/
 *   `trend`/`latestMeasurement`/`previousMeasurement`/`today`/`updatedText`）——它们是 UI
 *   派生或纯交互态，不迁。
 */
class BodyViewModel(application: Application) : AndroidViewModel(application) {

    private val store: JsonStore = JsonStore(application.appDataStore)

    // ── 数据态（原 BodyScreen.kt:146-153 的 remember 状态） ───────────────────

    var weightUnit by mutableStateOf(WeightUnit.KG)
        private set
    var records by mutableStateOf<List<WeightRecord>>(emptyList())
        private set
    var weekStart by mutableStateOf(WeekStart.MONDAY)
        private set
    var measurements by mutableStateOf<List<BodyMeasurement>>(emptyList())
        private set
    var profile by mutableStateOf(UserProfileService.getDefaultProfile())
        private set

    /** 「保存」即时反馈（原型 L552）。写成功后置 true，屏内消费后调 [consumeSaved] 复位。 */
    var saved by mutableStateOf(false)
        private set

    /**
     * 装载身体数据。逐行等价迁移自原 `BodyScreen.kt:156-163` 的 `LaunchedEffect(Unit)`。
     * 公开 `suspend`（同 Plan/Home/Profile：runBlocking 可驱动，规避 Robolectric Main dispatcher 死锁）。
     */
    suspend fun load() {
        val loadedProfile = UserProfileService.loadProfile(store)
        weightUnit = loadedProfile.weightUnit
        profile = loadedProfile
        records = BodyRecordService.loadRecords(store)
        measurements = BodyMeasurementService.loadMeasurements(store)
        weekStart = SettingsService.loadSettings(store).weekStart
    }

    // ── 写路径（原 BodyScreen 的三处 scope.launch 保存） ─────────────────────

    /**
     * 落盘体重记录（kg 基准）后重读 → 主数值/趋势/「较上周」刷新。对应原体重录入面板的 onSave。
     */
    fun addWeightRecord(kg: Double) {
        viewModelScope.launch {
            BodyRecordService.addRecord(
                store,
                WeightRecord(dateMillis = System.currentTimeMillis(), kg = kg),
            )
            records = BodyRecordService.loadRecords(store)
            saved = true
        }
    }

    /** 落盘身体测量（围度 + 体成分）后重读。对应原测量录入面板的 onSave。 */
    fun addMeasurement(draft: BodyMeasurement) {
        viewModelScope.launch {
            BodyMeasurementService.addMeasurement(
                store,
                draft.copy(dateMillis = System.currentTimeMillis()),
            )
            measurements = BodyMeasurementService.loadMeasurements(store)
            profile = UserProfileService.loadProfile(store)
        }
    }

    /** 落盘身体档案（身高/性别/出生年）后重读。对应原档案面板的 onSave。 */
    fun saveBodyProfile(heightCm: Int, gender: Gender, birthYear: Int) {
        viewModelScope.launch {
            UserProfileService.saveBodyProfile(store, heightCm, gender, birthYear)
            measurements = BodyMeasurementService.loadMeasurements(store)
            profile = UserProfileService.loadProfile(store)
        }
    }

    /** 屏内消费「保存」反馈后复位（避免跨屏残留 saved=true）。 */
    fun consumeSaved() {
        saved = false
    }
}
