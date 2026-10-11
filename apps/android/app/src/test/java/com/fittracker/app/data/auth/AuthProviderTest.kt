package com.fittracker.app.data.auth

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.fittracker.app.data.persist.JsonStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.util.concurrent.atomic.AtomicInteger

/**
 * Wave 5 认证内核（[SandboxAuthProvider] / [SessionManager]）的契约测试。
 *
 * 断言的中文文案**逐字取自鸿蒙源** `SandboxAuthProvider.ets` 的失败分支（如 L123
 * `'该邮箱尚未注册，请先注册'`、L127 `'密码错误，请重试'`），不得改写措辞。
 *
 * 测试手段照 `SessionAndPlanTest` / `RepositoriesTest`：以 [PreferenceDataStoreFactory]
 * 把每个用例的存储指向独立临时文件（互不污染、不触真实应用存储）。
 *
 * `@Config(sdk = [34])`：项目 targetSdk 37 超出 Robolectric 4.16 支持范围，必须钉到受支持
 * SDK（原因同 `SessionAndPlanTest`）。`android.util.Base64` 在 Robolectric 下可用。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class AuthProviderTest {

    @get:Rule
    val tempFolder: TemporaryFolder = TemporaryFolder()

    private val counter = AtomicInteger()

    /** 每例独立存储——避免跨用例串场。 */
    private fun createStore(): JsonStore {
        val file = File(tempFolder.root, "auth_${counter.incrementAndGet()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
        ) { file }
        return JsonStore(dataStore)
    }

    private fun sampleSession(userId: String = "sandbox:fan@example.com"): AuthSession = AuthSession(
        userId = userId,
        displayName = "小明",
        phone = "",
        email = "fan@example.com",
        providerId = SandboxAuthProvider.EMAIL_PASSWORD_PROVIDER,
        signedInAt = 1_759_000_000_000,
    )

    // ── 注册 → 登录 → 会话有效 → 登出 → 会话失效 往返 ────────────────────

    @Test
    fun `注册 登录 会话有效 登出 会话失效 往返`() = runBlocking {
        val store = createStore()
        val provider = SandboxAuthProvider(store)
        val session = SessionManager(store)

        // 1. 注册
        val signUpResult = provider.signUp("fan@example.com", "abcd1234", "小明")
        assertTrue("注册应成功：${signUpResult.exceptionOrNull()?.message}", signUpResult.isSuccess)
        val registered = signUpResult.getOrThrow()
        assertEquals("sandbox:fan@example.com", registered.userId)
        assertEquals("小明", registered.displayName)
        assertEquals("fan@example.com", registered.email)
        assertEquals(SandboxAuthProvider.EMAIL_PASSWORD_PROVIDER, registered.providerId)

        // 2. 登录
        val signInResult = provider.signIn("fan@example.com", "abcd1234")
        assertTrue("登录应成功：${signInResult.exceptionOrNull()?.message}", signInResult.isSuccess)
        val signedIn = signInResult.getOrThrow()
        assertTrue(provider.isLoggedIn())
        assertEquals(signedIn, provider.currentUser())

        // 3. 会话有效（写 token + 快照后 isLoggedIn 为真）
        val token = session.generateToken(signedIn.userId)
        session.saveToken(token)
        session.saveSession(signedIn)
        assertTrue(session.isLoggedIn())
        assertEquals(signedIn, session.getSession())
        assertEquals(token, session.getToken())

        // 4. 登出
        provider.signOut()
        session.clearSession()
        session.clearToken()

        // 5. 会话失效
        assertFalse(provider.isLoggedIn())
        assertNull(provider.currentUser())
        assertFalse(session.isLoggedIn())
        assertNull(session.getSession())
        assertNull(session.getToken())
    }

    // ── 错误路径 ──────────────────────────────────────────────────────────

    @Test
    fun `未注册用户登录报源文案`() = runBlocking {
        val provider = SandboxAuthProvider(createStore())

        val result = provider.signIn("nobody@example.com", "abcd1234")

        assertTrue(result.isFailure)
        assertEquals("该邮箱尚未注册，请先注册", result.exceptionOrNull()?.message)
        assertFalse(provider.isLoggedIn())
    }

    @Test
    fun `密码错误报源文案`() = runBlocking {
        val provider = SandboxAuthProvider(createStore())
        provider.signUp("fan@example.com", "abcd1234", "小明")
        // 源 signUp 经 completeSignIn 建立内存会话；先登出，隔离「失败登录不建会话」这一不变量
        provider.signOut()

        val result = provider.signIn("fan@example.com", "wrongpass")

        assertTrue(result.isFailure)
        assertEquals("密码错误，请重试", result.exceptionOrNull()?.message)
        assertFalse("失败登录不应建立会话", provider.isLoggedIn())
        assertNull(provider.currentUser())
    }

    @Test
    fun `注册邮箱格式非法报源文案`() = runBlocking {
        val provider = SandboxAuthProvider(createStore())

        val result = provider.signUp("not-an-email", "abcd1234", "小明")

        assertTrue(result.isFailure)
        assertEquals("请输入正确的邮箱", result.exceptionOrNull()?.message)
    }

    @Test
    fun `注册密码不足 8 位报源文案`() = runBlocking {
        val provider = SandboxAuthProvider(createStore())

        val result = provider.signUp("fan@example.com", "abcd123", "小明")

        assertTrue(result.isFailure)
        assertEquals("密码至少 8 位", result.exceptionOrNull()?.message)
    }

    @Test
    fun `重复注册同邮箱报源文案`() = runBlocking {
        val provider = SandboxAuthProvider(createStore())
        provider.signUp("fan@example.com", "abcd1234", "小明")

        val result = provider.signUp("fan@example.com", "abcd1234", "小明")

        assertTrue(result.isFailure)
        assertEquals("该邮箱已注册", result.exceptionOrNull()?.message)
    }

    // ── 持久化：新实例读回账号 ────────────────────────────────────────────

    @Test
    fun `账号落库后新实例可登录`() = runBlocking {
        val store = createStore()
        SandboxAuthProvider(store).signUp("fan@example.com", "abcd1234", "小明")

        // 新实例从存储加载用户目录
        val fresh = SandboxAuthProvider(store)
        val result = fresh.signIn("fan@example.com", "abcd1234")

        assertTrue("新实例应能读回持久化账号：${result.exceptionOrNull()?.message}", result.isSuccess)
        assertEquals("小明", result.getOrThrow().displayName)
    }

    // ── 会话过期 ──────────────────────────────────────────────────────────

    @Test
    fun `过期 token 判定会话失效`() = runBlocking {
        val store = createStore()
        val session = SessionManager(store)

        // 源 token 有效期 7 天：用「8 天前」的时刻签发 → 已过期
        val eightDaysAgo = System.currentTimeMillis() / 1000 - 8L * 24 * 60 * 60
        val expiredToken = session.generateToken("sandbox:fan@example.com", nowSeconds = eightDaysAgo)
        session.saveToken(expiredToken)
        session.saveSession(sampleSession())

        assertFalse("过期 token 的会话应失效", session.isLoggedIn())
        // 快照本身仍在（乐观判定口径未被破坏）——仅登录态判定叠加了过期
        assertNotNull(session.getSession())
    }

    @Test
    fun `有效 token 判定会话有效`() = runBlocking {
        val store = createStore()
        val session = SessionManager(store)

        val token = session.generateToken("sandbox:fan@example.com")
        session.saveToken(token)
        session.saveSession(sampleSession())

        assertTrue(session.isLoggedIn())
    }

    // ── Token 生成 / 解析 ─────────────────────────────────────────────────

    @Test
    fun `token 往返可解出 userId 且未过期`() = runBlocking {
        val session = SessionManager(createStore())

        val token = session.generateToken("sandbox:fan@example.com")

        assertEquals("sandbox:fan@example.com", session.getUserIdFromToken(token))
        assertTrue(session.validateToken(token))
        // 三段结构：header.body.signature
        assertEquals(3, token.split(".").size)
    }

    @Test
    fun `畸形 token 校验失败`() = runBlocking {
        val session = SessionManager(createStore())

        assertFalse(session.validateToken("not-a-token"))
        assertEquals("", session.getUserIdFromToken("broken"))
    }
}
