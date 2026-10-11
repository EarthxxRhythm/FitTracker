package com.fittracker.app.data.model

import com.fittracker.app.data.persist.JsonCodec
import kotlinx.serialization.encodeToString
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 备份包契约测试——互通目标是「鸿蒙导出的 JSON 可直接由本应用解析」（反之亦然）。
 *
 * 样本结构取自 `UserDataBackupService.ets:26-33`（导出经 `JSON.stringify(pkg, null, 2)`），
 * 字段与嵌套层级逐字模拟鸿蒙输出形态（含中文、`null` goal、空数组等边界）。
 */
class BackupPackageTest {

    /** 模拟鸿蒙 `exportPackage()` 输出的备份 JSON（含一条计划、一条会话、一个目标）。 */
    private val harmonySampleJson = """
    {
      "schemaVersion": 1,
      "exportedAt": 1759430400000,
      "goal": {
        "goalId": "goal-1",
        "goalType": "muscle_gain",
        "level": "intermediate",
        "weeklyDays": 4,
        "sessionMinutes": 60,
        "equipmentIds": ["barbell", "dumbbell"],
        "restrictedMuscleIds": [],
        "createdAt": 1759000000000,
        "updatedAt": 1759000000000
      },
      "plans": [
        {
          "id": "preset_upper_lower",
          "name": "二分化（上下肢）",
          "coverColor": "#43A047",
          "targetAudience": "初中级健身者",
          "weeklyFrequency": "4 天/周",
          "description": "按上肢、下肢两类交替安排，每周各练两次。",
          "days": [
            {
              "dayLabel": "上肢A",
              "exercises": [
                { "name": "杠铃平板卧推", "targetMuscle": "胸部", "sets": 4, "reps": "8-12" }
              ],
              "dayOfWeek": [1]
            }
          ],
          "enabledAt": 1759100000000
        }
      ],
      "currentPlanId": "preset_upper_lower",
      "sessions": [
        {
          "sessionId": "sess-1",
          "planId": "preset_upper_lower",
          "dayId": "上肢A",
          "startedAt": 1759300000000,
          "endedAt": 1759303600000,
          "durationSeconds": 3600,
          "totalSets": 12,
          "totalVolume": 8450.5,
          "fatigueScore": 7.5,
          "notes": "target_sets=12 completed_sets=12",
          "sets": [
            { "setId": "set-1", "exerciseId": "ex-bench", "weight": 62.5, "reps": 10, "rpe": 8, "isWarmup": false }
          ]
        }
      ],
      "contentMeta": { "contentVersion": 3 }
    }
    """.trimIndent()

    @Test
    fun `可解析鸿蒙导出的备份JSON`() {
        val pkg = JsonCodec.json.decodeFromString(UserDataBackupPackage.serializer(), harmonySampleJson)

        assertEquals(1, pkg.schemaVersion)
        assertEquals(1759430400000, pkg.exportedAt)
        assertEquals("goal-1", pkg.goal?.goalId)
        assertEquals(listOf("barbell", "dumbbell"), pkg.goal?.equipmentIds)
        assertEquals(1, pkg.plans.size)
        assertEquals("preset_upper_lower", pkg.plans[0].id)
        assertEquals("二分化（上下肢）", pkg.plans[0].name)
        assertEquals("杠铃平板卧推", pkg.plans[0].days[0].exercises[0].name)
        assertEquals(listOf(1), pkg.plans[0].days[0].dayOfWeek)
        assertEquals("preset_upper_lower", pkg.currentPlanId)
        assertEquals(1, pkg.sessions.size)
        assertEquals("sess-1", pkg.sessions[0].sessionId)
        assertEquals(8450.5, pkg.sessions[0].totalVolume, 1e-9)
        assertEquals("target_sets=12 completed_sets=12", pkg.sessions[0].notes)
        assertEquals(3, pkg.contentMeta.contentVersion)
    }

    @Test
    fun `null目标与空集合可解析`() {
        val json = """
        {
          "schemaVersion": 1, "exportedAt": 0, "goal": null, "plans": [],
          "currentPlanId": "", "sessions": [],
          "contentMeta": { "contentVersion": 0 }
        }
        """.trimIndent()
        val pkg = JsonCodec.json.decodeFromString(UserDataBackupPackage.serializer(), json)
        assertNull(pkg.goal)
        assertTrue(pkg.plans.isEmpty())
        assertEquals("", pkg.currentPlanId)
    }

    @Test
    fun `未知字段不破坏解析_前向兼容`() {
        // 模拟鸿蒙侧未来为 goal 添加字段：ignoreUnknownKeys 应容忍
        val json = harmonySampleJson.replace(
            "\"goalId\": \"goal-1\",",
            "\"goalId\": \"goal-1\", \"futureField\": 123,",
        )
        val pkg = JsonCodec.json.decodeFromString(UserDataBackupPackage.serializer(), json)
        assertEquals("goal-1", pkg.goal?.goalId)
    }

    @Test
    fun `备份包往返全等`() {
        val original = JsonCodec.json.decodeFromString(UserDataBackupPackage.serializer(), harmonySampleJson)
        val reEncoded = JsonCodec.json.encodeToString(UserDataBackupPackage.serializer(), original)
        val reDecoded = JsonCodec.json.decodeFromString(UserDataBackupPackage.serializer(), reEncoded)
        assertEquals(original, reDecoded)
    }

    @Test
    fun `schemaVersion缺省为1`() {
        assertEquals(1, BACKUP_SCHEMA_VERSION)
    }
}
