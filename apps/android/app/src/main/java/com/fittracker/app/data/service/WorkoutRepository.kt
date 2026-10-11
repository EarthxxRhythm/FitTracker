package com.fittracker.app.data.service

import com.fittracker.app.data.model.WorkoutSession
import com.fittracker.app.data.model.WorkoutSet
import com.fittracker.app.data.persist.JsonCodec
import com.fittracker.app.data.persist.JsonStore
import com.fittracker.app.data.persist.StoreNames
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString

/**
 * 本地训练会话仓储——方法名逐一对齐鸿蒙 `shared/services/WorkoutRepository.ets`。
 *
 * Failure #4：本地仓储与应用状态（源 `WorkoutRepository.ets:4`）。
 *
 * 持久化迁移说明（与源的**关键差异**）：
 * 鸿蒙 `WorkoutRepository` 是**纯内存**骨架（源 L9 `private sessions: WorkoutSession[] = []`，
 * 无 `preferences`）。本安卓移植按 Wave 3 要求把会话列表落到 DataStore——整块
 * `List<WorkoutSession>` JSON 存于键 [StoreNames.SESSIONS]（鸿蒙语义库名 `fit_tracker_sessions`）。
 * 因此源的**同步内存方法**在安卓侧升级为 `suspend` + 注入 [JsonStore]（每次读写即落盘/读盘），
 * 方法名保持不变，语义（含「从尾部查找」「重复 id 允许」等细节）逐行复刻。
 *
 * 注意：`createSession` 是**纯工厂**（源 L11），不落库、不打 IO，保持非 suspend。
 */
object WorkoutRepository {

    /** 实际 JsonStore 键——鸿蒙语义库名 `fit_tracker_sessions`（`AppStores.kt` StoreNames.SESSIONS）。 */
    const val STORE_KEY: String = StoreNames.SESSIONS

    // --- 源 L11-L37：纯工厂，不落库 -----------------------------------------

    /**
     * 源 `WorkoutRepository.ets:11` `createSession`——按源 `createWorkoutSession`
     * （`TrainingModels.ets:308`）字段顺序重建会话，并深拷贝组记录。
     */
    fun createSession(
        sessionId: String,
        planId: String,
        dayId: String,
        startedAt: Long,
        endedAt: Long,
        durationSeconds: Int,
        totalSets: Int,
        totalVolume: Double,
        fatigueScore: Double,
        notes: String,
        sets: List<WorkoutSet>,
    ): WorkoutSession = WorkoutSession(
        sessionId = sessionId,
        planId = planId,
        dayId = dayId,
        startedAt = startedAt,
        endedAt = endedAt,
        durationSeconds = durationSeconds,
        totalSets = totalSets,
        totalVolume = totalVolume,
        fatigueScore = fatigueScore,
        notes = notes,
        sets = copySets(sets),
    )

    // --- 源 L39-L101：集合操作（内存数组 → DataStore 落盘） -------------------

    /** 源 `WorkoutRepository.ets:39` `saveSession`——追加副本（源允许重复 id）。 */
    suspend fun saveSession(store: JsonStore, session: WorkoutSession) {
        val sessions: MutableList<WorkoutSession> = readSessions(store)
        sessions.add(copySession(session))
        writeSessions(store, sessions)
    }

    /** 源 `WorkoutRepository.ets:43` `updateSession`——按 id 就地替换，命中返回 `true`。 */
    suspend fun updateSession(store: JsonStore, session: WorkoutSession): Boolean {
        val sessions: MutableList<WorkoutSession> = readSessions(store)
        val index: Int = sessions.indexOfFirst { it.sessionId == session.sessionId }
        if (index < 0) {
            return false
        }
        sessions[index] = copySession(session)
        writeSessions(store, sessions)
        return true
    }

    /**
     * 源 `WorkoutRepository.ets:53` `removeSession`——**从尾部**找首个匹配（重复 id 时删最新一条），
     * 删除并返回其副本；未命中返回 `null`（源 `undefined`）。
     */
    suspend fun removeSession(store: JsonStore, sessionId: String): WorkoutSession? {
        val sessions: MutableList<WorkoutSession> = readSessions(store)
        val index: Int = sessions.indexOfLast { it.sessionId == sessionId }
        if (index < 0) {
            return null
        }
        val removed: WorkoutSession = sessions.removeAt(index)
        writeSessions(store, sessions)
        return copySession(removed)
    }

    /** 源 `WorkoutRepository.ets:64` `restoreSession`——id 已存在则返回 `false`（不覆盖）。 */
    suspend fun restoreSession(store: JsonStore, session: WorkoutSession): Boolean {
        val sessions: MutableList<WorkoutSession> = readSessions(store)
        if (sessions.any { it.sessionId == session.sessionId }) {
            return false
        }
        sessions.add(copySession(session))
        writeSessions(store, sessions)
        return true
    }

    /** 源 `WorkoutRepository.ets:74` `getSessions`——返回全部副本（保序）；空库返回空列表。 */
    suspend fun getSessions(store: JsonStore): List<WorkoutSession> =
        readSessions(store).map { copySession(it) }

    /**
     * 源 `WorkoutRepository.ets:82` `getSessionById`——**从尾部**匹配，故重复 id 取最新一条；
     * 未命中返回 `null`。
     */
    suspend fun getSessionById(store: JsonStore, sessionId: String): WorkoutSession? =
        readSessions(store).lastOrNull { it.sessionId == sessionId }?.let { copySession(it) }

    /** 源 `WorkoutRepository.ets:92` `getLatestSession`——空库返回 `null`，否则末条（最近）。 */
    suspend fun getLatestSession(store: JsonStore): WorkoutSession? =
        readSessions(store).lastOrNull()?.let { copySession(it) }

    /** 源 `WorkoutRepository.ets:99` `clear`——清空会话（删库键）。 */
    suspend fun clear(store: JsonStore) {
        store.remove(STORE_KEY)
    }

    // --- 内部：整块 JSON 读写 ------------------------------------------------

    /** 读回会话列表；缺失/空串/解析失败一律回落空列表（对齐源「空数组」初始态）。 */
    private suspend fun readSessions(store: JsonStore): MutableList<WorkoutSession> {
        val raw: String? = store.readString(STORE_KEY)
        if (raw.isNullOrEmpty()) {
            return mutableListOf()
        }
        return try {
            JsonCodec.json.decodeFromString<List<WorkoutSession>>(raw).toMutableList()
        } catch (error: Exception) {
            mutableListOf()
        }
    }

    private suspend fun writeSessions(store: JsonStore, sessions: List<WorkoutSession>) {
        store.writeString(STORE_KEY, JsonCodec.json.encodeToString(sessions))
    }

    /** 源 `WorkoutRepository.ets:103` `copyWorkoutSession`——重建会话并深拷贝组记录。 */
    private fun copySession(source: WorkoutSession): WorkoutSession =
        source.copy(sets = copySets(source.sets))

    /** 源 `WorkoutRepository.ets:119` `copyWorkoutSets`——逐组 `WorkoutSet` 重建。 */
    private fun copySets(source: List<WorkoutSet>): List<WorkoutSet> = source.map { it.copy() }
}
