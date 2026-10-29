package com.fittracker.app.ui.screens.active

import androidx.activity.compose.LocalOnBackPressedDispatcherOwner
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fittracker.app.R
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.appDataStore
import com.fittracker.app.data.service.ActiveWorkoutExercise
import com.fittracker.app.data.service.ActiveWorkoutService
import com.fittracker.app.data.service.ActiveWorkoutState
import com.fittracker.app.data.service.SettingsService
import com.fittracker.app.data.service.UserProfileService
import com.fittracker.app.data.service.WeightUnit
import com.fittracker.app.data.service.WeightUtils
import com.fittracker.app.data.service.WorkoutDraftService
import com.fittracker.app.data.service.WorkoutRepository
import com.fittracker.app.notifications.checkAndNotifyAchievement
import com.fittracker.app.data.service.hasWorkoutDraftProgress
import com.fittracker.app.ui.components.clickableNoRipple
import com.fittracker.app.ui.screens.library.ExerciseGif
import com.fittracker.app.ui.screens.library.FtLibraryModel
import com.fittracker.app.ui.screens.workout.activeStateToDraft
import com.fittracker.app.ui.screens.workout.draftToActiveState
import com.fittracker.app.ui.screens.workout.loadTodayWorkoutPreview
import com.fittracker.app.ui.theme.DuTokens
import com.fittracker.app.ui.theme.FtColor
import com.fittracker.app.ui.theme.FtMotion
import com.fittracker.app.ui.theme.FtShape
import com.fittracker.app.ui.theme.FtType
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.random.Random

/**
 * 训练执行屏（原型 `fittracker-training.html` 的 `screen-training` 帧，L411-676）。
 *
 * 画布 390×844 直绘（`.wo-screen { position:absolute; inset:0 }`）。无底栏
 * （非 Tab 一级路由；本文件 `FT_APP.routes` 为空表）。
 *
 * 版式来源（原型 CSS 行号）：
 * `.wo-top` L187-193 · `.progress-label`/`.top-timer` L194-206 · `.duo-*` L208-228 ·
 * `.wo-scroll`/`.wo-content` L230-232 · `.demo-card`/`.demo-*` L234-296 ·
 * `.set-list`/`.set-record`/`.rec-*` L298-331 · `.wo-dock`/`.wo-btn-primary` L333-360 ·
 * `.modal*` L362-441 · `.input-box`/`.stepper` L420-457 · `.celebrate*` L458-530。
 *
 * 三处**以源码为准**的取舍：
 * 1. 样式表末尾「Card Surface v1」（L538）把 `.demo-card` 的底色与描边改写为
 *    `rgba(255,255,255,.031)` / `--line-10`——按**末尾**规则实现。
 * 2. 页脚（L673）称流程为「提交 → 弹窗 → 完成本组 → 庆祝 → 进度前进」；
 *    但脚本里 `completeSet` 的 `renderSets(true)` 在 360ms 后才跑（L850-852），
 *    庆祝动画与记录新增**不同时**发生——按源码时序实现。
 * 3. `.celebrate` 的 `backdrop-filter: blur(18px)` **未复刻**：Compose 无等价的
 *    「模糊下层」原语（`Modifier.blur` 作用于节点自身内容，且需 API 31+）。
 *    沿用同仓 `PlanGroupScreen` 对 `.pgd-cta-bar` 的既有取舍——只保留半透明遮罩。
 *
 * 交互（原型脚本 L678-892）：
 * - 1s 计时器推进「总时长」（L711-714）
 * - 「提交」开弹窗（默认 32 KG / 9 次，步进按 `data-min/max` clamp，L864-880）
 * - 「完成本组」写入记录、关弹窗、播放庆祝、360ms 后进度前进（L847-853）
 * - 遮罩点击 / Escape 关弹窗（L855-857 / L860）、Tab 焦点循环（L845-862，见下）
 * - 集满 6 组后，`ft-stage.js` 的 `watchFinish`（L116-125）在 950ms 后跳 `complete`
 *
 * **未复刻**：弹窗内的手写 Tab 焦点循环（L845-862）——那是硬件键盘的无障碍兜底，
 * 触屏不可达；Compose 的默认焦点序已覆盖可聚焦元素。
 */
@Composable
fun ActiveScreen(
    onNavigate: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val store = remember { JsonStore(context.appDataStore) }
    val scope = rememberCoroutineScope()
    val view = LocalView.current

    var elapsed by remember { mutableIntStateOf(0) }
    // 记录区只显示「当前动作」的已完成组（见 FtActiveModel.currentRecords）：
    // 数据源是 workout（唯一真源），不在这里增量累加，避免展示与落库漂移。
    var records by remember { mutableStateOf<List<FtSetRecord>>(emptyList()) }
    var modalOpen by remember { mutableStateOf(false) }
    var weight by remember { mutableIntStateOf(FtActiveModel.WEIGHT_INIT) }
    var reps by remember { mutableIntStateOf(FtActiveModel.REPS_INIT) }
    var celebrate by remember { mutableStateOf(CelebratePhase.None) }
    var justDoneIndex by remember { mutableStateOf<Int?>(null) }
    var target by remember { mutableIntStateOf(FtActiveModel.TARGET) }
    var startedAt by remember { mutableLongStateOf(0L) }
    var workout by remember { mutableStateOf<ActiveWorkoutState?>(null) }
    // 顶部动作切换胶囊选中的动作下标（0 起）。改造前训练页只能停在「首个未录满」动作上，
    // 现在用户可切到任意动作补录；写入、记录区、演示卡、组号都以它为准。
    var selectedIndex by remember { mutableIntStateOf(0) }

    // 设置项消费（计划 A3/A4）：进屏读一次、屏内不再改——「训练中屏幕常亮」与
    // 「声音与震动」共用这一次 loadSettings。
    var keepScreenOn by remember { mutableStateOf(true) }
    var soundVibrationOn by remember { mutableStateOf(true) }
    // 「体重单位」（设置页）：重量基准值始终为 kg，仅输入与展示按单位换算。
    var weightUnit by remember { mutableStateOf(WeightUnit.KG) }

    // 全场进度取活跃训练态（跨动作求和）——records 只含当前动作，不能当全局计数用。
    val completed = workout?.completedSets ?: 0
    // 选中动作：写入、记录区、演示卡、组号全部以它为准（不再是「首个未录满」）。
    val selectedExercise: ActiveWorkoutExercise? = workout?.let { state ->
        state.exercises.getOrNull(selectedIndex) ?: state.exercises.lastOrNull()
    }
    // 提交按钮/记录弹窗的开关判据：选中动作还有空组（切到已录满的动作时不该能开弹窗）
    val selectedCanRecord: Boolean =
        selectedExercise != null && selectedExercise.completedSets < selectedExercise.targetSets
    val submitLabel: FtLabelRes =
        if (selectedCanRecord) FtLabelRes(R.string.active_submit) else FtLabelRes(R.string.active_submit_done)
    // 动作内组号（1 起，录满停在 targetSets）
    val selectedSetNumber: Int =
        selectedExercise?.let { (it.completedSets + 1).coerceAtMost(it.targetSets) } ?: 1

    LaunchedEffect(Unit) {
        val settings = SettingsService.loadSettings(store)
        keepScreenOn = settings.keepScreenOn
        soundVibrationOn = settings.soundVibration
        val unit = UserProfileService.loadProfile(store).weightUnit
        weightUnit = unit
        // 初值以 kg 基准存放（[FtActiveModel.WEIGHT_INIT]），按当前单位换算为显示整数。
        weight = Math.round(WeightUtils.kgToDisplay(FtActiveModel.WEIGHT_INIT.toDouble(), unit)).toInt()
    }

    // 屏幕常亮：View 级 `keepScreenOn`（等价 `FLAG_KEEP_SCREEN_ON` 的视图版，亮屏由窗口管理器
    // 持有、无需权限）；离开本屏（onDispose）即释放，不泄漏。开关关 → 交还系统默认熄屏策略。
    DisposableEffect(keepScreenOn) {
        view.keepScreenOn = keepScreenOn
        onDispose { view.keepScreenOn = false }
    }

    // 训练域接线：进入时优先恢复草稿（鸿蒙「进行中训练重入恢复」）；无草稿 / 无进度 → 全新训练
    // （0 记录），由「当前计划 → 今日训练」编译活跃训练态并落草稿。
    LaunchedEffect(Unit) {
        val draft = WorkoutDraftService.getDraft(store)
        if (draft != null && hasWorkoutDraftProgress(draft)) {
            startedAt = draft.startedAt
            elapsed = ((System.currentTimeMillis() - draft.startedAt) / 1000).toInt().coerceAtLeast(0)
            target = if (draft.totalTargetSets > 0) draft.totalTargetSets else FtActiveModel.TARGET
            val state = draftToActiveState(draft)
            workout = state
            // 胶囊选中态初值：首个未录满动作（= 改造前的「当前动作」口径）；全部录满停在最后一个。
            val unfinished = FtActiveModel.firstUnfinishedIndex(state.exercises)
            selectedIndex = if (unfinished >= 0) unfinished else state.exercises.lastIndex.coerceAtLeast(0)
            records = state.exercises.getOrNull(selectedIndex)
                ?.let { FtActiveModel.recordsFor(state.exercises, it.plannedExerciseId) }
                .orEmpty()
        } else {
            val summary = loadTodayWorkoutPreview(store)
            startedAt = System.currentTimeMillis()
            target = summary.exercises.sumOf { it.targetSets }.takeIf { it > 0 } ?: FtActiveModel.TARGET
            val state = ActiveWorkoutService.createState(summary)
            workout = state
            val unfinished = FtActiveModel.firstUnfinishedIndex(state.exercises)
            selectedIndex = if (unfinished >= 0) unfinished else state.exercises.lastIndex.coerceAtLeast(0)
            records = state.exercises.getOrNull(selectedIndex)
                ?.let { FtActiveModel.recordsFor(state.exercises, it.plannedExerciseId) }
                .orEmpty()
            WorkoutDraftService.saveDraft(store, activeStateToDraft(state, startedAt))
        }
    }

    // 原型 `window.setInterval(…, 1000)`（L711-714）
    LaunchedEffect(Unit) {
        while (true) {
            delay(1000)
            elapsed += 1
        }
    }

    // 原型 `playCelebration()`（L798-812）：1120ms 后转 fading，1500ms 后复位
    fun playCelebration() {
        celebrate = CelebratePhase.Playing
        scope.launch {
            delay(1120)
            celebrate = CelebratePhase.Fading
            delay(1500 - 1120)
            celebrate = CelebratePhase.None
        }
    }

    fun completeSet() {
        val state = workout ?: return
        // 写入选中的动作（不是「首个未录满动作」）——否则用户看着动作 3 却静默记到动作 1。
        val targetExercise = state.exercises.getOrNull(selectedIndex) ?: return
        // 输入框 `weight` 是显示单位下的整数；记录与草稿一律存 kg 基准。
        val weightKg = Math.round(WeightUtils.displayIntToKg(weight, weightUnit)).toInt()
        val origin = if (startedAt > 0L) startedAt else System.currentTimeMillis()
        val progressed = ActiveWorkoutService.recordSetFor(
            state = state,
            plannedExerciseId = targetExercise.plannedExerciseId,
            weightText = weightKg.toString(),
            repsText = reps.toString(),
        )
        modalOpen = false
        if (progressed === state) return // 目标动作已录满：服务原样返回，不落任何写
        workout = progressed
        // 选中的动作刚录满 → 自动前进到下一个未录满动作（保持既有体感）；跳着补录时不被拽走。
        if (targetExercise.completedSets + 1 >= targetExercise.targetSets) {
            val nextIdx = FtActiveModel.firstUnfinishedIndex(progressed.exercises)
            if (nextIdx >= 0) selectedIndex = nextIdx
        }
        records = progressed.exercises.getOrNull(selectedIndex)
            ?.let { FtActiveModel.recordsFor(progressed.exercises, it.plannedExerciseId) }
            .orEmpty()
        // 收尾判据：没有下一个未录满动作（跳着做时 completed 可能先追平，但那只是跳过的动作没做）
        val finished = FtActiveModel.firstUnfinishedIndex(progressed.exercises) < 0
        // 设置项「声音与震动」（计划 A4）：记录推进成功即给一次短促触觉反馈。
        // 音效素材缺失，本期仅震动（计划非目标表）；开关关 → 不响不动。
        if (soundVibrationOn) Haptics.confirm(context)
        modalOpen = false
        playCelebration()
        scope.launch {
            delay(360) // 原型 L850：`setTimeout(…, 360)` 后才 `renderSets(true)`
            justDoneIndex = progressed.completedSets - 1
            delay(FtMotion.DURATION_SEG_POP.toLong())
            justDoneIndex = null
        }
        // 训练域接线：自动保存草稿（对齐鸿蒙 active 页的进行中持久化）；
        // 集满目标则收尾——`createCompletedSession` 产物经 `WorkoutRepository.saveSession`
        // 落 SESSIONS 库，随后清草稿。
        scope.launch {
            WorkoutDraftService.saveDraft(store, activeStateToDraft(progressed, origin))
            if (finished) {
                val endedAt = System.currentTimeMillis()
                val session = ActiveWorkoutService.createCompletedSession(
                    sessionId = "session_$endedAt",
                    state = progressed,
                    startedAt = origin,
                    endedAt = endedAt,
                    completedSets = progressed.completedSets,
                )
                WorkoutRepository.saveSession(store, session)
                WorkoutDraftService.clearDraft(store)
                // 成就提醒（A6）：保存后检查连续训练里程碑——内部全静默，不阻塞训练流程
                checkAndNotifyAchievement(store, context)
                // ft-stage.js `watchFinish`：完成本组后 950ms，若标签已是「训练完成」则跳 complete
                delay(950)
                onNavigate("complete")
            }
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(FtColor.ink0), // `.wo-screen` 底 var(--ink-0)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            ActiveTop(
                exerciseName = selectedExercise?.name
                    ?: stringResource(R.string.active_fallback_exercise),
                clock = FtActiveModel.formatClock(elapsed),
                exercises = workout?.exercises.orEmpty(),
                selectedIndex = selectedIndex,
                onSelect = { index ->
                    selectedIndex = index
                    val exercises = workout?.exercises.orEmpty()
                    exercises.getOrNull(index)?.let { exercise ->
                        records = FtActiveModel.recordsFor(exercises, exercise.plannedExerciseId)
                    }
                },
            )

            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()), // `.wo-scroll`
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 18.dp, end = 18.dp, top = 16.dp, bottom = 24.dp), // `.wo-content`
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    DemoCard(workout = workout, selectedIndex = selectedIndex)
                    SetList(records = records, weightUnit = weightUnit)
                }
            }

            Dock(
                label = stringResource(submitLabel.res, *submitLabel.args.toTypedArray()),
                enabled = selectedCanRecord,
                onClick = { modalOpen = true },
            )
        }

        if (modalOpen) {
            RecordModal(
                setNumber = selectedSetNumber,
                exerciseName = selectedExercise?.name
                    ?: stringResource(R.string.active_fallback_exercise), // 选中动作名
                weight = weight,
                reps = reps,
                weightUnit = weightUnit,
                onWeight = {
                    // 步进在显示单位下进行（kg 时 ±1 kg、lbs 时 ±1 lbs）。
                    val minDisplay = Math.round(WeightUtils.kgToDisplay(FtActiveModel.WEIGHT_MIN.toDouble(), weightUnit)).toInt()
                    val maxDisplay = Math.round(WeightUtils.kgToDisplay(FtActiveModel.WEIGHT_MAX.toDouble(), weightUnit)).toInt()
                    weight = FtActiveModel.stepValue(weight, it, min = minDisplay, max = maxDisplay)
                },
                onReps = { reps = FtActiveModel.stepValue(reps, it, min = FtActiveModel.REPS_MIN, max = FtActiveModel.REPS_MAX) },
                onClose = { modalOpen = false },
                onComplete = ::completeSet,
            )
        }

        if (celebrate != CelebratePhase.None) {
            Celebration(phase = celebrate)
        }
    }
}

/** 庆祝动画的相位（原型 `.celebrate` 的 `playing` / `fading` 类，L798-812）。 */
private enum class CelebratePhase { None, Playing, Fading }

// ── 顶栏与进度条 ─────────────────────────────────────────────────

/**
 * `.wo-top`：收起按钮 + 当前动作名（大字）+ 右端计时器，下方一行动作切换胶囊。
 *
 * 与改造前的差别：去掉「第 N 组 / 共 M 组」与全场分格进度条——组号改由演示卡显示（动作内序号），
 * 全场进度由每个胶囊内的组进度承载。顶部因此只剩一层进度语义，动作维度第一次可见。
 */
@Composable
private fun ActiveTop(
    exerciseName: String,
    clock: String,
    exercises: List<ActiveWorkoutExercise>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(TopFill) // rgba(10,13,18,.96)
            // 真机 edge-to-edge：内容需避开系统状态栏（原型把状态栏区域画在设备框外）
            .windowInsetsPadding(WindowInsets.statusBars)
            .padding(start = 18.dp, end = 18.dp, top = 10.dp, bottom = 10.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(44.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CollapseButton()
            Text(
                text = exerciseName,
                style = FtType.natural(20f, 700),
                color = FtColor.txtHi,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f),
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                LiveDot()
                Text(
                    text = stringResource(R.string.active_elapsed_label),
                    style = FtType.natural(11.5f),
                    color = FtColor.white60,
                )
                Text(
                    text = clock,
                    style = FtType.natural(14f, 700, FtType.mono),
                    color = FtColor.txtHi,
                )
            }
        }

        Box(modifier = Modifier.height(10.dp))

        ExerciseTabs(exercises = exercises, selectedIndex = selectedIndex, onSelect = onSelect)
    }
}

/**
 * 收起按钮：纯线条 chevron-down，无底色块、无描边底、无常驻圆底（参考图左上角）。
 *
 * 返回走 `OnBackPressedDispatcher`，与系统返回键同一路径——不引入新的「折叠训练」状态。
 */
@Composable
private fun CollapseButton() {
    val dispatcher = LocalOnBackPressedDispatcherOwner.current?.onBackPressedDispatcher
    val collapseLabel = stringResource(R.string.active_collapse)
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) FtMotion.PRESS_SCALE_ICON_BTN else 1f,
        animationSpec = tween(FtMotion.DURATION_PRESS),
        label = "collapsePress",
    )
    Box(
        modifier = Modifier
            .size(44.dp)
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(FtShape.pill)
            .clickable(interactionSource = interaction, indication = null) { dispatcher?.onBackPressed() }
            .semantics { contentDescription = collapseLabel },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.size(24.dp)) {
            val path = Path().apply {
                moveTo(size.width * 0.25f, size.height * 0.40f)
                lineTo(size.width * 0.50f, size.height * 0.64f)
                lineTo(size.width * 0.75f, size.height * 0.40f)
            }
            drawPath(
                path = path,
                color = FtColor.accent,
                style = Stroke(width = 2.2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round),
            )
        }
    }
}

/**
 * 动作切换条：本次训练的每个动作一个胶囊，等分铺满。
 *
 * 超过 4 个动作时胶囊会变窄，但仍能容下「动作N」三字——比横向滚动少一次手势，
 * 且训练中只需要「看见有几个动作、现在在第几个」。
 */
@Composable
private fun ExerciseTabs(
    exercises: List<ActiveWorkoutExercise>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
) {
    if (exercises.isEmpty()) return
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        exercises.forEachIndexed { index, _ ->
            ExercisePill(
                label = stringResource(R.string.active_exercise_tab, index + 1),
                progress = FtActiveModel.exerciseProgress(exercises, index),
                selected = index == selectedIndex,
                modifier = Modifier.weight(1f),
                onClick = { onSelect(index) },
            )
        }
    }
}

/**
 * 单个动作胶囊：选中态用虚线强调，胶囊内底部细条承载该动作的组进度。
 *
 * 进度条放在胶囊内底部而不是用背景填充：填充式会让 12sp 文字压在亮色上，
 * 选中/未选中的对比反而失效。
 */
@Composable
private fun ExercisePill(
    label: String,
    progress: Float,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier = modifier
            .height(30.dp)
            .clip(FtShape.pill)
            .background(if (selected) FtColor.accent.copy(alpha = 0.10f) else FtColor.glass8)
            .then(
                if (selected) {
                    // Compose 的 Modifier.border 不支持虚线，用 drawBehind 手绘描边
                    Modifier.drawBehind {
                        drawRoundRect(
                            color = FtColor.accent,
                            topLeft = Offset.Zero,
                            size = Size(size.width, size.height),
                            cornerRadius = CornerRadius(size.height / 2f, size.height / 2f),
                            style = Stroke(
                                width = 1.2.dp.toPx(),
                                pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 4f)),
                            ),
                        )
                    }
                } else {
                    Modifier.border(1.dp, FtColor.line10, FtShape.pill)
                },
            )
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = FtType.natural(12f, if (selected) 700 else 400),
            color = if (selected) FtColor.accent else FtColor.white70,
            maxLines = 1,
        )
        Row(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .fillMaxWidth()
                .padding(start = 6.dp, end = 6.dp, bottom = 5.dp)
                .height(2.5.dp)
                .clip(FtShape.pill)
                .background(FtColor.glass8),
        ) {
            val done = progress.coerceIn(0f, 1f)
            if (done > 0f) {
                Box(
                    modifier = Modifier
                        .weight(done)
                        .height(2.5.dp)
                        .background(FtColor.accent),
                )
            }
            if (done < 1f) {
                Box(modifier = Modifier.weight(1f - done))
            }
        }
    }
}

/** `.top-timer .live-dot` L201-206：6px 圆点，`livePulse` 1.6s 循环。 */
@Composable
private fun LiveDot() {
    val pulse = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        pulse.animateTo(
            targetValue = 1f,
            animationSpec = androidx.compose.animation.core.infiniteRepeatable(
                animation = tween(FtMotion.DURATION_PULSE, easing = androidx.compose.animation.core.LinearEasing),
                repeatMode = androidx.compose.animation.core.RepeatMode.Reverse,
            ),
        )
    }
    // livePulse：0%/100% opacity 1 scale 1；50% opacity .45 scale .78
    val alpha = 1f - 0.55f * pulse.value
    val scale = 1f - 0.22f * pulse.value
    Box(
        modifier = Modifier
            .requiredSize(6.dp)
            .graphicsLayer {
                this.alpha = alpha
                scaleX = scale
                scaleY = scale
            }
            .clip(FtShape.pill)
            .background(FtColor.accent),
    )
}

/**
 * 单格进度（`.duo-seg` / `.done` / `.current` / `.just-done`，L208-228 + L905-921）。
 *
 * `.current` 的 `box-shadow: 0 0 0 2px rgba(80,236,167,.12)` 用 [drawBehind] 画外环，
 * 不占布局（box-shadow 同样不影响布局）；`.duo-marker` 18px 圆点用 [requiredSize]
 * 突破父级 12px 高度约束、居中溢出（原型为绝对定位）。
 */
@Composable
private fun DuoSegment(
    role: FtSegRole,
    justDone: Boolean,
    modifier: Modifier = Modifier,
) {
    val ringPx = with(LocalDensity.current) { 2.dp.toPx() }

    // `.duo-seg.just-done { animation: segPop .46s }`：0%→1、40%→1.12、100%→1
    val pop = remember { Animatable(1f) }
    LaunchedEffect(justDone) {
        if (justDone) {
            pop.animateTo(1.12f, tween(FtMotion.DURATION_SEG_POP * 40 / 100, easing = FtMotion.EASE_MOTION))
            pop.animateTo(1f, tween(FtMotion.DURATION_SEG_POP * 60 / 100, easing = FtMotion.EASE_MOTION))
        } else {
            pop.snapTo(1f)
        }
    }

    val fill = when (role) {
        FtSegRole.Done -> FtColor.accent
        FtSegRole.Current -> SegCurrentFill
        FtSegRole.Plain -> SegFill
    }
    val line = when (role) {
        FtSegRole.Done -> FtColor.accent
        FtSegRole.Current -> SegCurrentBorder
        FtSegRole.Plain -> SegBorder
    }

    Box(
        modifier = modifier
            .graphicsLayer {
                scaleX = pop.value
                scaleY = pop.value
            }
            .drawBehind {
                if (role == FtSegRole.Current) {
                    val r = (size.height + ringPx * 2f) / 2f
                    drawRoundRect(
                        color = SegCurrentRing,
                        topLeft = Offset(-ringPx, -ringPx),
                        size = Size(size.width + ringPx * 2f, size.height + ringPx * 2f),
                        cornerRadius = CornerRadius(r, r),
                    )
                }
            }
            .clip(FtShape.pill)
            .background(fill)
            .border(1.dp, line, FtShape.pill),
        contentAlignment = Alignment.Center,
    ) {
        if (role == FtSegRole.Current) {
            DuoMarker()
        }
    }
}

/** `.duo-marker` L220-228：18px 实心圆 + 3px `--ink-0` 描边，`markerPop .3s`。 */
@Composable
private fun DuoMarker() {
    val pop = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        pop.animateTo(1f, tween(FtMotion.DURATION_MARKER, easing = FtMotion.EASE_MOTION))
    }
    Box(
        modifier = Modifier
            .requiredSize(18.dp)
            .graphicsLayer {
                val s = 0.4f + 0.6f * pop.value
                scaleX = s
                scaleY = s
                alpha = pop.value
            }
            .clip(FtShape.pill)
            .background(FtColor.accent)
            .border(3.dp, FtColor.ink0, FtShape.pill),
    )
}

// ── 动作演示卡 ──────────────────────────────────────────────────

/**
 * `.demo-card` L234-296：230 高的演示卡，左上角动作序号、底部动作名与阶段。
 *
 * 卡底色与描边取样式表末尾的「Card Surface v1」（L538）。
 */
@Composable
private fun DemoCard(workout: ActiveWorkoutState?, selectedIndex: Int) {
    // 当前动作 = 顶部胶囊选中的动作；下标越界/无数据时回退「首个未录满」，再回退末个。
    val exercises = workout?.exercises.orEmpty()
    val currentIndex = if (selectedIndex in exercises.indices) {
        selectedIndex
    } else {
        exercises.indexOfFirst { it.completedSets < it.targetSets }
            .let { if (it >= 0) it else exercises.lastIndex.coerceAtLeast(0) }
    }
    val current = exercises.getOrNull(currentIndex)
    val demoName = current?.name ?: stringResource(R.string.active_fallback_exercise)
    val demoBadgeIndex = if (workout != null && exercises.isNotEmpty()) {
        "${currentIndex + 1} / ${exercises.size}"
    } else {
        "1 / 4"
    }
    val currentStageNumber = current?.let { (it.completedSets + 1).coerceAtMost(it.targetSets) } ?: 2
    val demoStage = stringResource(R.string.active_demo_stage, currentStageNumber)
    val demoGif = current?.let { FtLibraryModel.gifAssetFor(it.plannedExerciseId, it.name) }
    val demoVisualA11y = stringResource(R.string.active_a11y_demo_visual, demoName)

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(230.dp)
            .clip(RoundedCornerShape(28.dp))
            .background(DemoCardFill)
            .border(1.dp, FtColor.line10, RoundedCornerShape(28.dp)),
    ) {
        // 当前动作有 GIF 素材 → 播放真实动作演示（Coil；素材映射见 FtLibraryModel）；无素材/加载失败 → 回落矢量示意
        ExerciseGif(
            gifAsset = demoGif,
            iconSize = 40.dp,
            fill = FtColor.glass8,
            contentDescription = stringResource(R.string.active_a11y_demo_gif, demoName),
            contentScale = ContentScale.Fit, // Fit：完整显示全身（Crop 会裁掉上下，2026-10-09 验收反馈）
            fallback = {
                BenchPressVisual(
                    modifier = Modifier
                        .fillMaxSize()
                        .semantics { contentDescription = demoVisualA11y },
                )
            },
        )

        Row(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(start = 14.dp, top = 14.dp) // `.demo-position { top:14px; left:14px }`
                .clip(FtShape.pill)
                .background(OverlayBadgeFill)
                .border(1.dp, FtColor.line10, FtShape.pill)
                .padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = stringResource(R.string.active_demo_label),
                style = FtType.natural(11f),
                color = FtColor.white60,
            )
            Text(
                text = demoBadgeIndex, // 当前动作序号 / 总数（原静态 1/4）
                style = FtType.natural(12f, 700, FtType.mono),
                color = FtColor.accent,
            )
        }

        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(start = 14.dp, end = 14.dp, bottom = 14.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(OverlayBadgeFill)
                .border(1.dp, FtColor.glass8, RoundedCornerShape(16.dp))
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = demoName, // 当前动作名（原静态「杠铃卧推」）
                style = FtType.natural(18f, 700),
                color = FtColor.txtHi,
            )
            Text(
                text = demoStage, // 当前组号（原静态「第 2 组 · 正式组」）
                style = FtType.natural(12f, 700),
                color = FtColor.accent,
            )
        }
    }
}

/**
 * `.demo-visual` L250-285：viewBox `0 0 360 230`、`preserveAspectRatio="none"` 的杠铃卧推矢量图。
 *
 * 三段渐变（`benchGrad` / `barGrad` / `plateGrad`）用 Compose 画刷复刻；
 * `preserveAspectRatio="none"` 意味着 x/y 独立拉伸，故横纵各用一套比例尺。
 */
@Composable
private fun BenchPressVisual(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val kx = size.width / 360f
        val ky = size.height / 230f
        fun px(v: Float) = v * kx
        fun py(v: Float) = v * ky

        // benchGrad：竖直 #2A3934 → #16211F，作用于 y158..170 的矩形
        drawRoundRect(
            brush = Brush.verticalGradient(
                colors = listOf(BenchTop, BenchBottom),
                startY = py(158f),
                endY = py(170f),
            ),
            topLeft = Offset(px(42f), py(158f)),
            size = Size(px(276f), py(12f)),
            cornerRadius = CornerRadius(px(6f), py(6f)),
        )
        // 两条凳腿 #101816
        listOf(66f, 282f).forEach { x ->
            drawRoundRect(
                color = LegFill,
                topLeft = Offset(px(x), py(170f)),
                size = Size(px(12f), py(36f)),
                cornerRadius = CornerRadius(px(4f), py(4f)),
            )
        }

        // 卧推者剪影：fill #0D1117 + stroke rgba(80,236,167,.16) width 2
        val bodyStroke = Stroke(width = px(2f))
        drawCircle(BodyFill, radius = px(16f), center = Offset(px(176f), py(72f)))
        drawCircle(BodyStrokeAccent, radius = px(16f), center = Offset(px(176f), py(72f)), style = bodyStroke)
        drawRoundRect(
            color = BodyFill,
            topLeft = Offset(px(164f), py(88f)),
            size = Size(px(24f), py(62f)),
            cornerRadius = CornerRadius(px(12f), py(12f)),
        )
        drawRoundRect(
            color = BodyStrokeAccent,
            topLeft = Offset(px(164f), py(88f)),
            size = Size(px(24f), py(62f)),
            cornerRadius = CornerRadius(px(12f), py(12f)),
            style = bodyStroke,
        )
        // 双臂：粗 12 的圆头深色描边（原型以 stroke 画肢体）
        val armStroke = Stroke(width = px(12f), cap = StrokeCap.Round, join = StrokeJoin.Round)
        drawPath(
            Path().apply { moveTo(px(168f), py(100f)); lineTo(px(150f), py(108f)) },
            color = BodyFill,
            style = armStroke,
        )
        drawPath(
            Path().apply { moveTo(px(184f), py(100f)); lineTo(px(202f), py(108f)) },
            color = BodyFill,
            style = armStroke,
        )
        listOf(188f, 256f).forEach { x ->
            drawRoundRect(
                color = BodyFill,
                topLeft = Offset(px(x), py(142f)),
                size = Size(px(64f), py(15f)),
                cornerRadius = CornerRadius(px(7f), py(7f)),
            )
        }

        // barGrad：#7E8F96 → #3B4A45，作用于 y100..108 的杠铃杆
        drawRoundRect(
            brush = Brush.verticalGradient(
                colors = listOf(BarTop, BarBottom),
                startY = py(100f),
                endY = py(108f),
            ),
            topLeft = Offset(px(24f), py(100f)),
            size = Size(px(312f), py(8f)),
            cornerRadius = CornerRadius(px(4f), py(4f)),
        )

        // 四片杠铃片：radialGradient（objectBoundingBox cx/cy .35、r .9）+ #0B0F13 描边
        listOf(40f to 17f, 58f to 14f, 320f to 17f, 302f to 14f).forEach { (cx, r) ->
            val radius = px(r)
            val center = Offset(px(cx), py(104f))
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(PlateInner, PlateMid, PlateOuter),
                    center = Offset(center.x - 0.3f * radius, center.y - 0.3f * radius),
                    radius = 1.8f * radius,
                ),
                radius = radius,
                center = center,
            )
            drawCircle(
                color = PlateStroke,
                radius = radius,
                center = center,
                style = Stroke(width = px(1.5f)),
            )
        }
    }
}

// ── 已完成组列表 ────────────────────────────────────────────────

/**
 * `.set-count` / `.set-list` L298-331：已完成组逐条列出，条间 10px。
 *
 * 只列「当前动作」的组（见 [FtActiveModel.currentRecords]）：切到下一个动作后列表重新开始，
 * 组号是动作内序号。当前动作还没有完成组时回退到 `.set-empty` 空态。
 */
@Composable
private fun SetList(records: List<FtSetRecord>, weightUnit: WeightUnit) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp), // `.set-list { gap: 10px }`
    ) {
        if (records.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, FtColor.line10, RoundedCornerShape(14.dp))
                    .padding(16.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = stringResource(R.string.active_empty_sets),
                    style = FtType.natural(13f),
                    color = FtColor.white54,
                )
            }
        } else {
            records.forEach { record ->
                SetRecordRow(record = record, weightUnit = weightUnit)
            }
        }
    }
}

/** `.set-record` L312-322：`recordIn .18s` 入场（透明上移 6px → 不透明归位）。 */
@Composable
private fun SetRecordRow(record: FtSetRecord, weightUnit: WeightUnit) {
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    val progress by animateFloatAsState(
        targetValue = if (appeared) 1f else 0f,
        animationSpec = tween(FtMotion.DURATION_RECORD),
    )
    val density = LocalDensity.current
    val slidePx = with(density) { 6.dp.toPx() }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer {
                alpha = progress
                translationY = (1f - progress) * slidePx
            }
            .height(44.dp) // `min-height: 44px`
            .clip(RoundedCornerShape(12.dp))
            .border(1.dp, FtColor.glass8, RoundedCornerShape(12.dp))
            .padding(horizontal = 12.dp), // `padding: 10px 12px`
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = stringResource(R.string.active_set_index, record.setNumber),
            style = FtType.natural(13f),
            color = FtColor.white70,
        )
        Text(
            text = "${Math.round(WeightUtils.kgToDisplay(record.weight.toDouble(), weightUnit))} ${WeightUtils.unitLabel(weightUnit)} × ${record.reps}",
            style = FtType.natural(14f, 700, FtType.mono),
            color = FtColor.txtHi,
        )
        Text(
            text = "✓",
            style = FtType.natural(13f, 700),
            color = FtColor.accent,
        )
    }
}

// ── 底部提交栏 ──────────────────────────────────────────────────

/** `.wo-dock` / `.wo-btn-primary` L333-360：18 内边距、底部分隔线、50 高的主按钮。 */
@Composable
private fun Dock(label: String, enabled: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(DockFill) // rgba(10,13,18,.98)
            // 系统手势区避让：按钮不再贴着底部手势条（2026-10-09 反馈「按钮太靠下」）
            .windowInsetsPadding(WindowInsets.navigationBars)
            .padding(start = 18.dp, end = 18.dp, top = 12.dp, bottom = 18.dp),
    ) {
        PrimaryButton(
            label = label,
            enabled = enabled,
            onClick = onClick,
        )
    }
}

/**
 * `.wo-btn-primary`：50 高、圆角 16、翡翠底；`:disabled` 换 `rgba(255,255,255,.06)` 底
 * 与 `--white-40` 文案、去阴影；`:active` 缩到 .985。
 */
@Composable
private fun PrimaryButton(
    label: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(16.dp)
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    // Duolingo 硬边厚底：主按钮只用「厚底收平 + 下沉」，不参与缩放。
    // 此前用 `usesPressDepth = enabled` 去门控 scale：enabled 为真时门恒真、为假时
    // 条件里的 enabled 又为假，两个分支都取 1f——是条死分支，直接删掉更清楚。
    val depth = if (enabled && !pressed) DuTokens.PRESS_DEPTH else 0.dp
    val shift = if (enabled && pressed) DuTokens.PRESS_SHIFT else 0.dp

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(50.dp)
            .graphicsLayer {
                translationY = shift.toPx()
            }
            // 有硬边厚底时不再叠模糊阴影——硬边 + 软影两套深度线索同时出现会显脏
            .clip(shape)
            .background(if (enabled) FtColor.accent else FtColor.glass6)
            // 硬边厚底（零模糊）：画在按钮面之上，由 clip 收进圆角
            .drawBehind {
                if (depth.value > 0f) {
                    val thickness = depth.toPx()
                    drawRect(
                        color = FtColor.accentDeep,
                        topLeft = Offset(0f, size.height - thickness),
                        size = Size(size.width, thickness),
                    )
                }
            }
            // 内容避让厚底，按钮总高不变
            .padding(bottom = depth)
            .clickable(
                interactionSource = interaction,
                indication = null,
                enabled = enabled,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = FtType.natural(15f, 700),
            color = if (enabled) FtColor.onAccent else FtColor.white40,
        )
    }
}

// ── 记录本组弹窗 ────────────────────────────────────────────────

/**
 * `.modal` L362-441：遮罩 + 居中卡片。
 *
 * 遮罩点击关闭（原型 L855-857 只在 `e.target === modal` 时关闭，故卡片自己吞掉点击）、
 * Escape 关闭（L860）。卡片的 `modalIn .22s` 入场与遮罩的 `backdropIn .22s` 同长。
 */
@Composable
private fun RecordModal(
    setNumber: Int,
    exerciseName: String,
    weight: Int,
    reps: Int,
    weightUnit: WeightUnit,
    onWeight: (Int) -> Unit,
    onReps: (Int) -> Unit,
    onClose: () -> Unit,
    onComplete: () -> Unit,
) {
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    Box(modifier = Modifier.fillMaxSize()) {
        // 遮罩：点击空白处关闭
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(ModalScrim)
                .clickableNoRipple(onClick = onClose),
        )

        Box(
            modifier = Modifier
                .align(Alignment.Center)
                .fillMaxWidth()
                .padding(horizontal = 24.dp) // `.modal { padding: 24px }`
                .widthIn(max = 342.dp)
                .focusRequester(focusRequester)
                .focusable()
                .onPreviewKeyEvent { event ->
                    if (event.type == KeyEventType.KeyDown && event.key == Key.Escape) {
                        onClose()
                        true
                    } else {
                        false
                    }
                }
                // 卡片吞掉点击，避免透传到遮罩（原型 `e.target === modal` 才关闭）
                .pointerInput(Unit) { detectTapGestures { } },
        ) {
            ModalCard(
                setNumber = setNumber,
                exerciseName = exerciseName,
                weight = weight,
                reps = reps,
                weightUnit = weightUnit,
                onWeight = onWeight,
                onReps = onReps,
                onClose = onClose,
                onComplete = onComplete,
            )
        }
    }
}

/** `.modal-card` L380-395：342 上限、圆角 28、`modalIn .22s`入场。 */
@Composable
private fun ModalCard(
    setNumber: Int,
    exerciseName: String,
    weight: Int,
    reps: Int,
    weightUnit: WeightUnit,
    onWeight: (Int) -> Unit,
    onReps: (Int) -> Unit,
    onClose: () -> Unit,
    onComplete: () -> Unit,
) {
    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) { progress.animateTo(1f, tween(FtMotion.DURATION_OVERLAY, easing = FtMotion.EASE_MOTION)) }
    val closeA11y = stringResource(R.string.active_a11y_close_modal)

    Box(
        modifier = Modifier
            .graphicsLayer {
                alpha = progress.value
                val s = 0.98f + 0.02f * progress.value
                scaleX = s
                scaleY = s
                translationY = (1f - progress.value) * 12.dp.toPx()
            }
            .clip(RoundedCornerShape(28.dp))
            .background(ModalCardFill)
            .border(1.dp, FtColor.line10, RoundedCornerShape(28.dp))
            .shadow(0.dp, RoundedCornerShape(28.dp))
            .padding(20.dp), // `.modal-card { padding: 20px }`
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = stringResource(R.string.active_modal_eyebrow),
                        style = FtType.natural(10f, 400, FtType.mono).copy(letterSpacing = 0.8.sp), // .08em × 10px
                        color = FtColor.accent,
                    )
                    Text(
                        text = stringResource(R.string.active_modal_title),
                        modifier = Modifier.padding(top = 6.dp),
                        color = FtColor.txtHi,
                        fontSize = 22.sp,
                        lineHeight = 26.4.sp, // 1.2 × 22px（原型显式声明）
                        fontWeight = FontWeight.Bold,
                    )
                    Text(
                        text = stringResource(R.string.active_modal_subtitle, exerciseName, setNumber), // 当前动作名（原静态「杠铃卧推」，2026-10-09 验收后动态化）
                        modifier = Modifier.padding(top = 4.dp),
                        style = FtType.natural(13f),
                        color = FtColor.white60,
                    )
                }
                Box(
                    modifier = Modifier
                        .requiredSize(36.dp)
                        .clip(FtShape.pill)
                        .background(FtColor.glass4)
                        .border(1.dp, FtColor.glass8, FtShape.pill)
                        .semantics { contentDescription = closeA11y } // 原型 `aria-label`（L634）
                        .clickableNoRipple(onClick = onClose),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "×",
                        color = FtColor.white70,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Normal,
                        textAlign = TextAlign.Center,
                    )
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 18.dp, bottom = 16.dp), // `.modal-fields { margin: 18px 0 16px }`
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                StepperBox(
                    label = stringResource(R.string.active_field_weight),
                    unit = WeightUtils.unitLabel(weightUnit).uppercase(),
                    value = weight,
                    onDelta = onWeight,
                    modifier = Modifier.weight(1f),
                )
                StepperBox(
                    label = stringResource(R.string.active_field_reps),
                    unit = stringResource(R.string.active_field_reps_unit),
                    value = reps,
                    onDelta = onReps,
                    modifier = Modifier.weight(1f),
                )
            }

            PrimaryButton(
                label = stringResource(R.string.active_action_complete_set),
                enabled = true,
                onClick = onComplete,
            )
        }
    }
}

/** `.input-box` / `.stepper` L420-457：字段标签 + 单位 + 「− 值 +」步进。 */
@Composable
private fun StepperBox(
    label: String,
    unit: String,
    value: Int,
    onDelta: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(17.dp))
            .background(InputBoxFill) // rgba(255,255,255,.0235)
            .border(1.dp, FtColor.hairline, RoundedCornerShape(17.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp), // `.input-box { gap: 8px }`
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = label,
                style = FtType.natural(12f),
                color = FtColor.white60,
            )
            Text(
                text = unit,
                style = FtType.natural(10f, 400, FtType.mono),
                color = FtColor.accent,
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            StepButton(
                glyph = "−",
                contentDescription = stringResource(R.string.active_a11y_decrease, label),
                onClick = { onDelta(-1) },
            )
            Text(
                text = "$value",
                color = FtColor.txtHi,
                fontSize = 24.sp,
                lineHeight = 24.sp, // 1 × 24px（原型显式声明）
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            StepButton(
                glyph = "+",
                contentDescription = stringResource(R.string.active_a11y_increase, label),
                onClick = { onDelta(1) },
            )
        }
    }
}

/** `.stepper .step` L439-452：36×36、圆角 10。 */
@Composable
private fun StepButton(glyph: String, contentDescription: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .requiredSize(36.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(StepFill) // rgba(255,255,255,.031)
            .border(1.dp, FtColor.hairline, RoundedCornerShape(10.dp))
            .semantics { this.contentDescription = contentDescription }
            .clickableNoRipple(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = glyph,
            color = FtColor.white60,
            fontSize = 16.sp,
            lineHeight = 16.sp,
        )
    }
}

// ── 完成组庆祝动画 ──────────────────────────────────────────────

/**
 * `.celebrate` L458-530：半透明遮罩 + 36 个彩带粒子 + 中央对勾。
 *
 * 相位曲线（原型 L798-812）：`playing` 1120ms → `fading` 至 1500ms → 复位。
 * 彩带 36 枚按 [FtActiveModel.confetti] 的几何飞散，每枚各自时长/延迟/配色。
 */
@Composable
private fun Celebration(phase: CelebratePhase) {
    val particles = remember { FtActiveModel.confetti { Random.nextFloat() } }

    // 遮罩 fade：veilIn .22s / veilOut .3s（原型 L469-476）
    val veil = remember { Animatable(0f) }
    LaunchedEffect(phase) {
        when (phase) {
            CelebratePhase.Playing -> veil.animateTo(1f, tween(FtMotion.DURATION_OVERLAY, easing = FtMotion.EASE_MOTION))
            CelebratePhase.Fading -> veil.animateTo(0f, tween(FtMotion.DURATION_MARKER, easing = FtMotion.EASE_MOTION))
            CelebratePhase.None -> Unit
        }
    }

    // 粒子：以一条线性时钟统一驱动，逐枚按自身 delay/duration 取切片
    val totalMs = remember(particles) {
        particles.maxOf { it.delaySeconds + it.durationSeconds } * 1000f
    }
    val clock = remember { Animatable(0f) }
    LaunchedEffect(particles) {
        clock.snapTo(0f)
        clock.animateTo(
            targetValue = totalMs,
            animationSpec = tween(totalMs.toInt(), easing = androidx.compose.animation.core.LinearEasing),
        )
    }

    // 中央对勾 `coreIn .46s .06s`（原型 L495-503）
    val core = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        delay(60)
        core.animateTo(1f, tween(FtMotion.DURATION_CORE, easing = FtMotion.EASE_MOTION))
    }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .graphicsLayer { alpha = veil.value }
            .background(CelebrateScrim), // rgba(11,15,19,.55)
    ) {
        ConfettiLayer(particles = particles, clock = clock.value, totalMs = totalMs)

        Column(
            modifier = Modifier
                .align(Alignment.Center)
                // `.celebrate-core { top: 40% }`：中心在屏高 40%（按实际高度取比例，替代硬编码 844 基准）
                .offset(y = -(maxHeight * 0.10f))
                .graphicsLayer {
                    val s = 0.72f + 0.33f * core.value
                    scaleX = s
                    scaleY = s
                    alpha = core.value
                },
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .requiredSize(88.dp)
                    .drawBehind {
                        // box-shadow: 0 0 0 16px accent07, 0 0 54px 20px accent20
                        drawCircle(FtColor.accent07, radius = size.minDimension / 2f + 16.dp.toPx())
                    }
                    .clip(FtShape.pill)
                    .background(FtColor.accent),
                contentAlignment = Alignment.Center,
            ) {
                CheckGlyph(modifier = Modifier.requiredSize(42.dp), color = FtColor.onAccent)
            }
            Text(
                text = stringResource(R.string.active_celebrate_title),
                modifier = Modifier.padding(top = 12.dp),
                style = FtType.natural(21f, 700).copy(letterSpacing = 0.42.sp), // .02em × 21px
                color = FtColor.txtHi,
            )
            Text(
                text = stringResource(R.string.active_celebrate_subtitle),
                modifier = Modifier.offset(y = (-5).dp), // `.celebrate-sub { margin-top: -5px }`
                style = FtType.natural(14f, 500).copy(letterSpacing = 0.28.sp), // .02em × 14px
                color = FtColor.white70,
            )
        }
    }
}

/** 彩带层：36 枚粒子各自按 `clock` 的切片求进度（原型 `.celebrate-particles`）。 */
@Composable
private fun ConfettiLayer(
    particles: List<FtConfetti>,
    clock: Float,
    totalMs: Float,
) {
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        // `.confetti { left: 50%; top: 42% }`：起点是父容器的百分比（原型 px 值 195/354 只是 390×844 视口下的等价值）
        val originX = maxWidth * 0.5f
        val originY = maxHeight * 0.42f
        particles.forEach { p ->
            val delayMs = p.delaySeconds * 1000f
            val durMs = p.durationSeconds * 1000f
            val local = ((clock - delayMs) / durMs).coerceIn(0f, 1f)
            // confettiFly 的位移/缩放/旋转沿 cubic-bezier(.16,.7,.3,1)（原型 animation-timing-function）
            val eased = ConfettiEase.transform(local)
            // opacity 关键帧：0%→0；10%→1；100%→0
            val alpha = if (local <= 0.1f) local / 0.1f else 1f - (local - 0.1f) / 0.9f
            val scale = 0.45f + 0.55f * eased
            val rot = p.rotationDeg * eased

            Box(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .offset(
                        // 原型 `translate(-50%,-50%)`：以元素中心对齐起点，故各减半尺寸（8×14 → 4/7）
                        x = originX + (p.offsetX * eased).dp - 4.dp,
                        y = originY + (p.offsetY * eased).dp - 7.dp,
                    )
                    .requiredSize(width = 8.dp, height = 14.dp)
                    .graphicsLayer {
                        this.alpha = alpha
                        scaleX = scale
                        scaleY = scale
                        rotationZ = rot
                    }
                    .clip(RoundedCornerShape(2.dp))
                    .background(ConfettiColors[p.colorIndex]),
            )
        }
    }
}

/** 原型 `.confetti` 的 `animation: confettiFly 1.1s cubic-bezier(.16, .7, .3, 1)`。 */
private val ConfettiEase = CubicBezierEasing(0.16f, 0.7f, 0.3f, 1f)

/** `path M5 12.5l4.2 4.2L19 7`，描边 3、圆头（原型 L663 的庆祝对勾）。 */
@Composable
private fun CheckGlyph(modifier: Modifier = Modifier, color: Color = Color.Unspecified) {
    Canvas(modifier = modifier) {
        val k = size.minDimension / 24f
        val path = Path().apply {
            moveTo(5f * k, 12.5f * k)
            lineTo(9.2f * k, 16.7f * k)
            lineTo(19f * k, 7f * k)
        }
        drawPath(path, color, style = Stroke(3f * k, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }
}

// ── 屏内色值（原型 `:root` 无对应令牌，按 FtColorUtil 规则就地换算） ──
//
// 换算规则 AA = round(alpha × 255)

/** `.wo-top` 底 `rgba(10,13,18,.96)` → round(244.8) = 245 = 0xF5 */
private val TopFill = Color(0xF50A0D12)

/** `.wo-dock` 底 `rgba(10,13,18,.98)` → round(249.9) = 250 = 0xFA */
private val DockFill = Color(0xFA0A0D12)

/** `.duo-seg` 底 `rgba(255,255,255,.07)` → round(17.85) = 18 = 0x12 */
private val SegFill = Color(0x12FFFFFF)

/** `.duo-seg` 描边 `rgba(255,255,255,.05)` → round(12.75) = 13 = 0x0D */
private val SegBorder = Color(0x0DFFFFFF)

/** `.duo-seg.current` 底 `rgba(80,236,167,.16)` → round(40.8) = 41 = 0x29 */
private val SegCurrentFill = Color(0x2950ECA7)

/** `.duo-seg.current` 描边 `rgba(80,236,167,.5)` → round(127.5) = 128 = 0x80 */
private val SegCurrentBorder = Color(0x8050ECA7)

/** `.duo-seg.current` 外环 `rgba(80,236,167,.12)` → round(30.6) = 31 = 0x1F */
private val SegCurrentRing = Color(0x1F50ECA7)

/** 末尾覆盖层 `.demo-card` 底 `rgba(255,255,255,.031)` → round(7.905) = 8 = 0x08 */
private val DemoCardFill = Color(0x08FFFFFF)

/** `.demo-position` / `.demo-caption` 底 `rgba(8,13,17,.82)` → round(209.1) = 209 = 0xD1 */
private val OverlayBadgeFill = Color(0xD1080D11)

/** `.modal` 遮罩 `rgba(3,6,6,.72)` → round(183.6) = 184 = 0xB8 */
private val ModalScrim = Color(0xB8030606)

/** `.modal-card` 底 `#101816` */
private val ModalCardFill = Color(0xFF101816)

/** `.input-box` 底 `rgba(255,255,255,.0235)` → round(5.99) = 6 = 0x06 */
private val InputBoxFill = Color(0x06FFFFFF)

/** `.stepper .step` 底 `rgba(255,255,255,.031)` → round(7.905) = 8 = 0x08 */
private val StepFill = Color(0x08FFFFFF)

/** `.celebrate` 遮罩 `rgba(11,15,19,.55)` → round(140.25) = 140 = 0x8C */
private val CelebrateScrim = Color(0x8C0B0F13)

/** `benchGrad` 上端 `#2A3934` */
private val BenchTop = Color(0xFF2A3934)

/** `benchGrad` 下端 `#16211F` */
private val BenchBottom = Color(0xFF16211F)

/** 凳腿与 `.modal-card` 同色 `#101816` */
private val LegFill = Color(0xFF101816)

/** 卧推者剪影填充 `#0D1117` */
private val BodyFill = Color(0xFF0D1117)

/** 剪影描边 `rgba(80,236,167,.16)` → round(40.8) = 41 = 0x29 */
private val BodyStrokeAccent = Color(0x2950ECA7)

/** `barGrad` 上端 `#7E8F96` */
private val BarTop = Color(0xFF7E8F96)

/** `barGrad` 下端 `#3B4A45` */
private val BarBottom = Color(0xFF3B4A45)

/** `plateGrad` 0% `#243B35` */
private val PlateInner = Color(0xFF243B35)

/** `plateGrad` 65% `#0F1716` */
private val PlateMid = Color(0xFF0F1716)

/** `plateGrad` 100% `#080D0C` */
private val PlateOuter = Color(0xFF080D0C)

/** 杠铃片描边 `#0B0F13` */
private val PlateStroke = Color(0xFF0B0F13)

/** 彩带四色（原型 `colors`，L780）：accent / accentSoft / accentDeep / txtHi。 */
private val ConfettiColors = listOf(FtColor.accent, FtColor.accentSoft, FtColor.accentDeep, FtColor.txtHi)

// ── 训练域接线的屏内辅助 ─────────────────────────────────────────

/**
 * 当前动作——口径与 `ActiveWorkoutService` 内部的 `findCurrentExercise` 一致：
 * **首个**有效组未录满的动作；全部录满则取末个；无动作返回 `null`。
 * （服务未把 `plannedExerciseId` 暴露到 `ActiveWorkoutState`，故此处就地复刻该规则。）
 */
private fun nextExercise(state: ActiveWorkoutState) =
    state.exercises.firstOrNull { it.completedSets < it.targetSets } ?: state.exercises.lastOrNull()

/** [nextExercise] 命中动作的 `plannedExerciseId`；无动作时为空串（`updateSetEntry` 不会命中）。 */
private fun nextPlannedExerciseId(state: ActiveWorkoutState): String =
    nextExercise(state)?.plannedExerciseId ?: ""

/** [nextExercise] 命中动作的下一组序号（`completedSets` 即下一个待填组下标）。 */
private fun nextSetIndex(state: ActiveWorkoutState): Int = nextExercise(state)?.completedSets ?: 0
