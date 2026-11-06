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
 * [WeekWindow] 契约测试——「周开始日」（周一/周日）两态全组合。
 *
 * 纯 JVM 测试（java.util.Calendar + 纯 Kotlin 枚举），不需要 Robolectric。
 * 时间构造统一走默认时区（与实现口径一致）。
 */
class WeekWindowTest {

    private fun at(year: Int, month0: Int, day: Int, hour: Int = 12, minute: Int = 0, second: Int = 0): Long =
        Calendar.getInstance().apply {
            set(year, month0, day, hour, minute, second)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    private fun dayOfWeekOf(millis: Long): Int =
        Calendar.getInstance().apply { timeInMillis = millis }.get(Calendar.DAY_OF_WEEK)

    private fun millisOfDay(millis: Long): Int =
        Calendar.getInstance().apply { timeInMillis = millis }.let {
            it.get(Calendar.HOUR_OF_DAY) * 3600_000 +
                it.get(Calendar.MINUTE) * 60_000 +
                it.get(Calendar.SECOND) * 1000 +
                it.get(Calendar.MILLISECOND)
        }

    // --- offsetFromWeekStart -------------------------------------------------

    @Test
    fun `偏移矩阵 周一态与周日态全组合`() {
        val mondayExpected = mapOf(0 to 6, 1 to 0, 2 to 1, 3 to 2, 4 to 3, 5 to 4, 6 to 5)
        val sundayExpected = mapOf(0 to 0, 1 to 1, 2 to 2, 3 to 3, 4 to 4, 5 to 5, 6 to 6)
        for (js in 0..6) {
            assertEquals("MONDAY js=$js", mondayExpected.getValue(js), WeekWindow.offsetFromWeekStart(js, WeekStart.MONDAY))
            assertEquals("SUNDAY js=$js", sundayExpected.getValue(js), WeekWindow.offsetFromWeekStart(js, WeekStart.SUNDAY))
        }
    }

    // --- dayLabels -----------------------------------------------------------

    @Test
    fun `标签序 周一起始为 一至日 周日起始为 日至六`() {
        assertEquals(listOf("一", "二", "三", "四", "五", "六", "日"), WeekWindow.dayLabels(WeekStart.MONDAY))
        assertEquals(listOf("日", "一", "二", "三", "四", "五", "六"), WeekWindow.dayLabels(WeekStart.SUNDAY))
    }

    @Test
    fun `标签序 英文 周一起始 Mon 起 周日起始 Sun 起`() {
        assertEquals(
            listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"),
            WeekWindow.dayLabels(WeekStart.MONDAY, "en"),
        )
        assertEquals(
            listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"),
            WeekWindow.dayLabels(WeekStart.SUNDAY, "en-US"),
        )
    }

    // --- weekRange -----------------------------------------------------------

    @Test
    fun `weekRange 周三锚点 窗口为周首零点起 7 天`() {
        val wednesday = at(2026, 9, 7) // 2026-10-07 周三
        val (monStart, monEnd) = WeekWindow.weekRange(wednesday, WeekStart.MONDAY)
        assertEquals(0, millisOfDay(monStart))
        assertEquals(Calendar.MONDAY, dayOfWeekOf(monStart))
        assertEquals("2026-10-05", WorkoutSessionService.formatDate(monStart))
        assertEquals("2026-10-12", WorkoutSessionService.formatDate(monEnd)) // exclusive：下周一

        val (sunStart, sunEnd) = WeekWindow.weekRange(wednesday, WeekStart.SUNDAY)
        assertEquals(Calendar.SUNDAY, dayOfWeekOf(sunStart))
        assertEquals("2026-10-04", WorkoutSessionService.formatDate(sunStart))
        assertEquals("2026-10-11", WorkoutSessionService.formatDate(sunEnd))
    }

    @Test
    fun `weekRange 周日深夜 周一态仍属当周`() {
        val sundayLate = at(2026, 9, 11, 23, 59, 59) // 2026-10-11 周日
        val (start, _) = WeekWindow.weekRange(sundayLate, WeekStart.MONDAY)
        assertEquals("2026-10-05", WorkoutSessionService.formatDate(start)) // 仍是 10-05 起的一周
    }

    @Test
    fun `weekRange 跨年 2026-01-01 属 2025-12-29 起的一周`() {
        val newYear = at(2026, 0, 1) // 2026-01-01 周四
        val (start, _) = WeekWindow.weekRange(newYear, WeekStart.MONDAY)
        assertEquals("2025-12-29", WorkoutSessionService.formatDate(start))
        assertEquals(Calendar.MONDAY, dayOfWeekOf(start))
    }

    // --- weekDateRange -------------------------------------------------------

    @Test
    fun `weekDateRange 闭区间首尾 两态`() {
        val wednesday = at(2026, 9, 7)
        assertEquals("2026-10-05" to "2026-10-11", WeekWindow.weekDateRange(wednesday, WeekStart.MONDAY))
        assertEquals("2026-10-04" to "2026-10-10", WeekWindow.weekDateRange(wednesday, WeekStart.SUNDAY))
    }

    // --- weekRangeText（原型格式「M 月 d – d 日」，en dash） -------------------

    @Test
    fun `weekRangeText 同月 两态`() {
        val wednesday = at(2026, 9, 7) // 2026-10-07 周三
        assertEquals("10 月 5 – 11 日", WeekWindow.weekRangeText(wednesday, WeekStart.MONDAY))
        assertEquals("10 月 4 – 10 日", WeekWindow.weekRangeText(wednesday, WeekStart.SUNDAY))
    }

    @Test
    fun `weekRangeText 跨月 2026-10-01 周一态含 9 月尾`() {
        val oct1 = at(2026, 9, 1) // 2026-10-01 周四
        // 周一态：09-28 ~ 10-04，跨月格式「M 月 d – M 月 d 日」
        assertEquals("9 月 28 – 10 月 4 日", WeekWindow.weekRangeText(oct1, WeekStart.MONDAY))
    }

    @Test
    fun `weekRangeText 英文格式 同月与跨月`() {
        val wednesday = at(2026, 9, 7) // 2026-10-07 周三
        assertEquals("Oct 5 – 11", WeekWindow.weekRangeText(wednesday, WeekStart.MONDAY, "en"))
        assertEquals("Oct 4 – 10", WeekWindow.weekRangeText(wednesday, WeekStart.SUNDAY, "en"))
        val oct1 = at(2026, 9, 1) // 2026-10-01 周四
        assertEquals("Sep 28 – Oct 4", WeekWindow.weekRangeText(oct1, WeekStart.MONDAY, "en"))
    }
}

/**
 * 周窗口「委托等价」交叉校验——服务内私有 `createWeekStart` / `mondayStart` 与
 * [WeekWindow.weekRange] 的**周首 millis 逐值相等**。
 *
 * 为什么要反射进私有方法：`mod-weekwindow-dedup` 要把三处 `createWeekStart`
 * （`ReviewInsightsService` / `stats.StatsDashboardService`）与 `mondayStart`
 * （`BodyRecordService`）改为委托 [WeekWindow]，「行为保持」若无可执行断言就只是承诺。
 * 这三处现在是 `private`，测试唯一的对照入口就是反射调用——它测的正是「原实现」与
 * 「委托目标」在同一时间戳上是否给出同一结果，即重构前后的逐字节等价。
 *
 * 断言语义（每个样例 × 周一/周日两态）：
 * 1. 三家服务的周首 millis == `WeekWindow.weekRange(...).first`；
 * 2. 周首的日期字符串也逐字节相等（防「millis 相等但日期口径不同」的巧合）；
 * 3. 窗口终点 == 起点 + 7 个日历日的零点（与 `weekRange` 的 `add(DAY_OF_MONTH, 7)` 同口径）。
 *
 * 时区：本类固定为 `America/New_York`（@Before 设定、@After 还原）——该时区含 DST 切换，
 * 等价性必须在「周内跨夏令时边界」仍成立；选它是因为其切换点在 02:00，本地零点始终存在。
 */
class WeekWindowDelegationParityTest {

    private lateinit var originalTimeZone: TimeZone

    @Before
    fun pinTimeZone() {
        originalTimeZone = TimeZone.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("America/New_York"))
    }

    @After
    fun restoreTimeZone() {
        TimeZone.setDefault(originalTimeZone)
    }

    /** 本地时间构造（[hour] 缺省 12 = 正午，避开 DST 与日界）。 */
    private fun at(
        year: Int,
        month0: Int,
        day: Int,
        hour: Int = 12,
        minute: Int = 0,
        second: Int = 0,
    ): Long = Calendar.getInstance().apply {
        clear()
        set(year, month0, day, hour, minute, second)
    }.timeInMillis

    /** 某日零点的 7 个日历日之后（Calendar 归一跨月/跨年），作为窗口终点的独立口径。 */
    private fun sevenDaysLater(startMillis: Long): Long {
        val start = Calendar.getInstance().apply { timeInMillis = startMillis }
        return Calendar.getInstance().apply {
            clear()
            set(start.get(Calendar.YEAR), start.get(Calendar.MONTH), start.get(Calendar.DAY_OF_MONTH) + 7)
        }.timeInMillis
    }

    /**
     * 反射调用服务内私有周首计算，统一折算为 millis。
     *
     * 方法缺失即判失败并给出迁移指引——不静默跳过：静默跳过会让「等价性已证」变成又一次假门。
     */
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

    @Test
    fun `服务私有周首计算与 weekRange 起止逐值相等`() {
        val samples: List<Pair<String, Long>> = listOf(
            "周中 2026-10-07 周三" to at(2026, 9, 7),
            "跨月 2026-10-01 周四" to at(2026, 9, 1),
            "跨年 2026-01-01 周四" to at(2026, 0, 1),
            "周末 2026-10-10 周六" to at(2026, 9, 10),
            "周日深夜 2026-10-11" to at(2026, 9, 11, 23, 59, 59),
            "周日零点后 2026-10-04" to at(2026, 9, 4, 0, 0, 30),
            "闰日 2024-02-29 周四" to at(2024, 1, 29),
            "DST 春切前 2026-03-07" to at(2026, 2, 7, 1, 30),
            "DST 春切后 2026-03-09" to at(2026, 2, 9, 23, 30),
            "DST 秋切前 2026-10-31" to at(2026, 9, 31, 23, 30),
            "DST 秋切后 2026-11-02" to at(2026, 10, 2, 1, 30),
        )

        for ((label, millis) in samples) {
            for (weekStart in listOf(WeekStart.MONDAY, WeekStart.SUNDAY)) {
                val (expectStart, expectEnd) = WeekWindow.weekRange(millis, weekStart)

                assertEquals(
                    "$label / $weekStart / ReviewInsightsService.createWeekStart",
                    expectStart,
                    weekStartVia(ReviewInsightsService, "createWeekStart", millis, weekStart),
                )
                assertEquals(
                    "$label / $weekStart / StatsDashboardService.createWeekStart",
                    expectStart,
                    weekStartVia(StatsDashboardService, "createWeekStart", millis, weekStart),
                )
                assertEquals(
                    "$label / $weekStart / BodyRecordService.mondayStart",
                    expectStart,
                    weekStartVia(BodyRecordService, "mondayStart", millis, weekStart),
                )

                // 日期字符串逐字节相等（防 millis 相等而日期口径不同的巧合）
                assertEquals(
                    "$label / $weekStart / 周首日期口径",
                    WorkoutSessionService.formatDate(expectStart),
                    DateUtils.formatDate(expectStart),
                )
                // 窗口终点：7 个日历日后的零点
                assertEquals("$label / $weekStart / 窗口终点", sevenDaysLater(expectStart), expectEnd)
            }
        }
    }
}
