package com.fittracker.app.data.service

import com.fittracker.app.data.service.stats.StatsDashboardService
import java.lang.reflect.Method
import java.util.Calendar
import java.util.TimeZone
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * 周窗口**十字交叉比对**——「旧私有实现」× [WeekWindow] 共享实现 × 服务内私有入口（反射）三方相等。
 *
 * 背景：`ReviewInsightsService.createWeekStart` / `stats.StatsDashboardService.createWeekStart` /
 * `BodyRecordService.mondayStart` 原本各自实现一遍「当周周首 00:00」，现收敛为委托
 * [WeekWindow.weekRange]。行为保持若无可执行断言就只是承诺，本类把三件事钉在一起：
 *
 * 1. **旧私有实现**——本文件内冻结的算法快照（[legacyWeekStartOfReview] / [legacyMondayStartOf]，
 *    照搬重构前逐行代码：`calendarFrom` → 取 `DAY_OF_WEEK-1` → `(dow+6)%7` 或 `dow` → `calendarAt(y, m, d-offset)`），
 *    独立于 [WeekWindow] 实现，作为外部参照；
 * 2. **[WeekWindow] 共享实现**——委托目标；
 * 3. **服务内私有入口**——实际被业务调用的那一层（反射，签名不在则断言失败并给出迁移指引，
 *    不静默跳过）。
 *
 * 断言语义（每样例 × 周一/周日两态 × 每时区）：三者的周首 millis 逐值相等，且周首的
 * `YYYY-MM-DD` 字符串逐字节相等（防「millis 相等而日期口径不同」的巧合）。
 *
 * 时区：默认时区 + 三个 DST 切换点落在**本地午夜**的时区（`America/Santiago` 春季 00:00 跳 01:00、
 * `Asia/Beirut` 00:00 跳、`America/New_York` 02:00 跳）。零点不存在的日子是 `Calendar` 宽松归一
 * 与 `add(DAY_OF_MONTH, ±n)` 最可能分叉的地方，收敛后必须仍逐值相等。
 */
class WeekWindowCrosstabTest {

    private lateinit var originalTimeZone: TimeZone

    @Before
    fun saveTimeZone() {
        originalTimeZone = TimeZone.getDefault()
    }

    @After
    fun restoreTimeZone() {
        TimeZone.setDefault(originalTimeZone)
    }

    // --- 样例 -----------------------------------------------------------------

    /** (标签, 年, 月0, 日, 时, 分, 秒) —— 本地时间口径，构造在每个时区循环内部。 */
    private data class Sample(
        val label: String,
        val year: Int,
        val month0: Int,
        val day: Int,
        val hour: Int = 12,
        val minute: Int = 0,
        val second: Int = 0,
    )

    private val samples: List<Sample> = listOf(
        Sample("普通工作日 2026-10-07 周三", 2026, 9, 7),
        Sample("周首当日 2026-10-05 周一", 2026, 9, 5, 0, 0, 30),
        Sample("周末 2026-10-10 周六 23:59:59", 2026, 9, 10, 23, 59, 59),
        Sample("周日深夜 2026-10-11 周日", 2026, 9, 11, 23, 59, 59),
        Sample("闰日 2024-02-29 周四", 2024, 1, 29),
        Sample("闰日周首 2024-02-26 周一", 2024, 1, 26),
        Sample("年末 2024-12-31 周二", 2024, 11, 31, 23, 30, 0),
        Sample("跨年 2025-01-01 周三", 2025, 0, 1, 0, 0, 1),
        Sample("跨月 2026-10-01 周四", 2026, 9, 1),
        Sample("DST 春切前日 2026-03-07", 2026, 2, 7, 1, 30, 0),
        Sample("DST 秋切后日 2026-11-02", 2026, 10, 2, 1, 30, 0),
    )

    private val zones: List<String> = listOf(
        "UTC",
        "Asia/Shanghai",
        "America/New_York",
        "America/Santiago",
        "Asia/Beirut",
    )

    // --- 旧私有实现快照（独立参照，不调用 WeekWindow） ------------------------

    /** 重构前 `WeekStart` → 距周首天数的硬编码写法（`(dow+6)%7` / `dow`）。 */
    private fun legacyOffset(jsDayOfWeek: Int, weekStart: WeekStart): Int =
        if (weekStart == WeekStart.MONDAY) (jsDayOfWeek + 6) % 7 else jsDayOfWeek

    /**
     * 重构前 `ReviewInsightsService.createWeekStart` / `stats.StatsDashboardService.createWeekStart`
     * 的逐行算法：`calendarFrom(timestamp)` → 读年月日 → `calendarAt(y, m, d - offset)`。
     */
    private fun legacyWeekStartOfReview(timestamp: Long, weekStart: WeekStart): Long {
        val value = Calendar.getInstance().apply { timeInMillis = timestamp }
        val jsDayOfWeek = value.get(Calendar.DAY_OF_WEEK) - 1
        val offset = legacyOffset(jsDayOfWeek, weekStart)
        return calendarAt(
            value.get(Calendar.YEAR),
            value.get(Calendar.MONTH),
            value.get(Calendar.DAY_OF_MONTH) - offset,
        )
    }

    /** 重构前 `BodyRecordService.mondayStart` 的逐行算法：`addDays(startOfDay(millis), -offset)`。 */
    private fun legacyMondayStartOf(millis: Long, weekStart: WeekStart): Long {
        val jsDayOfWeek = jsDayOfWeek(millis)
        val offset = legacyOffset(jsDayOfWeek, weekStart)
        return addDays(startOfDay(millis), -offset)
    }

    private fun jsDayOfWeek(millis: Long): Int =
        Calendar.getInstance().apply { timeInMillis = millis }.get(Calendar.DAY_OF_WEEK) - 1

    private fun startOfDay(millis: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        return calendarAt(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH), cal.get(Calendar.DAY_OF_MONTH))
    }

    private fun addDays(millis: Long, days: Int): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = millis }
        return calendarAt(
            cal.get(Calendar.YEAR),
            cal.get(Calendar.MONTH),
            cal.get(Calendar.DAY_OF_MONTH) + days,
        )
    }

    private fun calendarAt(year: Int, month0: Int, dayOfMonth: Int): Long {
        val cal = Calendar.getInstance()
        cal.clear()
        cal.set(year, month0, dayOfMonth)
        return cal.timeInMillis
    }

    private fun at(sample: Sample): Long = Calendar.getInstance().apply {
        clear()
        set(sample.year, sample.month0, sample.day, sample.hour, sample.minute, sample.second)
    }.timeInMillis

    // --- 服务内私有入口 -------------------------------------------------------

    /** 反射调用服务内私有周首计算，统一折算为 millis；方法缺失即失败（不静默跳过）。 */
    private fun weekStartVia(target: Any, methodName: String, millis: Long, weekStart: WeekStart): Long {
        val method: Method = try {
            target.javaClass.getDeclaredMethod(
                methodName,
                Long::class.javaPrimitiveType!!,
                WeekStart::class.java,
            )
        } catch (e: NoSuchMethodException) {
            throw AssertionError(
                "私有辅助 ${target.javaClass.simpleName}.$methodName(Long, WeekStart) 已不存在——" +
                    "本交叉校验依赖该签名保留（内部改为委托 WeekWindow）；若已删除或改名，" +
                    "请把断言迁移到新的委托入口，不要删掉这条等价证据。",
                e,
            )
        }
        method.isAccessible = true
        return when (val result = method.invoke(target, millis, weekStart)) {
            is Calendar -> result.timeInMillis
            is Long -> result
            else -> throw AssertionError("$methodName 返回类型未知：${result?.javaClass?.name}")
        }
    }

    // --- 十字交叉 -------------------------------------------------------------

    @Test
    fun `旧私有实现 WeekWindow 与服务私有口三方周首逐值相等`() {
        for (zone in zones) {
            TimeZone.setDefault(TimeZone.getTimeZone(zone))
            for (sample in samples) {
                val millis = at(sample)
                for (weekStart in listOf(WeekStart.MONDAY, WeekStart.SUNDAY)) {
                    val where = "$zone / ${sample.label} / $weekStart"
                    val shared = WeekWindow.weekRange(millis, weekStart).first

                    val legacyReview = legacyWeekStartOfReview(millis, weekStart)
                    assertEquals("$where / 旧 vs WeekWindow", legacyReview, shared)
                    assertEquals("$where / 旧 vs WeekWindow（日期口径）", DateUtils.formatDate(legacyReview), DateUtils.formatDate(shared))

                    assertEquals("$where / 旧 vs WeekWindow", legacyMondayStartOf(millis, weekStart), shared)

                    assertEquals(
                        "$where / ReviewInsightsService.createWeekStart vs WeekWindow",
                        shared,
                        weekStartVia(ReviewInsightsService, "createWeekStart", millis, weekStart),
                    )
                    assertEquals(
                        "$where / StatsDashboardService.createWeekStart vs WeekWindow",
                        shared,
                        weekStartVia(StatsDashboardService, "createWeekStart", millis, weekStart),
                    )
                    assertEquals(
                        "$where / BodyRecordService.mondayStart vs WeekWindow",
                        shared,
                        weekStartVia(BodyRecordService, "mondayStart", millis, weekStart),
                    )

                    // 周首 = 当周周首日零点：毫秒偏移为零（DST 跳变日零点可能被 Calendar 归一，
                    // 故用「周首日的时间戳 − 独立重建的周首日零点」比较，二者必须一致）
                    assertEquals(
                        "$where / 周首即当日零点",
                        calendarAt(
                            Calendar.getInstance().apply { timeInMillis = shared }.get(Calendar.YEAR),
                            Calendar.getInstance().apply { timeInMillis = shared }.get(Calendar.MONTH),
                            Calendar.getInstance().apply { timeInMillis = shared }.get(Calendar.DAY_OF_MONTH),
                        ),
                        shared,
                    )
                }
            }
        }
    }

    @Test
    fun `窗口终点 起点加 7 个日历日零点`() {
        for (zone in zones) {
            TimeZone.setDefault(TimeZone.getTimeZone(zone))
            for (sample in samples) {
                val millis = at(sample)
                for (weekStart in listOf(WeekStart.MONDAY, WeekStart.SUNDAY)) {
                    val (start, end) = WeekWindow.weekRange(millis, weekStart)
                    assertEquals(
                        "$zone / ${sample.label} / $weekStart / 窗口终点",
                        addDays(start, 7),
                        end,
                    )
                }
            }
        }
    }
}
