package com.fittracker.app.data.auth

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.persist.JsonStore
import java.io.File
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * `AuthService` 门面层的手机验证码链路契约（沙盒模式）。
 *
 * 覆盖的回归：验证码的「签发」与「校验」必须落在**同一个** provider 实例上。
 * `AuthService.provider(store)` 每次调用都新建 provider，而 `SandboxAuthProvider.issuedCodes`
 * 是实例内存态——若门面各方法各建一个实例，发码记录立刻随实例丢失，
 * 登录恒返回「请先获取验证码」，沙盒模式下手机验证码登录完全不可用。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class AuthServicePhoneCodeTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "auth_service_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    /**
     * 显式注入**沙盒** provider——本用例专测沙盒链路（见类注释），且求环境无关：
     * 否则 Supabase 已配置（本机有 local.properties）时 `AuthService.provider` 走云端分支，
     * 其 `requestPhoneCode` 会发出真实 HTTP（`SupabaseAuthProvider.kt:125-139`）。
     */
    @Before
    fun injectSandboxProvider() {
        AuthService.setProviderFactoryForTesting { SandboxAuthProvider(it) }
    }

    @After
    fun clearProviderFactory() {
        AuthService.setProviderFactoryForTesting(null)
    }

    @Test
    fun `发码后立即用演示码登录_应成功`() = runBlocking {
        val store = createStore()
        val phone = "13900000001"

        val sent = AuthService.requestPhoneCode(store, phone)
        assertTrue("发码应成功，实际：${sent.message}", sent.success)

        val result = AuthService.signInWithPhoneCode(store, phone, "000000")
        assertTrue(
            "发码后应能用演示码登录，实际失败：${result.exceptionOrNull()?.message}",
            result.isSuccess,
        )
    }
}
