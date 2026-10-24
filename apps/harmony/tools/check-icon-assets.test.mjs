// check-icon-assets.mjs 判据回归测试。
//
// 每条判据两侧都要锁：既能抓住真违规，也不误伤合理资产。后者同样重要 ——
// 「视框规则」最初写成「必须 24 视框」，实测会误报 6 个勾选/箭头/奖牌类小图形
// （13×9、15×15、80×80 等天然非方形），故改为只禁 1024 视框（iconfont 族指纹）。
// 这组用例把「不误伤」这一侧也钉住了。
//
// 运行：node --test apps/harmony/tools/check-icon-assets.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'

import {
  checkName,
  checkViewBox,
  extractRawfileSvgRefs,
  collectIconIssues
} from './check-icon-assets.mjs'

/** 造一份 24 视框的合规图标源码。 */
function svg24() {
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"></svg>'
}

test('checkName：ASCII kebab 通过', function () {
  assert.equal(checkName('pencil-lucide-dumbbell.svg'), null)
  assert.equal(checkName('pencil-tab-workout.svg'), null)
  assert.equal(checkName('a.svg'), null)
})

test('checkName：中文名被拒（原 首页.svg 这类）', function () {
  assert.notEqual(checkName('首页.svg'), null)
  assert.notEqual(checkName('首页_选中 .svg'), null)
})

test('checkName：空格与大写被拒（原 Arrow Right.svg 这类）', function () {
  assert.notEqual(checkName('Arrow Right.svg'), null)
  assert.notEqual(checkName('pencil-tab.svg '), null, '末尾空格也算违规')
  assert.notEqual(checkName('Pencil-Tab.svg'), null, '大写违规')
  assert.notEqual(checkName('pencil_tab.svg'), null, '下划线不在 kebab 字符集内')
})

test('checkViewBox：24 视框通过', function () {
  assert.equal(checkViewBox(svg24()), null)
})

test('checkViewBox：1024 视框被拒（iconfont 族指纹）', function () {
  const iconfont = '<svg viewBox="0 0 1024 1024"><path fill="#8e8e93"/></svg>'
  assert.notEqual(checkViewBox(iconfont), null)
})

test('checkViewBox：非 24 的小图形不被误伤（勾选/箭头/奖牌是合理例外）', function () {
  assert.equal(checkViewBox('<svg viewBox="0 0 13 9"></svg>'), null, '勾选标记')
  assert.equal(checkViewBox('<svg viewBox="-1 -1 15 15"></svg>'), null, '箭头（负原点）')
  assert.equal(checkViewBox('<svg viewBox="0 0 80 80"></svg>'), null, '奖牌')
  assert.equal(checkViewBox('<svg viewBox="0 0 42 42"></svg>'), null, '圆形勾选')
})

test('extractRawfileSvgRefs：提取字面量引用（单双引号都认）', function () {
  const source = [
    "Image($rawfile('a.svg'))",
    'Image($rawfile("b.svg"))',
    "Image($rawfile( 'c.svg' ))"
  ].join('\n')
  assert.deepEqual(extractRawfileSvgRefs(source), ['a.svg', 'b.svg', 'c.svg'])
})

test('extractRawfileSvgRefs：动态引用不被当成字面量（避免假命中）', function () {
  assert.deepEqual(extractRawfileSvgRefs('Image($rawfile(this.source))'), [])
  assert.deepEqual(extractRawfileSvgRefs('Image($rawfile(path + ".gif"))'), [])
})

test('collectIconIssues：全合规资产返回 0 违规', function () {
  const icons = [
    { name: 'pencil-lucide-dumbbell.svg', source: svg24() },
    { name: 'pencil-tab-workout.svg', source: svg24() }
  ]
  const ets = [
    "Image($rawfile('pencil-lucide-dumbbell.svg'))",
    "Image($rawfile('pencil-tab-workout.svg'))"
  ]
  const result = collectIconIssues(icons, ets)
  assert.equal(result.issues.length, 0)
  assert.equal(result.iconCount, 2)
  assert.equal(result.refCount, 2)
})

test('collectIconIssues：命名违规被报出', function () {
  const icons = [{ name: '首页.svg', source: svg24() }]
  const result = collectIconIssues(icons, ["Image($rawfile('首页.svg'))"])
  assert.equal(result.issues.length, 1)
  assert.equal(result.issues[0].rule, 'name')
})

test('collectIconIssues：1024 视框被报出（改名换皮也能抓）', function () {
  const icons = [
    { name: 'pencil-calendar.svg', source: '<svg viewBox="0 0 1024 1024"></svg>' }
  ]
  const result = collectIconIssues(icons, ["Image($rawfile('pencil-calendar.svg'))"])
  assert.equal(result.issues.length, 1)
  assert.equal(result.issues[0].rule, 'viewBox')
  assert.equal(result.issues[0].file, 'pencil-calendar.svg')
})

test('collectIconIssues：引用不存在的文件被报出，且同一缺失只报一次', function () {
  const result = collectIconIssues(
    [],
    ["Image($rawfile('ghost.svg'))", "Image($rawfile('ghost.svg'))"]
  )
  assert.equal(result.issues.length, 1, '重复引用同一个缺失文件只报一条')
  assert.equal(result.issues[0].rule, 'missing')
  assert.equal(result.issues[0].file, 'ghost.svg')
})

test('collectIconIssues：孤儿资产被报出', function () {
  const icons = [
    { name: 'pencil-lucide-dumbbell.svg', source: svg24() },
    { name: 'pencil-lucide-wifi.svg', source: svg24() }
  ]
  const result = collectIconIssues(icons, ["Image($rawfile('pencil-lucide-dumbbell.svg'))"])
  assert.equal(result.issues.length, 1)
  assert.equal(result.issues[0].rule, 'orphan')
  assert.equal(result.issues[0].file, 'pencil-lucide-wifi.svg')
})

test('collectIconIssues：白名单豁免孤儿（动态引用场景）', function () {
  const icons = [{ name: 'pencil-dynamic.svg', source: svg24() }]
  const result = collectIconIssues(icons, ['Image($rawfile(this.source))'], ['pencil-dynamic.svg'])
  assert.equal(result.issues.length, 0, '登记白名单后不应报孤儿')
})

test('collectIconIssues：一个文件可同时命中命名与视框两条', function () {
  const icons = [{ name: '首页.svg', source: '<svg viewBox="0 0 1024 1024"></svg>' }]
  const result = collectIconIssues(icons, ["Image($rawfile('首页.svg'))"])
  const rules = result.issues.map((item) => item.rule).sort()
  assert.deepEqual(rules, ['name', 'viewBox'])
})
