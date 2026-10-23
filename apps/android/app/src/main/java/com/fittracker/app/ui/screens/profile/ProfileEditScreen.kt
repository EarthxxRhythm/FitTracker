package com.fittracker.app.ui.screens.profile

import android.app.Application
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
import com.fittracker.app.R
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.Gender
import com.fittracker.app.data.service.UserProfile
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.WeightUnit
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 个人资料编辑页（设计侧新增，路由 `profileEdit`）。
 *
 * 入口：个人页头部「头像 + 身份」区域与「编辑」胶囊（`FtProfileModel.EDIT_ROUTE`）。
 * 画布 390×844 直绘，由 `FtCanvas` 施加；底栏不出现（非 Tab 路由）。
 *
 * 读写全部走既有的 [UserProfileService]：`loadProfile` 读回全字段，`saveProfile` 整份落盘并 flush。
 * 头像**不选图**（无媒体权限依赖），用「昵称首字 + 色键」表达，色键写入 `UserProfile.avatar`，
 * 与个人页 `avatarTintOf` 的映射一一对应。
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
    val savedTick = vm.savedTick

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
                onAvatarKey = { vm.onAvatarKeyChange(it) },
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
            }

            SaveButton(onSave = { vm.save() })
        }

        SavedToast(visible = showSaved, modifier = Modifier.align(Alignment.BottomCenter))
    }
}

/** 顶栏：返回圆钮 + 标题。 */
@Composable
private fun EditHeader(onBack: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale = if (pressed) FtMotion.PRESS_SCALE_ICON_BTN else 1f
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

/** 头像预览 + 色键选择。 */
@Composable
private fun AvatarSection(avatarKey: String, initial: String, onAvatarKey: (String) -> Unit) {
    val tint = avatarTintOf(avatarKey)
    SectionCardRaw {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
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
    val scale = if (pressed) FtMotion.PRESS_SCALE_CARD else 1f
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

@Composable
private fun GenderChip(labelRes: Int, selected: Boolean, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale = if (pressed) FtMotion.PRESS_SCALE_CARD else 1f
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
    val scale = if (pressed) FtMotion.PRESS_SCALE_CTA else 1f
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
private fun SavedToast(visible: Boolean, modifier: Modifier = Modifier) {
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
                text = stringResource(R.string.profile_edit_saved),
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
    /** 保存成功次数——屏侧以它为键触发 toast 与返回。 */
    var savedTick by mutableIntStateOf(0)
        private set

    private var weightUnit = WeightUnit.KG

    suspend fun load() {
        val profile = UserProfileService.loadProfile(store)
        weightUnit = profile.weightUnit
        nickname = profile.nickname
        avatarKey = profile.avatar
        heightText = if (profile.heightCm > 0) profile.heightCm.toString() else ""
        birthYearText = if (profile.birthYear > 0) profile.birthYear.toString() else ""
        gender = profile.gender
    }

    fun onNicknameChange(value: String) {
        if (value.length <= NICKNAME_MAX) {
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
            )
            UserProfileService.saveProfile(store, profile)
            if (UserProfileService.getLastPersistenceError().isEmpty()) {
                savedTick += 1
            }
        }
    }

    private companion object {
        const val NICKNAME_MAX = 20
    }
}

// ── 屏内常量 ────────────────────────────────────────────────────────────────

/** 色键顺序：首项空串 = 默认翡翠（与 `UserProfile.avatar` 空值同义）。 */
private val AVATAR_KEYS: List<String> = listOf("", "gold", "sky", "rose", "violet", "amber")

private val GENDER_OPTIONS: List<Pair<Gender, Int>> = listOf(
    Gender.UNSPECIFIED to R.string.profile_edit_gender_unset,
    Gender.MALE to R.string.profile_edit_gender_male,
    Gender.FEMALE to R.string.profile_edit_gender_female,
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
