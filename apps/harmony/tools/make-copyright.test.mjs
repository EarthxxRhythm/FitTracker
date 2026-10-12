import { test } from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { mkdtempSync, writeFileSync, readFileSync, readdirSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

// 这两个脚本产出的是交给版权中心的登记材料，一旦页数/行数/页眉不合规就要退回重来；
// 而敏感内容哨兵如果失效，会把密钥随材料一起交出去。所以这里固定住三类行为：
//   ① 源程序材料的页数与每页行数；② 说明书材料每页不少于 30 行；③ 哨兵能拦住且在干净语料上不误报。
// ③ 尤其重要：只跑真实源码的「未命中」不能证明哨兵有效——那条路只有在正则写错时也一样绿。

const HERE = path.dirname(fileURLToPath(import.meta.url))
const SOURCE_SCRIPT = path.join(HERE, 'make-copyright-source.mjs')
const DOC_SCRIPT = path.join(HERE, 'make-copyright-doc.mjs')

const HEADER_RE = /第 (\d+) 页 \/ 共 (\d+) 页/

function runScript(script, args) {
  return spawnSync(process.execPath, [script, ...args], {
    encoding: 'utf8',
    cwd: HERE
  })
}

function tmpDir(prefix) {
  return mkdtempSync(path.join(tmpdir(), prefix))
}

function readHeaders(text) {
  const lines = text.split('\n')
  const indexes = []
  lines.forEach((line, index) => {
    if (HEADER_RE.test(line)) {
      indexes.push(index)
    }
  })
  return { lines, indexes }
}

test('源程序材料：60 页、每页 50 行、页眉含软件全称与版本号', () => {
  const out = tmpDir('cr-src-')
  const result = runScript(SOURCE_SCRIPT, ['--out', out])
  assert.equal(result.status, 0, `脚本应成功结束：${result.stderr}`)

  const combined = readdirSync(out).find((name) => name.includes('合计60页'))
  assert.ok(combined, '应产出「合计60页」文件')

  const { lines, indexes } = readHeaders(readFileSync(path.join(out, combined), 'utf8'))
  assert.equal(indexes.length, 60, '合计文件应有 60 个页眉')
  assert.match(lines[indexes[0]], /菲特健身训练软件 V1\.0/)
  assert.match(lines[indexes[0]], /第 1 页 \/ 共 60 页/)
  assert.match(lines[indexes[59]], /第 60 页 \/ 共 60 页/)

  for (const index of indexes) {
    assert.match(lines[index + 1], /^-+$/, '页眉下一行应为分隔线')
    const body = lines.slice(index + 2, index + 2 + 50)
    assert.equal(body.length, 50, '每页应有 50 行正文')
    assert.ok(
      body.every((line) => line !== undefined),
      '正文不应在满 50 行前结束'
    )
  }
})

test('源程序材料：不足 60 页时整体提交，不做前后截取', () => {
  const ets = tmpDir('cr-small-ets-')
  const out = tmpDir('cr-small-out-')
  writeFileSync(path.join(ets, 'tiny.ets'), 'export const a: number = 1\n', 'utf8')

  const result = runScript(SOURCE_SCRIPT, ['--ets-root', ets, '--out', out])
  assert.equal(result.status, 0, result.stderr)

  const files = readdirSync(out)
  assert.ok(
    files.some((name) => name.includes('合计60页')),
    '小语料也应产出合并文件'
  )
  assert.ok(
    !files.some((name) => name.includes('后30页')),
    '不足 60 页时不应产出「后30页」文件'
  )

  const combined = files.find((name) => name.includes('合计60页'))
  const { indexes } = readHeaders(readFileSync(path.join(out, combined), 'utf8'))
  assert.equal(indexes.length, 1, '单行源码应只占 1 页')
})

test('敏感哨兵：命中疑似密钥时报警并以 exit 2 结束', () => {
  const ets = tmpDir('cr-leak-ets-')
  const out = tmpDir('cr-leak-out-')
  writeFileSync(
    path.join(ets, 'leak.ets'),
    ['export class C {', '  static readonly KEY: string = "sk-abcdefghijklmnop1234"', '}', ''].join('\n'),
    'utf8'
  )

  const result = runScript(SOURCE_SCRIPT, ['--ets-root', ets, '--out', out])
  assert.equal(result.status, 2, `命中敏感内容应以 exit 2 结束，实际 ${result.status}`)
  assert.match(result.stderr, /疑似敏感内容/, '应打印告警标题')
  assert.match(result.stderr, /API key|口令\/令牌/, '应指出命中的哨兵类型')
})

test('敏感哨兵：干净源码不误报', () => {
  const ets = tmpDir('cr-clean-ets-')
  const out = tmpDir('cr-clean-out-')
  writeFileSync(path.join(ets, 'ok.ets'), 'export const answer: number = 42\n', 'utf8')

  const result = runScript(SOURCE_SCRIPT, ['--ets-root', ets, '--out', out])
  assert.equal(result.status, 0, result.stderr)
  assert.match(result.stdout, /未发现疑似密钥/)
})

test('说明书材料：每页正文不少于 30 行且不超过 40 行，页眉含软件全称与版本号', () => {
  const out = tmpDir('cr-doc-')
  const result = runScript(DOC_SCRIPT, ['--out', out])
  assert.equal(result.status, 0, result.stderr)

  const file = readdirSync(out).find((name) => name.startsWith('说明书'))
  assert.ok(file, '应产出说明书文件')

  const { lines, indexes } = readHeaders(readFileSync(path.join(out, file), 'utf8'))
  assert.ok(indexes.length >= 1, '至少应有一页')

  for (let i = 0; i < indexes.length; i += 1) {
    assert.match(lines[indexes[i]], /菲特健身训练软件 V1\.0/, '页眉应含软件全称与版本号')

    const start = indexes[i] + 2
    const end = i + 1 < indexes.length ? indexes[i + 1] : lines.length
    const body = lines.slice(start, end)
    while (body.length > 0 && body[body.length - 1].trim() === '') {
      body.pop()
    }

    assert.ok(
      body.length >= 30 && body.length <= 40,
      `第 ${i + 1} 页正文应在 30-40 行之间，实际 ${body.length}`
    )
  }
})

test('说明书材料：Markdown 标记不会漏进材料', () => {
  const out = tmpDir('cr-doc-plain-')
  const result = runScript(DOC_SCRIPT, ['--out', out])
  assert.equal(result.status, 0, result.stderr)

  const file = readdirSync(out).find((name) => name.startsWith('说明书'))
  const text = readFileSync(path.join(out, file), 'utf8')

  assert.ok(!/^\s*#{1,6}\s/m.test(text), '不应残留 Markdown 标题符号')
  assert.ok(!/\*\*/m.test(text), '不应残留加粗标记')
  assert.ok(!/^\s*\|[\s\-:|]+\|\s*$/m.test(text), '不应残留表格分隔行')
})
