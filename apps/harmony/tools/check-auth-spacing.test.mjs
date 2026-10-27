// check-auth-spacing.mjs 的回归测试。
//
// RED 用例的来源：register 屏视觉偏差 11.61%（目标 ≤8%），与 login 同源。
// login 已通过补齐原型 `.auth-cta{margin-top:20px}` 达标；register 是否也有同类缺失，
// 必须用原型 CSS 对照确认，而不能因为「同源」就预设。
//
// 运行：node --test tools/check-auth-spacing.test.mjs

import { test as nodeTest } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  AUTH_PROTOTYPE_HTML,
  REGISTER_PAGE_ETS,
  LOGIN_PAGE_ETS,
  parsePrototypeAuthSpacing,
  collectAuthScreenFacts,
  evaluateRegisterSpacing
} from './check-auth-spacing.mjs'

const scriptDir = dirname(fileURLToPath(import.meta.url))

/** 向上定位仓库根（同时含 AGENTS.md 与 docs/）；monorepo 下与 cwd 无关。 */
function findRepoRoot(startDir) {
  let dir = resolve(startDir)
  for (let depth = 0; depth < 8; depth += 1) {
    if (existsSync(join(dir, 'AGENTS.md')) && existsSync(join(dir, 'docs'))) {
      return dir
    }
    const parent = dirname(dir)
    if (parent === dir) {
      break
    }
    dir = parent
  }
  return null
}

// 本仓库是 monorepo：`design/…` 位于仓库根，而 `entry/…` 位于 apps/harmony/ 下。
// 旧实现以 `resolve(scriptDir, '..')`（= apps/harmony）为仓库根，仓库根的 design/… 永远
// 解析不到 —— 依赖它的用例全部 ENOENT（实测 pass 1 / fail 7）。此处改为双基准解析。
const repoRoot = findRepoRoot(scriptDir) ?? resolve(scriptDir, '..')
const baseDirs = [repoRoot, resolve(repoRoot, 'apps', 'harmony')]

/**
 * 设计资产 design/ 已于 2026-10-28 移出主仓（见仓库根 ASSETS.md）。
 *
 * 本文件所有断言都在核对 ArkUI 实现与原型 HTML 的间距一致性——没有原型就没有判据。
 * 故 design 缺失时整体 skip，而不是让外部贡献者看到一片红。本地若需跑这些断言，
 * 把 FitTracker-design 放回 design/ 即可自动恢复。
 */
const DESIGN_AVAILABLE = existsSync(
  resolve(repoRoot, 'design/06_prototype_redraw/src/fittracker-auth.html')
)

/** 统一注入 skip：缺失设计资产时说明原因，避免被误读成「测试坏了」。 */
const test = (name, fn) =>
  nodeTest(name, { skip: DESIGN_AVAILABLE ? false : '设计原型已移出主仓（FitTracker-design），无判据可比' }, fn)

function readRepoFile(relativePath) {
  for (const base of baseDirs) {
    const full = resolve(base, relativePath)
    if (existsSync(full)) {
      return readFileSync(full, 'utf8')
    }
  }
  // fail closed：两个基准都找不到时明确报错，而不是静默返回空内容
  throw new Error(`找不到仓库文件 ${relativePath}（已尝试基准：${baseDirs.join(' | ')}）`)
}

function registerReport() {
  return evaluateRegisterSpacing(
    readRepoFile(REGISTER_PAGE_ETS),
    readRepoFile(LOGIN_PAGE_ETS),
    parsePrototypeAuthSpacing(readRepoFile(AUTH_PROTOTYPE_HTML))
  )
}

test('原型 <style> 解析出 auth 屏共用间距（与 probe-css-metrics.py 实测一致）', function () {
  const spacing = parsePrototypeAuthSpacing(readRepoFile(AUTH_PROTOTYPE_HTML))
  assert.equal(spacing.headMarginBottom, 26, '.auth-head{margin-bottom:26px}')
  assert.equal(spacing.formGap, 14, '.auth-form{gap:14px}')
  assert.equal(spacing.fieldLabelMarginBottom, 8, '.field-label{margin-bottom:8px}')
  assert.equal(spacing.agreeMarginTop, 4, '.agree{margin-top:4px}')
  assert.equal(spacing.ctaMarginTop, 20, '.auth-cta{margin-top:20px}')
  assert.equal(spacing.brandMarginBottom, 22, '.auth-brand{margin:8px 0 22px}')
})

test('register 的 auth-head 补齐原型 .auth-head{margin-bottom:26px}', function () {
  const report = registerReport()
  assert.equal(report.headMarginBottom.expected, 26)
  assert.equal(report.headMarginBottom.actual, 26)
})

test('register 的 CTA 补齐原型 .auth-cta{margin-top:20px}', function () {
  const report = registerReport()
  assert.equal(report.ctaMarginTop.expected, 20)
  assert.equal(report.ctaMarginTop.actual, 20)
})

test('register 的同意条款保留原型 .agree{margin-top:4px}', function () {
  const report = registerReport()
  assert.equal(report.agreeMarginTop.expected, 4)
  assert.equal(report.agreeMarginTop.actual, 4)
})

test('register 的同意条款与 CTA 必须落在 gap:14 的表单容器内（原型 .auth-form 结构）', function () {
  const report = registerReport()
  assert.equal(report.fieldCountInForm, 4, 'register 独有 4 个输入字段（含确认密码）')
  assert.equal(report.agreeInsideForm, true, '同意条款须在 Column({ space: 14 }) 内，gap 才会生效')
  assert.equal(report.ctaInsideForm, true, 'CTA 须在 Column({ space: 14 }) 内，gap 才会生效')
})

test('register 表单容器 margin 与已达标 login 保持一致', function () {
  const report = registerReport()
  assert.equal(report.formGapConsistency.registerTop, report.formGapConsistency.loginTop)
  assert.equal(report.formGapConsistency.registerBottom, report.formGapConsistency.loginBottom)
})

test('login 的 2ea9813 修复仍在（对照组，证明判据可区分已修屏）', function () {
  const report = registerReport()
  assert.equal(report.loginCtaMarginTop, 20)
})

test('缺失声明时必须判 FAIL——合成样本证明判据有鉴别力', function () {
  const stillBroken = [
    'Column({ space: 14 }) {',
    "  this.buildField('昵称', '给自己起个名字', false, this.nickname, this.nicknameError, (value: string) => {})",
    '}',
    ".margin({ top: 8, bottom: 8 })",
    "Button(this.loading ? '注册中…' : '注册')",
    '  .margin({ bottom: 10 })',
    ''
  ].join('\n')

  const facts = collectAuthScreenFacts(stillBroken)
  assert.notEqual(facts.cta.margin.top, 20, '未补 margin-top 时不得通过')
  assert.equal(facts.ctaInsideForm, false, 'CTA 在容器外时不得通过')
  assert.equal(facts.agreeInsideForm, false, '同意条款在容器外时不得通过')
  assert.equal(facts.fieldCountInForm, 1)

  const fixed = [
    'Column({ space: 14 }) {',
    "  this.buildField('昵称', '给自己起个名字', false, this.nickname, this.nicknameError, (value: string) => {})",
    "  Row({ space: 10 }) { Span('我已阅读并同意') }",
    "  Button(this.loading ? '注册中…' : '注册')",
    '    .margin({ top: 20 })',
    '}',
    ".margin({ top: 10, bottom: 10 })",
    ''
  ].join('\n')

  const fixedFacts = collectAuthScreenFacts(fixed)
  assert.equal(fixedFacts.ctaInsideForm, true)
  assert.equal(fixedFacts.agreeInsideForm, true)
  assert.equal(fixedFacts.cta.margin.top, 20)
})
