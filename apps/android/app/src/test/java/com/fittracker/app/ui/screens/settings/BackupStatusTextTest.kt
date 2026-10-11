package com.fittracker.app.ui.screens.settings

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.fittracker.app.R
import com.fittracker.app.data.model.UserDataBackupImportResult
import com.fittracker.app.data.service.backup.UserDataBackupService
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 备份域文案资源的**逐字真源**断言（Wave 8 i18n）。
 *
 * 中文真值在 `values/strings_backup.xml`（逐字取自既有硬编码常量，其源自鸿蒙
 * `shared/services/UserDataBackupService.ets`），此处以 `context.getString` 解析校验；
 * 改动中文即红。
 *
 * `qualifiers = "zh-rCN"`：不钉区域限定符时 Robolectric 默认走 en 资源。
 * 注意：Kotlin 字符串里的模板占位须转义为 `%1\$d`（资源 XML 里照写 `%1$d`）。
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "zh-rCN")
class BackupStatusTextTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    private fun importResult(
        success: Boolean = true,
        statusId: String = "import_success",
        importedPlanCount: Int = 0,
        mergedSessionCount: Int = 0,
        effectiveCurrentPlanId: String = "",
        usedPlanFallback: Boolean = false,
    ) = UserDataBackupImportResult(
        success = success,
        statusId = statusId,
        importedPlanCount = importedPlanCount,
        importedSessionCount = 0,
        mergedSessionCount = mergedSessionCount,
        effectiveCurrentPlanId = effectiveCurrentPlanId,
        usedPlanFallback = usedPlanFallback,
    )

    @Test
    fun `备份域文案中文逐字对齐`() {
        val expectations = listOf(
            R.string.backup_scope_summary to "仅备份目标、计划和训练记录；不包含训练草稿、内容库和媒体缓存。",
            R.string.backup_usage_hint to "适用于换机、清理前导出或手工恢复。",
            R.string.backup_restore_rule to "目标与计划以导入包为准，训练记录按 sessionId 去重合并。",
            R.string.backup_export_success_status to "备份包已生成，可用于换机、清理前导出或手工恢复。",
            R.string.backup_export_failure_status to "备份包生成失败，请稍后重试。",
            R.string.backup_import_empty_status to "请先粘贴备份 JSON。",
            R.string.backup_import_failure_unsupported to "备份包版本暂不受支持，请先升级应用后再试。",
            R.string.backup_import_failure_invalid to "备份包格式无效，无法导入。",
            R.string.backup_import_success to "备份已导入：目标与计划已按导入包恢复，训练记录已按 sessionId 去重合并。共恢复 %1\$d 个计划，合并后保留 %2\$d 条训练记录。",
            R.string.backup_import_success_fallback_plan to "当前计划指针无效，已回退到首个可用计划。",
            R.string.backup_import_success_plan_cleared to "导入包没有可用计划，当前计划已清空。",
        )

        assertEquals("备份域 zh 文案应为 11 条", 11, expectations.size)
        expectations.forEach { (id, expected) ->
            assertEquals("资源 id=$id 与既有中文不一致", expected, context.getString(id))
        }
    }

    /** 服务常量必须是本域资源 id（Wave 8：常量由 String 改 @StringRes Int）。 */
    @Test
    fun `服务常量映射到资源 id`() {
        assertEquals(R.string.backup_scope_summary, UserDataBackupService.BACKUP_SCOPE_SUMMARY_RES)
        assertEquals(R.string.backup_usage_hint, UserDataBackupService.BACKUP_USAGE_HINT_RES)
        assertEquals(R.string.backup_restore_rule, UserDataBackupService.BACKUP_RESTORE_RULE_RES)
        assertEquals(
            R.string.backup_export_success_status,
            UserDataBackupService.BACKUP_EXPORT_SUCCESS_STATUS_RES,
        )
        assertEquals(
            R.string.backup_export_failure_status,
            UserDataBackupService.BACKUP_EXPORT_FAILURE_STATUS_RES,
        )
        assertEquals(R.string.backup_import_empty_status, UserDataBackupService.BACKUP_IMPORT_EMPTY_STATUS_RES)
    }

    @Test
    fun `导入失败文案按 statusId 二分`() {
        assertEquals(
            R.string.backup_import_failure_unsupported,
            UserDataBackupService.importFailureStatusRes(UserDataBackupService.STATUS_BACKUP_SCHEMA_UNSUPPORTED),
        )
        assertEquals(
            R.string.backup_import_failure_invalid,
            UserDataBackupService.importFailureStatusRes(UserDataBackupService.STATUS_BACKUP_INVALID_JSON),
        )
    }

    /** 成功主句插值逐字（计数替换 + 回退子句以空格相连）。 */
    @Test
    fun `导入成功文案含计数与回退追加`() {
        assertEquals(
            "备份已导入：目标与计划已按导入包恢复，训练记录已按 sessionId 去重合并。共恢复 2 个计划，合并后保留 3 条训练记录。",
            backupImportStatusText(context, importResult(importedPlanCount = 2, mergedSessionCount = 3)),
        )

        assertEquals(
            "备份已导入：目标与计划已按导入包恢复，训练记录已按 sessionId 去重合并。共恢复 1 个计划，合并后保留 1 条训练记录。 当前计划指针无效，已回退到首个可用计划。",
            backupImportStatusText(
                context,
                importResult(
                    importedPlanCount = 1,
                    mergedSessionCount = 1,
                    effectiveCurrentPlanId = "p1",
                    usedPlanFallback = true,
                ),
            ),
        )

        assertEquals(
            "备份已导入：目标与计划已按导入包恢复，训练记录已按 sessionId 去重合并。共恢复 0 个计划，合并后保留 1 条训练记录。 导入包没有可用计划，当前计划已清空。",
            backupImportStatusText(
                context,
                importResult(
                    importedPlanCount = 0,
                    mergedSessionCount = 1,
                    effectiveCurrentPlanId = "",
                    usedPlanFallback = true,
                ),
            ),
        )
    }

    @Test
    fun `导入失败时渲染失败文案`() {
        assertEquals(
            "备份包版本暂不受支持，请先升级应用后再试。",
            backupImportStatusText(
                context,
                importResult(success = false, statusId = UserDataBackupService.STATUS_BACKUP_SCHEMA_UNSUPPORTED),
            ),
        )
    }

    /** English 资源生效（`values-en/strings_backup.xml`）——方法级区域限定符覆盖类级 `zh-rCN`。 */
    @Test
    @Config(sdk = [34], qualifiers = "en-rUS")
    fun `英文资源在 en 区域生效`() {
        assertEquals(
            "Backup created. Use it to switch phones, export before a cleanup, or restore by hand.",
            context.getString(R.string.backup_export_success_status),
        )
        assertEquals(
            "Backup imported: goals and plans were restored from the imported package, and workout records were merged and de-duplicated by sessionId. Restored 2 plans and kept 3 workout records after merging.",
            backupImportStatusText(context, importResult(importedPlanCount = 2, mergedSessionCount = 3)),
        )
    }
}
