package com.fittracker.app.nav

import com.fittracker.app.nav.FtNavDirection.BACK
import com.fittracker.app.nav.FtNavDirection.FORWARD
import com.fittracker.app.nav.FtNavDirection.INSTANT
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 换屏语义的不可变量测试。
 *
 * 断言逐条对应原型外壳 `fittracker-webapp.html` 的 `PARENT`（L571-575）与
 * `navDir`（L578-583）：层级关系决定 forward / back / instant 三态。
 *
 * 这些用例的价值在于**锁死二级关系**：`plan → planGroup` 这类跨级跳转在只看一级
 * 的实现里会退化为 instant（丢动画），是本次接线最容易写错的地方。
 */
class FtNavTransitionsTest {

    /** 原型 `PARENT` 表（L571-575）——逐字抄录，作为保真基准。 */
    private val prototypeParent = mapOf(
        "login" to "welcome",
        "register" to "login",
        "home" to "welcome",
        "plans" to "plan",
        "planGroup" to "plans",
        "active" to "workout",
        "complete" to "active",
        "library" to "profile",
        "body" to "profile",
        "settings" to "profile",
    )

    // ── 12 组父子关系：父 → 子 = 前进 ────────────────────────────

    @Test
    fun `层级表含原型 10 条 + 补 2 条共 12 条`() {
        assertEquals(12, FtNavTransitions.PARENT.size)
        prototypeParent.forEach { (child, parent) ->
            assertEquals("$child 的父屏", parent, FtNavTransitions.PARENT[child])
        }
        assertEquals("settings", FtNavTransitions.PARENT["accountSync"])
        assertEquals("profile", FtNavTransitions.PARENT["trainingPreferences"])
    }

    @Test
    fun `12 组父子关系——父到子判为前进`() {
        val wrong = FtNavTransitions.PARENT
            .filterNot { (child, parent) -> FtNavTransitions.navDir(parent, child) == FORWARD }
        assertEquals(emptyList<String>(), wrong.keys.toList())
    }

    @Test
    fun `12 组父子关系——子到父判为返回`() {
        val wrong = FtNavTransitions.PARENT
            .filterNot { (child, parent) -> FtNavTransitions.navDir(child, parent) == BACK }
        assertEquals(emptyList<String>(), wrong.keys.toList())
    }

    // ── 跨级（二级）关系：原型 navDir 的 `PARENT[PARENT[to]]` 分支 ──

    @Test
    fun `跨一级的进入仍是前进`() {
        assertEquals(FORWARD, FtNavTransitions.navDir("plan", "planGroup"))
        assertEquals(FORWARD, FtNavTransitions.navDir("plan", "plans"))
        assertEquals(FORWARD, FtNavTransitions.navDir("workout", "complete"))
        assertEquals(FORWARD, FtNavTransitions.navDir("profile", "accountSync"))
        assertEquals(FORWARD, FtNavTransitions.navDir("profile", "trainingPreferences"))
    }

    @Test
    fun `跨一级的退出仍是返回`() {
        assertEquals(BACK, FtNavTransitions.navDir("planGroup", "plan"))
        assertEquals(BACK, FtNavTransitions.navDir("complete", "workout"))
        assertEquals(BACK, FtNavTransitions.navDir("accountSync", "profile"))
    }

    // ── 无关跳转 = 瞬时（含 Tab 间） ─────────────────────────────

    @Test
    fun `Tab 之间的跳转判为瞬时`() {
        val tabIds = listOf("home", "plan", "workout", "review", "profile")
        val wrong = tabIds.flatMap { a -> tabIds.map { b -> a to b } }
            .filterNot { (a, b) -> a == b || FtNavTransitions.navDir(a, b) == INSTANT }
        assertEquals(emptyList<Pair<String, String>>(), wrong)
    }

    @Test
    fun `无层级关系的跳转判为瞬时`() {
        assertEquals(INSTANT, FtNavTransitions.navDir("library", "body"))
        assertEquals(INSTANT, FtNavTransitions.navDir("library", "plan"))
        assertEquals(INSTANT, FtNavTransitions.navDir("welcome", "settings"))
        assertEquals(INSTANT, FtNavTransitions.navDir("login", "home")) // 认证成功直落首页
        assertEquals(INSTANT, FtNavTransitions.navDir("splash", "home"))
        assertEquals(INSTANT, FtNavTransitions.navDir("splash", "login"))
    }

    // ── 边界：同屏 / 空态 ───────────────────────────────────────

    @Test
    fun `同屏判为瞬时`() {
        listOf("home", "body", "settings", "").forEach { id ->
            assertEquals("同屏 $id", INSTANT, FtNavTransitions.navDir(id, id))
        }
    }

    @Test
    fun `空态（路由未就绪）判为瞬时`() {
        assertEquals(INSTANT, FtNavTransitions.navDir(null, "home"))
        assertEquals(INSTANT, FtNavTransitions.navDir("home", null))
        assertEquals(INSTANT, FtNavTransitions.navDir(null, null))
    }

    @Test
    fun `未知路由不产生方向`() {
        assertEquals(INSTANT, FtNavTransitions.navDir("home", "unknown"))
        assertEquals(INSTANT, FtNavTransitions.navDir("unknown", "home"))
    }

    // ── 返回回退目标（屏内返回箭头 / 深链直达） ──────────────────

    @Test
    fun `返回回退目标为父屏`() {
        assertEquals("plans", FtNavTransitions.backTarget("planGroup"))
        assertEquals("plan", FtNavTransitions.backTarget("plans"))
        assertEquals("profile", FtNavTransitions.backTarget("body"))
        assertEquals("profile", FtNavTransitions.backTarget("library"))
        assertEquals("profile", FtNavTransitions.backTarget("trainingPreferences"))
        assertEquals("settings", FtNavTransitions.backTarget("accountSync"))
        assertEquals("workout", FtNavTransitions.backTarget("active"))
        assertEquals("active", FtNavTransitions.backTarget("complete"))
    }

    @Test
    fun `无父屏的返回回退目标为 home`() {
        listOf("review", "splash", "welcome", "exerciseDetail", "legal", null)
            .forEach { id ->
                assertEquals("$id 的回退", "home", FtNavTransitions.backTarget(id))
            }
    }

    // ── 转场三态：瞬时不得携带任何位移 / 淡入 ────────────────────

    @Test
    fun `瞬时态不带入场与退场动画`() {
        assertEquals(androidx.compose.animation.EnterTransition.None, FtNavTransitions.enter(INSTANT))
        assertEquals(androidx.compose.animation.ExitTransition.None, FtNavTransitions.exit(INSTANT))
    }
}
