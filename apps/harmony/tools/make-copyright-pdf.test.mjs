import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtempSync, writeFileSync, readFileSync, existsSync, statSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parseMaterialPages, countPdfPages, escapeHtml } from './make-copyright-pdf.mjs'

// PDF 材料是直接交给版权中心的成品，两个失效模式一旦发生就是白等一两个月：
//   ① 解析时丢行 → 该页不足 50 行（源程序）/ 30 行（文档），被要求补正；
//   ② 渲染时折行溢出 → PDF 物理页数 ≠ txt 逻辑页数，「第 N 页」与实际错位。
// 这里用固定语料把 ① 钉死在解析层；② 需要真实浏览器，只在可用时跑集成断言。

const HERE = path.dirname(fileURLToPath(import.meta.url))
const PDF_SCRIPT = path.join(HERE, 'make-copyright-pdf.mjs')

const HEADER = (n, total) => `菲特健身训练软件 V1.0${' '.repeat(20)}第 ${n} 页 / 共 ${total} 页`
const RULE = '-'.repeat(72)

/** 构造一份材料：每页 bodyLines 行正文，页与页之间用 '\n\n' 连接（与 renderDocument 一致）。 */
function buildMaterial(pageCount, bodyLines) {
  const pages = []
  for (let p = 1; p <= pageCount; p += 1) {
    const body = []
    for (let i = 0; i < bodyLines; i += 1) {
      // 第 3 行刻意留空，模拟源码空行
      body.push(i === 2 ? '' : `line ${p}-${i}`)
    }
    pages.push([HEADER(p, pageCount), RULE, ...body].join('\n'))
  }
  return `${pages.join('\n\n')}\n`
}

test('parseMaterialPages：页数、页码、页眉文字与每页行数守恒', () => {
  const text = buildMaterial(4, 50)
  const pages = parseMaterialPages(text)

  assert.equal(pages.length, 4, '应解析出 4 页')
  pages.forEach((page, index) => {
    assert.equal(page.header.page, index + 1, `第 ${index + 1} 页的页码应正确`)
    assert.equal(page.header.total, 4, '总页数应为 4')
    assert.equal(page.header.left, '菲特健身训练软件 V1.0', '页眉左半应是软件全称与版本号')
    // 关键不变量：50 行正文一行都不能丢（含正文内的空行）
    assert.equal(page.body.length, 50, `第 ${index + 1} 页应保留 50 行正文，实际 ${page.body.length}`)
    assert.equal(page.body[2], '', '正文内的空行必须保留')
  })
})

test('parseMaterialPages：末页不满时按实际行数保留，不补齐也不丢行', () => {
  const text = buildMaterial(2, 37)
  const pages = parseMaterialPages(text)
  assert.equal(pages.length, 2)
  assert.equal(pages[1].body.length, 37)
})

test('parseMaterialPages：纯空行紧邻页尾时只剥连接空行，不误删正文', () => {
  // 最后一页正文末尾本身是空行：只应剥掉 '\n\n' 带来的一个连接空行
  const body = ['a', 'b', 'c', '']
  const text = [HEADER(1, 1), RULE, ...body].join('\n') + '\n'
  const pages = parseMaterialPages(text)
  assert.equal(pages.length, 1)
  assert.equal(pages[0].body.length, 4, '正文末的空行是真实行，不能剥掉')
  assert.equal(pages[0].body[3], '')
})

test('escapeHtml：源码里的 < > & 必须转义，否则 HTML 结构被破坏', () => {
  assert.equal(escapeHtml('a < b && c > d'), 'a &lt; b &amp;&amp; c &gt; d')
  assert.equal(escapeHtml('"quoted"'), '&quot;quoted&quot;')
})

test('集成：PDF 物理页数与 txt 逻辑页数一致，且字体已嵌入', () => {
  const out = mkdtempSync(path.join(tmpdir(), 'cr-pdf-'))
  const name = '测试软件'
  const version = 'V1.0'

  // 用 3 页小语料，避免整份 60 页材料的耗时
  const txt = buildMaterial(3, 50)
  writeFileSync(path.join(out, `源程序（${name}${version}）_合计60页.txt`), txt, 'utf8')

  const result = spawnSync(process.execPath, [PDF_SCRIPT, '--dir', out, '--name', name, '--version', version], {
    encoding: 'utf8',
    cwd: HERE,
    timeout: 180000
  })

  const stdout = `${result.stdout}${result.stderr}`
  if (/未找到 Chrome \/ Edge/.test(stdout)) {
    console.log('（跳过：本机无 Chrome/Edge，PDF 渲染未验证）')
    return
  }

  const pdfPath = path.join(out, `源程序（${name}${version}）.pdf`)
  assert.ok(existsSync(pdfPath), `应产出 PDF；stdout=${stdout}`)
  assert.ok(statSync(pdfPath).size > 1024, 'PDF 不应为空文件')
  assert.equal(countPdfPages(pdfPath), 3, 'PDF 物理页数应与 txt 逻辑页数一致')
  assert.match(stdout, /已嵌入/, `字体应嵌入；stdout=${stdout}`)
})
