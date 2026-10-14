package com.fittracker.app.data.service

import android.content.Context
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.R
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import com.fittracker.app.data.sync.SyncOrchestrator
import com.fittracker.app.ui.screens.settings.FtSettingRow
import com.fittracker.app.ui.screens.settings.FtSettingTrailing
import com.fittracker.app.ui.screens.settings.FtSettingsModel
import com.fittracker.app.ui.screens.settings.FtSettingsSection
import java.io.File
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * [SettingsService] 契约测试（Wave 1 · W1-6/7/8/9）。
 *
 * 覆盖：
 * ① 空 store 回落原型静止态缺省；
 * ② 存取往返；
 * ③ 单字段读-改-写不丢其余字段；
 * ④ 宽容解析——未知语言 / 周开始日归一为缺省且不连带丢开关；
 * ⑤ [SettingsService.clearSettings] 回落缺省。
 *
 * 另含设置分段映射（[FtSettingsModel.sections]）与**文案资源**（Wave 6 i18n）的断言——
 * 分段 / 开关的「回显」与「点击反馈」是 W1-7/8/9 的核心可测面，文案断言保持**逐字**
 * （资源值 vs 期望中文），只是取值路径从模型常量改为 `context.getString(资源 ID)`。
 *
 * 测试手段照 `RepositoriesTest` / `SyncOrchestratorTest`：以 [PreferenceDataStoreFactory]
 * 把每个用例的存储指向独立临时文件（互不污染、不触真实应用存储）；单例静态态（
 * [SyncOrchestrator] 的测试注入存储）在每例前后清空，避免串场。
 *
 * `@Config(sdk = [34])`：项目 targetSdk 37 超出 Robolectric 4.16 支持范围，必须钉到受支持 SDK。
 * `qualifiers = "zh-rCN"`：文案断言取 `values/` 的中文真源；不钉区域限定符时 Robolectric 默认
 * 走 en 资源，断言会取到英文译文。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class SettingsServiceTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    /** 中文资源真源（`values/strings_settings.xml`）的取值入口。 */
    private val context: Context get() = ApplicationProvider.getApplicationContext()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "settings_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    @Before
    fun resetSingletonState() {
        SyncOrchestrator.setStoreForTesting(null)
    }

    @After
    fun clearSingletonState() {
        SyncOrchestrator.setStoreForTesting(null)
    }

    // --- 存储模型（W1-6） ---------------------------------------------------

    @Test
    fun `空 store 读回原型静止态缺省`() = runBlocking {
        val store = createStore()
        val settings = SettingsService.loadSettings(store)

        assertEquals(FtSettings(), settings)
        // 原型静止态：语言简体中文 / 周一开始 / 训练提醒·声音震动·屏幕常亮为开，成就提醒·匿名数据为关
        assertEquals(SettingsLanguage.ZH, settings.language)
        assertEquals(WeekStart.MONDAY, settings.weekStart)
        assertTrue(settings.workoutReminder)
        assertFalse(settings.achievementReminder)
        assertTrue(settings.soundVibration)
        assertTrue(settings.keepScreenOn)
        assertFalse(settings.anonymousData)
    }

    @Test
    fun `整份存取往返全等`() = runBlocking {
        val store = createStore()
        val settings = FtSettings(
            language = SettingsLanguage.EN,
            weekStart = WeekStart.SUNDAY,
            workoutReminder = false,
            achievementReminder = true,
            soundVibration = false,
            keepScreenOn = false,
            anonymousData = true,
        )
        SettingsService.saveSettings(store, settings)

        assertEquals(settings, SettingsService.loadSettings(store))
    }

    @Test
    fun `单字段写不丢其它字段`() = runBlocking {
        val store = createStore()
        SettingsService.saveSettings(store, FtSettings())

        SettingsService.setLanguage(store, SettingsLanguage.EN)
        SettingsService.setWeekStart(store, WeekStart.SUNDAY)
        SettingsService.setAnonymousData(store, true)

        val loaded = SettingsService.loadSettings(store)
        assertEquals(SettingsLanguage.EN, loaded.language)
        assertEquals(WeekStart.SUNDAY, loaded.weekStart)
        assertTrue(loaded.anonymousData)
        // 未改动的开关原样保留
        assertTrue(loaded.workoutReminder)
        assertFalse(loaded.achievementReminder)
        assertTrue(loaded.soundVibration)
        assertTrue(loaded.keepScreenOn)
    }

    @Test
    fun `并发单字段写不丢更新`() = runBlocking {
        val store = createStore()
        // 两协程并发写两个不同单字段——读-改-写若未串行化，后写者会以自己读到的旧快照
        // 覆盖先写者已提交的字段（丢更新）。分派到 Dispatchers.Default 制造真实并行。
        val languageWrite = async(Dispatchers.Default) {
            SettingsService.setLanguage(store, SettingsLanguage.EN)
        }
        val anonymousWrite = async(Dispatchers.Default) {
            SettingsService.setAnonymousData(store, true)
        }
        languageWrite.await()
        anonymousWrite.await()

        val loaded = SettingsService.loadSettings(store)
        assertEquals(SettingsLanguage.EN, loaded.language)
        assertTrue(loaded.anonymousData)
    }

    @Test
    fun `未知语言与周开始日归一为缺省且不丢开关`() = runBlocking {
        val store = createStore()
        // 直接写一块「含未知枚举值」的 JSON——模拟旧版 / 跨端写入的宽容读取场景
        store.writeString(
            StoreNames.SETTINGS,
            """{"language":"klingon","weekStart":"friday","workoutReminder":false}""",
        )

        val loaded = SettingsService.loadSettings(store)
        assertEquals(SettingsLanguage.ZH, loaded.language)
        assertEquals(WeekStart.MONDAY, loaded.weekStart)
        assertFalse(loaded.workoutReminder) // 未知枚举不连带丢其余字段
        assertTrue(loaded.keepScreenOn) // 缺键回落缺省
    }

    @Test
    fun `清空后读回缺省`() = runBlocking {
        val store = createStore()
        SettingsService.saveSettings(store, FtSettings(language = SettingsLanguage.EN, anonymousData = true))

        SettingsService.clearSettings(store)

        assertEquals(FtSettings(), SettingsService.loadSettings(store))
    }

    @Test
    fun `归一函数仅识别 en 与 sunday`() {
        assertEquals(SettingsLanguage.ZH, SettingsService.normalizeLanguage("zh"))
        assertEquals(SettingsLanguage.EN, SettingsService.normalizeLanguage("en"))
        assertEquals(SettingsLanguage.ZH, SettingsService.normalizeLanguage("ja"))

        assertEquals(WeekStart.MONDAY, SettingsService.normalizeWeekStart("monday"))
        assertEquals(WeekStart.SUNDAY, SettingsService.normalizeWeekStart("sunday"))
        assertEquals(WeekStart.MONDAY, SettingsService.normalizeWeekStart("friday"))
    }

    // --- 设置分段映射（W1-7/8 回显） ----------------------------------------

    private fun row(sections: List<FtSettingsSection>, key: String): FtSettingRow =
        sections.flatMap { it.rows }.first { it.key == key }

    private fun segment(sections: List<FtSettingsSection>, key: String): FtSettingTrailing.Segment =
        row(sections, key).trailing as FtSettingTrailing.Segment

    @Test
    fun `分段 active 随设置重算`() {
        val sections = FtSettingsModel.sections(
            weightUnit = WeightUnit.LBS,
            settings = FtSettings(language = SettingsLanguage.EN, weekStart = WeekStart.SUNDAY),
            versionName = "0.0.0-test",
        )

        assertEquals(listOf(false, true), segment(sections, FtSettingsModel.KEY_WEIGHT_UNIT).options.map { it.active })
        assertEquals(listOf(false, true), segment(sections, FtSettingsModel.KEY_LANGUAGE).options.map { it.active })
        assertEquals(listOf(false, true), segment(sections, FtSettingsModel.KEY_WEEK_START).options.map { it.active })
    }

    @Test
    fun `开关 on 态随设置重算`() {
        val sections = FtSettingsModel.sections(
            weightUnit = WeightUnit.KG,
            settings = FtSettings(
                workoutReminder = false,
                achievementReminder = true,
                anonymousData = true,
            ),
            versionName = "0.0.0-test",
        )

        fun on(key: String): Boolean = (row(sections, key).trailing as FtSettingTrailing.Switch).on

        assertFalse(on(FtSettingsModel.KEY_WORKOUT_REMINDER))
        assertTrue(on(FtSettingsModel.KEY_ACHIEVEMENT_REMINDER))
        assertTrue(on(FtSettingsModel.KEY_ANONYMOUS_DATA))
    }

    @Test
    fun `分段与开关行均带唯一派发键`() {
        val rows = FtSettingsModel.SECTIONS.flatMap { it.rows }
        val interactive = rows.filter {
            it.trailing is FtSettingTrailing.Segment || it.trailing is FtSettingTrailing.Switch
        }
        interactive.forEach { assertNotNull("交互行缺 key：${it.labelRes}", it.key) }
        assertEquals(interactive.size, interactive.mapNotNull { it.key }.toSet().size)
    }

    // --- 文案资源（Wave 6 i18n） --------------------------------------------

    /**
     * 设置屏文案的**中文逐字**真源断言——资源值 vs 期望中文（原型 `fittracker-settings.html`
     * L374/377/385/388-465 与鸿蒙对齐项）。逐字断言不弱化：改动 `values/strings_settings.xml`
     * 的中文即红。
     */
    @Test
    fun `设置屏文案资源中文逐字对齐原型`() {
        val expectations = listOf(
            R.string.settings_title to "设置",
            R.string.settings_a11y_back to "返回个人页",
            R.string.settings_foot_note to "FitTracker 本地优先，训练数据与身体数据默认仅保存在本机。",
            R.string.settings_section_general to "通用",
            R.string.settings_section_data_privacy to "数据与隐私",
            R.string.settings_section_about to "关于",
            R.string.settings_row_weight_unit to "体重单位",
            R.string.settings_row_language to "语言",
            R.string.settings_row_week_start to "周开始日",
            R.string.settings_row_workout_reminder to "训练提醒",
            R.string.settings_row_achievement_reminder to "成就提醒",
            R.string.settings_row_sound_vibration to "声音与震动",
            R.string.settings_row_keep_screen_on to "训练中屏幕常亮",
            R.string.settings_row_health_auth to "健康数据授权",
            R.string.settings_row_value_authorized to "已授权",
            R.string.settings_row_anonymous_data to "匿名使用数据",
            R.string.settings_row_version to "版本",
            R.string.settings_row_privacy to "隐私说明",
            R.string.settings_option_kg to "千克",
            R.string.settings_option_lbs to "磅",
            R.string.settings_option_zh to "简体中文",
            R.string.settings_option_en to "English",
            R.string.settings_option_monday to "周一",
            R.string.settings_option_sunday to "周日",
            R.string.settings_toast_health to "健康数据授权暂未接入系统平台",
            R.string.settings_toast_reminder_need_permission to "需要通知权限才能开启提醒",
            R.string.settings_sign_out to "退出登录",
            R.string.settings_sign_out_processing to "处理中…",
        )

        expectations.forEach { (id, expected) ->
            assertEquals("资源 id=$id 与原型中文不一致", expected, context.getString(id))
        }
    }

    /**
     * English 资源生效（`values-en/strings_settings.xml`）——方法级区域限定符覆盖类级 `zh-rCN`。
     * 取代表性几条：en 目录被识别、译文可取值、带参模板插值正确。
     */
    @Test
    @Config(sdk = [34], qualifiers = "en-rUS")
    fun `英文资源在 en 区域生效`() {
        assertEquals("Settings", context.getString(R.string.settings_title))
        assertEquals("Back to profile", context.getString(R.string.settings_a11y_back))
        assertEquals(
            "Workout reminder turned on",
            context.getString(
                R.string.settings_toast_switch_on,
                context.getString(R.string.settings_row_workout_reminder),
            ),
        )
    }

    /** 带参 toast：`{行标题}已切换为「{选项}」`——含「」标点，逐字断言。 */
    @Test
    fun `分段 toast 资源插值逐字`() {
        assertEquals(
            "体重单位已切换为「磅」",
            context.getString(R.string.settings_toast_segment, "体重单位", "磅"),
        )
    }

    /** 开关 toast：资源 ID 随开关态选择，插值后逐字对齐原型 L519 主句。 */
    @Test
    fun `开关 toast 资源随开关态选择且插值逐字`() {
        assertEquals(R.string.settings_toast_switch_on, FtSettingsModel.switchToastRes(on = true))
        assertEquals(R.string.settings_toast_switch_off, FtSettingsModel.switchToastRes(on = false))

        val label = context.getString(R.string.settings_row_workout_reminder)
        assertEquals("训练提醒已开启", context.getString(FtSettingsModel.switchToastRes(on = true), label))
        assertEquals("训练提醒已关闭", context.getString(FtSettingsModel.switchToastRes(on = false), label))
    }

    /** 静止态基线：分组标题 / 行标签 / 分段选项的资源指向正确（防资源 ID 串位）。 */
    @Test
    fun `静止态资源指向与原型行序一致`() {
        val sections = FtSettingsModel.SECTIONS

        assertEquals(
            listOf(
                R.string.settings_section_general,
                R.string.settings_section_data_privacy,
                R.string.settings_section_about,
            ),
            sections.map { it.titleRes },
        )
        assertEquals(R.string.settings_section_about_meta, sections[2].metaRes)
        assertEquals(R.string.settings_title, FtSettingsModel.TITLE_RES)
        assertEquals(R.string.settings_a11y_back, FtSettingsModel.BACK_A11Y_RES)
        assertEquals(R.string.settings_foot_note, FtSettingsModel.FOOT_NOTE_RES)

        assertEquals(R.string.settings_row_weight_unit, row(sections, FtSettingsModel.KEY_WEIGHT_UNIT).labelRes)
        assertEquals(
            listOf(R.string.settings_option_kg, R.string.settings_option_lbs),
            segment(sections, FtSettingsModel.KEY_WEIGHT_UNIT).options.map { it.labelRes },
        )
        assertEquals(
            listOf(R.string.settings_option_zh, R.string.settings_option_en),
            segment(sections, FtSettingsModel.KEY_LANGUAGE).options.map { it.labelRes },
        )
        assertEquals(
            listOf(R.string.settings_option_monday, R.string.settings_option_sunday),
            segment(sections, FtSettingsModel.KEY_WEEK_START).options.map { it.labelRes },
        )

        val healthRow = sections[1].rows.first { it.action == FtSettingsModel.ACTION_HEALTH }
        assertEquals(R.string.settings_row_health_auth, healthRow.labelRes)
        assertEquals(
            R.string.settings_row_value_authorized,
            (healthRow.trailing as FtSettingTrailing.ValueLink).textRes,
        )
    }

    @Test
    fun `版本行值取传入的 versionName`() {
        val sections = FtSettingsModel.sections(
            weightUnit = WeightUnit.KG,
            settings = FtSettings(),
            versionName = "9.9.9-test",
        )
        val versionRow = row(sections, FtSettingsModel.KEY_VERSION)
        assertEquals("9.9.9-test", (versionRow.trailing as FtSettingTrailing.Value).text)
    }
}
