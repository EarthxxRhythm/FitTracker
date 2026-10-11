package com.fittracker.app.data.auth

import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/**
 * 沙盒认证实现——逐方法移植自鸿蒙 `entry/src/main/ets/common/services/auth/SandboxAuthProvider.ets`。
 *
 * 用途：AGC 云服务未配置 / 测试环境时的降级实现，保证注册 / 登录 / 退出全链路可用
 * （源 `SandboxAuthProvider.ets:1` 文件头注释）。
 *
 * 持久化模型（与源的映射）：
 * - 鸿蒙侧：`preferences.getPreferences(context, 'fit_tracker_sandbox_auth')` 打开
 *   `fit_tracker_sandbox_auth` 库（源 L20 `SANDBOX_STORE_NAME`），库内 `'users'` 键
 *   （源 L21 `KEY_USERS`）装一整块 `SandboxUserRecord[]` JSON（源 L328 `persistUsers`）。
 * - 安卓侧（Wave 2 折叠模型）：所有鸿蒙 preferences 库折叠进**同一个** DataStore，库名退化
 *   为**键名**。本提供方把整块用户目录 JSON 存到键 [StoreNames.SANDBOX_AUTH]。
 *
 * 与源的差异：
 *  - 源为单例（`export default new SandboxAuthProvider()`）且首参 `context: Context`；
 *    安卓侧改为 [JsonStore] **构造注入**、可实例化——便于单测每例新建、互不串场。
 *  - 源 `registerWithEmail(email, password, code, nickname)` → [signUp] 去掉 `code`；
 *    源 `loginWithEmailPassword` → [signIn]。验证码链路（`requestPhoneCode` /
 *    `verifyCode` 等）未纳入本波。
 *
 * 密码散列：源 L305 `hashPassword` 为 **djb2** 变形（`hash = hash*33 + charCode`，取无符号
 * 32 位并按 16 进制前缀 `'sb_'`）；**非生产级安全**（源即如此，注释明示「仅演示与测试」）。
 * 安卓侧逐位复刻同一算法，保证两端就同一密码产出一致散列（跨平台对照）。
 */
class SandboxAuthProvider(private val store: JsonStore) : AuthProvider {

    /** 提供方标识（源 `SandboxAuthProvider.ets:48` `getProviderId` → `'sandbox'`）。 */
    override val providerId: String = PROVIDER_ID

    /** 内存用户目录（源 `SandboxAuthProvider.ets:42` 的 `users`）。 */
    private var users: List<SandboxUserRecord> = emptyList()

    /** 内存镜像会话（源 `SandboxAuthProvider.ets:44` 的 `currentSession`）。 */
    private var currentSession: AuthSession? = null

    /** 是否已从存储加载（源 `SandboxAuthProvider.ets:46` 的 `loaded`）。 */
    private var loaded: Boolean = false

    /** 内存验证码签发记录（源 `SandboxAuthProvider.ets:43` 的 `codes`——`targetKey → {code, expiresAt, sentAt}`）。 */
    private val issuedCodes: MutableMap<String, SandboxCodeRecord> = mutableMapOf()

    /** 当前环境恒可用（源 `SandboxAuthProvider.ets:52` `isAvailable` → `true`）。 */
    override fun isAvailable(): Boolean = true

    // --- 源 L99-L118：邮箱注册 ----------------------------------------------

    /**
     * 源 `SandboxAuthProvider.ets:99` `registerWithEmail`：
     * 邮箱格式 → 密码位数 → 邮箱已注册（源 L107）→（源还校验验证码）→ 建记录 → 落库 →
     * `completeSignIn(user, 'email_password', '', email)`（源 L117）。
     *
     * 安卓侧省略验证码校验（源 L110），其余判定链与文案逐字对齐。
     */
    override suspend fun signUp(email: String, password: String, nickname: String): Result<AuthSession> {
        val trimmedEmail: String = email.trim()
        if (!EMAIL_PATTERN.matches(trimmedEmail)) {
            return failure("请输入正确的邮箱")
        }
        if (password.length < MIN_PASSWORD_LENGTH) {
            return failure("密码至少 8 位")
        }
        ensureLoaded()
        if (findUserByEmail(trimmedEmail) != null) {
            return failure("该邮箱已注册")
        }
        val user: SandboxUserRecord = createUserRecord("", trimmedEmail, nickname.trim(), password)
        users = users + user
        persistUsers()
        return success(completeSignIn(user, EMAIL_PASSWORD_PROVIDER, "", trimmedEmail))
    }

    // --- 源 L120-L130：邮箱 + 密码登录 --------------------------------------

    /**
     * 源 `SandboxAuthProvider.ets:120` `loginWithEmailPassword`：
     * 用户不存在 → `'该邮箱尚未注册，请先注册'`（源 L123-L125）；
     * 密文不符 → `'密码错误，请重试'`（源 L126-L128）。
     *
     * 安卓侧 `account` 按**邮箱**解析（对齐源 `loginWithEmailPassword`，本波不含手机号登录）。
     */
    override suspend fun signIn(account: String, password: String): Result<AuthSession> {
        val trimmedEmail: String = account.trim()
        ensureLoaded()
        val user: SandboxUserRecord? = findUserByEmail(trimmedEmail)
        if (user == null) {
            return failure("该邮箱尚未注册，请先注册")
        }
        if (user.passwordHash != hashPassword(password)) {
            return failure("密码错误，请重试")
        }
        return success(completeSignIn(user, EMAIL_PASSWORD_PROVIDER, "", trimmedEmail))
    }

    // --- 源 L65-L89：手机验证码链路 -----------------------------------------

    /**
     * 源 `SandboxAuthProvider.ets:65` `requestPhoneCode`：格式校验 → `issueCode('phone:'+phone)`。
     * 演示码 `000000` 经 `devCodeHint` 回显（源 L23 `SANDBOX_CODE` / L210）。
     */
    override suspend fun requestPhoneCode(phone: String): VerifyCodeResult {
        val trimmed: String = phone.trim()
        if (!PHONE_PATTERN.matches(trimmed)) {
            return VerifyCodeResult(success = false, message = "请输入正确的手机号", devCodeHint = "")
        }
        return issueCode("phone:$trimmed")
    }

    /**
     * 源 `SandboxAuthProvider.ets:73` `loginWithPhoneCode`：格式校验 → 验证码校验 →
     * 用户不存在则**自动建号**（源 L82-L86，验证码登录即快速注册）→
     * `completeSignIn(user, 'phone_code', phone, '')`（源 L88，providerId = `'phone_code'`）。
     */
    override suspend fun signInWithPhoneCode(phone: String, code: String): Result<AuthSession> {
        val trimmed: String = phone.trim()
        if (!PHONE_PATTERN.matches(trimmed)) {
            return failure("请输入正确的手机号")
        }
        val codeError: String = verifyCode("phone:$trimmed", code)
        if (codeError.isNotEmpty()) {
            return failure(codeError)
        }
        ensureLoaded()
        var user: SandboxUserRecord? = findUserByPhone(trimmed)
        if (user == null) {
            user = createUserRecord(trimmed, "", "", "")
            users = users + user
            persistUsers()
        }
        return success(completeSignIn(user, PHONE_CODE_PROVIDER, trimmed, ""))
    }

    // --- 源 L198-L224：验证码签发 / 校验（内存态） ---------------------------

    /**
     * 源 `SandboxAuthProvider.ets:198` `issueCode`：频控窗口（[CODE_RESEND_MS]）内重复请求
     * → `'验证码已发送，请稍后再试'`；否则记录 `{code, expiresAt, sentAt}` 并回显演示码。
     */
    private fun issueCode(targetKey: String): VerifyCodeResult {
        val now: Long = System.currentTimeMillis()
        val existing: SandboxCodeRecord? = issuedCodes[targetKey]
        if (existing != null && now - existing.sentAt < CODE_RESEND_MS) {
            return VerifyCodeResult(success = false, message = "验证码已发送，请稍后再试", devCodeHint = "")
        }
        issuedCodes[targetKey] = SandboxCodeRecord(code = SANDBOX_CODE, expiresAt = now + CODE_TTL_MS, sentAt = now)
        return VerifyCodeResult(success = true, message = "验证码已发送", devCodeHint = SANDBOX_CODE)
    }

    /**
     * 源 `SandboxAuthProvider.ets:214` `verifyCode`：未签发 / 超时（[CODE_TTL_MS]）/ 码不符
     * 分别返回源文案；通过时**消费验证码**（源 L223 `codes.delete`）并返回空串。
     */
    private fun verifyCode(targetKey: String, code: String): String {
        val record: SandboxCodeRecord = issuedCodes[targetKey] ?: return "请先获取验证码"
        if (System.currentTimeMillis() > record.expiresAt) {
            return "验证码已过期，请重新获取"
        }
        if (code.trim() != record.code) {
            return "验证码错误，请重试"
        }
        issuedCodes.remove(targetKey)
        return ""
    }

    /** 源 `SandboxAuthProvider.ets:287` `findUserByPhone`——只匹配非空手机号。 */
    private fun findUserByPhone(phone: String): SandboxUserRecord? =
        users.firstOrNull { it.phone.isNotEmpty() && it.phone == phone }

    /** 源 `SandboxAuthProvider.ets:145` `signOut`——仅清内存会话。 */
    override suspend fun signOut() {
        currentSession = null
    }

    /** 源 `SandboxAuthProvider.ets:149` `getCurrentSession`。 */
    override fun currentUser(): AuthSession? = currentSession

    /** 是否已登录 = 内存会话非空（由 `getCurrentSession` 派生）。 */
    override fun isLoggedIn(): Boolean = currentSession != null

    /** 源 `SandboxAuthProvider.ets:178` `clearAllData`——清空内存用户目录与会话。 */
    override fun clearAllData() {
        users = emptyList()
        currentSession = null
    }

    /** 源 `SandboxAuthProvider.ets:185` `clearPersisted`——清内存 + 重置加载标志 + 删存储键。 */
    override suspend fun clearPersisted() {
        clearAllData()
        // 重置加载标志：下次 ensureLoaded 时按已清空的存储重新加载
        loaded = false
        try {
            store.remove(STORE_KEY)
        } catch (error: Exception) {
            // 沙盒存储不可用时不阻塞清理（对齐源 L190-L195 try/catch 吞异常）
        }
    }

    // --- 源 L228-L245：会话构造 ---------------------------------------------

    /**
     * 源 `SandboxAuthProvider.ets:228` `completeSignIn`：
     * `accountKey = phone 非空 ? phone : email`；构造会话并写入内存镜像。
     */
    private fun completeSignIn(
        user: SandboxUserRecord,
        providerId: String,
        phone: String,
        email: String,
    ): AuthSession {
        val accountKey: String = if (phone.isNotEmpty()) phone else email
        val session: AuthSession = AuthSession(
            userId = "sandbox:$accountKey",
            displayName = resolveDisplayName(user),
            phone = phone,
            email = email,
            providerId = providerId,
            signedInAt = System.currentTimeMillis(),
        )
        currentSession = session
        return session
    }

    /**
     * 源 `SandboxAuthProvider.ets:247` `resolveDisplayName`：
     * 昵称优先 → `手机号后 4 位` → `邮箱 @ 前缀` → 兜底 `'训练者'`。
     */
    private fun resolveDisplayName(user: SandboxUserRecord): String {
        if (user.nickname.isNotEmpty()) {
            return user.nickname
        }
        if (user.phone.length >= 4) {
            return "用户" + user.phone.substring(user.phone.length - 4)
        }
        if (user.email.isNotEmpty()) {
            val atIndex: Int = user.email.indexOf('@')
            if (atIndex > 0) {
                return user.email.substring(0, atIndex)
            }
        }
        return "训练者"
    }

    // --- 源 L276-L303：用户目录查找 -----------------------------------------

    /** 源 `SandboxAuthProvider.ets:276` `createUserRecord`——空密码记录散列为空串。 */
    private fun createUserRecord(
        phone: String,
        email: String,
        nickname: String,
        rawPassword: String,
    ): SandboxUserRecord = SandboxUserRecord(
        phone = phone,
        email = email,
        nickname = nickname,
        passwordHash = if (rawPassword.isNotEmpty()) hashPassword(rawPassword) else "",
        createdAt = System.currentTimeMillis(),
    )

    /** 源 `SandboxAuthProvider.ets:296` `findUserByEmail`——只匹配非空邮箱。 */
    private fun findUserByEmail(email: String): SandboxUserRecord? =
        users.firstOrNull { it.email.isNotEmpty() && it.email == email }

    // --- 源 L305-L312：密码散列 ---------------------------------------------

    /**
     * 源 `SandboxAuthProvider.ets:305` `hashPassword`——djb2 变形：
     * `hash = ((hash << 5) + hash + charCode) | 0`（32 位有符号溢出回绕），
     * 末了 `>>> 0` 转无符号后按 16 进制、前缀 `'sb_'`。
     *
     * Kotlin `Int` 同为 32 位、算术溢出自动回绕（等价 JS `| 0`）；`toUInt().toString(16)`
     * 等价 JS `>>> 0` 的十六进制表示。
     */
    private fun hashPassword(password: String): String {
        var hashValue: Int = 5381
        for (index in password.indices) {
            hashValue = (hashValue shl 5) + hashValue + password[index].code
        }
        return "sb_" + hashValue.toUInt().toString(16)
    }

    // --- 源 L314-L372：加载 / 落库 ------------------------------------------

    /** 懒加载——源 `SandboxAuthProvider.ets:56` `attachContext` → `loadUsers`（只加载一次）。 */
    private suspend fun ensureLoaded() {
        if (loaded) {
            return
        }
        users = parseUsers(readUsersJson())
        loaded = true
    }

    /** 源 `SandboxAuthProvider.ets:314` `loadUsers`——缺键回落 `'[]'`（源 `prefs.get(KEY_USERS, '[]')`）。 */
    private suspend fun readUsersJson(): String = try {
        store.readString(STORE_KEY) ?: "[]"
    } catch (error: Exception) {
        "[]"
    }

    /** 源 `SandboxAuthProvider.ets:328` `persistUsers`——整块 JSON 落库；失败保留内存数据。 */
    private suspend fun persistUsers() {
        try {
            store.writeString(STORE_KEY, JsonCodec.json.encodeToString(users))
        } catch (error: Exception) {
            // 沙盒演示模式：持久化失败时保留内存数据，不阻塞流程（对齐源 L328-L340）
        }
    }

    /** 源 `SandboxAuthProvider.ets:342` `parseUsers`——逐条校验收录，解析失败回落空目录。 */
    private fun parseUsers(json: String): List<SandboxUserRecord> = try {
        val parsed: List<SandboxUserRecord> = JsonCodec.json.decodeFromString(json)
        parsed.filter { isValidUserRecord(it) }
    } catch (error: Exception) {
        emptyList()
    }

    /**
     * 源 `SandboxAuthProvider.ets:358` `isValidUserRecord`：源逐字段校验类型（Kotlin 静态类型
     * 已保证，无需重复）；安卓侧收窄为「手机号或邮箱非空」——空账号对登录无意义。沙盒账号
     * 恒经由手机号或邮箱路径创建，故此过滤不会误删有效记录。
     */
    private fun isValidUserRecord(record: SandboxUserRecord): Boolean =
        record.phone.isNotEmpty() || record.email.isNotEmpty()

    private fun failure(message: String): Result<AuthSession> =
        Result.failure(AuthException(message))

    private fun success(session: AuthSession): Result<AuthSession> = Result.success(session)

    companion object {
        /** 提供方标识（源 `SandboxAuthProvider.ets:48`）。 */
        const val PROVIDER_ID: String = "sandbox"

        /**
         * 实际 [JsonStore] 键——鸿蒙库名 `fit_tracker_sandbox_auth`
         * （`StoreNames.SANDBOX_AUTH` = 源 `SandboxAuthProvider.ets:20` `SANDBOX_STORE_NAME`）。
         */
        const val STORE_KEY: String = StoreNames.SANDBOX_AUTH

        /** 鸿蒙源键名（源 `SandboxAuthProvider.ets:21` `KEY_USERS`）。安卓侧折叠为库名键，仅作对照。 */
        const val KEY_USERS: String = "users"

        /** 邮箱注册/登录的提供方通道标识（源 `SandboxAuthProvider.ets:117` / `:129`）。 */
        const val EMAIL_PASSWORD_PROVIDER: String = "email_password"

        /** 源 `SandboxAuthProvider.ets:104`——密码最小长度 8。 */
        private const val MIN_PASSWORD_LENGTH: Int = 8

        /** 手机验证码登录的提供方通道标识（源 `SandboxAuthProvider.ets:88`）。 */
        const val PHONE_CODE_PROVIDER: String = "phone_code"

        /** 源 `SandboxAuthProvider.ets:23`——沙盒固定演示验证码。 */
        private const val SANDBOX_CODE: String = "000000"

        /** 源 `SandboxAuthProvider.ets:25`——验证码有效期 5 分钟。 */
        private const val CODE_TTL_MS: Long = 5 * 60 * 1000

        /** 源 `SandboxAuthProvider.ets:26`——重发间隔 60 秒。 */
        private const val CODE_RESEND_MS: Long = 60 * 1000

        /** 源 `SandboxAuthProvider.ets:66`——手机号正则 `^1[3-9]\d{9}package com.fittracker.app.data.auth

import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/**
 * 沙盒认证实现——逐方法移植自鸿蒙 `entry/src/main/ets/common/services/auth/SandboxAuthProvider.ets`。
 *
 * 用途：AGC 云服务未配置 / 测试环境时的降级实现，保证注册 / 登录 / 退出全链路可用
 * （源 `SandboxAuthProvider.ets:1` 文件头注释）。
 *
 * 持久化模型（与源的映射）：
 * - 鸿蒙侧：`preferences.getPreferences(context, 'fit_tracker_sandbox_auth')` 打开
 *   `fit_tracker_sandbox_auth` 库（源 L20 `SANDBOX_STORE_NAME`），库内 `'users'` 键
 *   （源 L21 `KEY_USERS`）装一整块 `SandboxUserRecord[]` JSON（源 L328 `persistUsers`）。
 * - 安卓侧（Wave 2 折叠模型）：所有鸿蒙 preferences 库折叠进**同一个** DataStore，库名退化
 *   为**键名**。本提供方把整块用户目录 JSON 存到键 [StoreNames.SANDBOX_AUTH]。
 *
 * 与源的差异：
 *  - 源为单例（`export default new SandboxAuthProvider()`）且首参 `context: Context`；
 *    安卓侧改为 [JsonStore] **构造注入**、可实例化——便于单测每例新建、互不串场。
 *  - 源 `registerWithEmail(email, password, code, nickname)` → [signUp] 去掉 `code`；
 *    源 `loginWithEmailPassword` → [signIn]。验证码链路（`requestPhoneCode` /
 *    `verifyCode` 等）未纳入本波。
 *
 * 密码散列：源 L305 `hashPassword` 为 **djb2** 变形（`hash = hash*33 + charCode`，取无符号
 * 32 位并按 16 进制前缀 `'sb_'`）；**非生产级安全**（源即如此，注释明示「仅演示与测试」）。
 * 安卓侧逐位复刻同一算法，保证两端就同一密码产出一致散列（跨平台对照）。
 */
class SandboxAuthProvider(private val store: JsonStore) : AuthProvider {

    /** 提供方标识（源 `SandboxAuthProvider.ets:48` `getProviderId` → `'sandbox'`）。 */
    override val providerId: String = PROVIDER_ID

    /** 内存用户目录（源 `SandboxAuthProvider.ets:42` 的 `users`）。 */
    private var users: List<SandboxUserRecord> = emptyList()

    /** 内存镜像会话（源 `SandboxAuthProvider.ets:44` 的 `currentSession`）。 */
    private var currentSession: AuthSession? = null

    /** 是否已从存储加载（源 `SandboxAuthProvider.ets:46` 的 `loaded`）。 */
    private var loaded: Boolean = false

    /** 内存验证码签发记录（源 `SandboxAuthProvider.ets:43` 的 `codes`——`targetKey → {code, expiresAt, sentAt}`）。 */
    private val issuedCodes: MutableMap<String, SandboxCodeRecord> = mutableMapOf()

    /** 当前环境恒可用（源 `SandboxAuthProvider.ets:52` `isAvailable` → `true`）。 */
    override fun isAvailable(): Boolean = true

    // --- 源 L99-L118：邮箱注册 ----------------------------------------------

    /**
     * 源 `SandboxAuthProvider.ets:99` `registerWithEmail`：
     * 邮箱格式 → 密码位数 → 邮箱已注册（源 L107）→（源还校验验证码）→ 建记录 → 落库 →
     * `completeSignIn(user, 'email_password', '', email)`（源 L117）。
     *
     * 安卓侧省略验证码校验（源 L110），其余判定链与文案逐字对齐。
     */
    override suspend fun signUp(email: String, password: String, nickname: String): Result<AuthSession> {
        val trimmedEmail: String = email.trim()
        if (!EMAIL_PATTERN.matches(trimmedEmail)) {
            return failure("请输入正确的邮箱")
        }
        if (password.length < MIN_PASSWORD_LENGTH) {
            return failure("密码至少 8 位")
        }
        ensureLoaded()
        if (findUserByEmail(trimmedEmail) != null) {
            return failure("该邮箱已注册")
        }
        val user: SandboxUserRecord = createUserRecord("", trimmedEmail, nickname.trim(), password)
        users = users + user
        persistUsers()
        return success(completeSignIn(user, EMAIL_PASSWORD_PROVIDER, "", trimmedEmail))
    }

    // --- 源 L120-L130：邮箱 + 密码登录 --------------------------------------

    /**
     * 源 `SandboxAuthProvider.ets:120` `loginWithEmailPassword`：
     * 用户不存在 → `'该邮箱尚未注册，请先注册'`（源 L123-L125）；
     * 密文不符 → `'密码错误，请重试'`（源 L126-L128）。
     *
     * 安卓侧 `account` 按**邮箱**解析（对齐源 `loginWithEmailPassword`，本波不含手机号登录）。
     */
    override suspend fun signIn(account: String, password: String): Result<AuthSession> {
        val trimmedEmail: String = account.trim()
        ensureLoaded()
        val user: SandboxUserRecord? = findUserByEmail(trimmedEmail)
        if (user == null) {
            return failure("该邮箱尚未注册，请先注册")
        }
        if (user.passwordHash != hashPassword(password)) {
            return failure("密码错误，请重试")
        }
        return success(completeSignIn(user, EMAIL_PASSWORD_PROVIDER, "", trimmedEmail))
    }

    // --- 源 L65-L89：手机验证码链路 -----------------------------------------

    /**
     * 源 `SandboxAuthProvider.ets:65` `requestPhoneCode`：格式校验 → `issueCode('phone:'+phone)`。
     * 演示码 `000000` 经 `devCodeHint` 回显（源 L23 `SANDBOX_CODE` / L210）。
     */
    override suspend fun requestPhoneCode(phone: String): VerifyCodeResult {
        val trimmed: String = phone.trim()
        if (!PHONE_PATTERN.matches(trimmed)) {
            return VerifyCodeResult(success = false, message = "请输入正确的手机号", devCodeHint = "")
        }
        return issueCode("phone:$trimmed")
    }

    /**
     * 源 `SandboxAuthProvider.ets:73` `loginWithPhoneCode`：格式校验 → 验证码校验 →
     * 用户不存在则**自动建号**（源 L82-L86，验证码登录即快速注册）→
     * `completeSignIn(user, 'phone_code', phone, '')`（源 L88，providerId = `'phone_code'`）。
     */
    override suspend fun signInWithPhoneCode(phone: String, code: String): Result<AuthSession> {
        val trimmed: String = phone.trim()
        if (!PHONE_PATTERN.matches(trimmed)) {
            return failure("请输入正确的手机号")
        }
        val codeError: String = verifyCode("phone:$trimmed", code)
        if (codeError.isNotEmpty()) {
            return failure(codeError)
        }
        ensureLoaded()
        var user: SandboxUserRecord? = findUserByPhone(trimmed)
        if (user == null) {
            user = createUserRecord(trimmed, "", "", "")
            users = users + user
            persistUsers()
        }
        return success(completeSignIn(user, PHONE_CODE_PROVIDER, trimmed, ""))
    }

    // --- 源 L198-L224：验证码签发 / 校验（内存态） ---------------------------

    /**
     * 源 `SandboxAuthProvider.ets:198` `issueCode`：频控窗口（[CODE_RESEND_MS]）内重复请求
     * → `'验证码已发送，请稍后再试'`；否则记录 `{code, expiresAt, sentAt}` 并回显演示码。
     */
    private fun issueCode(targetKey: String): VerifyCodeResult {
        val now: Long = System.currentTimeMillis()
        val existing: SandboxCodeRecord? = issuedCodes[targetKey]
        if (existing != null && now - existing.sentAt < CODE_RESEND_MS) {
            return VerifyCodeResult(success = false, message = "验证码已发送，请稍后再试", devCodeHint = "")
        }
        issuedCodes[targetKey] = SandboxCodeRecord(code = SANDBOX_CODE, expiresAt = now + CODE_TTL_MS, sentAt = now)
        return VerifyCodeResult(success = true, message = "验证码已发送", devCodeHint = SANDBOX_CODE)
    }

    /**
     * 源 `SandboxAuthProvider.ets:214` `verifyCode`：未签发 / 超时（[CODE_TTL_MS]）/ 码不符
     * 分别返回源文案；通过时**消费验证码**（源 L223 `codes.delete`）并返回空串。
     */
    private fun verifyCode(targetKey: String, code: String): String {
        val record: SandboxCodeRecord = issuedCodes[targetKey] ?: return "请先获取验证码"
        if (System.currentTimeMillis() > record.expiresAt) {
            return "验证码已过期，请重新获取"
        }
        if (code.trim() != record.code) {
            return "验证码错误，请重试"
        }
        issuedCodes.remove(targetKey)
        return ""
    }

    /** 源 `SandboxAuthProvider.ets:287` `findUserByPhone`——只匹配非空手机号。 */
    private fun findUserByPhone(phone: String): SandboxUserRecord? =
        users.firstOrNull { it.phone.isNotEmpty() && it.phone == phone }

    /** 源 `SandboxAuthProvider.ets:145` `signOut`——仅清内存会话。 */
    override suspend fun signOut() {
        currentSession = null
    }

    /** 源 `SandboxAuthProvider.ets:149` `getCurrentSession`。 */
    override fun currentUser(): AuthSession? = currentSession

    /** 是否已登录 = 内存会话非空（由 `getCurrentSession` 派生）。 */
    override fun isLoggedIn(): Boolean = currentSession != null

    /** 源 `SandboxAuthProvider.ets:178` `clearAllData`——清空内存用户目录与会话。 */
    override fun clearAllData() {
        users = emptyList()
        currentSession = null
    }

    /** 源 `SandboxAuthProvider.ets:185` `clearPersisted`——清内存 + 重置加载标志 + 删存储键。 */
    override suspend fun clearPersisted() {
        clearAllData()
        // 重置加载标志：下次 ensureLoaded 时按已清空的存储重新加载
        loaded = false
        try {
            store.remove(STORE_KEY)
        } catch (error: Exception) {
            // 沙盒存储不可用时不阻塞清理（对齐源 L190-L195 try/catch 吞异常）
        }
    }

    // --- 源 L228-L245：会话构造 ---------------------------------------------

    /**
     * 源 `SandboxAuthProvider.ets:228` `completeSignIn`：
     * `accountKey = phone 非空 ? phone : email`；构造会话并写入内存镜像。
     */
    private fun completeSignIn(
        user: SandboxUserRecord,
        providerId: String,
        phone: String,
        email: String,
    ): AuthSession {
        val accountKey: String = if (phone.isNotEmpty()) phone else email
        val session: AuthSession = AuthSession(
            userId = "sandbox:$accountKey",
            displayName = resolveDisplayName(user),
            phone = phone,
            email = email,
            providerId = providerId,
            signedInAt = System.currentTimeMillis(),
        )
        currentSession = session
        return session
    }

    /**
     * 源 `SandboxAuthProvider.ets:247` `resolveDisplayName`：
     * 昵称优先 → `手机号后 4 位` → `邮箱 @ 前缀` → 兜底 `'训练者'`。
     */
    private fun resolveDisplayName(user: SandboxUserRecord): String {
        if (user.nickname.isNotEmpty()) {
            return user.nickname
        }
        if (user.phone.length >= 4) {
            return "用户" + user.phone.substring(user.phone.length - 4)
        }
        if (user.email.isNotEmpty()) {
            val atIndex: Int = user.email.indexOf('@')
            if (atIndex > 0) {
                return user.email.substring(0, atIndex)
            }
        }
        return "训练者"
    }

    // --- 源 L276-L303：用户目录查找 -----------------------------------------

    /** 源 `SandboxAuthProvider.ets:276` `createUserRecord`——空密码记录散列为空串。 */
    private fun createUserRecord(
        phone: String,
        email: String,
        nickname: String,
        rawPassword: String,
    ): SandboxUserRecord = SandboxUserRecord(
        phone = phone,
        email = email,
        nickname = nickname,
        passwordHash = if (rawPassword.isNotEmpty()) hashPassword(rawPassword) else "",
        createdAt = System.currentTimeMillis(),
    )

    /** 源 `SandboxAuthProvider.ets:296` `findUserByEmail`——只匹配非空邮箱。 */
    private fun findUserByEmail(email: String): SandboxUserRecord? =
        users.firstOrNull { it.email.isNotEmpty() && it.email == email }

    // --- 源 L305-L312：密码散列 ---------------------------------------------

    /**
     * 源 `SandboxAuthProvider.ets:305` `hashPassword`——djb2 变形：
     * `hash = ((hash << 5) + hash + charCode) | 0`（32 位有符号溢出回绕），
     * 末了 `>>> 0` 转无符号后按 16 进制、前缀 `'sb_'`。
     *
     * Kotlin `Int` 同为 32 位、算术溢出自动回绕（等价 JS `| 0`）；`toUInt().toString(16)`
     * 等价 JS `>>> 0` 的十六进制表示。
     */
    private fun hashPassword(password: String): String {
        var hashValue: Int = 5381
        for (index in password.indices) {
            hashValue = (hashValue shl 5) + hashValue + password[index].code
        }
        return "sb_" + hashValue.toUInt().toString(16)
    }

    // --- 源 L314-L372：加载 / 落库 ------------------------------------------

    /** 懒加载——源 `SandboxAuthProvider.ets:56` `attachContext` → `loadUsers`（只加载一次）。 */
    private suspend fun ensureLoaded() {
        if (loaded) {
            return
        }
        users = parseUsers(readUsersJson())
        loaded = true
    }

    /** 源 `SandboxAuthProvider.ets:314` `loadUsers`——缺键回落 `'[]'`（源 `prefs.get(KEY_USERS, '[]')`）。 */
    private suspend fun readUsersJson(): String = try {
        store.readString(STORE_KEY) ?: "[]"
    } catch (error: Exception) {
        "[]"
    }

    /** 源 `SandboxAuthProvider.ets:328` `persistUsers`——整块 JSON 落库；失败保留内存数据。 */
    private suspend fun persistUsers() {
        try {
            store.writeString(STORE_KEY, JsonCodec.json.encodeToString(users))
        } catch (error: Exception) {
            // 沙盒演示模式：持久化失败时保留内存数据，不阻塞流程（对齐源 L328-L340）
        }
    }

    /** 源 `SandboxAuthProvider.ets:342` `parseUsers`——逐条校验收录，解析失败回落空目录。 */
    private fun parseUsers(json: String): List<SandboxUserRecord> = try {
        val parsed: List<SandboxUserRecord> = JsonCodec.json.decodeFromString(json)
        parsed.filter { isValidUserRecord(it) }
    } catch (error: Exception) {
        emptyList()
    }

    /**
     * 源 `SandboxAuthProvider.ets:358` `isValidUserRecord`：源逐字段校验类型（Kotlin 静态类型
     * 已保证，无需重复）；安卓侧收窄为「手机号或邮箱非空」——空账号对登录无意义。沙盒账号
     * 恒经由手机号或邮箱路径创建，故此过滤不会误删有效记录。
     */
    private fun isValidUserRecord(record: SandboxUserRecord): Boolean =
        record.phone.isNotEmpty() || record.email.isNotEmpty()

    private fun failure(message: String): Result<AuthSession> =
        Result.failure(AuthException(message))

    private fun success(session: AuthSession): Result<AuthSession> = Result.success(session)

    companion object {
        /** 提供方标识（源 `SandboxAuthProvider.ets:48`）。 */
        const val PROVIDER_ID: String = "sandbox"

        /**
         * 实际 [JsonStore] 键——鸿蒙库名 `fit_tracker_sandbox_auth`
         * （`StoreNames.SANDBOX_AUTH` = 源 `SandboxAuthProvider.ets:20` `SANDBOX_STORE_NAME`）。
         */
        const val STORE_KEY: String = StoreNames.SANDBOX_AUTH

        /** 鸿蒙源键名（源 `SandboxAuthProvider.ets:21` `KEY_USERS`）。安卓侧折叠为库名键，仅作对照。 */
        const val KEY_USERS: String = "users"

        /** 邮箱注册/登录的提供方通道标识（源 `SandboxAuthProvider.ets:117` / `:129`）。 */
        const val EMAIL_PASSWORD_PROVIDER: String = "email_password"

。 */
        private val PHONE_PATTERN: Regex = Regex("^1[3-9]\\d{9}$")

        /** 源 `SandboxAuthProvider.ets:101`——邮箱正则 `^[^\s@]+@[^\s@]+\.[^\s@]+$`。 */
        private val EMAIL_PATTERN: Regex = Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
    }
}

/**
 * 沙盒本地账号记录——源 `SandboxAuthProvider.ets:27` `interface SandboxUserRecord`。
 *
 * 字段名与源 JSON 输出逐字一致（`phone` / `email` / `nickname` / `passwordHash` / `createdAt`），
 * 使两端同一账号目录 JSON 可互读。`createdAt` 承载源 `number`（毫秒）→ 安卓侧 [Long]。
 * 本波仅用邮箱账号，`phone` 保留字段以对齐源结构。
 */
@Serializable
data class SandboxUserRecord(
    val phone: String,
    val email: String,
    val nickname: String,
    val passwordHash: String,
    val createdAt: Long,
)

/** 沙盒验证码签发记录——源 `SandboxAuthProvider.ets:35` `interface SandboxCodeRecord`（内存态，不落盘）。 */
private data class SandboxCodeRecord(
    val code: String,
    val expiresAt: Long,
    val sentAt: Long,
)
