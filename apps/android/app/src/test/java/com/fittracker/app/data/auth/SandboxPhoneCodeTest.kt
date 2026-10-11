package com.fittracker.app.data.auth

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.persist.JsonStore
import java.io.File
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 沙盒手机验证码链路（[SandboxAuthProvider.requestPhoneCode] / [SandboxAuthProvider.signInWithPhoneCode]）契约测试。
 *
 * 语义基线：鸿蒙 `SandboxAuthProvider.ets:65-89`（发码/验证码登录）、`:198-224`（签发与校验）、
 * `:287`（按手机号找号）。覆盖：格式校验、演示码回显、60 秒频控、验证码错误/未获取文案、
 * 验证码登录自动建号与会话语义（providerId = `phone_code`）。
 *
 * 「验证码过期」分支（TTL 5 分钟）依赖真实时钟推进，本批不覆盖——已注记。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SandboxPhoneCodeTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "sandbox_phone_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    @Test
    fun `手机号格式错误_发码与登录均拒绝`() = runBlocking {
        val provider = SandboxAuthProvider(createStore())

        val request = provider.requestPhoneCode("12345")
        assertFalse(request.success)
        assertEquals("请输入正确的手机号", request.message)

        val login = provider.signInWithPhoneCode("12345", "000000")
        assertTrue(login.isFailure)
        assertEquals("请输入正确的手机号", login.exceptionOrNull()?.message)
    }

    @Test
    fun `发码成功_回显演示码`() = runBlocking {
        val provider = SandboxAuthProvider(createStore())

        val result = provider.requestPhoneCode("13900000001")

        assertTrue(result.success)
        assertEquals("验证码已发送", result.message)
        assertEquals("000000", result.devCodeHint) // 沙盒演示码（源 SANDBOX_CODE）
    }

    @Test
    fun `频控_60秒内重复发码被拒`() = runBlocking {
        val provider = SandboxAuthProvider(createStore())

        val first = provider.requestPhoneCode("13900000001")
        val second = provider.requestPhoneCode("13900000001")

        assertTrue(first.success)
        assertFalse(second.success)
        assertEquals("验证码已发送，请稍后再试", second.message)
    }

    @Test
    fun `登录_未获取验证码与错误码文案`() = runBlocking {
        val provider = SandboxAuthProvider(createStore())

        val notRequested = provider.signInWithPhoneCode("13900000001", "000000")
        assertEquals("请先获取验证码", notRequested.exceptionOrNull()?.message)

        provider.requestPhoneCode("13900000001")
        val wrongCode = provider.signInWithPhoneCode("13900000001", "123456")
        assertEquals("验证码错误，请重试", wrongCode.exceptionOrNull()?.message)
    }

    @Test
    fun `验证码登录_自动建号与会话语义`() = runBlocking {
        val store = createStore()
        val provider = SandboxAuthProvider(store)
        provider.requestPhoneCode("13900000001")

        val result = provider.signInWithPhoneCode("13900000001", "000000")

        assertTrue("应成功：${result.exceptionOrNull()?.message}", result.isSuccess)
        val session = result.getOrThrow()
        assertEquals("sandbox:13900000001", session.userId)
        assertEquals("13900000001", session.phone)
        assertEquals("", session.email)
        assertEquals(SandboxAuthProvider.PHONE_CODE_PROVIDER, session.providerId)
        assertEquals("用户0001", session.displayName) // resolveDisplayName：手机号后 4 位
        assertTrue(provider.isLoggedIn())

        // 账号已持久化：新实例（同 store）再走一遍，命中「用户已存在」路径
        val provider2 = SandboxAuthProvider(store)
        provider2.requestPhoneCode("13900000001")
        val again = provider2.signInWithPhoneCode("13900000001", "000000")
        assertTrue(again.isSuccess)
        assertEquals("sandbox:13900000001", again.getOrThrow().userId)
    }
}
