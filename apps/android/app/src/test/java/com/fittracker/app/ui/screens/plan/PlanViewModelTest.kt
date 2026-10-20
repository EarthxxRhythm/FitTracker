package com.fittracker.app.ui.screens.plan

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * [PlanViewModel] 装载逻辑的等价迁移测试。
 *
 * 迁移前装载逻辑内联在 `PlanScreen.kt` 的 `LaunchedEffect(Unit)` 里（不可单测）；
 * 迁移后成为 `PlanViewModel.load()`，这里用 `runBlocking { vm.awaitLoaded() }` 驱动等待
 * （沿用项目现有测试的 `runBlocking` 手法，无 `kotlinx-coroutines-test` 依赖）。
 *
 * Robolectric 提供 `Application`（`AndroidViewModel` 需要），`appDataStore` 委托会落到
 * 测试环境的内存/临时文件——本测试只断言「装载收敛到非空 / 空态」两种结果，不依赖
 * 具体计划数据（设备/仓库数据不同会导致断言脆）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class PlanViewModelTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun `装载完成后 planName 非空且 progressFraction 在 0 到 1 之间`() = runBlocking {
        val vm = PlanViewModel(context.applicationContext as android.app.Application)
        vm.load()

        // 无当前计划时回落 plan_fallback_name；有则填真实名。两种都应非空。
        assertTrue("planName 应非空", vm.planName.isNotBlank())
        assertTrue(
            "progressFraction 应在 [0,1]",
            vm.progressFraction in 0f..1f,
        )
        // 装载完成后 restored 必须为 true（卡片位置恢复流程已收敛）
        assertTrue("restored 应为 true", vm.restored)
    }

    @Test
    fun `无当前计划时收敛到空态`() = runBlocking {
        val vm = PlanViewModel(context.applicationContext as android.app.Application)
        vm.load()

        // 空态语义：days 为空列表（无「五日增肌计划」样例），planMeta 为 plan_empty_meta 文案。
        assertEquals("days 应为空列表", emptyList<FtPlanDay>(), vm.days)
        assertEquals(
            "planMeta 应为空态文案",
            context.getString(com.fittracker.app.R.string.plan_empty_meta),
            vm.planMeta,
        )
    }

    @Test
    fun `装载完成前 selectCard 越界忽略`() = runBlocking {
        val vm = PlanViewModel(context.applicationContext as android.app.Application)
        // 未 load：days 仍是 emptyList，任何索引都越界，不应改变 activeIndex。
        vm.selectCard(3)
        assertEquals("装载前 activeIndex 应保持 0", 0, vm.activeIndex)
    }
}
