package com.fittracker.app.ui.screens.profile

import android.app.Application
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
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
 * 个人资料编辑页（设计侧新增，路由 `profileEdit`）。
 *
 * 入口：个人页头部「头像 + 身份」区域与「编辑」胶囊（`FtProfileModel.EDIT_ROUTE`）。
 * 画布 390×844 直绘，由 `FtCanvas` 施加；底栏不出现（非 Tab 路由）。
 *
 * 读写全部走既有的 [UserProfileService]：`loadProfile` 读回全字段，`saveProfile` 整份落盘并 flush。
 * 头像可用系统照片选择器选图（免相册/存储权限，压缩后写入应用私有目录），也可只用「昵称首字 + 色键」
 * 表达——色键写入 `UserProfile.avatar`，与个人页 `avatarTintOf` 的映射一一对应。
 */
@Composable
fun ProfileEditScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    vm: ProfileEditViewModel = viewModel(),
) {
    LaunchedEffect(Unit) { vm.load() }

    val nickname = vm.nickname
    val avatarKey = vm.avatarKey
    val heightText = vm.heightText
    val birthYearText = vm.birthYearText
    val gender = vm.gender
    val experience = vm.experience
    val avatarImagePath = vm.avatarImagePath
    val avatarFailedTick = vm.avatarFailedTick
    val savedTick = vm.savedTick
    val saveFailedTick = vm.saveFailedTick
    val nicknameTooLong = vm.nicknameTooLong
    val region = vm.region
    val tickle = vm.tickle
    val whatsUp = vm.whatsUp
    val gymAddress = vm.gymAddress
    val accountId = vm.accountId
    val maskedPhone = maskPhone(vm.phone)

    // 保存成功 → 轻微停顿让 toast 可见，再返回个人页。
    var showSaved by remember { mutableStateOf(false) }
    LaunchedEffect(savedTick) {
        if (savedTick > 0) {
            showSaved = true
            delay(1200)
            showSaved = false
            onBack()
        }
    }
    // 保存失败 → 只提示，不返回（用户可重试或手动返回）。
    var showSaveFailed by remember { mutableStateOf(false) }
    LaunchedEffect(saveFailedTick) {
        if (saveFailedTick > 0) {
            showSaveFailed = true
            delay(1600)
            showSaveFailed = false
        }
    }
    // 选图失败 → 只提示，保持原头像（取消选择不提示）。
    var showAvatarFailed by remember { mutableStateOf(false) }
    LaunchedEffect(avatarFailedTick) {
        if (avatarFailedTick > 0) {
            showAvatarFailed = true
            delay(1600)
            showAvatarFailed = false
        }
    }
    // 系统照片选择器：免存储权限（minSdk 24 由 AndroidX 回落 ACTION_OPEN_DOCUMENT）。
    val avatarPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia(),
    ) { uri: Uri? ->
        if (uri != null) {
            vm.onAvatarPicked(uri)
        }
    }

    Box(modifier = modifier.fillMaxSize().background(FtColor.ink0)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(start = 16.dp, end = 16.dp, top = 44.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            EditHeader(onBack = onBack)

            AvatarSection(
                avatarKey = avatarKey,
                initial = avatarInitialOf(nickname),
                avatarImagePath = avatarImagePath,
                onAvatarKey = { vm.onAvatarKeyChange(it) },
                onPickAvatar = {
                    avatarPicker.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                    )
                },
                onRemoveAvatar = { vm.onAvatarRemove() },
            )

            SectionCard(titleRes = R.string.profile_edit_nickname_section) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 44.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    BasicTextField(
                        value = nickname,
                        onValueChange = { vm.onNicknameChange(it) },
                        modifier = Modifier.weight(1f),
                        singleLine = true,
                        textStyle = FtType.natural(16f, 600).copy(color = FtColor.txtHi),
                        cursorBrush = SolidColor(FtColor.accent),
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                        decorationBox = { inner ->
                            Box(contentAlignment = Alignment.CenterStart) {
                                if (nickname.isEmpty()) {
                                    Text(
                                        text = stringResource(R.string.profile_edit_nickname_placeholder),
                                        style = FtType.natural(16f),
                                        color = FtColor.white40,
                                    )
                                }
                                inner()
                            }
                        },
                    )
                }
                if (nicknameTooLong) {
                    Text(
                        text = stringResource(R.string.profile_edit_nickname_too_long),
                        modifier = Modifier.padding(top = 6.dp),
                        style = FtType.natural(12f),
                        color = FtColor.warn,
                    )
                }
            }

            SectionCard(titleRes = R.string.profile_edit_social_section) {
                TextRow(
                    labelRes = R.string.profile_edit_region,
                    value = region,
                    placeholderRes = R.string.profile_edit_region_placeholder,
                    onValue = { vm.onRegionChange(it) },
                )
                Hairline()
                TextRow(
                    labelRes = R.string.profile_edit_tickle,
                    value = tickle,
                    placeholderRes = R.string.profile_edit_tickle_placeholder,
                    onValue = { vm.onTickleChange(it) },
                )
                Hairline()
                TextRow(
                    labelRes = R.string.profile_edit_whats_up,
                    value = whatsUp,
                    placeholderRes = R.string.profile_edit_whats_up_placeholder,
                    onValue = { vm.onWhatsUpChange(it) },
                    singleLine = false,
                )
            }

            SectionCard(titleRes = R.string.profile_edit_preference_section) {
                WeightUnitRow(unit = vm.weightUnit, onUnit = { vm.onWeightUnitChange(it) })
                Hairline()
                TextRow(
                    labelRes = R.string.profile_edit_gym,
                    value = gymAddress,
                    placeholderRes = R.string.profile_edit_gym_placeholder,
                    onValue = { vm.onGymAddressChange(it) },
                )
            }

            SectionCard(titleRes = R.string.profile_edit_account_section) {
                ReadonlyRow(labelRes = R.string.profile_edit_phone, value = maskedPhone)
                Hairline()
                ReadonlyRow(labelRes = R.string.profile_edit_account_id, value = accountId)
                Text(
                    text = stringResource(R.string.profile_edit_account_hint),
                    modifier = Modifier.padding(top = 10.dp),
                    style = FtType.natural(11.5f),
                    color = FtColor.white48,
                )
            }

            SectionCard(titleRes = R.string.profile_edit_body_section) {
                NumberRow(
                    labelRes = R.string.profile_edit_height,
                    unitRes = R.string.profile_edit_height_unit,
                    value = heightText,
                    onValue = { vm.onHeightChange(it) },
                )
                Hairline()
                GenderRow(gender = gender, onGender = { vm.onGenderChange(it) })
                Hairline()
                NumberRow(
                    labelRes = R.string.profile_edit_birth_year,
                    unitRes = 0,
                    value = birthYearText,
                    onValue = { vm.onBirthYearChange(it) },
                )
                Hairline()
                ExperienceRow(experience = experience, onExperience = { vm.onExperienceChange(it) })
            }

            SaveButton(onSave = { vm.save() })
        }

        SavedToast(
            visible = showSaved || showSaveFailed || showAvatarFailed,
            textRes = when {
                showAvatarFailed -> R.string.profile_edit_avatar_failed
                showSaveFailed -> R.string.profile_edit_save_failed
                else -> R.string.profile_edit_saved
            },
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

/** 顶栏：返回圆钮 + 标题。 */
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
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .requiredSize(40.dp)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                }
                .clip(CircleShape)
                .background(ChipFill)
                .border(1.dp, FtColor.line10, CircleShape)
                .clickable(interactionSource = interaction, indication = null, onClick = onBack),
            contentAlignment = Alignment.Center,
        ) {
            BackChevron(color = FtColor.txtHi)
        }
        Text(
            text = stringResource(R.string.profile_edit_title),
            color = FtColor.txtHi,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.weight(1f),
        )
    }
}

/** 头像预览 + 选图 / 移除 + 色键选择。 */
@Composable
private fun AvatarSection(
    avatarKey: String,
    initial: String,
    avatarImagePath: String,
    onAvatarKey: (String) -> Unit,
    onPickAvatar: () -> Unit,
    onRemoveAvatar: () -> Unit,
) {
    val tint = avatarTintOf(avatarKey)
    SectionCardRaw {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (avatarImagePath.isNotEmpty()) {
                AsyncImage(
                    model = File(avatarImagePath),
                    contentDescription = stringResource(R.string.profile_edit_avatar_section),
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .requiredSize(64.dp)
                        .clip(CircleShape)
                        .border(1.dp, tint.border, CircleShape),
                )
            } else {
                Box(
                    modifier = Modifier
                        .requiredSize(64.dp)
                        .clip(CircleShape)
                        .background(tint.bg)
                        .border(1.dp, tint.border, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = initial,
                        style = FtType.natural(26f, 700, FtType.num),
                        color = tint.fg,
                    )
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = stringResource(R.string.profile_edit_avatar_section),
                    color = FtColor.txtHi,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = stringResource(R.string.profile_edit_avatar_hint),
                    style = FtType.natural(11.5f),
                    color = FtColor.white48,
                )
            }
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            PillButton(textRes = R.string.profile_edit_avatar_pick, onClick = onPickAvatar)
            if (avatarImagePath.isNotEmpty()) {
                PillButton(
                    textRes = R.string.profile_edit_avatar_remove,
                    onClick = onRemoveAvatar,
                    subdued = true,
                )
            }
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            AVATAR_KEYS.forEach { key ->
                AvatarSwatch(
                    key = key,
                    selected = if (avatarKey.isEmpty()) key == "" else avatarKey == key,
                    modifier = Modifier.weight(1f),
                    onClick = { onAvatarKey(key) },
                )
            }
        }
    }
}

/** 头像区的小胶囊按钮（选图 = 翡翠实底；移除 = 描边弱化）。 */
@Composable
private fun PillButton(textRes: Int, onClick: () -> Unit, subdued: Boolean = false) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) FtMotion.PRESS_SCALE_CARD else 1f,
        animationSpec = tween(FtMotion.DURATION_PRESS, easing = FtMotion.EASE_MOTION),
        label = "profile-edit-avatar-action-press-scale",
    )
    Box(
        modifier = Modifier
            .height(32.dp)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(FtShape.pill)
            .background(if (subdued) ChipFill else FtColor.accent)
            .border(1.dp, if (subdued) FtColor.line10 else FtColor.accent, FtShape.pill)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .padding(horizontal = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = stringResource(textRes),
            style = FtType.natural(12.5f, if (subdued) 500 else 700),
            color = if (subdued) FtColor.white70 else FtColor.onAccent,
        )
    }
}

@Composable
private fun AvatarSwatch(
    key: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val tint = avatarTintOf(key)
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) FtMotion.PRESS_SCALE_CARD else 1f,
        animationSpec = tween(FtMotion.DURATION_PRESS, easing = FtMotion.EASE_MOTION),
        label = "profile-edit-card-press-scale",
    )
    Column(
        modifier = modifier
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(FtShape.lg)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(
            modifier = Modifier
                .requiredSize(32.dp)
                .clip(CircleShape)
                .background(tint.bg)
                .border(if (selected) 2.dp else 1.dp, if (selected) FtColor.accent else tint.border, CircleShape),
        )
        Box(
            modifier = Modifier
                .size(width = 6.dp, height = 2.dp)
                .clip(FtShape.pill)
                .background(if (selected) FtColor.accent else Color.Transparent),
        )
    }
}

/** 卡片外壳（带标题）。 */
@Composable
private fun SectionCard(titleRes: Int, content: @Composable () -> Unit) {
    SectionCardRaw {
        Text(
            text = stringResource(titleRes),
                color = FtColor.white54,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(bottom = 10.dp),
        )
        content()
    }
}

@Composable
private fun SectionCardRaw(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(FtShape.panel)
            .background(CardFill)
            .border(1.dp, FtColor.line10, FtShape.panel)
            .padding(16.dp),
    ) {
        content()
    }
}

/** 文本输入行（地区 / 拍一拍 / 个性签名 / 常用健身房）。[singleLine] = false 时按多行排。 */
@Composable
private fun TextRow(
    labelRes: Int,
    value: String,
    placeholderRes: Int,
    onValue: (String) -> Unit,
    singleLine: Boolean = true,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            text = stringResource(labelRes),
            style = FtType.natural(14f),
            color = FtColor.white70,
        )
        BasicTextField(
            value = value,
            onValueChange = onValue,
            singleLine = singleLine,
            textStyle = FtType.natural(15f, 600).copy(color = FtColor.txtHi),
            cursorBrush = SolidColor(FtColor.accent),
            keyboardOptions = KeyboardOptions(imeAction = if (singleLine) ImeAction.Done else ImeAction.Default),
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = if (singleLine) 24.dp else 48.dp),
            decorationBox = { inner ->
                Box(contentAlignment = Alignment.CenterStart) {
                    if (value.isEmpty()) {
                        Text(
                            text = stringResource(placeholderRes),
                            style = FtType.natural(15f),
                            color = FtColor.white32,
                        )
                    }
                    inner()
                }
            },
        )
    }
}

/** 体重单位两选（千克 / 磅）——与设置页同一 `UserProfile.weightUnit`。 */
@Composable
private fun WeightUnitRow(unit: WeightUnit, onUnit: (WeightUnit) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = stringResource(R.string.profile_edit_weight_unit),
            style = FtType.natural(14f),
            color = FtColor.white70,
            modifier = Modifier.weight(1f),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            WEIGHT_UNIT_OPTIONS.forEach { option ->
                GenderChip(
                    labelRes = option.second,
                    selected = unit == option.first,
                    onClick = { onUnit(option.first) },
                )
            }
        }
    }
}

/** 只读行（手机号 / 档案号）：值来自登录会话，页面内不可改。 */
@Composable
private fun ReadonlyRow(labelRes: Int, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = stringResource(labelRes),
            style = FtType.natural(14f),
            color = FtColor.white70,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = if (value.isEmpty()) stringResource(R.string.profile_edit_unset) else value,
            style = FtType.natural(14f, 600, FtType.num),
            color = if (value.isEmpty()) FtColor.white40 else FtColor.white70,
        )
    }
}

/** 数字输入行（身高 / 出生年）。[unitRes] 为 0 时不显示单位。 */
@Composable
private fun NumberRow(labelRes: Int, unitRes: Int, value: String, onValue: (String) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = stringResource(labelRes),
            style = FtType.natural(14f),
            color = FtColor.white70,
            modifier = Modifier.weight(1f),
        )
        BasicTextField(
            value = value,
            onValueChange = onValue,
            singleLine = true,
            textStyle = FtType.natural(15f, 600, FtType.num).copy(color = FtColor.txtHi),
            cursorBrush = SolidColor(FtColor.accent),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = {}),
            modifier = Modifier.width(88.dp),
            decorationBox = { inner ->
                Box(
                    modifier = Modifier.fillMaxWidth(),
                    contentAlignment = Alignment.CenterEnd,
                ) { inner() }
            },
        )
        if (unitRes != 0) {
            Text(
                text = stringResource(unitRes),
                modifier = Modifier.padding(start = 6.dp),
                style = FtType.natural(12f),
                color = FtColor.white48,
            )
        }
    }
}

/** 性别三选：未填 / 男 / 女。 */
@Composable
private fun GenderRow(gender: Gender, onGender: (Gender) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = stringResource(R.string.profile_edit_gender),
            style = FtType.natural(14f),
            color = FtColor.white70,
            modifier = Modifier.weight(1f),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            GENDER_OPTIONS.forEach { option ->
                GenderChip(
                    labelRes = option.second,
                    selected = gender == option.first,
                    onClick = { onGender(option.first) },
                )
            }
        }
    }
}

/** 训练经验四选：未填 / 新手 / 进阶 / 高阶。 */
@Composable
private fun ExperienceRow(experience: Experience, onExperience: (Experience) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = stringResource(R.string.profile_edit_experience),
            style = FtType.natural(14f),
            color = FtColor.white70,
            modifier = Modifier.weight(1f),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            EXPERIENCE_OPTIONS.forEach { option ->
                GenderChip(
                    labelRes = option.second,
                    selected = experience == option.first,
                    onClick = { onExperience(option.first) },
                )
            }
        }
    }
}

@Composable
private fun GenderChip(labelRes: Int, selected: Boolean, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) FtMotion.PRESS_SCALE_CARD else 1f,
        animationSpec = tween(FtMotion.DURATION_PRESS, easing = FtMotion.EASE_MOTION),
        label = "profile-edit-field-press-scale",
    )
    Box(
        modifier = Modifier
            .height(30.dp)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(FtShape.pill)
            .background(if (selected) FtColor.accent else ChipFill)
            .border(1.dp, if (selected) FtColor.accent else FtColor.line10, FtShape.pill)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .padding(horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = stringResource(labelRes),
            style = FtType.natural(12f, if (selected) 700 else 500),
            color = if (selected) FtColor.onAccent else FtColor.white70,
        )
    }
}

/** 底部主按钮：翡翠底 + 按压缩放。 */
@Composable
private fun SaveButton(onSave: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) FtMotion.PRESS_SCALE_CTA else 1f,
        animationSpec = tween(FtMotion.DURATION_PRESS, easing = FtMotion.EASE_MOTION),
        label = "profile-edit-save-press-scale",
    )
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(FtShape.pill)
            .background(FtColor.accent)
            .clickable(interactionSource = interaction, indication = null, onClick = onSave),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = stringResource(R.string.profile_edit_save),
            color = FtColor.onAccent,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}

/** 轻量成功提示（对齐 `AuthToast` 的位置与语汇：底部居中、淡入上浮）。 */
@Composable
private fun SavedToast(
    visible: Boolean,
    textRes: Int = R.string.profile_edit_saved,
    modifier: Modifier = Modifier,
) {
    val toastAlpha by androidx.compose.animation.core.animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = androidx.compose.animation.core.tween(
            durationMillis = FtMotion.DURATION_COLOR_BASE,
            easing = FtMotion.EASE_MOTION,
        ),
        label = "saved-toast",
    )
    if (toastAlpha > 0.01f) {
        Box(
            modifier = modifier
                .padding(bottom = 36.dp)
                .graphicsLayer { this.alpha = toastAlpha }
                .clip(FtShape.pill)
                .background(FtColor.surface)
                .border(1.dp, FtColor.line10, FtShape.pill)
                .padding(horizontal = 16.dp, vertical = 10.dp),
        ) {
            Text(
                text = stringResource(textRes),
                style = FtType.natural(13f, 600),
                color = FtColor.txtHi,
            )
        }
    }
}

@Composable
private fun Hairline() {
    Spacer(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(FtColor.hairline),
    )
}

/** 返回箭头（`m15 18-6-6 6-6`，描边 2、圆头圆角）。 */
@Composable
private fun BackChevron(color: Color) {
    androidx.compose.foundation.Canvas(modifier = Modifier.size(18.dp)) {
        val k = size.minDimension / 24f
        val path = Path().apply {
            moveTo(15f * k, 18f * k)
            lineTo(9f * k, 12f * k)
            lineTo(15f * k, 6f * k)
        }
        drawPath(
            path = path,
            color = color,
            style = Stroke(2f * k, cap = StrokeCap.Round, join = StrokeJoin.Round),
        )
    }
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
    /** 保存成功次数——屏侧以它为键触发 toast 与返回。 */
    var savedTick by mutableIntStateOf(0)
        private set
    /** 保存失败次数——屏侧以它为键提示重试，不返回。 */
    var saveFailedTick by mutableIntStateOf(0)
        private set
    /** 昵称输入超长：保留已输入内容并提示，而不是静默吞掉按键。 */
    var nicknameTooLong by mutableStateOf(false)
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
        val seed = session?.userId.orEmpty().ifEmpty { sessionPhone }
        accountId = profileAccountIdOf(seed)
    }

    fun onNicknameChange(value: String) {
        nicknameTooLong = value.length > NICKNAME_MAX
        if (!nicknameTooLong) {
            nickname = value
        }
    }

    fun onAvatarKeyChange(value: String) {
        avatarKey = value
    }

    fun onHeightChange(value: String) {
        heightText = value.filter { it.isDigit() }.take(3)
    }

    fun onBirthYearChange(value: String) {
        birthYearText = value.filter { it.isDigit() }.take(4)
    }

    fun onGenderChange(value: Gender) {
        gender = value
    }

    fun onExperienceChange(value: Experience) {
        experience = value
    }

    fun onWeightUnitChange(value: WeightUnit) {
        weightUnit = value
    }

    /** 地区：最多 24 字（与鸿蒙 ProfileExtrasService 面板口径一致）。 */
    fun onRegionChange(value: String) {
        region = value.take(REGION_MAX)
    }

    /** 拍一拍：最多 20 字。 */
    fun onTickleChange(value: String) {
        tickle = value.take(TICKLE_MAX)
    }

    /** 个性签名：最多 40 字。 */
    fun onWhatsUpChange(value: String) {
        whatsUp = value.take(WHATS_UP_MAX)
    }

    /** 常用健身房：最多 40 字。 */
    fun onGymAddressChange(value: String) {
        gymAddress = value.take(GYM_MAX)
    }

    /** 系统选择器返回 Uri：压缩落盘后替换预览；旧图在保存成功或离开时统一清理。 */
    fun onAvatarPicked(uri: Uri) {
        viewModelScope.launch {
            val newPath = AvatarImageService.importFromUri(getApplication(), uri)
            if (newPath == null) {
                avatarFailedTick += 1
                return@launch
            }
            val previous = avatarImagePath
            avatarImagePath = newPath
            if (previous != loadedAvatarImagePath) {
                AvatarImageService.remove(previous)
            }
        }
    }

    /** 移除头像：只清路径并回收本次未保存的临时文件。 */
    fun onAvatarRemove() {
        val previous = avatarImagePath
        avatarImagePath = ""
        if (previous != loadedAvatarImagePath) {
            viewModelScope.launch { AvatarImageService.remove(previous) }
        }
    }

    /** 落盘并 bump [savedTick]。失败时保持页面（不做假成功）。 */
    fun save() {
        viewModelScope.launch {
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
                savedTick += 1
                // 保存成功即触发后台同步：否则要等下次登录/训练完成才上云（含头像 base64 上行）。
                triggerBackgroundSync()
            } else {
                // 落盘失败：停在页面提示重试，不做假成功。
                saveFailedTick += 1
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
        const val NICKNAME_MAX = 20
        const val REGION_MAX = 24
        const val TICKLE_MAX = 20
        const val WHATS_UP_MAX = 40
        const val GYM_MAX = 40
    }
}

// ── 屏内常量 ────────────────────────────────────────────────────────────────

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

private val GENDER_OPTIONS: List<Pair<Gender, Int>> = listOf(
    Gender.UNSPECIFIED to R.string.profile_edit_gender_unset,
    Gender.MALE to R.string.profile_edit_gender_male,
    Gender.FEMALE to R.string.profile_edit_gender_female,
)

private val WEIGHT_UNIT_OPTIONS: List<Pair<WeightUnit, Int>> = listOf(
    WeightUnit.KG to R.string.profile_edit_weight_unit_kg,
    WeightUnit.LBS to R.string.profile_edit_weight_unit_lbs,
)

private val EXPERIENCE_OPTIONS: List<Pair<Experience, Int>> = listOf(
    Experience.UNSPECIFIED to R.string.profile_experience_unset,
    Experience.BEGINNER to R.string.profile_experience_beginner,
    Experience.INTERMEDIATE to R.string.profile_experience_intermediate,
    Experience.ADVANCED to R.string.profile_experience_advanced,
)

/** Card Surface v1 卡底 `rgba(255,255,255,.031)` → `0x08FFFFFF`。 */
private val CardFill = Color(0x08FFFFFF)

/** 小控件底（返回钮 / 未选中的性别胶囊）`rgba(255,255,255,.047)` → `0x0CFFFFFF`。 */
private val ChipFill = Color(0x0CFFFFFF)

/** 头像首字：昵称去空格后的首个字符；空昵称回落「—」（与个人页占位一致）。 */
private fun avatarInitialOf(nickname: String): String {
    val trimmed = nickname.trim()
    return if (trimmed.isEmpty()) "—" else trimmed.first().toString()
}
