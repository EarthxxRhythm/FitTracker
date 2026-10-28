package com.fittracker.app.nav

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume
import org.junit.Test
import java.io.File

/**
 * 路由表的不可变量测试。
 *
 * 这些断言直接对应本次迁移最容易出错的地方：
 *  - 路由条数与顺序必须与原型 `fittracker-webapp.html` 的 ROUTE_ORDER 逐项一致；
 *  - 每屏的画布口径（430×900 缩放 vs 390×844 直绘）必须与源码实证一致；
 *  - 每条路由引用的源文件与 frame id 必须在冻结规格副本里真实存在。
 */
class FtRoutesTest {

    /** 原型 `fittracker-webapp.html` 的 ROUTE_ORDER 逐字顺序 */
    private val expectedOrder = listOf(
        "welcome", "login", "register", "home", "plan", "workout", "plans", "planGroup",
        "active", "complete", "review", "library", "body", "profile", "settings",
    )

    @Test
    fun `路由共 15 条且顺序与原型 ROUTE_ORDER 一致`() {
        assertEquals(15, FtRoutes.all.size)
        assertEquals(expectedOrder, FtRoutes.all.map { it.id })
    }

    @Test
    fun `路由 id 唯一`() {
        val ids = FtRoutes.all.map { it.id }
        assertEquals(ids.size, ids.toSet().size)
    }

    /** 原型 15 条之外的 5 条与 [FtRoutes.all] 分开维护；导航注册用 navigable（合并 20 条）。 */
    @Test
    fun `原型外 5 条路由挂在 extra 且并入 navigable`() {
        assertEquals(
            listOf("splash", "exerciseDetail", "legal", "trainingPreferences", "profileEdit"),
            FtRoutes.extra.map { it.id },
        )
        assertEquals(20, FtRoutes.navigable.size)
        assertEquals(FtRoutes.all, FtRoutes.navigable.take(15))
    }

    @Test
    fun `navigable 共 20 条 id 唯一且两侧均可 byId`() {
        val ids = FtRoutes.navigable.map { it.id }
        assertEquals(20, ids.size)
        assertEquals(ids.size, ids.toSet().size)
        assertTrue(FtRoutes.byId("splash") != null)
        assertTrue(FtRoutes.byId("home") != null)
        assertTrue(FtRoutes.byId("trainingPreferences") != null)
        assertTrue(FtRoutes.byId("profileEdit") != null)
    }

    /**
     * 画布口径：逐屏实测（`tools/audit-canvas.mjs`）结论是**四屏**缩放——
     * welcome / login / register / complete。
     * 依据 `fittracker-welcome-home.html:190-197`（.w-frame）、`fittracker-auth.html:176-184`（.auth-frame）、
     * `fittracker-training-complete.html:178-190`（.cf-frame）。
     * 注意：这与 `docs/opendesign-1to1-rules.md` §2「仅 welcome 缩放」冲突，以源码为准。
     */
    @Test
    fun `缩放画布屏恰为 welcome login register complete 四屏`() {
        val scaled = FtRoutes.all.filter { it.canvas == FtCanvasKind.Scaled }.map { it.id }
        assertEquals(setOf("welcome", "login", "register", "complete"), scaled.toSet())
    }

    @Test
    fun `其余 11 屏均为直绘`() {
        val direct = FtRoutes.all.filter { it.canvas == FtCanvasKind.Direct }.map { it.id }
        assertEquals(11, direct.size)
        assertTrue(direct.none { it in setOf("welcome", "login", "register", "complete") })
    }

    /**
     * 缩放屏的设计空间逐屏不同，不能一概而论：
     * welcome/login/register 为 430×900；complete 为 430×(844/0.90698) ≈ 930.56
     * （`height: calc(844px / var(--scale))`）。硬编码 430×900 会把 complete 误判为直绘。
     */
    @Test
    fun `缩放屏的设计空间与原型逐屏一致`() {
        listOf("welcome", "login", "register").forEach { id ->
            val r = FtRoutes.byId(id)!!
            assertEquals("$id 设计宽", 430f, r.designW, 1e-4f)
            assertEquals("$id 设计高", 900f, r.designH, 1e-4f)
        }
        val complete = FtRoutes.byId("complete")!!
        assertEquals(430f, complete.designW, 1e-4f)
        assertEquals(930.56f, complete.designH, 0.05f)
    }

    @Test
    fun `底部 Tab 恰为 home plan workout review profile 五枚`() {
        assertEquals(
            listOf("home", "plan", "workout", "review", "profile"),
            FtRoutes.all.filter { it.isTab }.map { it.id },
        )
    }

    /** 原型 tabbar 第三枚是中央胶囊（`welcome-home.html:934` 的 `.tab-center`）。 */
    @Test
    fun `中央胶囊 Tab 恰为 workout 一枚且位于 Tab 列表正中`() {
        val centers = FtRoutes.tabs.filter { it.isTabCenter }
        assertEquals(listOf("workout"), centers.map { it.id })
        assertEquals(2, FtRoutes.tabs.indexOfFirst { it.isTabCenter })
    }

    @Test
    fun `非 Tab 路由不得标记为 Tab 或中央胶囊`() {
        val bogus = FtRoutes.all.filter { !it.isTab && it.isTabCenter }
        assertEquals(emptyList<FtRoute>(), bogus)
    }

    /**
     * 路由表引用的源文件必须在仓库内的冻结规格副本中真实存在。
     *
     * 2026-10-28：`design/06_prototype_redraw` 冻结副本已随仓库清理移除（授权与体积双重原因）。
     * 副本在场时照旧逐条校验，不在场时以 assumption 跳过——不删除断言，便于日后恢复基线。
     */
    @Test
    fun `每条路由的源文件都存在于冻结规格副本`() {
        val dir = specDir()
        Assume.assumeTrue("冻结规格副本已移除（design/06_prototype_redraw/src），跳过该断言", dir != null)
        val missing = FtRoutes.all
            .map { it.srcFile }
            .distinct()
            .filterNot { File(dir, it).isFile }
        assertEquals("冻结副本缺失：$missing", emptyList<String>(), missing)
    }

    /** 每条路由的 frame id 必须能在对应源文件里找到（副本缺失时跳过，见上）。 */
    @Test
    fun `每条路由的 frame id 都能在源文件中命中`() {
        val dir = specDir()
        Assume.assumeTrue("冻结规格副本已移除（design/06_prototype_redraw/src），跳过该断言", dir != null)
        val bad = FtRoutes.all.filterNot { route ->
            val f = File(dir, route.srcFile)
            f.isFile && f.readText(Charsets.UTF_8).contains("data-od-id=\"${route.frame}\"")
        }
        assertEquals("frame id 未命中：${bad.map { "${it.id}->${it.frame}" }}", emptyList<FtRoute>(), bad)
    }

    /**
     * 深链接 scheme 必须与主清单 `<data android:scheme=...>` 声明一致——
     * 否则 `adb shell am start -d "fittracker://home"` 会静默地打开 App 却停在起始路由，
     * 验收脚本会误判为「路由不可达」。
     */
    @Test
    fun `深链接 scheme 与主清单声明一致`() {
        val manifest = sequenceOf(
            File("src/main/AndroidManifest.xml"),
            File("app/src/main/AndroidManifest.xml"),
        ).firstOrNull { it.isFile }
        assertTrue("未找到主清单", manifest != null)
        val declared = manifest!!.readText(Charsets.UTF_8)
            .contains("android:scheme=\"${FtRoutes.DEEP_LINK_SCHEME}\"")
        assertTrue("主清单未声明深链接 scheme：${FtRoutes.DEEP_LINK_SCHEME}", declared)
    }

    /**
     * 底栏 Tab 文案必须与原型 tabbar **标记内**的 `<span>` 文案逐字一致。
     *
     * 注意它与 [FtRoute.label] 不是同一来源：`label` 取自 webapp 壳的 `ROUTES[key].label`
     * （如 review = 「训练回顾」），而 tabbar 标记写的是「回顾」。混用会导致底栏文案错字。
     * 中央胶囊 Tab（`.tab-center`）在标记里没有文字 `<span>`，只有 `aria-label`，故排除。
     */
    @Test
    fun `底栏 Tab 文案与原型 tabbar 标记逐字一致`() {
        val specFile = specFile("fittracker-welcome-home.html")
        Assume.assumeTrue("冻结规格副本已移除（fittracker-welcome-home.html），跳过该断言", specFile != null)
        val html = specFile!!.readText(Charsets.UTF_8)
        val expected = Regex("""data-tab="(\w+)"[^>]*>\s*<span>([^<]+)</span>""")
            .findAll(html)
            .associate { it.groupValues[1] to it.groupValues[2].trim() }
        assertTrue("未从原型 tabbar 解析出任何 Tab 文案", expected.isNotEmpty())

        val mismatches = FtRoutes.tabs
            .filterNot { it.isTabCenter }
            .mapNotNull { route ->
                val exp = expected[route.id] ?: return@mapNotNull "${route.id}: 原型标记中无此 Tab"
                val actual = route.tabLabel ?: route.label
                if (actual == exp) null else "${route.id}: 期望'$exp' 实际'$actual'"
            }
        assertEquals(emptyList<String>(), mismatches)
    }

    /**
     * 冻结规格副本的定位——**向上搜索仓库根**，不依赖 CWD 到仓库根的固定层数。
     *
     * 单测 CWD 是模块目录（`apps/android/app`）。monorepo 归一（`8f256af` 起安卓并入
     * `apps/android/`）把工程下沉一级后，原候选 `../design` 落在 `apps/android/design`
     * （不存在）、`design` 落在 `apps/android/app/design`（不存在）——两候选全空，
     * 三例断言连同 `底栏 Tab 文案…` 一并红（后者以 FileNotFoundException 暴露）。
     * 改为逐级上溯取首个真实存在的副本：目录再调整、或从其它工作目录跑测试都不会失效。
     */
    private fun specDir(): File? {
        var dir: File? = File("").absoluteFile // CWD
        while (dir != null) {
            val candidate = File(dir, "design/06_prototype_redraw/src")
            if (candidate.isDirectory) return candidate
            dir = dir.parentFile
        }
        return null
    }

    private fun specFile(name: String): File? = specDir()?.let { File(it, name) }?.takeIf { it.isFile }
}
