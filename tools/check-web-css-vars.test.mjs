import { test } from 'node:test'
import assert from 'node:assert/strict'
import { scanCss, findUndefined } from './check-web-css-vars.mjs'

/** 造一个内存 fixture：files 是路径数组，内容由 map 提供。 */
function fixture(map) {
  const files = Object.keys(map)
  return scanCss(files, '/repo', (f) => map[f])
}

test('裸引用未定义 → 报出来（复现 357b9d5 的令牌丢失）', () => {
  const { defined, bareRefs } = fixture({
    '/repo/a.css': 'body { color: var(--text); border-radius: var(--radius-pill); }'
  })
  const missing = findUndefined(bareRefs, defined)
  assert.deepEqual(
    missing.map((m) => m.name).sort(),
    ['--radius-pill', '--text']
  )
})

test('定义了就不报', () => {
  const { defined, bareRefs } = fixture({
    '/repo/a.css': ':root { --text: #EDF6F2; }\nbody { color: var(--text); }'
  })
  assert.deepEqual(findUndefined(bareRefs, defined), [])
})

test('带 fallback 的引用豁免', () => {
  const { defined, bareRefs } = fixture({
    '/repo/a.css': 'a { transform: scaleX(var(--sp, 0)); border: 1px solid var(--line, red); }'
  })
  // 这两个都是 var(--x, ...) 形式，正则不应把它们当裸引用
  assert.deepEqual(findUndefined(bareRefs, defined), [])
})

test('Tailwind 内部变量豁免', () => {
  const { defined, bareRefs } = fixture({
    '/repo/a.css': 'a { color: var(--tw-ring-color); font: var(--default-font-family); }'
  })
  assert.deepEqual(findUndefined(bareRefs, defined), [])
})

test('运行时 JS 写入的变量豁免', () => {
  const { defined, bareRefs } = fixture({
    '/repo/a.css': '.ch { --i: 0; }\n.ch { animation-delay: calc(var(--i) * 40ms); }'
  })
  // --i 在 fixture 里有定义，换一个没有定义的运行时变量再验一次
  const second = fixture({
    '/repo/b.css': '.card { transform: rotateX(var(--rx)) rotateY(var(--ry)); }'
  })
  assert.deepEqual(findUndefined(bareRefs, defined), [])
  assert.deepEqual(findUndefined(second.bareRefs, second.defined), [])
})

test('跨文件的定义也算数（index.css 定义、legacy.css 使用）', () => {
  const { defined, bareRefs } = fixture({
    '/repo/index.css': ':root { --bg: var(--color-ink); --color-ink: #0E100D; }',
    '/repo/legacy.css': 'body { background: var(--bg); }'
  })
  assert.deepEqual(findUndefined(bareRefs, defined), [])
})

test('记录行列位置，便于定位', () => {
  const { defined, bareRefs } = fixture({
    '/repo/x.css': 'a { color: red; }\nb { color: var(--nope); }'
  })
  const missing = findUndefined(bareRefs, defined)
  assert.equal(missing.length, 1)
  assert.equal(missing[0].file, 'x.css')
  assert.equal(missing[0].line, 2)
})
