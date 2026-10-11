package com.fittracker.app.ui.screens.settings

import android.Manifest
import android.content.ContentResolver
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.StringRes
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.fittracker.app.BuildConfig
import com.fittracker.app.R
import com.fittracker.app.data.auth.AuthService
import com.fittracker.app.data.model.UserDataBackupImportResult
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.FtSettings
import com.fittracker.app.data.service.SettingsLanguage
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.WeekStart
import com.fittracker.app.data.service.WeightUnit
import com.fittracker.app.data.service.backup.UserDataBackupService
import com.fittracker.app.notifications.ReminderScheduler
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 设置屏（原型 `design/06_prototype_redraw/src/fittracker-settings.html` 的
 * `data-od-id="screen-settings"` 帧，L364-472）。
 *
 * **画布 390×844 直绘**——`.phone { width:390px; height:844px }`（L139-142）、
 * `.st-frame { position:absolute; inset:0 }`（L165-170）。屏内按真实 dp 布局，
 * 缩放由 `FtCanvas` 依 `FtRoute.canvas` 施加，**屏内不写缩放**。无底栏（非 Tab 一级路由）。
 *
 * 版式来源（原型 CSS 行号）：
 * `.st-frame`/`.st-content` L165-173 · `.st-top`/`.st-back`/`.st-title`/`.st-top-spacer` L178-202 ·
 * `.st-scroll`/`.st-scroll-inner` L204-212 · `.sub-card`/`.sub-sec-head`/`.sub-sec-title`/`.sub-sec-meta` L213-221 ·
 * `.set-group`/`.set-row`/行分隔线 L223-235 · `.sr-label`/`.sr-value`/`.sr-chev`/`.sr-right` L236-240 ·
 * `.seg` L242-266 · `.switch` L268-293 · `.st-foot-note` L295 · 图标 `#i-back`/`#i-chevron` L341-348。
 *
 * 三处**以源码为准**的取舍：
 * 1. 样式表末尾「Card Surface v1」（L335-336）把 `.sub-card` 的底色与描边改写为
 *    `rgba(255,255,255,.031)` / `var(--line-10)`——按**末尾**规则实现。
 * 2. `.st-toast`（L298-317 / 默认文案 `已保存` L469）：屏底居中胶囊浮层（`bottom:30`），
 *    180ms 淡入 + 上移 10px，1900ms 后自动隐藏（脚本 L487-496）；形态对齐同仓
 *    `LibraryScreen` 的 `ScreenToast`。
 * 3. 行右侧的开关/分段/箭头现为**可交互**：分段取 [FtSettingsModel.sections] 按真实状态重算的
 *    `class="active"` 项，开关同理由互斥的 on 值重算；`.set-row` 的 `data-action`
 *    （`health` L430 / `privacy` L458）经 [FtSettingRow.action] 派发。
 *
 * 交互（原型脚本 L481-560，本轮全量接线）：
 * 1. 分段（体重单位 / 语言 / 周开始日）：点击切换 active → 持久化 → 回显；toast
 *    `{行标题}已切换为「{选项}」`（原型 L507 主句，已去演示后缀）。体重单位落 `UserProfileService`（资料域），
 *    语言 / 周开始日落 [SettingsService]。
 * 2. 开关（6 个）：点击 toggle → 持久化 → 回显；toast `{行标题}已开启/已关闭`（原型 L519 主句）。
 *    「训练数据同步」联动 `SyncOrchestrator.setAutoEnabled`（`autoEnabled` 单一真源），
 *    **开启前校验登录态**（未登录 toast「请先登录后再开启同步」，对齐鸿蒙 `toggleSyncRow`）。
 * 3. `data-action` 行：健康数据授权 toast 如实说明（Android 无对等数据源）；
 *    **隐私说明改为导航** `legal?kind=privacy`（对齐鸿蒙 pushUrl(LEGAL_DOC)）。
 * 4. 返回——`FT_APP.routes` 的 `['[data-action="back"]','profile']`（L560），发
 *    `onNavigate("profile")`（原型返回亦 toast「返回个人页（原型）」，但本侧随即离屏，省略）。
 *
 * V2（值照常持久化与回显；行为落地进度见《设置模块功能实现》计划）：语言的应用级切换
 * （字符串资源重载，Wave 6）、通知与屏幕常亮系统行为（Wave 3/4）、匿名数据上报（维持本地存储）。
 */
@Composable
fun SettingsScreen(
    onNavigate: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val store = remember { JsonStore(context.appDataStore) }

    var settings by remember { mutableStateOf(SettingsService.getDefaultSettings()) }
    var weightUnit by remember { mutableStateOf(WeightUnit.KG) }
    var toast by remember { mutableStateOf<SettingsToastState?>(null) }

    // 首帧读回真实偏好：体重单位取自 [UserProfileService]（资料域），
    // 其余分段 / 开关取自 [SettingsService]（「训练数据同步」由其委托 SyncOrchestrator）。
    LaunchedEffect(Unit) {
        weightUnit = UserProfileService.loadProfile(store).weightUnit
        settings = SettingsService.loadSettings(store)
        // 语言真源对齐：AppCompat per-app locale（可能经系统设置页修改）优先于本地存储回显
        val appLocales = AppCompatDelegate.getApplicationLocales()
        if (!appLocales.isEmpty) {
            val tag = appLocales.toLanguageTags()
            settings = settings.copy(
                language = if (tag.startsWith("en")) SettingsLanguage.EN else SettingsLanguage.ZH,
            )
        }
    }

    // 原型 `showToast` 的 `setTimeout(…, 1900)`（L488-495）
    LaunchedEffect(toast) {
        if (toast != null) {
            delay(1900)
            toast = null
        }
    }

    // ── W3-3 备份导出 / 导入 —— SAF 文件读写 ─────────────────────────────
    // 备份「包」即 [UserDataBackupService] 产出/消费的 JSON 字符串（schemaVersion=1，与鸿蒙
    // 备份包互通），故落地为 `.json` 文件（非 ZIP）。用户取消选择（uri=null）静默返回、不弹 toast。
    var pendingImportJson by remember { mutableStateOf<String?>(null) }

    // 导出：CreateDocument 建议文件名 → 用户选路径 → 写 UTF-8 JSON → 成功/失败 toast
    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument(BACKUP_MIME_TYPE),
    ) { uri: Uri? ->
        if (uri != null) {
            scope.launch {
                val message = try {
                    val json = UserDataBackupService.exportPackage(store)
                    if (writeBackupFile(context.contentResolver, uri, json)) {
                        context.getString(R.string.backup_export_success_status)
                    } else {
                        context.getString(R.string.backup_export_failure_status)
                    }
                } catch (error: Exception) {
                    context.getString(R.string.backup_export_failure_status)
                }
                toast = SettingsToastState.next(toast, message)
            }
        }
    }

    // 导入：OpenDocument 选文件 → 读 JSON → 覆盖确认 → 交服务导入 → 结果 toast
    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? ->
        if (uri != null) {
            scope.launch {
                val json = readBackupFile(context.contentResolver, uri)
                if (json == null) {
                    toast = SettingsToastState.next(toast, context.getString(R.string.settings_backup_read_failure))
                } else {
                    pendingImportJson = json // 待用户确认后再落库
                }
            }
        }
    }

    // 分段点击：值变化 + 持久化 + 回显（原型 L502-511）
    fun onSegmentSelect(row: FtSettingRow, index: Int, optionLabel: String) {
        when (row.key) {
            FtSettingsModel.KEY_WEIGHT_UNIT -> {
                val unit = if (index == 0) WeightUnit.KG else WeightUnit.LBS
                weightUnit = unit
                scope.launch { UserProfileService.saveWeightUnit(store, unit) }
            }

            FtSettingsModel.KEY_LANGUAGE -> {
                val language = if (index == 0) SettingsLanguage.ZH else SettingsLanguage.EN
                settings = settings.copy(language = language)
                scope.launch { SettingsService.setLanguage(store, language) } // 存储双写（备份互通）
                // 应用级切换（AppCompat per-app language；Activity 自动重建 → 字符串资源重载）
                AppCompatDelegate.setApplicationLocales(
                    LocaleListCompat.forLanguageTags(if (index == 0) "zh" else "en"),
                )
            }

            FtSettingsModel.KEY_WEEK_START -> {
                val weekStart = if (index == 0) WeekStart.MONDAY else WeekStart.SUNDAY
                settings = settings.copy(weekStart = weekStart)
                scope.launch { SettingsService.setWeekStart(store, weekStart) }
            }
        }
        toast = SettingsToastState.next(
            toast,
            context.getString(
                FtSettingsModel.TOAST_SEGMENT_RES,
                context.getString(row.labelRes),
                optionLabel,
            ),
        )
    }

    // ── W4：训练 / 成就提醒 —— 通知权限（Android 13+）与调度 ──────────────
    // 通知权限是否已具备（Android < 13 无运行时权限，恒为真）。
    fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    // 提醒开关落库 + 调度 + 回显——权限通过（或关闭）后调用；被拒时不写状态、开关回弹。
    fun applyReminderToggle(row: FtSettingRow, on: Boolean) {
        when (row.key) {
            FtSettingsModel.KEY_WORKOUT_REMINDER -> {
                settings = settings.copy(workoutReminder = on)
                scope.launch { SettingsService.setWorkoutReminder(store, on) }
                // 周期任务登记 / 取消（Worker 每次执行现读开关，故与落库的先后不影响判定）
                ReminderScheduler.syncWorkoutReminder(context, on)
            }

            FtSettingsModel.KEY_ACHIEVEMENT_REMINDER -> {
                settings = settings.copy(achievementReminder = on)
                scope.launch { SettingsService.setAchievementReminder(store, on) }
            }
        }
        toast = SettingsToastState.next(toast, context.getString(FtSettingsModel.switchToastRes(on), context.getString(row.labelRes)))
    }

    // 待授权的提醒行——launcher 回调只带授权结果，需记住是哪一行触发的。
    var pendingReminderRow by remember { mutableStateOf<FtSettingRow?>(null) }
    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted: Boolean ->
        val row = pendingReminderRow
        pendingReminderRow = null
        if (row != null) {
            if (granted) {
                applyReminderToggle(row, true)
            } else {
                // 拒绝：不写库、不登记调度、不改开关（回弹到真源值），只说明原因
                toast = SettingsToastState.next(
                    toast,
                    context.getString(R.string.settings_toast_reminder_need_permission),
                )
            }
        }
    }

    // 开关点击：toggle + 持久化 + 回显（原型 L514-523）
    fun onToggle(row: FtSettingRow, on: Boolean) {
        // 「训练数据同步」需登录态校验（对齐鸿蒙 SettingsContent.ets toggleSyncRow）——自管状态与 toast
        if (row.key == FtSettingsModel.KEY_DATA_SYNC) {
            scope.launch {
                if (FtSettingsModel.canToggleDataSync(enable = on, loggedIn = AuthService.currentSession(store) != null)) {
                    settings = settings.copy(dataSync = on)
                    SettingsService.setDataSync(store, on)
                    toast = SettingsToastState.next(toast, context.getString(FtSettingsModel.switchToastRes(on), context.getString(row.labelRes)))
                } else {
                    // 未登录：不改状态、不写库（开关回弹到真源值）
                    toast = SettingsToastState.next(toast, context.getString(FtSettingsModel.TOAST_SYNC_NEED_LOGIN_RES))
                }
            }
            return
        }
        // 「训练提醒 / 成就提醒」开启需通知权限（Android 13+）——自管状态与 toast（同 KEY_DATA_SYNC 先例）
        if (row.key == FtSettingsModel.KEY_WORKOUT_REMINDER ||
            row.key == FtSettingsModel.KEY_ACHIEVEMENT_REMINDER
        ) {
            if (!on || hasNotificationPermission()) {
                applyReminderToggle(row, on)
            } else {
                pendingReminderRow = row
                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
            return
        }
        when (row.key) {
            FtSettingsModel.KEY_SOUND_VIBRATION -> {
                settings = settings.copy(soundVibration = on)
                scope.launch { SettingsService.setSoundVibration(store, on) }
            }

            FtSettingsModel.KEY_KEEP_SCREEN_ON -> {
                settings = settings.copy(keepScreenOn = on)
                scope.launch { SettingsService.setKeepScreenOn(store, on) }
            }

            FtSettingsModel.KEY_ANONYMOUS_DATA -> {
                settings = settings.copy(anonymousData = on)
                scope.launch { SettingsService.setAnonymousData(store, on) }
            }
        }
        toast = SettingsToastState.next(toast, context.getString(FtSettingsModel.switchToastRes(on), context.getString(row.labelRes)))
    }

    // `data-action` 行（原型 L526-541）
    fun onAction(row: FtSettingRow) {
        when (row.action) {
            FtSettingsModel.ACTION_HEALTH -> toast = SettingsToastState.next(
                toast,
                context.getString(FtSettingsModel.TOAST_HEALTH_RES),
            )
            // 隐私说明 → 打开隐私政策页（对齐鸿蒙 pushUrl(LEGAL_DOC)；先例 LoginScreen.kt:229-230）
            FtSettingsModel.ACTION_PRIVACY -> onNavigate("legal?kind=privacy")
        }
    }

    val sections = FtSettingsModel.sections(weightUnit, settings, BuildConfig.VERSION_NAME)

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(FtColor.ink0), // `.st-frame` 底 var(--ink-0) = #0B0F13（L165-170）
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            SettingsTopBar(onBack = { onNavigate(FtSettingsModel.BACK_ROUTE) })

            // `.st-scroll` L204：`flex: 1 1 auto; overflow-y: auto`——转为 LazyColumn（纪律⑦）
            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                // `.st-scroll-inner { padding: 8px 16px 30px }`（L206-212）
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 30.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp), // `.st-scroll-inner { gap: 14px }`
            ) {
                items(sections) { section ->
                    SettingsSectionCard(
                        section = section,
                        onSegmentSelect = ::onSegmentSelect,
                        onToggle = ::onToggle,
                        onAction = ::onAction,
                    )
                }
                // 鸿蒙独有功能块（原型无此项）：账号与同步入口——对齐
                // `SettingsContent.ets` 的 `accountSyncRow`（L285-307）
                item { AccountSyncEntryCard(onOpen = { onNavigate("accountSync") }) }
                // W3-3：备份与恢复区块（导出 / 导入 → UserDataBackupService）
                item {
                    BackupRestoreCard(
                        onExport = { exportLauncher.launch(backupExportFileName(Date())) },
                        onImport = { importLauncher.launch(arrayOf("*/*")) },
                    )
                }
                item { FootNote() }
            }
        }

        // `.st-toast { bottom: 30px; left: 50% }`（L298-317）
        ScreenToast(
            message = toast?.text,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 30.dp),
        )

        // 导入覆盖确认（服务既定语义见 `backup_restore_rule`）
        pendingImportJson?.let { json ->
            AlertDialog(
                onDismissRequest = { pendingImportJson = null },
                title = { Text(stringResource(R.string.settings_action_import_backup)) },
                text = { Text(stringResource(R.string.backup_restore_rule)) },
                confirmButton = {
                    TextButton(
                        onClick = {
                            pendingImportJson = null
                            scope.launch {
                                val message = try {
                                    backupImportStatusText(
                                        context,
                                        UserDataBackupService.importPackage(store, json),
                                    )
                                } catch (error: Exception) {
                                    context.getString(R.string.settings_backup_read_failure)
                                }
                                toast = SettingsToastState.next(toast, message)
                            }
                        },
                    ) { Text(stringResource(R.string.settings_action_import)) }
                },
                dismissButton = {
                    TextButton(onClick = { pendingImportJson = null }) { Text(stringResource(R.string.settings_action_cancel)) }
                },
            )
        }
    }
}

// ── 顶栏 ──────────────────────────────────────────────────────────────────

/**
 * `.st-top` L178-202：`50/16/12` 内边距、`gap:10px`；44px 圆形返回键 +
 * 居中标题（`flex:1 1 auto`）+ 44px 对称占位（`.st-top-spacer`）。
 */
@Composable
private fun SettingsTopBar(onBack: () -> Unit) {
    // `stringResource` 只能在 @Composable 上下文调用，`.semantics {}` lambda 不是——先解析再闭包捕获
    val backA11y = stringResource(FtSettingsModel.BACK_A11Y_RES)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 16.dp, top = 50.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            modifier = Modifier
                .size(44.dp) // `.st-back { width: 44px; height: 44px }`（L185-190）
                .clip(FtShape.pill) // border-radius: 50%
                .background(BackBtnFill) // rgba(255,255,255,.047)
                .border(1.dp, FtColor.glass8, FtShape.pill) // 1px rgba(255,255,255,.08)
                .semantics { contentDescription = backA11y } // aria-label（L374）
                .clickableNoRipple(onClick = onBack),
            contentAlignment = Alignment.Center,
        ) {
            BackIcon(modifier = Modifier.size(20.dp), color = FtColor.white70) // `.st-back svg` 20×20（L198）
        }

        Text(
            text = stringResource(FtSettingsModel.TITLE_RES),
            modifier = Modifier.weight(1f), // `.st-title { flex: 1 1 auto }`（L201）
            style = FtType.natural(18f, 700), // 18px/700；未声明 line-height → natural
            color = FtColor.txtHi,
            textAlign = TextAlign.Center, // `text-align: center`
        )

        Spacer(modifier = Modifier.width(44.dp)) // `.st-top-spacer { width: 44px }`（L202）
    }
}

// ── 分组卡片 ──────────────────────────────────────────────────────────────

/** `.sub-card` L213-221：圆角 22、`16px` 内边距；底色与描边取末尾覆盖层（L335-336）。 */
@Composable
private fun SettingsSectionCard(
    section: FtSettingsSection,
    onSegmentSelect: (FtSettingRow, Int, String) -> Unit,
    onToggle: (FtSettingRow, Boolean) -> Unit,
    onAction: (FtSettingRow) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(FtShape.panel) // border-radius: 22px
            .background(CardFill) // rgba(255,255,255,.031)（L336）
            .border(1.dp, FtColor.line10, FtShape.panel) // var(--line-10)（L336）
            .padding(16.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 4.dp), // `.sub-sec-head { margin-bottom: 4px }`（L219）
            horizontalArrangement = Arrangement.SpaceBetween, // justify-content: space-between
        ) {
            Text(
                text = stringResource(section.titleRes),
                modifier = Modifier.alignByBaseline(), // align-items: baseline
                style = FtType.natural(15f, 700), // `.sub-sec-title` 15px/700（L220）
                color = FtColor.txtHi,
            )
            val metaRes = section.metaRes
            if (metaRes != null) {
                Text(
                    text = stringResource(metaRes),
                    modifier = Modifier.alignByBaseline(),
                    style = FtType.natural(11f), // `.sub-sec-meta` 11px（L221）
                    color = FtColor.white62,
                )
            }
        }

        section.rows.forEachIndexed { index, row ->
            // `.set-row + .set-row { border-top: 1px solid var(--hairline) }`（L232）
            if (index > 0) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(FtColor.hairline),
                )
            }
            SettingsRowView(
                row = row,
                onSegmentSelect = onSegmentSelect,
                onToggle = onToggle,
                onAction = onAction,
            )
        }
    }
}

/**
 * 鸿蒙独有入口卡：账号与同步（对齐 `SettingsContent.ets:285-307` 的 `accountSyncRow`；
 * 原型 `fittracker-settings.html` 无此功能块）。形态贴近 `.set-row`：14px 标签 + 右箭头。
 */
@Composable
private fun AccountSyncEntryCard(onOpen: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(FtShape.panel) // `.sub-card` 圆角 22
            .background(CardFill)
            .border(1.dp, FtColor.line10, FtShape.panel)
            .clickableNoRipple(onClick = onOpen)
            .padding(horizontal = 18.dp, vertical = 15.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = stringResource(R.string.settings_row_account_sync),
            style = FtType.natural(14f),
            color = FtColor.txtHi,
        )
        ChevronIcon(modifier = Modifier.size(18.dp), color = FtColor.white40)
    }
}

/** 一行设置 `.set-row` L224-240：左右两端对齐、`padding: 15px 2px`。 */
@Composable
private fun SettingsRowView(
    row: FtSettingRow,
    onSegmentSelect: (FtSettingRow, Int, String) -> Unit,
    onToggle: (FtSettingRow, Boolean) -> Unit,
    onAction: (FtSettingRow) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            // `<button class="set-row">`（`data-action` 行）可点击；纯 `<div class="set-row">` 不可（L430/L458）
            .then(
                if (row.action != null) Modifier.clickableNoRipple { onAction(row) } else Modifier,
            )
            .padding(vertical = 15.dp, horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically, // align-items: center
        horizontalArrangement = Arrangement.SpaceBetween, // justify-content: space-between
    ) {
        Text(
            text = stringResource(row.labelRes),
            style = FtType.natural(14f), // `.sr-label` 14px；未声明 line-height（L236）
            color = FtColor.txtHi,
        )

        when (val trailing = row.trailing) {
            is FtSettingTrailing.Segment -> SegControl(
                options = trailing.options,
                onSelect = { index, label -> onSegmentSelect(row, index, label) },
            )

            is FtSettingTrailing.Switch -> SwitchControl(
                on = trailing.on,
                label = stringResource(row.labelRes),
                onToggle = { onToggle(row, !trailing.on) },
            )

            is FtSettingTrailing.Value -> ValueText(trailing.text)
            is FtSettingTrailing.ValueLink -> ValueLinkRow(stringResource(trailing.textRes))
            FtSettingTrailing.Link -> ChevronIcon(modifier = Modifier.size(18.dp), color = FtColor.white40)
        }
    }
}

// ── 右侧控件 ──────────────────────────────────────────────────────────────

/**
 * `.seg` L242-266：圆角 12、内边距 3、`rgba(255,255,255,.06)` 底 + `var(--line-10)` 描边、
 * `gap:2px`。按钮 30 高、`0 16px` 内边距、圆角 9、12.5px/600；`.active` 走翡翠底 + `--on-accent` 字。
 */
@Composable
private fun SegControl(options: List<FtSegOption>, onSelect: (Int, String) -> Unit) {
    Row(
        modifier = Modifier
            .clip(FtShape.md) // border-radius: 12px
            .background(FtColor.glass6) // rgba(255,255,255,.06)
            .border(1.dp, FtColor.line10, FtShape.md)
            .padding(3.dp), // `.seg { padding: 3px }`
        horizontalArrangement = Arrangement.spacedBy(2.dp), // `.seg { gap: 2px }`
        verticalAlignment = Alignment.CenterVertically,
    ) {
        options.forEachIndexed { index, option ->
            val optionLabel = stringResource(option.labelRes) // 供 Text 与点击回调复用（`onSelect` 非 @Composable）
            Box(
                modifier = Modifier
                    .height(30.dp) // `.seg button { height: 30px }`（L251-263）
                    .clip(FtShape.s) // border-radius: 9px
                    .background(if (option.active) FtColor.accent else Color.Transparent) // `.active`（L265）
                    .clickableNoRipple { onSelect(index, optionLabel) }
                    .padding(horizontal = 16.dp), // `.seg button { padding: 0 16px }`
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = optionLabel,
                    style = FtType.natural(12.5f, 600), // `.seg button` 12.5px/600；未声明 line-height
                    color = if (option.active) FtColor.onAccent else FtColor.white62, // L265 / L251-263
                )
            }
        }
    }
}

/**
 * `.switch` L268-293：46×28 胶囊，底 `rgba(255,255,255,.12)`、描边 `var(--line-10)`；
 * `.on` 时底/描边均走翡翠（L292）。旋钮 22×22、`top/left: 2px`（L281-291），
 * `.on` 时 `translateX(18px)`（L293）且换成 `var(--on-accent)`。
 */
@Composable
private fun SwitchControl(on: Boolean, label: String, onToggle: () -> Unit) {
    Box(
        modifier = Modifier
            .size(width = 46.dp, height = 28.dp)
            .clip(FtShape.pill) // border-radius: 999px
            .background(if (on) FtColor.accent else SwitchOffFill)
            .border(1.dp, if (on) FtColor.accent else FtColor.line10, FtShape.pill) // L268-278 / L292
            .semantics { contentDescription = label } // 原型 `aria-label`（L410 等）＝行标题
            .clickableNoRipple { onToggle() },
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.TopStart)
                // `left: 2px`（L281-291）+ `.on` 的 `translateX(18px)`（L293）→ 2 / 20
                .offset(x = if (on) 20.dp else 2.dp, y = 2.dp)
                .size(22.dp) // `.switch::after { width/height: 22px }`
                .clip(FtShape.pill)
                .background(if (on) FtColor.onAccent else Color.White), // `.switch.on::after`（L293）
        )
    }
}

/** `.sr-value` L237：12.5px、`--white-54`；未声明 line-height。 */
@Composable
private fun ValueText(text: String) {
    Text(
        text = text,
        style = FtType.natural(12.5f),
        color = FtColor.white54,
    )
}

/** `.sr-right` L240：`[.sr-value, .sr-chev]`、`gap: 6px`、`flex: 0 0 auto`。 */
@Composable
private fun ValueLinkRow(text: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        ValueText(text)
        ChevronIcon(modifier = Modifier.size(18.dp), color = FtColor.white40) // `.sr-chev` 18×18（L238）
    }
}

/** `.st-foot-note` L295：`padding: 2px 6px 0`、11px、`--white-54`、`line-height: 1.6`。 */
@Composable
private fun FootNote() {
    Text(
        text = stringResource(FtSettingsModel.FOOT_NOTE_RES),
        modifier = Modifier.padding(start = 6.dp, end = 6.dp, top = 2.dp),
        style = FtType.ft(11f, 400, 17.6f), // 11px × 1.6 = 17.6px 行高（原型显式声明）
        color = FtColor.white54,
    )
}

// ── 图标（路径逐字取自本文件的 `<symbol>`，L341-348） ──────────────────────

private const val ICON_VIEW = 24f

/** 返回（`#i-back`，L342-344）：`M15.5 5 8.5 12l7 7`，描边 1.8、圆头圆角。 */
@Composable
private fun BackIcon(modifier: Modifier = Modifier, color: Color = FtColor.white70) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val p = Path().apply {
            moveTo(15.5f * k, 5f * k)
            lineTo(8.5f * k, 12f * k)
            lineTo(15.5f * k, 19f * k)
        }
        drawPath(p, color, style = Stroke(1.8f * k, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

/** 右箭头（`#i-chevron`，L345-347）：`M9 6.5 15 12l-6 5.5`，描边 1.8、圆头圆角。 */
@Composable
private fun ChevronIcon(modifier: Modifier = Modifier, color: Color = FtColor.white40) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val p = Path().apply {
            moveTo(9f * k, 6.5f * k)
            lineTo(15f * k, 12f * k)
            lineTo(9f * k, 17.5f * k)
        }
        drawPath(p, color, style = Stroke(1.8f * k, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

// ── 局部色值（原型值无对应全局令牌，或需按末尾规则覆盖） ──────────────────

/**
 * `.sub-card` 的统一底色（末尾覆盖层 L335-336）：`rgba(255,255,255,.031)`。
 * `AA = round(.031 × 255) = round(7.905) = 8 = 0x08` → `0x08FFFFFF`。
 */
private val CardFill = Color(0x08FFFFFF)

/**
 * `.st-back` 底 `rgba(255,255,255,.047)`（L185-190）。
 * `AA = round(.047 × 255) = round(11.985) = 12 = 0x0C` → `0x0CFFFFFF`。
 */
private val BackBtnFill = Color(0x0CFFFFFF)

/**
 * `.switch` 关态底 `rgba(255,255,255,.12)`（L268-278）。
 * `AA = round(.12 × 255) = round(30.6) = 31 = 0x1F` → `0x1FFFFFFF`。
 */
private val SwitchOffFill = Color(0x1FFFFFFF)

// ── 浮层提示 ──────────────────────────────────────────────────────────────

/**
 * `.st-toast` L298-317：底部居中胶囊，180ms 淡入 + 上移 10px；文本 13px / `line-height: 1.4`。
 * 形态对齐同仓 `LibraryScreen` 的 `ScreenToast`。
 */
@Composable
private fun ScreenToast(message: String?, modifier: Modifier = Modifier) {
    var shown by remember { mutableStateOf("") }
    if (message != null && message != shown) {
        shown = message
    }
    // 原型 `translateY(10px)`：入出场位移固定 10px，须在 Density 作用域内换算为 px
    val slideOffset = with(LocalDensity.current) { 10.dp.roundToPx() }
    androidx.compose.animation.AnimatedVisibility(
        visible = message != null,
        modifier = modifier,
        enter = androidx.compose.animation.fadeIn(
            androidx.compose.animation.core.tween(180),
        ) + androidx.compose.animation.slideInVertically(
            androidx.compose.animation.core.tween(180),
        ) { slideOffset },
        exit = androidx.compose.animation.fadeOut(
            androidx.compose.animation.core.tween(180),
        ) + androidx.compose.animation.slideOutVertically(
            androidx.compose.animation.core.tween(180),
        ) { slideOffset },
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 320.dp)
                .clip(FtShape.pill)
                .background(ToastFill) // rgba(13,17,23,.94)
                .border(1.dp, FtColor.line10, FtShape.pill)
                .padding(horizontal = 16.dp, vertical = 10.dp), // `padding: 10px 16px`
        ) {
            Text(
                text = shown,
                style = FtType.natural(13f).copy(lineHeight = 18.2.sp), // 1.4 × 13px（原型显式声明）
                color = FtColor.txtHi,
                textAlign = TextAlign.Center,
            )
        }
    }
}

/** `.st-toast` 底 `rgba(13,17,23,.94)` → round(239.7) = 240 = 0xF0 → `0xF00D1117`。 */
private val ToastFill = Color(0xF00D1117)

/**
 * 浮层消息的携带序号（对齐 `FtScreens.kt` 的 `AuthToastState`）。
 *
 * `LaunchedEffect(toast)` 以**实例**为键：若两次连发同一文案（或 `String?` 值相等）而键不变，
 * 协程不重启、浮层续不足计时（原型每次 `showToast` 都 `clearTimeout` 后重设）。以自增 [seq]
 * 区分每次触发，使同文案连发也能重新计时。
 */
private data class SettingsToastState(val seq: Int, val text: String) {
    companion object {
        fun next(current: SettingsToastState?, text: String): SettingsToastState =
            SettingsToastState((current?.seq ?: -1) + 1, text)
    }
}

// ── W3-3 备份与恢复 ──────────────────────────────────────────────────────

/**
 * 备份与恢复区块——形态对齐 `.sub-card`（标题 15px/700）+ `.set-row`（两行 14px + 右箭头）。
 * 两行均为动作行：导出 / 导入经 SAF 文件选择器，实际读写与业务由 [UserDataBackupService] 承担。
 */
@Composable
private fun BackupRestoreCard(onExport: () -> Unit, onImport: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(FtShape.panel) // `.sub-card` 圆角 22
            .background(CardFill) // rgba(255,255,255,.031)
            .border(1.dp, FtColor.line10, FtShape.panel)
            .padding(16.dp),
    ) {
        Text(
            text = stringResource(R.string.settings_section_backup),
            modifier = Modifier.padding(bottom = 4.dp), // `.sub-sec-head { margin-bottom: 4px }`
            style = FtType.natural(15f, 700), // `.sub-sec-title` 15px/700
            color = FtColor.txtHi,
        )
        BackupActionRow(labelRes = R.string.settings_action_export_backup, onClick = onExport)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(FtColor.hairline), // `.set-row + .set-row` 分隔线
        )
        BackupActionRow(labelRes = R.string.settings_action_import_backup, onClick = onImport)
    }
}

/** 备份区块的一行动作（对齐 `.set-row`：`padding: 15px 2px`、14px 标签 + 18px 右箭头）。 */
@Composable
private fun BackupActionRow(@StringRes labelRes: Int, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickableNoRipple(onClick = onClick)
            .padding(vertical = 15.dp, horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = stringResource(labelRes),
            style = FtType.natural(14f), // `.sr-label` 14px
            color = FtColor.txtHi,
        )
        ChevronIcon(modifier = Modifier.size(18.dp), color = FtColor.white40)
    }
}

/** 建议文件名：`fittracker-backup-YYYYMMDD.json`（备份「包」为 JSON，见 [UserDataBackupService]）。 */
private fun backupExportFileName(date: Date): String =
    "fittracker-backup-" + SimpleDateFormat("yyyyMMdd", Locale.US).format(date) + ".json"

/** 把备份 JSON 写入 SAF 目标 uri；任一步失败返回 `false`（含 `openOutputStream` 为 null）。 */
private fun writeBackupFile(resolver: ContentResolver, uri: Uri, content: String): Boolean = try {
    resolver.openOutputStream(uri)?.use { it.write(content.toByteArray(Charsets.UTF_8)) } != null
} catch (error: Exception) {
    false
}

/** 从 SAF 源 uri 读取备份 JSON；读取失败返回 `null`。 */
private fun readBackupFile(resolver: ContentResolver, uri: Uri): String? = try {
    resolver.openInputStream(uri)?.use { it.readBytes().toString(Charsets.UTF_8) }
} catch (error: Exception) {
    null
}

/** W3-3 常量（备份「包」为 JSON，故 MIME 取 `application/json`、扩展名 `.json`）；文案见 `values/strings_settings.xml`。 */
private const val BACKUP_MIME_TYPE = "application/json"

/**
 * 把导入结果渲染为用户可见文案（Wave 8 i18n：文案真源在 `values/strings_backup.xml`，
 * data 层 [UserDataBackupService] 不再持有 `Context` 与文案）。
 *
 * 失败：按 `statusId` 二分（[UserDataBackupService.importFailureStatusRes]）；
 * 成功：主句（含计数）+ 计划回退分支追加——源 `:314-321` 逐字对齐（子句间以空格相连）。
 */
internal fun backupImportStatusText(context: Context, result: UserDataBackupImportResult): String {
    if (!result.success) {
        return context.getString(UserDataBackupService.importFailureStatusRes(result.statusId))
    }
    val baseText: String = context.getString(
        R.string.backup_import_success,
        result.importedPlanCount,
        result.mergedSessionCount,
    )
    if (!result.usedPlanFallback) {
        return baseText
    }
    val fallbackRes: Int = if (result.effectiveCurrentPlanId.isNotEmpty()) {
        R.string.backup_import_success_fallback_plan
    } else {
        R.string.backup_import_success_plan_cleared
    }
    return "$baseText ${context.getString(fallbackRes)}"
}

