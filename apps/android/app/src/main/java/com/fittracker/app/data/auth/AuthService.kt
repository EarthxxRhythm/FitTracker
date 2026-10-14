package com.fittracker.app.data.auth

import com.fittracker.app.data.cloud.SupabaseAuthProvider
import com.fittracker.app.data.cloud.SupabaseConfig
import com.fittracker.app.data.cloud.SupabaseSessionStore
import com.fittracker.app.data.persist.JsonStore

/**
 * 认证门面——对齐鸿蒙 `common/services/AuthService.ets` 的门面职责：
 * provider 解析 + 会话落地 + 启动分流判定。
 *
 * provider 解析规则（Wave 6 起生效）：
 * - **已配置 Supabase**（`BuildConfig.SUPABASE_URL` 非空）→ [SupabaseAuthProvider]
 *   ——云端正式链路；会话（access/refresh token）由 provider 自持久化于
 *   `StoreNames.CLOUD_SESSION`，门面不再重复落盘。
 * - **未配置** → [SandboxAuthProvider]——本地沙盒链路；会话由门面落
 *   `StoreNames.SESSION`（token 7 天，[SessionManager.TOKEN_EXPIRY_DAYS]）。
 *
 * 所有方法以 [JsonStore] 注入，与 `data/service/` 各服务同模式。
 */
object AuthService {

    /**
     * provider 实例缓存——**同一 store 只持有一份** provider。
     *
     * `SandboxAuthProvider` 的 `issuedCodes`（验证码签发记录）与 `currentSession` 是**实例内存态**：
     * 若每次调用都新建实例，「发码」与「验证码登录」会落在两个不同实例上，登录恒返回
     * 「请先获取验证码」——沙盒（未配置云服务）模式下手机验证码登录完全不可用；
     * 同理 `signOut()` 也清不掉那个临时实例里的内存会话。
     * 同一 store 复用实例即对齐源实现「模块级单例持有内存态」的语义。
     * （回归护栏：`AuthServicePhoneCodeTest`）
     */
    private val providers: java.util.concurrent.ConcurrentHashMap<JsonStore, AuthProvider> =
        java.util.concurrent.ConcurrentHashMap()

    /**
     * 测试注入的 provider 工厂（对齐 `SyncOrchestrator.setStoreForTesting` 惯例；
     * `null` 恢复默认解析）。
     *
     * 存在的理由：provider 解析的正负由 `SupabaseConfig.isConfigured`（编译期读 `BuildConfig`、
     * 值来自未入库的 `local.properties`）单向决定，测试无法在不改磁盘配置的前提下声明
     * 「本用例走哪套 provider」——导致依赖云端会话的测试（`SyncOrchestratorTest`）在无凭据
     * 环境（CI / 换机）必然红。注入工厂后测试可显式选择分支，生产路径零变化。
     */
    @Volatile
    private var testingProviderFactory: ((JsonStore) -> AuthProvider)? = null

    /**
     * 设置 / 清除（传 `null`）测试用 provider 工厂。
     *
     * 切换同时清空 [providers] 缓存——否则旧分支的实例会被 `computeIfAbsent` 复用、
     * 注入不生效。
     */
    fun setProviderFactoryForTesting(factory: ((JsonStore) -> AuthProvider)?) {
        testingProviderFactory = factory
        providers.clear()
    }

    /** provider 解析（单一切换点——调用方对两套实现无感）。 */
    fun provider(store: JsonStore): AuthProvider = providers.computeIfAbsent(store) {
        testingProviderFactory?.invoke(store)
            ?: if (SupabaseConfig.isConfigured) SupabaseAuthProvider(store) else SandboxAuthProvider(store)
    }

    /** 沙盒会话存储门面。 */
    fun sessionManager(store: JsonStore): SessionManager = SessionManager(store)

    /**
     * 登录：provider 校验；沙盒 provider 不自持久化——由门面补会话落地；
     * Supabase provider 内部已落 `CLOUD_SESSION`。
     */
    suspend fun signIn(store: JsonStore, account: String, password: String): Result<AuthSession> {
        val provider = provider(store)
        val result: Result<AuthSession> = provider.signIn(account, password)
        if (provider is SandboxAuthProvider) {
            result.getOrNull()?.let { persistSession(store, it) }
        }
        return result
    }

    /**
     * 注册——沙盒语义：注册成功即已登录（源 `SandboxAuthProvider.ets:117` `completeSignIn`）；
     * Supabase 语义：响应含会话（确认关闭）才落盘，否则返回「待确认」失败（见 provider 实现）。
     */
    suspend fun signUp(
        store: JsonStore,
        account: String,
        password: String,
        nickname: String,
    ): Result<AuthSession> {
        val provider = provider(store)
        val result: Result<AuthSession> = provider.signUp(account, password, nickname)
        if (provider is SandboxAuthProvider) {
            result.getOrNull()?.let { persistSession(store, it) }
        }
        return result
    }

    /** 退出登录：provider 清会话（Supabase 侧另发 logout 请求）+ 沙盒存储双清（防御性）。 */
    suspend fun signOut(store: JsonStore) {
        provider(store).signOut()
        val manager = sessionManager(store)
        manager.clearToken()
        manager.clearSession()
        SupabaseSessionStore(store).clear()
    }

    /**
     * 启动分流输入（`StartupDecision.getInitialRoute` 的 `hasValidSession`）：
     * Supabase → **仅查本地持久化会话**（不触网——2026-10-09 修复「不会保持登陆」：
     * 原实现走 `validAccessToken`，网络波动/离线时刷新失败即判未登录）；token 续期交给实际网络请求路径；
     * 沙盒 → `SessionManager.isLoggedIn`（快照 + token 未过期）。
     */
    suspend fun isLoggedIn(store: JsonStore): Boolean = when (val provider = provider(store)) {
        is SupabaseAuthProvider -> provider.hasPersistedSession()
        else -> sessionManager(store).isLoggedIn()
    }

    /** 请求手机验证码（门面转调 provider；沙盒回显演示码、云端发真短信）。 */
    suspend fun requestPhoneCode(store: JsonStore, phone: String): VerifyCodeResult =
        provider(store).requestPhoneCode(phone)

    /**
     * 手机验证码登录——沙盒 provider 不自持久化，由门面补会话落地（同 [signIn] 结构）；
     * Supabase provider 内部已落 `CLOUD_SESSION`。语义同源：手机号未注册时自动建号。
     */
    suspend fun signInWithPhoneCode(store: JsonStore, phone: String, code: String): Result<AuthSession> {
        val provider = provider(store)
        val result: Result<AuthSession> = provider.signInWithPhoneCode(phone, code)
        if (provider is SandboxAuthProvider) {
            result.getOrNull()?.let { persistSession(store, it) }
        }
        return result
    }

    /** 当前会话（UI 展示用；优先 provider 内存，回落持久化快照）。 */
    suspend fun currentSession(store: JsonStore): AuthSession? = when (val provider = provider(store)) {
        is SupabaseAuthProvider -> provider.currentUser() ?: SupabaseSessionStore(store).load()?.snapshot
        else -> provider.currentUser() ?: sessionManager(store).getSession()
    }

    /**
     * 沙盒会话落地：token 按 `userId` 签发（7 天有效期），快照整块存 [SessionManager.STORE_KEY]。
     */
    private suspend fun persistSession(store: JsonStore, session: AuthSession) {
        val manager = sessionManager(store)
        manager.saveToken(manager.generateToken(session.userId))
        manager.saveSession(session)
    }
}
