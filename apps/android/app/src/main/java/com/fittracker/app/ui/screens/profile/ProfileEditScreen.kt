package com.fittracker.app.ui.screens.profile

import android.app.Application
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.fittracker.app.R
import com.fittracker.app.data.auth.SessionManager
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.AvatarImageService
import com.fittracker.app.data.service.Experience
import com.fittracker.app.data.service.Gender
import com.fittracker.app.data.service.ProfileExtras
import com.fittracker.app.data.service.ProfileExtrasService
import com.fittracker.app.data.service.UserProfile
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.WeightUnit
import com.fittracker.app.data.sync.SyncOrchestrator
import com.fittracker.app.ui.components.FtButton
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File

/**
 * 个人资料编辑页（路由 `profileEdit`）。
 *
 * ── 形态对齐鸿蒙 `ProfileEditContent.ets`（2026-10-28）──────────────────
 * 交互骨架沿用微信资料页：**分组只读行 + chevron，点行弹底部编辑面板**。
 * 原安卓实现是「页内直编」（昵称/地区/签名/身高都是常驻输入框、性别与经验是页内胶囊），
 * 与鸿蒙是两套交互；本次整体改为面板式，分组与顺序也一并对齐：
 *
 *   个人资料：头像 / 名字 / 性别 / 地区 / 手机号
 *   名片：    档案号 / 拍一拍 / 个性签名
 *   偏好：    体重单位 / 常用健身房
 *   身体档案：身高 / 出生年份 / 训练经验
 *
 * 颜色一律映射到安卓中性灰基线（`FtColor` 系列），不搬鸿蒙的冷翠底色相。
 * 数据层未变：一切读写仍走 [UserProfileService] / [ProfileExtrasService]，
 * 头像仍用系统照片选择器（免相册权限）。
 */
@Composable
fun ProfileEditScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    vm: ProfileEditViewModel = viewModel(),
) {
    LaunchedEffect(Unit) { vm.load() }

    // 顶部提示（保存失败 / 选图失败）：与鸿蒙一致，1600ms 后自动消失。
    var toastRes by remember { mutableIntStateOf(0) }
    LaunchedEffect(toastRes) {
        if (toastRes != 0) {
            delay(1600)
            toastRes = 0
        }
    }
    // 保存成功即返回：鸿蒙 `saveAll` 成功后直接 `leavePage()`，不弹成功提示。
    LaunchedEffect(vm.savedTick) { if (vm.savedTick > 0) onBack() }
    LaunchedEffect(vm.saveFailedTick) { if (vm.saveFailedTick > 0) toastRes = R.string.profile_edit_save_failed }
    LaunchedEffect(vm.avatarFailedTick) { if (vm.avatarFailedTick > 0) toastRes = R.string.profile_edit_avatar_failed }

    // ── 底部编辑面板 ──────────────────────────────────────────────
    // `sheet` 保存面板内容，`sheetVisible` 单独控制显隐：退场动画期间内容仍需存在，
    // 二者共用一份状态会让面板在滑出前先被清空（鸿蒙侧靠 ArkUI 的 transition 保留）。
    var sheet by remember { mutableStateOf<EditSheet?>(null) }
    var sheetVisible by remember { mutableStateOf(false) }
    var draft by remember { mutableStateOf("") }

    val openSheet: (EditSheet) -> Unit = { next ->
        sheet = next
        draft = next.value
        sheetVisible = true
    }
    val openField: (EditField) -> Unit = { field ->
        openSheet(
            when (field) {
                EditField.AVATAR -> EditSheet(SheetKind.AVATAR, field, R.string.profile_edit_avatar_section)
                EditField.NAME -> EditSheet(
                    SheetKind.TEXT, field, R.string.profile_edit_sheet_name_title,
                    value = vm.nickname, maxLen = NICKNAME_MAX,
                )
                EditField.GENDER -> EditSheet(SheetKind.CHOICE, field, R.string.profile_edit_gender)
                EditField.REGION -> EditSheet(
                    SheetKind.TEXT, field, R.string.profile_edit_region_title,
                    value = vm.region, maxLen = REGION_MAX,
                )
                EditField.PHONE -> EditSheet(
                    SheetKind.INFO, field, R.string.profile_edit_phone,
                    hintRes = R.string.profile_edit_sheet_phone_hint,
                )
                EditField.ACCOUNT -> EditSheet(
                    SheetKind.INFO, field, R.string.profile_edit_account_id,
                    hintRes = R.string.profile_edit_sheet_account_hint,
                )
                EditField.TICKLE -> EditSheet(
                    SheetKind.TEXT, field, R.string.profile_edit_tickle,
                    value = vm.tickle, maxLen = TICKLE_MAX,
                )
                EditField.WHATS_UP -> EditSheet(
                    SheetKind.TEXT, field, R.string.profile_edit_whats_up,
                    value = vm.whatsUp, maxLen = WHATS_UP_MAX, multiline = true,
                    placeholderRes = R.string.profile_edit_whats_up_placeholder,
                )
                EditField.WEIGHT_UNIT -> EditSheet(SheetKind.CHOICE, field, R.string.profile_edit_weight_unit)
                EditField.GYM -> EditSheet(
                    SheetKind.TEXT, field, R.string.profile_edit_gym,
                    value = vm.gymAddress, maxLen = GYM_MAX,
                )
                EditField.HEIGHT -> EditSheet(
                    SheetKind.TEXT, field, R.string.profile_edit_height_title,
                    value = vm.heightText, maxLen = HEIGHT_MAX, numeric = true,
                )
                EditField.BIRTH_YEAR -> EditSheet(
                    SheetKind.TEXT, field, R.string.profile_edit_birth_year,
                    value = vm.birthYearText, maxLen = BIRTH_YEAR_MAX, numeric = true,
                )
                EditField.EXPERIENCE -> EditSheet(SheetKind.CHOICE, field, R.string.profile_edit_experience)
            },
        )
    }
    val commitText: () -> Unit = {
        val value = draft.trim()
        when (sheet?.field) {
            EditField.NAME -> vm.onNicknameChange(value)
            EditField.REGION -> vm.onRegionChange(value)
            EditField.TICKLE -> vm.onTickleChange(value)
            EditField.WHATS_UP -> vm.onWhatsUpChange(value)
            EditField.GYM -> vm.onGymAddressChange(value)
            EditField.HEIGHT -> vm.onHeightChange(value)
            EditField.BIRTH_YEAR -> vm.onBirthYearChange(value)
            else -> Unit
        }
        sheetVisible = false
    }
    val commitChoice: (String) -> Unit = { value ->
        when (sheet?.field) {
            EditField.GENDER -> vm.onGenderChange(
                when (value) {
                    "male" -> Gender.MALE
                    "female" -> Gender.FEMALE
                    else -> Gender.UNSPECIFIED
                },
            )
            EditField.EXPERIENCE -> vm.onExperienceChange(
                when (value) {
                    "beginner" -> Experience.BEGINNER
                    "intermediate" -> Experience.INTERMEDIATE
                    "advanced" -> Experience.ADVANCED
                    else -> Experience.UNSPECIFIED
                },
            )
            EditField.WEIGHT_UNIT -> vm.onWeightUnitChange(if (value == "lbs") WeightUnit.LBS else WeightUnit.KG)
            else -> Unit
        }
        sheetVisible = false
    }

    // 系统照片选择器：免存储权限（minSdk 24 由 AndroidX 回落 ACTION_OPEN_DOCUMENT）。
    val avatarPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia(),
    ) { uri: Uri? ->
        if (uri != null) {
            vm.onAvatarPicked(uri)
        }
    }

    // 头像首字与个人页同口径：昵称优先，空则回落登录会话显示名。
    val displayName = vm.nickname.trim().ifEmpty { vm.fallbackName.trim() }
    val initial = avatarInitialOf(displayName)

    Box(modifier = modifier.fillMaxSize().background(FtColor.ink0)) {
        Column(modifier = Modifier.fillMaxSize()) {
            // 头部固定不滚（鸿蒙 `buildHeader()` 在 Scroll 之外）。
            EditHeader(onBack = onBack)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(start = 16.dp, end = 16.dp, top = 2.dp, bottom = 30.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                SectionCard(titleRes = R.string.profile_edit_section_identity) {
                    AvatarRow(
                        initial = initial,
                        tint = avatarTintOf(vm.avatarKey),
                        imagePath = vm.avatarImagePath,
                        onOpen = { openField(EditField.AVATAR) },
                    )
                    ValueRow(
                        labelRes = R.string.profile_edit_row_name,
                        value = vm.nickname.trim(),
                        placeholderRes = R.string.profile_edit_placeholder_unset,
                        dividerTop = true,
                        onOpen = { openField(EditField.NAME) },
                    )
                    ValueRow(
                        labelRes = R.string.profile_edit_gender,
                        value = genderLabelOf(vm.gender),
                        placeholderRes = R.string.profile_edit_placeholder_unset,
                        dividerTop = true,
                        onOpen = { openField(EditField.GENDER) },
                    )
                    ValueRow(
                        labelRes = R.string.profile_edit_region,
                        value = vm.region,
                        placeholderRes = R.string.profile_edit_placeholder_unset,
                        dividerTop = true,
                        onOpen = { openField(EditField.REGION) },
                    )
                    ValueRow(
                        labelRes = R.string.profile_edit_phone,
                        value = maskPhone(vm.phone),
                        placeholderRes = R.string.profile_edit_placeholder_unbound,
                        dividerTop = true,
                        onOpen = { openField(EditField.PHONE) },
                    )
                }

                SectionCard(titleRes = R.string.profile_edit_section_card) {
                    ValueRow(
                        labelRes = R.string.profile_edit_account_id,
                        value = vm.accountId,
                        placeholderRes = R.string.profile_edit_placeholder_not_generated,
                        dividerTop = false,
                        onOpen = { openField(EditField.ACCOUNT) },
                    )
                    ValueRow(
                        labelRes = R.string.profile_edit_tickle,
                        value = vm.tickle,
                        placeholderRes = R.string.profile_edit_placeholder_unset,
                        dividerTop = true,
                        onOpen = { openField(EditField.TICKLE) },
                    )
                    ValueRow(
                        labelRes = R.string.profile_edit_whats_up,
                        value = vm.whatsUp,
                        placeholderRes = R.string.profile_edit_placeholder_unset,
                        dividerTop = true,
                        onOpen = { openField(EditField.WHATS_UP) },
                    )
                }

                SectionCard(titleRes = R.string.profile_edit_preference_section) {
                    ValueRow(
                        labelRes = R.string.profile_edit_weight_unit,
                        value = weightUnitLabelOf(vm.weightUnit),
                        placeholderRes = R.string.profile_edit_weight_unit_kg_full,
                        dividerTop = false,
                        onOpen = { openField(EditField.WEIGHT_UNIT) },
                    )
                    ValueRow(
                        labelRes = R.string.profile_edit_gym,
                        value = vm.gymAddress,
                        placeholderRes = R.string.profile_edit_placeholder_unset,
                        dividerTop = true,
                        onOpen = { openField(EditField.GYM) },
                    )
                }

                SectionCard(titleRes = R.string.profile_edit_body_section) {
                    ValueRow(
                        labelRes = R.string.profile_edit_height,
                        value = if (vm.heightText.isEmpty()) {
                            ""
                        } else {
                            stringResource(R.string.profile_edit_height_value, vm.heightText)
                        },
                        placeholderRes = R.string.profile_edit_placeholder_blank,
                        dividerTop = false,
                        onOpen = { openField(EditField.HEIGHT) },
                    )
                    ValueRow(
                        labelRes = R.string.profile_edit_birth_year,
                        value = vm.birthYearText,
                        placeholderRes = R.string.profile_edit_placeholder_blank,
                        dividerTop = true,
                        onOpen = { openField(EditField.BIRTH_YEAR) },
                    )
                    ValueRow(
                        labelRes = R.string.profile_edit_experience,
                        value = experienceLabelOf(vm.experience),
                        placeholderRes = R.string.profile_edit_placeholder_blank,
                        dividerTop = true,
                        onOpen = { openField(EditField.EXPERIENCE) },
                    )
                }

                // 厚底保存键（`DuTokens` 语汇）；未改动时直接返回，不写库。
                FtButton(
                    text = stringResource(
                        if (vm.saving) R.string.profile_edit_saving else R.string.profile_edit_save,
                    ),
                    onClick = {
                        when {
                            vm.saving -> Unit
                            vm.dirty -> vm.save()
                            else -> onBack()
                        }
                    },
                    fontSize = 15f,
                    fontWeight = 700,
                    height = 52.dp,
                    shape = FtShape.xl,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 4.dp)
                        .alpha(if (vm.saving) 0.6f else 1f),
                )

                Text(
                    text = stringResource(R.string.profile_edit_footer),
                    modifier = Modifier.fillMaxWidth().padding(start = 8.dp, end = 8.dp, top = 2.dp),
                    style = FtType.natural(11.5f).copy(lineHeight = 17.sp),
                    color = FtColor.white40,
                    textAlign = TextAlign.Center,
                )
            }
        }

        // 遮罩：鸿蒙侧只有面板带过渡，遮罩瞬时出现/消失 → 这里同样不做动画。
        if (sheetVisible) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(SheetScrim)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                    ) { sheetVisible = false },
            )
        }

        AnimatedVisibility(
            visible = sheetVisible,
            enter = slideInVertically(
                animationSpec = tween(FtMotion.DURATION_PANEL, easing = FtMotion.EASE_PANEL),
                initialOffsetY = { it },
            ) + fadeIn(tween(FtMotion.DURATION_PANEL, easing = FtMotion.EASE_PANEL)),
            exit = slideOutVertically(
                animationSpec = tween(FtMotion.DURATION_PANEL, easing = FtMotion.EASE_PANEL),
                targetOffsetY = { it },
            ) + fadeOut(tween(FtMotion.DURATION_PANEL, easing = FtMotion.EASE_PANEL)),
            modifier = Modifier.align(Alignment.BottomCenter),
        ) {
            sheet?.let { current ->
                SheetPanel(
                    sheet = current,
                    draft = draft,
                    onDraftChange = { draft = it },
                    avatarKey = vm.avatarKey,
                    avatarImagePath = vm.avatarImagePath,
                    initial = initial,
                    picking = vm.picking,
                    currentChoice = { currentChoiceOf(current.field, vm) },
                    onCancel = { sheetVisible = false },
                    onCommitText = commitText,
                    onCommitChoice = commitChoice,
                    onAvatarKey = { vm.onAvatarKeyChange(it) },
                    onPickAvatar = {
                        avatarPicker.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                        )
                    },
                    onRemoveAvatar = { vm.onAvatarRemove() },
                )
            }
        }

        if (toastRes != 0) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 90.dp)
                    .clip(FtShape.lg)
                    .background(ToastFill)
                    .border(1.dp, FtColor.line10, FtShape.lg)
                    .padding(horizontal = 18.dp, vertical = 11.dp),
            ) {
                Text(
                    text = stringResource(toastRes),
                    style = FtType.natural(13f),
                    color = FtColor.txtHi,
                )
            }
        }
    }
}

// ── 分区与行 ────────────────────────────────────────────────────────────────

/** 顶栏：左返回圆钮（44、圆角 14、按压 0.94/120ms）+ 居中标题 + 右侧等宽占位。 */
@Composable
private fun EditHeader(onBack: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) FtMotion.PRESS_SCALE_ICON_BTN else 1f,
        animationSpec = tween(FtMotion.DURATION_PRESS, easing = FtMotion.EASE_MOTION),
        label = "profile-edit-back-press-scale",
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            // 鸿蒙窗口非全屏（页面已在状态栏下）用 `52 - topInset`；安卓 edge-to-edge
            // 直接写绝对 52，二者落到屏幕上的位置相同。
            .padding(start = 12.dp, end = 12.dp, top = 52.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                }
                .clip(FtShape.lg)
                .clickable(interactionSource = interaction, indication = null, onClick = onBack),
            contentAlignment = Alignment.Center,
        ) {
            BackChevron(color = FtColor.txtHi.copy(alpha = 0.7f), size = 22.dp)
        }
        Text(
            text = stringResource(R.string.profile_edit_title),
            modifier = Modifier.weight(1f),
            style = FtType.natural(16f, 700),
            color = FtColor.txtHi,
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
        Spacer(modifier = Modifier.size(44.dp))
    }
}

/** 分组卡：标题 + 卡体（`WHITE_A03` 底、圆角 22、`WHITE_A10` 描边、左右内边距 16）。 */
@Composable
private fun SectionCard(titleRes: Int, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = stringResource(titleRes),
            modifier = Modifier.padding(start = 18.dp, bottom = 8.dp),
            style = FtType.natural(12f, 700),
            color = FtColor.white54,
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(FtShape.panel)
                .background(CardFill)
                .border(1.dp, FtColor.line10, FtShape.panel)
                .padding(start = 16.dp, end = 16.dp),
            content = content,
        )
    }
}

/** 通用只读行：标签 + 右值（空则占位）+ chevron；[dividerTop] 决定上方是否画分隔线。 */
@Composable
private fun ValueRow(
    labelRes: Int,
    value: String,
    placeholderRes: Int,
    dividerTop: Boolean,
    onOpen: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    Column(modifier = Modifier.fillMaxWidth()) {
        if (dividerTop) {
            Hairline()
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(if (pressed) RowPressedFill else Color.Transparent)
                .clickable(interactionSource = interaction, indication = null, onClick = onOpen)
                .padding(start = 2.dp, end = 2.dp, top = 14.dp, bottom = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(labelRes),
                modifier = Modifier.weight(1f),
                style = FtType.natural(14f),
                color = RowLabelColor,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (value.isNotEmpty()) {
                Text(
                    text = value,
                    modifier = Modifier.widthIn(max = 200.dp).padding(start = 12.dp),
                    style = FtType.natural(13.5f),
                    color = RowValueColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.End,
                )
            } else {
                Text(
                    text = stringResource(placeholderRes),
                    modifier = Modifier.padding(start = 12.dp),
                    style = FtType.natural(13.5f),
                    color = FtColor.white32,
                    maxLines = 1,
                )
            }
            Text(
                text = "›",
                modifier = Modifier.padding(start = 8.dp),
                style = FtType.natural(16f),
                color = FtColor.white32,
            )
        }
    }
}

/** 头像行：右侧 56 缩略图 + chevron，下沿画分隔线（它是卡内首行）。 */
@Composable
private fun AvatarRow(initial: String, tint: AvatarTint, imagePath: String, onOpen: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(if (pressed) RowPressedFill else Color.Transparent)
                .clickable(interactionSource = interaction, indication = null, onClick = onOpen)
                .padding(start = 2.dp, end = 2.dp, top = 12.dp, bottom = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(R.string.profile_edit_avatar_section),
                modifier = Modifier.weight(1f),
                style = FtType.natural(14f),
                color = RowLabelColor,
                maxLines = 1,
            )
            AvatarBadge(size = 56.dp, radius = 28.dp, initial = initial, tint = tint, imagePath = imagePath)
            Text(
                text = "›",
                modifier = Modifier.padding(start = 8.dp),
                style = FtType.natural(16f),
                color = FtColor.white32,
            )
        }
        Hairline()
    }
}

/** 头像圆片：有图显示图；无图回落「色键底 + 首字」。 */
@Composable
private fun AvatarBadge(size: Dp, radius: Dp, initial: String, tint: AvatarTint, imagePath: String) {
    if (imagePath.isNotEmpty()) {
        AsyncImage(
            model = File(imagePath),
            contentDescription = stringResource(R.string.profile_edit_avatar_section),
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .size(size)
                .clip(RoundedCornerShape(radius))
                .border(1.dp, tint.border, RoundedCornerShape(radius)),
        )
    } else {
        Box(
            modifier = Modifier
                .size(size)
                .clip(RoundedCornerShape(radius))
                .background(tint.bg)
                .border(1.dp, tint.border, RoundedCornerShape(radius)),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = initial,
                style = FtType.natural(size.value * 0.42f, 700, FtType.num),
                color = tint.fg,
            )
        }
    }
}

// ── 底部编辑面板 ────────────────────────────────────────────────────────────

/** 面板形态（对标鸿蒙 `SheetMode`）。 */
private enum class SheetKind { TEXT, CHOICE, AVATAR, INFO }

/** 面板绑定的字段（对标鸿蒙 `Field`）。 */
private enum class EditField {
    AVATAR, NAME, GENDER, REGION, PHONE, ACCOUNT,
    TICKLE, WHATS_UP, WEIGHT_UNIT, GYM, HEIGHT, BIRTH_YEAR, EXPERIENCE,
}

/** 一次面板打开所需的全部入参。 */
private data class EditSheet(
    val kind: SheetKind,
    val field: EditField,
    val titleRes: Int,
    val value: String = "",
    val placeholderRes: Int = 0,
    val maxLen: Int = 0,
    val numeric: Boolean = false,
    val multiline: Boolean = false,
    val hintRes: Int = 0,
)

@Composable
private fun SheetPanel(
    sheet: EditSheet,
    draft: String,
    onDraftChange: (String) -> Unit,
    avatarKey: String,
    avatarImagePath: String,
    initial: String,
    picking: Boolean,
    currentChoice: () -> String,
    onCancel: () -> Unit,
    onCommitText: () -> Unit,
    onCommitChoice: (String) -> Unit,
    onAvatarKey: (String) -> Unit,
    onPickAvatar: () -> Unit,
    onRemoveAvatar: () -> Unit,
) {
    val panelShape = RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(panelShape)
            .background(SheetFill)
            .border(1.dp, FtColor.line10, panelShape)
            .padding(bottom = 28.dp),
    ) {
        // 面板头：左「取消/关闭」、中标题、右「保存」（仅文本面板）。
        Row(
            modifier = Modifier.fillMaxWidth().height(48.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .height(48.dp)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = onCancel,
                    )
                    .padding(start = 20.dp, end = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = stringResource(
                        if (sheet.kind == SheetKind.TEXT) {
                            R.string.profile_edit_sheet_cancel
                        } else {
                            R.string.profile_edit_sheet_close
                        },
                    ),
                    style = FtType.natural(13.5f),
                    color = FtColor.white54,
                )
            }
            Text(
                text = stringResource(sheet.titleRes),
                modifier = Modifier.weight(1f),
                style = FtType.natural(15f, 700),
                color = FtColor.txtHi,
                textAlign = TextAlign.Center,
                maxLines = 1,
            )
            if (sheet.kind == SheetKind.TEXT) {
                Box(
                    modifier = Modifier
                        .height(48.dp)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                            onClick = onCommitText,
                        )
                        .padding(start = 12.dp, end = 20.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = stringResource(R.string.profile_edit_save),
                        style = FtType.natural(14f, 700),
                        color = FtColor.accent,
                    )
                }
            } else {
                Spacer(modifier = Modifier.width(80.dp).height(48.dp))
            }
        }

        when (sheet.kind) {
            SheetKind.TEXT -> TextSheetBody(sheet, draft, onDraftChange)
            SheetKind.CHOICE -> ChoiceSheetBody(
                options = choiceOptionsOf(sheet.field),
                current = currentChoice(),
                onPick = onCommitChoice,
            )
            SheetKind.AVATAR -> AvatarSheetBody(
                avatarKey = avatarKey,
                avatarImagePath = avatarImagePath,
                initial = initial,
                picking = picking,
                onAvatarKey = onAvatarKey,
                onPickAvatar = onPickAvatar,
                onRemoveAvatar = onRemoveAvatar,
            )
            SheetKind.INFO -> InfoSheetBody(hintRes = sheet.hintRes, onConfirm = onCancel)
        }
    }
}

@Composable
private fun TextSheetBody(sheet: EditSheet, draft: String, onDraftChange: (String) -> Unit) {
    Column(modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 4.dp)) {
        val fieldHeight = if (sheet.multiline) 104.dp else 48.dp
        BasicTextField(
            value = draft,
            onValueChange = { next ->
                onDraftChange(if (next.length > sheet.maxLen) next.take(sheet.maxLen) else next)
            },
            singleLine = !sheet.multiline,
            textStyle = FtType.natural(14.5f).copy(color = FtColor.txtHi),
            cursorBrush = SolidColor(FtColor.accent),
            keyboardOptions = if (sheet.numeric) {
                KeyboardOptions(keyboardType = KeyboardType.Number)
            } else {
                KeyboardOptions.Default
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(fieldHeight)
                .clip(FtShape.lg)
                .background(InputFill)
                .border(1.dp, InputBorder, FtShape.lg),
            decorationBox = { inner ->
                Box(
                    modifier = Modifier.fillMaxSize().padding(horizontal = 12.dp),
                    contentAlignment = if (sheet.multiline) Alignment.TopStart else Alignment.CenterStart,
                ) {
                    if (draft.isEmpty() && sheet.placeholderRes != 0) {
                        Text(
                            text = stringResource(sheet.placeholderRes),
                            style = FtType.natural(14.5f),
                            color = FtColor.white32,
                        )
                    }
                    inner()
                }
            },
        )
        Text(
            text = if (sheet.numeric) {
                stringResource(R.string.profile_edit_sheet_hint_numeric)
            } else {
                stringResource(R.string.profile_edit_sheet_hint_max, sheet.maxLen)
            },
            modifier = Modifier.fillMaxWidth().padding(top = 10.dp, start = 2.dp),
            style = FtType.natural(11.5f),
            color = FtColor.white40,
        )
    }
}

@Composable
private fun ChoiceSheetBody(options: List<SheetOption>, current: String, onPick: (String) -> Unit) {
    Column(modifier = Modifier.fillMaxWidth().padding(start = 12.dp, end = 12.dp, top = 4.dp)) {
        options.forEach { option ->
            val selected = current == option.value
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 4.dp)
                    .height(50.dp)
                    .clip(FtShape.lg)
                    .background(if (selected) FtColor.accent07 else Color.Transparent)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                    ) { onPick(option.value) }
                    .padding(horizontal = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(option.labelRes),
                    modifier = Modifier.weight(1f),
                    style = FtType.natural(14.5f),
                    color = if (selected) FtColor.txtHi else FtColor.white70,
                )
                if (selected) {
                    Text(
                        text = "✓",
                        style = FtType.natural(15f),
                        color = FtColor.accent,
                    )
                }
            }
        }
    }
}

@Composable
private fun AvatarSheetBody(
    avatarKey: String,
    avatarImagePath: String,
    initial: String,
    picking: Boolean,
    onAvatarKey: (String) -> Unit,
    onPickAvatar: () -> Unit,
    onRemoveAvatar: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        AvatarBadge(
            size = 88.dp,
            radius = 44.dp,
            initial = initial,
            tint = avatarTintOf(avatarKey),
            imagePath = avatarImagePath,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            AVATAR_KEYS.forEach { key ->
                val tint = avatarTintOf(key)
                val selected = avatarKey == key
                Box(
                    modifier = Modifier
                        .size(38.dp)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                        ) { onAvatarKey(key) },
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        modifier = Modifier
                            .size(26.dp)
                            .clip(CircleShape)
                            .background(tint.bg)
                            .border(
                                width = if (selected) 2.dp else 1.dp,
                                color = if (selected) tint.fg else tint.border,
                                shape = CircleShape,
                            ),
                    )
                }
            }
        }
        SheetButton(
            text = stringResource(
                if (picking) R.string.profile_edit_avatar_reading else R.string.profile_edit_avatar_pick,
            ),
            primary = true,
            onClick = { if (!picking) onPickAvatar() },
        )
        if (avatarImagePath.isNotEmpty()) {
            SheetButton(
                text = stringResource(R.string.profile_edit_avatar_remove),
                primary = false,
                onClick = onRemoveAvatar,
            )
        }
    }
}

@Composable
private fun InfoSheetBody(hintRes: Int, onConfirm: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 4.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = stringResource(hintRes),
            modifier = Modifier.fillMaxWidth(),
            style = FtType.natural(13.5f).copy(lineHeight = 21.sp),
            color = FtColor.white70,
        )
        SheetButton(
            text = stringResource(R.string.profile_edit_sheet_confirm),
            primary = true,
            onClick = onConfirm,
        )
    }
}

/** 面板内的胶囊按钮（46 高、圆角 14）：主色实底 / 次级面 + 描边。无厚底。 */
@Composable
private fun SheetButton(text: String, primary: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(46.dp)
            .clip(FtShape.lg)
            .background(if (primary) FtColor.accent else InputFill)
            .border(1.dp, if (primary) FtColor.accent else InputBorder, FtShape.lg)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            style = FtType.natural(14f, if (primary) 700 else 400),
            color = if (primary) FtColor.onAccent else FtColor.white70,
        )
    }
}

// ── 小部件 ──────────────────────────────────────────────────────────────────

@Composable
private fun Hairline() {
    Spacer(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(FtColor.hairline),
    )
}

/** 返回箭头：`M15 5 L8 12 L15 19`，描边 2、圆头圆角（逐值与鸿蒙 `pencil-plan-nav-chevron-left.svg` 相同）。 */
@Composable
private fun BackChevron(color: Color, size: Dp) {
    Canvas(modifier = Modifier.size(size)) {
        val k = this.size.minDimension / 24f
        val path = androidx.compose.ui.graphics.Path().apply {
            moveTo(15f * k, 5f * k)
            lineTo(8f * k, 12f * k)
            lineTo(15f * k, 19f * k)
        }
        drawPath(
            path = path,
            color = color,
            style = Stroke(2f * k, cap = StrokeCap.Round, join = StrokeJoin.Round),
        )
    }
}

/** 选项：值 + 文案资源（鸿蒙 `ChoiceOption` 的等价物，文案走资源以便本地化）。 */
private data class SheetOption(val value: String, val labelRes: Int)

private fun choiceOptionsOf(field: EditField): List<SheetOption> = when (field) {
    EditField.GENDER -> listOf(
        SheetOption("male", R.string.profile_edit_gender_male),
        SheetOption("female", R.string.profile_edit_gender_female),
        SheetOption("", R.string.profile_edit_gender_hidden),
    )
    EditField.EXPERIENCE -> listOf(
        SheetOption("beginner", R.string.profile_edit_experience_beginner_full),
        SheetOption("intermediate", R.string.profile_edit_experience_intermediate_full),
        SheetOption("advanced", R.string.profile_edit_experience_advanced_full),
        SheetOption("", R.string.profile_edit_experience_none),
    )
    EditField.WEIGHT_UNIT -> listOf(
        SheetOption("kg", R.string.profile_edit_weight_unit_kg_full),
        SheetOption("lbs", R.string.profile_edit_weight_unit_lbs_full),
    )
    else -> emptyList()
}

private fun currentChoiceOf(field: EditField, vm: ProfileEditViewModel): String = when (field) {
    EditField.GENDER -> when (vm.gender) {
        Gender.MALE -> "male"
        Gender.FEMALE -> "female"
        else -> ""
    }
    EditField.EXPERIENCE -> when (vm.experience) {
        Experience.BEGINNER -> "beginner"
        Experience.INTERMEDIATE -> "intermediate"
        Experience.ADVANCED -> "advanced"
        else -> ""
    }
    EditField.WEIGHT_UNIT -> if (vm.weightUnit == WeightUnit.LBS) "lbs" else "kg"
    else -> ""
}

// ── 数据状态 ────────────────────────────────────────────────────────────────

/**
 * 编辑页状态持有者。
 *
 * 装载与保存都是公开 `suspend`（同 [ProfileViewModel] 的理由：`viewModelScope` 在 Main 调度，
 * Robolectric 单测无 Main Looper 会死锁）。屏侧 `LaunchedEffect` 调用，测试 `runBlocking` 驱动。
 */
class ProfileEditViewModel(application: Application) : AndroidViewModel(application) {

    private val store: JsonStore = JsonStore(application.appDataStore)

    var nickname by mutableStateOf("")
        private set
    var avatarKey by mutableStateOf("")
        private set
    var heightText by mutableStateOf("")
        private set
    var birthYearText by mutableStateOf("")
        private set
    var gender by mutableStateOf(Gender.UNSPECIFIED)
        private set
    var experience by mutableStateOf(Experience.UNSPECIFIED)
        private set
    /** 头像图片沙箱绝对路径（'' = 未设置，回落色键 + 昵称首字）。 */
    var avatarImagePath by mutableStateOf("")
        private set
    /** 选图失败次数——屏侧以它为键提示「图片读取失败」。 */
    var avatarFailedTick by mutableIntStateOf(0)
        private set
    /** 保存成功次数——屏侧以它为键直接返回（鸿蒙保存成功即离页，不弹提示）。 */
    var savedTick by mutableIntStateOf(0)
        private set
    /** 保存失败次数——屏侧以它为键提示重试，不返回。 */
    var saveFailedTick by mutableIntStateOf(0)
        private set
    /** 本次进入页面后是否有改动：无改动时「保存」等价于返回，不写库（对齐鸿蒙 `dirty`）。 */
    var dirty by mutableStateOf(false)
        private set
    /** 正在落盘：按钮文案切「保存中…」并压暗，同时挡住重复提交。 */
    var saving by mutableStateOf(false)
        private set
    /** 正在读取/压缩选中的图片：面板按钮切「读取中…」。 */
    var picking by mutableStateOf(false)
        private set
    /** 地区（名片字段，仅本机）。 */
    var region by mutableStateOf("")
        private set
    /** 拍一拍（名片字段，仅本机）。 */
    var tickle by mutableStateOf("")
        private set
    /** 个性签名（名片字段，仅本机）。 */
    var whatsUp by mutableStateOf("")
        private set
    /** 常用健身房（名片字段，仅本机）。 */
    var gymAddress by mutableStateOf("")
        private set
    /** 登录手机号（来自会话快照，脱敏展示）。 */
    var phone by mutableStateOf("")
        private set
    /** 档案号：由账号派生的稳定展示 ID。 */
    var accountId by mutableStateOf("")
        private set
    /** 账号显示名：本地昵称为空时作为头像首字的回落（与个人页同口径）。 */
    var fallbackName by mutableStateOf("")
        private set

    /** 体重单位（偏好；整份资料保存时回写，与设置页同一字段）。 */
    var weightUnit by mutableStateOf(WeightUnit.KG)
        private set
    /** 进入页面时的头像路径：保存成功才删旧文件，未保存离开时删掉本次新选的文件。 */
    private var loadedAvatarImagePath = ""
    /** 是否已成功保存：决定离开页面时清理哪一份头像文件。 */
    private var saved = false

    suspend fun load() {
        val profile = UserProfileService.loadProfile(store)
        weightUnit = profile.weightUnit
        nickname = profile.nickname
        avatarKey = profile.avatar
        heightText = if (profile.heightCm > 0) profile.heightCm.toString() else ""
        birthYearText = if (profile.birthYear > 0) profile.birthYear.toString() else ""
        gender = profile.gender
        experience = profile.experience
        // 文件已被系统清理时不展示失效路径，回到色键 + 首字。
        avatarImagePath = if (AvatarImageService.exists(profile.avatarImagePath)) profile.avatarImagePath else ""
        loadedAvatarImagePath = avatarImagePath
        // 名片字段：与鸿蒙同库同键（fit_tracker_profile_extras），仅本机保存。
        val extras = ProfileExtrasService.loadExtras(store)
        region = extras.region
        tickle = extras.tickle
        whatsUp = extras.whatsUp
        gymAddress = extras.gymAddress
        // 只读账号信息：手机号 + 档案号（与鸿蒙同口径：userId 缺省回落手机号）。
        val session = SessionManager(store).getSession()
        val sessionPhone = session?.phone.orEmpty()
        phone = sessionPhone
        fallbackName = session?.displayName.orEmpty()
        val seed = session?.userId.orEmpty().ifEmpty { sessionPhone }
        accountId = profileAccountIdOf(seed)
        dirty = false
    }

    /** 昵称上限 20 字：超出直接截断（对齐鸿蒙面板的 `maxLength` + `substring` 口径）。 */
    fun onNicknameChange(value: String) {
        nickname = value.trim().take(NICKNAME_MAX)
        dirty = true
    }

    fun onAvatarKeyChange(value: String) {
        if (avatarKey == value) return
        avatarKey = value
        dirty = true
    }

    fun onHeightChange(value: String) {
        heightText = value.filter { it.isDigit() }.take(HEIGHT_MAX)
        dirty = true
    }

    fun onBirthYearChange(value: String) {
        birthYearText = value.filter { it.isDigit() }.take(BIRTH_YEAR_MAX)
        dirty = true
    }

    fun onGenderChange(value: Gender) {
        if (gender == value) return
        gender = value
        dirty = true
    }

    fun onExperienceChange(value: Experience) {
        if (experience == value) return
        experience = value
        dirty = true
    }

    fun onWeightUnitChange(value: WeightUnit) {
        if (weightUnit == value) return
        weightUnit = value
        dirty = true
    }

    /** 地区：最多 24 字（与鸿蒙 ProfileExtrasService 面板口径一致）。 */
    fun onRegionChange(value: String) {
        region = value.take(REGION_MAX)
        dirty = true
    }

    /** 拍一拍：最多 20 字。 */
    fun onTickleChange(value: String) {
        tickle = value.take(TICKLE_MAX)
        dirty = true
    }

    /** 个性签名：最多 40 字。 */
    fun onWhatsUpChange(value: String) {
        whatsUp = value.take(WHATS_UP_MAX)
        dirty = true
    }

    /** 常用健身房：最多 40 字。 */
    fun onGymAddressChange(value: String) {
        gymAddress = value.take(GYM_MAX)
        dirty = true
    }

    /** 系统选择器返回 Uri：压缩落盘后替换预览；旧图在保存成功或离开时统一清理。 */
    fun onAvatarPicked(uri: Uri) {
        if (picking) return
        picking = true
        viewModelScope.launch {
            try {
                val newPath = AvatarImageService.importFromUri(getApplication(), uri)
                if (newPath == null) {
                    avatarFailedTick += 1
                    return@launch
                }
                val previous = avatarImagePath
                avatarImagePath = newPath
                dirty = true
                if (previous != loadedAvatarImagePath) {
                    AvatarImageService.remove(previous)
                }
            } finally {
                picking = false
            }
        }
    }

    /** 移除头像：只清路径并回收本次未保存的临时文件。 */
    fun onAvatarRemove() {
        val previous = avatarImagePath
        avatarImagePath = ""
        dirty = true
        if (previous != loadedAvatarImagePath) {
            viewModelScope.launch { AvatarImageService.remove(previous) }
        }
    }

    /** 落盘并 bump [savedTick]。失败时保持页面（不做假成功）。 */
    fun save() {
        if (saving) return
        saving = true
        viewModelScope.launch {
            try {
                val profile = UserProfile(
                    nickname = nickname.trim(),
                    avatar = avatarKey,
                    weightUnit = weightUnit,
                    heightCm = UserProfileService.normalizeHeightCm(heightText.toIntOrNull() ?: 0),
                    gender = gender,
                    birthYear = UserProfileService.normalizeBirthYear(birthYearText.toIntOrNull() ?: 0),
                    experience = experience,
                    avatarImagePath = avatarImagePath,
                )
                UserProfileService.saveProfile(store, profile)
                val extras = ProfileExtras(
                    region = region.trim(),
                    tickle = tickle.trim(),
                    whatsUp = whatsUp.trim(),
                    gymAddress = gymAddress.trim(),
                )
                ProfileExtrasService.saveExtras(store, extras)
                val profileSaved = UserProfileService.getLastPersistenceError().isEmpty()
                val extrasSaved = ProfileExtrasService.getLastPersistenceError().isEmpty()
                if (profileSaved && extrasSaved) {
                    saved = true
                    // 换图成功：旧头像文件此时才可安全删除。
                    if (loadedAvatarImagePath != avatarImagePath) {
                        AvatarImageService.remove(loadedAvatarImagePath)
                        loadedAvatarImagePath = avatarImagePath
                    }
                    dirty = false
                    savedTick += 1
                    // 保存成功即触发后台同步：否则要等下次登录/训练完成才上云（含头像 base64 上行）。
                    triggerBackgroundSync()
                } else {
                    // 落盘失败：停在页面提示重试，不做假成功。
                    saveFailedTick += 1
                }
            } finally {
                saving = false
            }
        }
    }

    /** 离开页面时清理「选了但没保存」的头像文件（旧头像仍在原位，资料未变）。 */
    override fun onCleared() {
        super.onCleared()
        if (!saved && avatarImagePath != loadedAvatarImagePath) {
            CoroutineScope(Dispatchers.IO).launch { AvatarImageService.remove(avatarImagePath) }
        }
    }

    /**
     * 保存成功后触发后台同步：独立作用域、不阻塞返回，也不因页面销毁被取消
     * （对齐鸿蒙：`requestBackgroundSync` 不随页面返回中断）。
     */
    private fun triggerBackgroundSync() {
        val application = getApplication<Application>()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            SyncOrchestrator.requestBackgroundSync(
                store,
                SyncOrchestrator.forFilesDir(application.filesDir),
                AvatarImageService.resolveDir(application),
            )
        }
    }

    private companion object {
        // 限长值放在文件级（见下方 `NICKNAME_MAX` 等），面板与 ViewModel 共用一份，避免漂移。
    }
}

// ── 屏内常量 ────────────────────────────────────────────────────────────────

/** 各字段限长（与鸿蒙 `ProfileEditContent` 的面板口径逐值一致）。 */
private const val NICKNAME_MAX = 20
private const val REGION_MAX = 24
private const val TICKLE_MAX = 20
private const val WHATS_UP_MAX = 40
private const val GYM_MAX = 40
private const val HEIGHT_MAX = 3
private const val BIRTH_YEAR_MAX = 4

/** 行标签 `WHITE_A82`。 */
private val RowLabelColor = Color(0xD1FFFFFF)

/** 行右值 `WHITE_A65`。 */
private val RowValueColor = Color(0xA6FFFFFF)

/** 行按压底 `WHITE_A05`。 */
private val RowPressedFill = Color(0x0CFFFFFF)

/** 卡底 `WHITE_A03`（Card Surface v1）。 */
private val CardFill = Color(0x08FFFFFF)

/** 面板底：鸿蒙 `STAT_BG #14181E` 的中性等效（安卓基线去色相）。 */
private val SheetFill = FtColor.visualB

/** 面板遮罩 `BLACK_A40`。 */
private val SheetScrim = Color(0x66000000)

/** 面板内输入框 / 次按钮底 `WHITE_A06`。 */
private val InputFill = Color(0x0CFFFFFF)

/** 面板内输入框 / 次按钮描边 `WHITE_A08`。 */
private val InputBorder = FtColor.glass8

/** 轻提示底：鸿蒙 `#E61A201E` 的中性等效。 */
private val ToastFill = Color(0xE61A1A1A)

/** 手机号脱敏：前 3 + 6 星 + 后 2（与鸿蒙 maskedPhone 同口径）；过短原样返回。 */
internal fun maskPhone(phone: String): String =
    if (phone.length < 8) phone else phone.take(3) + "******" + phone.takeLast(2)

/**
 * 档案号：由登录账号（userId，缺省回落手机号）哈希派生的稳定展示 ID。
 * 算法与鸿蒙 ProfileEditContent.accountIdLabel 逐字一致：
 * seed = 7、每字符 hash = (hash*31+code) % 1e8、左补零到 8 位。
 */
internal fun profileAccountIdOf(seed: String): String {
    if (seed.isEmpty()) return ""
    var hash = 7L
    for (ch in seed) {
        hash = (hash * 31 + ch.code) % 100_000_000L
    }
    return "FT" + hash.toString().padStart(8, '0')
}

/** 色键顺序：首项空串 = 默认翡翠（与 `UserProfile.avatar` 空值同义）。 */
private val AVATAR_KEYS: List<String> = listOf("", "gold", "sky", "rose", "violet", "amber")

/** 性别行右值：未设置时返回空串（走占位）。 */
@Composable
private fun genderLabelOf(gender: Gender): String = when (gender) {
    Gender.MALE -> stringResource(R.string.profile_edit_gender_male)
    Gender.FEMALE -> stringResource(R.string.profile_edit_gender_female)
    else -> ""
}

/** 体重单位行右值（鸿蒙 `weightUnitLabel`）。 */
@Composable
private fun weightUnitLabelOf(unit: WeightUnit): String = stringResource(
    if (unit == WeightUnit.LBS) R.string.profile_edit_weight_unit_lbs_full else R.string.profile_edit_weight_unit_kg_full,
)

/** 训练经验行右值：未设置时返回空串（走占位）。 */
@Composable
private fun experienceLabelOf(experience: Experience): String = when (experience) {
    Experience.BEGINNER -> stringResource(R.string.profile_edit_experience_beginner_full)
    Experience.INTERMEDIATE -> stringResource(R.string.profile_edit_experience_intermediate_full)
    Experience.ADVANCED -> stringResource(R.string.profile_edit_experience_advanced_full)
    else -> ""
}

/** 头像首字：昵称去空格后的首个字符；空昵称回落「—」（与个人页占位一致）。 */
private fun avatarInitialOf(nickname: String): String {
    val trimmed = nickname.trim()
    return if (trimmed.isEmpty()) "—" else trimmed.first().toString()
}
