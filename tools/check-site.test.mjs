// check-site.test.mjs —— check-site.mjs 纯函数回归（node:test，fixture 字符串，不依赖磁盘）
import { test } from 'node:test'
import assert from 'node:assert/strict'
import {
  localRefsOf,
  findPlaceholders,
  externalResourceRefs,
  imgsMissingAttrs,
  headMissing
} from './check-site.mjs'

// ── localRefsOf ──────────────────────────────────────────────────────────────

test('localRefsOf 提取本地 href/src，跳过锚点与协议', () => {
  const html = [
    '<a href="#top">锚点</a>',
    '<a href="https://github.com/x/y">外链</a>',
    '<a href="mailto:a@b.c">邮件</a>',
    '<img src="assets/img/01-home.jpg">',
    '<img src="data:image/png;base64,xx">',
    '<link rel="stylesheet" href="assets/site.css#v2">',
    '<img srcset="assets/img/a.jpg 1x, https://cdn.example.com/b.jpg 2x">'
  ].join('\n')
  const refs = localRefsOf(html)
  assert.ok(refs.includes('assets/img/01-home.jpg'))
  assert.ok(refs.includes('assets/site.css'))
  assert.ok(refs.includes('assets/img/a.jpg'))
  assert.ok(!refs.includes('https://github.com/x/y'))
  assert.ok(!refs.includes('https://cdn.example.com/b.jpg'))
  assert.ok(!refs.some((r) => r.startsWith('#') || r.startsWith('mailto:') || r.startsWith('data:')))
})

// ── findPlaceholders ─────────────────────────────────────────────────────────

test('findPlaceholders 检出未完成注释与假文，data-pending 元素放行', () => {
  assert.deepEqual(findPlaceholders('<!-- TODO: 修这个 -->'), ['未完成注释'])
  assert.deepEqual(findPlaceholders('<p>lorem ipsum dolor</p>'), ['假文段落'])
  assert.deepEqual(findPlaceholders('<p>数字 xxxx 测试</p>'), ['连续 x 占位'])
  const allowed = '<span data-pending="icp">TODO 备案号待取得 xxxx</span>'
  assert.deepEqual(findPlaceholders(allowed), [])
})

// ── externalResourceRefs ─────────────────────────────────────────────────────

test('externalResourceRefs 检出外链资源与 css url()', () => {
  const html = '<script src="https://cdn.example.com/x.js"></script><style>a{background:url(https://img.example.com/a.png)}</style>'
  const hits = externalResourceRefs(html)
  assert.ok(hits.includes('https://cdn.example.com/x.js'))
  assert.ok(hits.includes('https://img.example.com/a.png'))
  assert.deepEqual(externalResourceRefs('<a href="https://github.com">ok</a><img src="assets/img/a.jpg">'), [])
})

// ── imgsMissingAttrs ─────────────────────────────────────────────────────────

test('imgsMissingAttrs 检出缺 alt/width/height 的 img', () => {
  const bad = '<img src="a.jpg">'
  assert.deepEqual(imgsMissingAttrs(bad), ['缺 alt', '缺 width', '缺 height'])
  const emptyAlt = '<img src="a.jpg" alt=" " width="540" height="1186">'
  assert.deepEqual(imgsMissingAttrs(emptyAlt), ['缺 alt'])
  const good = '<img src="a.jpg" alt="训练截图" width="540" height="1186">'
  assert.deepEqual(imgsMissingAttrs(good), [])
})

// ── headMissing ──────────────────────────────────────────────────────────────

test('headMissing 检出缺 lang/title/description', () => {
  const good = '<html lang="zh-CN"><head><title>标题</title><meta name="description" content="描述"></head></html>'
  assert.deepEqual(headMissing(good), [])
  const bad = '<html lang="en"><head><title></title></head>'
  const missing = headMissing(bad)
  assert.ok(missing.includes('lang="zh-CN"'))
  assert.ok(missing.includes('非空 <title>'))
  assert.ok(missing.includes('meta description'))
})

// ── 转义边界（fixture 含 < > & 的文本不引发误报） ──────────────────────────

test('含 HTML 实体的正文不触发占位误报', () => {
  const html = '<p>使用 &lt;div&gt; 与 &amp; 符号说明</p>'
  assert.deepEqual(findPlaceholders(html), [])
  assert.deepEqual(imgsMissingAttrs(html), [])
})
