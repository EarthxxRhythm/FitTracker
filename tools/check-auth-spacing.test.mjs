// check-auth-spacing.mjs 的回归测试。
//
// RED 用例的来源：register 屏视觉偏差 11.61%（目标 ≤8%），与 login 同源。
// login 已通过补齐原型 `.auth-cta{margin-top:20px}` 达标；register 是否也有同类缺失，
// 必须用原型 CSS 对照确认，而不能因为「同源」就预设。
//
// 运行：node --test tools/check-auth-spacing.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

import {
  AUTH_PROTOTYPE_HTML,
  REGISTER_PAGE_ETS,
  LOGIN_PAGE_ETS,
  parsePrototypeAuthSpacing,
  collectAuthScreenFacts,
  evaluateRegisterSpacing
} from './check-auth-spacing.mjs'

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')

function readRepoFile(relativePath) {
  return readFileSync(resolve(repoRoot, relativePath), 'utf8')
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
