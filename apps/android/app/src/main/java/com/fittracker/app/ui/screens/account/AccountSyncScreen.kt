package com.fittracker.app.ui.screens.account

import android.content.Context
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
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
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.data.auth.AuthService
import com.fittracker.app.data.auth.AuthSession
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.sync.SyncOrchestrator
import com.fittracker.app.data.sync.SyncState
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 账号与同步屏（规格源：鸿蒙 `features/account/pages/AccountSyncPage.ets`，513 行——无原型 HTML 帧，逐值移植）。
 *
 * 390×844 直绘（路由 `accountSync` 的 `canvas` = `Direct`），画布由 `FtCanvas` 施加；
 * 本文件 px 值 1:1 映射为 dp（源页数值为页面内联字面量，非 CSS px）。无底栏（非 Tab 一级路由）。
 *
 * 版式来源（源文件行号）：
 * `buildTopBar()` L235-276 · `buildAccountCard()` L278-334 · `buildSyncCard()` L335-446 ·
 * `buildSignOutButton()` L447-464 · `build()` L465-512。
 * 返回图标取自 `rawfile/pencil-plan-nav-chevron-left.svg`（`M15 5 L8 12 L15 19`，描边 2、圆头圆角）。
 *
 * 三处**以源码为准**的取舍：
 * 1. **数据与交互已接线**（Wave 6 收口）：屏内读 `AuthService.currentSession` + `SyncOrchestrator.getState`
 *    （源 `refreshState` L67-83）；「立即同步」接 `SyncOrchestrator.syncNow`、「自动同步」接
 *    `setAutoEnabled`、退出登录接 `resetMeta` + `AuthService.signOut`（源 `performSignOut` L223-232）。
 *    结果 toast 已渲染（见 [SyncToast]）。[AccountSyncUiState.Companion.sample] 保留为首帧占位。
 * 2. 源页 L426-435 的「隔离探针（临时）」按钮**未移植**——源注释（L176-177）明示其为行级隔离
 *    实测的临时代码、验证后删除；且其中 `probeQueryByUser` 硬编码了测试 userId。
 * 3. 源页 L491-511 的底部浮层 `.toast` 已按源样式渲染（[SyncToast]）：`#F00D1117` 底 +
 *    `#1AFFFFFF` 描边 + 999 圆角 + 13px / 行高 18 + `bottom: 30`。触发点对齐源 `showToast`
 *    （L135-145，1800ms 自动隐藏）：同步结果取 `SyncResult.message`（L158）、自动同步开合取
 *    「已开启自动同步 / 已关闭自动同步」（L170）。退出登录不弹（源 `performSignOut` 直接跳转）。
 *
 * 交互与返回：
 * - 顶栏返回（源 L237-249 的 44px 圆形键，`onClick` → `router.back()`，L261）汇入 [onBack]；
 *   系统返回一并经 [BackHandler] 走 [onBack]，屏的返回自包含。
 * - [onNavigate] 为既定的路由出口，本波无静止态可触发（退出登录的 `router.clear()` + 登录页跳转
 *   属 `performSignOut` L223-232 的数据/栈逻辑），留给主会话接线。
 */
@Composable
fun AccountSyncScreen(
    onNavigate: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val resources = LocalResources.current
    val store = remember { JsonStore(context.appDataStore) }
    val scope = rememberCoroutineScope()
    val sandboxDir = remember { SyncOrchestrator.forFilesDir(context.filesDir) }

    var uiState by remember { mutableStateOf(AccountSyncUiState.sample(context)) }
    var syncing by remember { mutableStateOf(false) }
    // 结果浮层文案（源 `showToast` L135-145）
    var toast by remember { mutableStateOf<SyncToastState?>(null) }

    // 源 `showToast`：1800ms 后自动隐藏
    LaunchedEffect(toast) {
        if (toast != null) {
            delay(1800)
            toast = null
        }
    }

    // 读真实态（源 `refreshState` L67-83：会话 + 同步状态 → 展示字段）。
    suspend fun refresh() {
        val session: AuthSession? = AuthService.currentSession(store)
        val state: SyncState = SyncOrchestrator.getState(store)
        uiState = accountSyncUiState(context, session, state)
            .copy(syncing = syncing, signingOut = uiState.signingOut)
    }
    LaunchedEffect(Unit) { refresh() }

    // 源页返回键（L261 `router.back()`）+ 系统返回统一走 onBack。
    BackHandler(enabled = true, onBack = onBack)

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(FtColor.ink0), // 源 L512 backgroundColor('#0B0F13') = ink-0
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            AccountSyncTopBar(onBack = onBack)

            // 源 L469 `Scroll()` + L483-488 `.layoutWeight(1)`：滚动区占满剩余高度。
            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        // 源 L481-482 `.padding({ top: 8, left: 16, right: 16, bottom: 30 })`
                        .padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 30.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp), // 源 L470 Column({ space: 14 })
                ) {
                    AccountCard(state = uiState)
                    SyncCard(
                        state = uiState,
                        onSyncNow = {
                            if (!syncing) {
                                scope.launch {
                                    syncing = true
                                    uiState = uiState.copy(syncing = true)
                                    // 源 `syncNow` L146-159：结果文案直接取 `SyncResult.message`
                                    val result = SyncOrchestrator.syncNow(store, sandboxDir)
                                    syncing = false
                                    refresh()
                                    toast = SyncToastState.next(toast, result.message) // 源 L158 `showToast(result.message)`
                                }
                            }
                        },
                        onToggleAutoSync = { next ->
                            uiState = uiState.copy(autoEnabled = next) // 本地回显开合（源 L164-169）
                            scope.launch {
                                SyncOrchestrator.setAutoEnabled(store, next)
                                refresh()
                                // 源 L170 `showToast(next ? '已开启自动同步' : '已关闭自动同步')`
                                toast = SyncToastState.next(
                                    toast,
                                    if (next) resources.getString(R.string.account_toast_auto_on)
                                    else resources.getString(R.string.account_toast_auto_off),
                                )
                            }
                        },
                    )
                    SignOutButton(
                        signingOut = uiState.signingOut,
                        onClick = {
                            scope.launch {
                                uiState = uiState.copy(signingOut = true)
                                // 源 `performSignOut` L223-232：重置同步元数据（防切换串账）→ 清会话 → 回登录页
                                SyncOrchestrator.resetMeta(store)
                                AuthService.signOut(store)
                                onNavigate("login")
                            }
                        },
                    )
                    SyncScopeNote()
                }
            }
        }

        // 源 L491-511 的底部浮层 `.toast`：`bottom: 30`、居中胶囊
        SyncToast(
            message = toast?.text,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 30.dp),
        )
    }
}

// ── 顶栏 ──────────────────────────────────────────────────────────────────

/**
 * `.buildTopBar()` L235-276：`gap:10px`；44px 圆形返回键（底 `#0CFFFFFF` + 描边 `#14FFFFFF`）+
 * 居中标题（`layoutWeight(1)`）+ 44px 对称占位。
 */
@Composable
private fun AccountSyncTopBar(onBack: () -> Unit) {
    val backA11y = stringResource(R.string.account_a11y_back)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            // 源 L274：`padding({ top: Math.max(50 - topInsetVp, 0), bottom: 12, left: 16, right: 16 })`
            // 直绘画布自屏幕顶起算，故顶距取满 50（同 `SettingsScreen` 口径）
            .padding(start = 16.dp, end = 16.dp, top = 50.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically, // 源 L275 VerticalAlign.Center
        horizontalArrangement = Arrangement.spacedBy(10.dp), // 源 L237 Row({ space: 10 })
    ) {
        Box(
            modifier = Modifier
                .size(44.dp) // 源 L244-245
                .clip(FtShape.pill) // 源 L246 borderRadius(22)
                .background(BackBtnFill) // 源 L247 '#0CFFFFFF'
                .border(1.dp, FtColor.line14, FtShape.pill) // 源 L248 '#14FFFFFF'
                // 源页该 Image 无 aria-label，此处补无障碍标签（非视觉字符串）
                .semantics { contentDescription = backA11y }
                .clickableNoRipple(onClick = onBack),
            contentAlignment = Alignment.Center, // 源 L249 FlexAlign.Center
        ) {
            ChevronLeftIcon(modifier = Modifier.size(20.dp)) // 源 L240-241：20×20、opacity 0.7
        }

        Text(
            text = stringResource(R.string.account_title), // 源 L262
            modifier = Modifier.weight(1f), // 源 L267 layoutWeight(1)
            style = FtType.natural(18f, 700), // 源 L264-265：18px / Bold（未声明行高）
            color = FtColor.txtHi, // 源 L266 '#F7FBF8'
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.width(44.dp)) // 源 L269-271 右侧同宽占位
    }
}

// ── 账号状态卡 ────────────────────────────────────────────────────────────

/** `buildAccountCard()` L278-334：52px 字母头像 + 姓名/账号 + `provider` 胶囊。 */
@Composable
private fun AccountCard(state: AccountSyncUiState) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(FtShape.panel) // 源 L332 borderRadius(22)
            .background(CardFill) // 源 L330 '#08FFFFFF'
            .border(1.dp, FtColor.line10, FtShape.panel) // 源 L331 '#1AFFFFFF'
            .padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 16.dp), // 源 L329
        verticalAlignment = Alignment.CenterVertically, // 源 L326 VerticalAlign.Center
        horizontalArrangement = Arrangement.spacedBy(12.dp), // 源 L281 Row({ space: 12 })
    ) {
        AvatarLetter(text = state.displayName)

        Column(
            modifier = Modifier.weight(1f), // 源 L312 layoutWeight(1)
            verticalArrangement = Arrangement.spacedBy(5.dp), // 源 L297 Column({ space: 5 })
            horizontalAlignment = Alignment.Start, // 源 L313 HorizontalAlign.Start
        ) {
            Text(
                text = state.displayName,
                style = FtType.natural(18f, 700), // 源 L300-301：18px / Bold
                color = FtColor.txtHi, // 源 L302 '#F7FBF8'
                maxLines = 1, // 源 L303
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = state.accountText,
                style = FtType.natural(12.5f), // 源 L307：12.5px
                color = FtColor.white62, // 源 L308 '#9EFFFFFF'
                maxLines = 1, // 源 L309
                overflow = TextOverflow.Ellipsis,
            )
        }

        if (state.providerLabel.isNotEmpty()) { // 源 L314 if 分支
            ProviderPill(label = state.providerLabel)
        }
    }
}

/** 字母头像（源 L282-296）：52px 圆、`#1A50ECA7` 底 + `#4D50ECA7` 描边，首字 22px/700/Inter。 */
@Composable
private fun AvatarLetter(text: String) {
    Box(
        modifier = Modifier
            .size(52.dp) // 源 L284-285 / L295-296
            .clip(FtShape.pill) // 源 L286 borderRadius(26)
            .background(FtColor.accent10) // 源 L287 '#1A50ECA7' = accent 10%
            .border(1.dp, AvatarRing, FtShape.pill), // 源 L288 '#4D50ECA7'
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text.take(1).ifEmpty { stringResource(R.string.account_avatar_fallback) }, // 源 L289：displayName 首字，空则 '训'
            style = FtType.natural(22f, 700, FtType.num), // 源 L291-292：22px / Bold / Inter
            color = FtColor.accent, // 源 L293 '#50ECA7'
        )
    }
}

/** `provider` 胶囊（源 L315-322）：11px/500、`#50ECA7` 字、`#1A50ECA7` 底、999 圆角。 */
@Composable
private fun ProviderPill(label: String) {
    Text(
        text = label,
        modifier = Modifier
            .clip(FtShape.pill) // 源 L322 borderRadius(999)
            .background(FtColor.accent10) // 源 L321 '#1A50ECA7'
            .padding(horizontal = 10.dp, vertical = 5.dp), // 源 L320
        style = FtType.natural(11f, 500), // 源 L317-318：11px / Medium
        color = FtColor.accent, // 源 L319 '#50ECA7'
    )
}

// ── 同步操作卡 ────────────────────────────────────────────────────────────

/** `buildSyncCard()` L335-446：同步状态 / 上次同步 / 自动同步开关 / 立即同步按钮。 */
@Composable
private fun SyncCard(
    state: AccountSyncUiState,
    onSyncNow: () -> Unit,
    onToggleAutoSync: (Boolean) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(FtShape.panel) // 源 L444 borderRadius(22)
            .background(CardFill) // 源 L442 '#08FFFFFF'
            .border(1.dp, FtColor.line10, FtShape.panel) // 源 L443 '#1AFFFFFF'
            .padding(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 16.dp), // 源 L441
    ) {
        // 同步状态（源 L338-351）
        SyncRow {
            RowLabel(stringResource(R.string.account_sync_status_label))
            Spacer(modifier = Modifier.weight(1f)) // 源 L343 Blank()
            Text(
                text = state.syncStatusText,
                style = FtType.natural(13f, 500), // 源 L346-347：13px / Medium
                // 源 L348：'同步失败' → '#D77C78'，否则 '#50ECA7'
                color = if (state.syncFailed) DangerColor else FtColor.accent,
            )
        }

        if (state.syncDetailText.isNotEmpty()) { // 源 L353 if 分支
            Text(
                text = state.syncDetailText,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 2.dp, end = 2.dp, bottom = 12.dp), // 源 L359
                style = FtType.natural(11.5f), // 源 L356：11.5px
                color = DangerColor, // 源 L357 '#D77C78'
            )
        }

        RowDivider() // 源 L375 border-top '#0FFFFFFF'

        // 上次同步（源 L362-374）
        SyncRow {
            RowLabel(stringResource(R.string.account_last_sync_label))
            Spacer(modifier = Modifier.weight(1f)) // 源 L367 Blank()
            Text(
                text = state.lastSyncText,
                style = FtType.natural(12.5f), // 源 L370：12.5px
                color = FtColor.white54, // 源 L371 '#8AFFFFFF'
            )
        }

        RowDivider() // 源 L407 border-top '#0FFFFFFF'

        // 自动同步（源 L377-407）
        SyncRow {
            RowLabel(stringResource(R.string.account_auto_sync_label))
            Spacer(modifier = Modifier.weight(1f)) // 源 L382 Blank()
            AutoSyncSwitch(on = state.autoEnabled, onToggle = onToggleAutoSync)
        }

        // 立即同步（源 L409-424）
        PrimaryActionButton(
            text = if (state.syncing) stringResource(R.string.account_status_syncing) else stringResource(R.string.account_sync_now), // 源 L409
            enabled = !state.syncing, // 源 L422 enabled(!syncing)
            onClick = onSyncNow, // 已接线：屏内 onSyncNow 走 SyncOrchestrator.syncNow + 结果 toast（源 L146-159）
        )
    }
}

/** 同步卡内一行（源用 `Row() { … }.width('100%').padding({ top: 15, bottom: 15, left: 2, right: 2 })`）。 */
@Composable
private fun SyncRow(content: @Composable RowScope.() -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 2.dp, vertical = 15.dp), // 源 L351 / L374 / L406
        verticalAlignment = Alignment.CenterVertically,
    ) {
        content()
    }
}

/** 行标签：14px、`--txt-hi`（源 L341-342 / L365-366 / L380-381）。 */
@Composable
private fun RowLabel(text: String) {
    Text(
        text = text,
        style = FtType.natural(14f), // 未声明行高
        color = FtColor.txtHi, // '#F7FBF8'
    )
}

/** 行间分隔线（源 L375 / L407 的 `border({ width: { top: 1 }, color: '#0FFFFFFF' })`）。 */
@Composable
private fun RowDivider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(FtColor.hairline), // '#0FFFFFFF'
    )
}

/**
 * 自动同步开关（源 L383-404）：46×28 胶囊、`padding: left/top 1`；旋钮 22×22。
 * 关态底 `#1FFFFFFF` + 描边 `#1AFFFFFF`、旋钮 `#FFFFFF`；开态底/描边 `#50ECA7`、旋钮 `#07100B`
 * 且 `translateX(18)`（故旋钮 x = 1 / 19）。
 */
@Composable
private fun AutoSyncSwitch(on: Boolean, onToggle: (Boolean) -> Unit) {
    Box(
        modifier = Modifier
            .size(width = 46.dp, height = 28.dp) // 源 L392-393
            .clip(FtShape.pill) // 源 L394 borderRadius(14)
            .background(if (on) FtColor.accent else SwitchOffFill) // 源 L395
            .border(1.dp, if (on) FtColor.accent else FtColor.line10, FtShape.pill) // 源 L396
            .clickableNoRipple { onToggle(!on) },
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.TopStart) // 源 L398 FlexAlign.Start / L399 VerticalAlign.Top
                // 源 L397 `padding({ left: 1, top: 1 })` + L391 `translate({ x: 18 | 0 })` → 1 / 19
                .offset(x = if (on) 19.dp else 1.dp, y = 1.dp)
                .size(22.dp) // 源 L385-386
                .clip(FtShape.pill) // 源 L387 borderRadius(11)
                .background(if (on) FtColor.onAccent else Color.White), // 源 L388 '#07100B' / '#FFFFFF'
        )
    }
}

/**
 * 立即同步按钮（源 L409-424）：满宽、46 高、顶距 4、14.5px/700、`#07100B` 字 + `#50ECA7` 底、圆角 14。
 */
@Composable
private fun PrimaryActionButton(text: String, enabled: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp) // 源 L414 margin({ top: 4 })
            .height(46.dp) // 源 L411
            .clip(FtShape.lg) // 源 L419 borderRadius(14)
            .background(FtColor.accent) // 源 L418 '#50ECA7'
            .clickableNoRipple(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            style = FtType.natural(14.5f, 700), // 源 L415-416：14.5px / Bold
            color = FtColor.onAccent, // 源 L417 '#07100B'
        )
    }
}

// ── 退出登录 ──────────────────────────────────────────────────────────────

/** `buildSignOutButton()` L447-464：满宽、50 高、15px/700、`#D77C78` 字、`#14D77C78` 底、`#4DD77C78` 描边、圆角 16。 */
@Composable
private fun SignOutButton(signingOut: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(50.dp) // 源 L451
            .clip(FtShape.xl) // 源 L459 borderRadius(16)
            .background(DangerSoftFill) // 源 L457 '#14D77C78'
            .border(1.dp, DangerBorder, FtShape.xl) // 源 L458 '#4DD77C78'
            // 已接线：屏内 onClick 走 resetMeta + AuthService.signOut + 回登录页（源 L223-232）；
            // 源的「未同步变更确认」弹窗（源 L196-220）未移植——留存项。
            .clickableNoRipple(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = if (signingOut) stringResource(R.string.account_sign_out_processing) else stringResource(R.string.account_sign_out), // 源 L449
            style = FtType.natural(15f, 700), // 源 L454-455：15px / Bold
            color = DangerColor, // 源 L456 '#D77C78'
        )
    }
}

// ── 页脚说明 ──────────────────────────────────────────────────────────────

/** 页脚说明（源 L474-479）：11px、`--white-54`、行高 18、`padding: 2px 6px 0`。 */
@Composable
private fun SyncScopeNote() {
    Text(
        text = stringResource(R.string.account_sync_scope_note), // 源 L474；行为口径与隐私政策第八节对齐（本机业务数据不被退出操作删除）
        modifier = Modifier.padding(start = 6.dp, end = 6.dp, top = 2.dp), // 源 L479
        style = FtType.ft(11f, 400, 18f), // 源 L476-478：11px / 行高 18
        color = FtColor.white54, // 源 L477 '#8AFFFFFF'
    )
}

// ── 数据 ──────────────────────────────────────────────────────────────────

/**
 * 由会话与同步状态构建展示态（源 `refreshState` L67-83 + 解析器 L85-133 逐条对齐）。
 *
 * providerId 映射：`supabase` → "邮箱密码"（对齐源 `email_password` 语义——Supabase 即
 * 邮箱+密码流程）；其余未知 → "本地账号"（源缺省分支）。`syncing` / `signingOut` 为屏内瞬态，
 * 由调用方 copy 叠加。
 */
private fun accountSyncUiState(context: Context, session: AuthSession?, state: SyncState): AccountSyncUiState {
    val displayName: String
    val accountText: String
    val providerLabel: String
    if (session != null) {
        displayName = session.displayName.ifEmpty { context.getString(R.string.account_default_display_name) } // 源 L67
        accountText = session.phone.ifEmpty { // 源 L68
            session.email.ifEmpty { context.getString(R.string.account_local_account) }
        }
        providerLabel = if (session.providerId == "supabase") { // 源 L85-102 口径
            context.getString(R.string.account_provider_email_password)
        } else {
            context.getString(R.string.account_provider_local)
        }
    } else {
        displayName = context.getString(R.string.account_status_unauthenticated) // 源 L70-72
        accountText = ""
        providerLabel = ""
    }
    return AccountSyncUiState(
        displayName = displayName,
        accountText = accountText,
        providerLabel = providerLabel,
        syncStatusText = when (state.status) { // 源 resolveStatusLabel L104-118
            "unauthenticated" -> context.getString(R.string.account_status_unauthenticated)
            "syncing" -> context.getString(R.string.account_status_syncing)
            "synced" -> context.getString(R.string.account_status_synced)
            "failed" -> context.getString(R.string.account_status_failed)
            else -> context.getString(R.string.account_status_never_synced)
        },
        syncFailed = state.status == "failed", // 源 L348：'同步失败' 态取危险色
        syncDetailText = if (state.status == "failed" && state.lastError.isNotEmpty()) state.lastError else "", // 源 L82
        lastSyncText = formatSyncTime(context, state.lastSyncAt), // 源 L23 / L120-133
        autoEnabled = state.autoEnabled, // 源 L79
        syncing = false,
        signingOut = false,
    )
}

/** 源 `formatSyncTime` L122-133：`<= 0` → "尚未同步"；否则 `MM-DD HH:mm`（本地时区）。 */
private fun formatSyncTime(context: Context, timestamp: Long): String {
    if (timestamp <= 0) {
        return context.getString(R.string.account_status_never_synced)
    }
    val calendar = java.util.Calendar.getInstance().apply { timeInMillis = timestamp }
    val month = calendar.get(java.util.Calendar.MONTH) + 1
    val day = calendar.get(java.util.Calendar.DAY_OF_MONTH)
    val hours = calendar.get(java.util.Calendar.HOUR_OF_DAY)
    val minutes = calendar.get(java.util.Calendar.MINUTE)
    return "${if (month < 10) "0" else ""}$month-${if (day < 10) "0" else ""}$day " +
        "${if (hours < 10) "0" else ""}$hours:${if (minutes < 10) "0" else ""}$minutes"
}

/**
 * 屏内展示态（对应源页 `@State`，L16-29 的展示字段子集）。
 *
 * 首帧以 [AccountSyncUiState.Companion.sample] 静态渲染；接线时由 `SessionManager.getSession` + `CloudSyncService.getState`
 * 驱动（源 `refreshState` L76-83）。
 */
private data class AccountSyncUiState(
    val displayName: String,
    val accountText: String,
    val providerLabel: String,
    val syncStatusText: String,
    val syncFailed: Boolean,
    val syncDetailText: String,
    val lastSyncText: String,
    val autoEnabled: Boolean,
    val syncing: Boolean,
    val signingOut: Boolean,
) {
    companion object {
        /**
         * 静态样例态：已登录（本地账号）、云同步尚未执行。各字段口径取自源页解析器，
         * 避免自造不一致的组合。
         */
        fun sample(context: Context): AccountSyncUiState = AccountSyncUiState(
            displayName = context.getString(R.string.account_default_display_name), // 源 L67：displayName 空则回退 '训练者'
            accountText = context.getString(R.string.account_local_account), // 源 L68：phone → email → '本机账号'
            providerLabel = context.getString(R.string.account_provider_local), // 源 L85-102：未知 providerId 的回退
            syncStatusText = context.getString(R.string.account_status_never_synced), // 源 L104-118：resolveStatusLabel 缺省分支
            syncFailed = false, // 源 L348：非失败态取强调色
            syncDetailText = "", // 源 L82：仅 failed 且有 lastError 时非空
            lastSyncText = context.getString(R.string.account_status_never_synced), // 源 L23 / L120-133：lastSyncAt <= 0
            autoEnabled = true, // 源 L24 初值
            syncing = false,
            signingOut = false,
        )
    }
}

// ── 图标（路径逐字取自 `pencil-plan-nav-chevron-left.svg`） ────────────────

private const val ICON_VIEW = 24f

/**
 * 返回（`pencil-plan-nav-chevron-left.svg`：`M15 5 L8 12 L15 19`，描边 2、圆头圆角；
 * 源页置于 20×20 盒、`opacity(0.7)`，故色取 [FtColor.white70]）。
 */
@Composable
private fun ChevronLeftIcon(modifier: Modifier = Modifier, color: Color = FtColor.white70) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / ICON_VIEW
        val path = Path().apply {
            moveTo(15f * k, 5f * k)
            lineTo(8f * k, 12f * k)
            lineTo(15f * k, 19f * k)
        }
        drawPath(path, color, style = Stroke(2f * k, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

// ── 局部色值（源内联 hex，无对应全局令牌） ────────────────────────────────
//
// 换算：`#AARRGGBB` 内联字面量，逐字取自源页对应行。

/** 卡片底 `#08FFFFFF`（源 L330-331 / L442-443）。 */
private val CardFill = Color(0x08FFFFFF)

/** 顶栏返回键底 `#0CFFFFFF`（源 L247）。 */
private val BackBtnFill = Color(0x0CFFFFFF)

/** 字母头像描边 `#4D50ECA7`（源 L288）。 */
private val AvatarRing = Color(0x4D50ECA7)

/** 危险色 `#D77C78`（源 L348 / L357 / L456）。 */
private val DangerColor = Color(0xFFD77C78)

/** 退出登录底 `#14D77C78`（源 L457）。 */
private val DangerSoftFill = Color(0x14D77C78)

/** 退出登录描边 `#4DD77C78`（源 L458）。 */
private val DangerBorder = Color(0x4DD77C78)

/** 开关关态底 `#1FFFFFFF`（源 L395）。 */
private val SwitchOffFill = Color(0x1FFFFFFF)

/** 浮层底 `#F00D1117`（源 L506）。 */
private val ToastFill = Color(0xF00D1117)

// ── 结果浮层 ──────────────────────────────────────────────────────────────

/**
 * 源 L491-511 的底部浮层 `.toast`：居中胶囊、`bottom: 30`、
 * 入场 `OPACITY + translate(y: 10)`（`MotionTokens.DURATION_COLOR_BASE` = 180ms）。
 * 实现做法对齐同仓 `LibraryScreen.ScreenToast`。
 */
@Composable
private fun SyncToast(message: String?, modifier: Modifier = Modifier) {
    var shown by remember { mutableStateOf("") }
    if (message != null && message != shown) {
        shown = message
    }
    // 原型 `translate({ y: 10 })`：位移固定 10px，须在 Density 作用域内换算为 px
    val slideOffset = with(LocalDensity.current) { 10.dp.roundToPx() }
    AnimatedVisibility(
        visible = message != null,
        modifier = modifier,
        enter = fadeIn(tween(FtMotion.DURATION_COLOR_BASE)) +
            slideInVertically(tween(FtMotion.DURATION_COLOR_BASE)) { slideOffset },
        exit = fadeOut(tween(FtMotion.DURATION_COLOR_BASE)) +
            slideOutVertically(tween(FtMotion.DURATION_COLOR_BASE)) { slideOffset },
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 320.dp) // 源 L505 constraintSize maxWidth 320
                .clip(FtShape.pill) // 源 L508 borderRadius(999)
                .background(ToastFill) // 源 L506 '#F00D1117'
                .border(1.dp, FtColor.line10, FtShape.pill) // 源 L507 '#1AFFFFFF'
                .padding(horizontal = 16.dp, vertical = 10.dp), // 源 L504
        ) {
            Text(
                text = shown,
                style = FtType.natural(13f).copy(lineHeight = 18.sp), // 源 L500-502：13px / 行高 18
                color = FtColor.txtHi, // 源 L501 '#F7FBF8'
                textAlign = TextAlign.Center,
            )
        }
    }
}

/**
 * 浮层消息的携带序号（对齐 `FtScreens.kt` 的 `AuthToastState`）。
 *
 * `LaunchedEffect(toast)` 以**实例**为键：若两次连发同一文案（或 `String?` 值相等）而键不变，
 * 协程不重启、浮层续不足计时（源每次 `showToast` 都 `clearTimeout` 后重设）。以自增 [seq]
 * 区分每次触发，使同文案连发也能重新计时。
 */
private data class SyncToastState(val seq: Int, val text: String) {
    companion object {
        fun next(current: SyncToastState?, text: String): SyncToastState =
            SyncToastState((current?.seq ?: -1) + 1, text)
    }
}
