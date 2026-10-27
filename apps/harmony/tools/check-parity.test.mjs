// check-parity.mjs 判据回归测试。
//
// 背景（红用例的来源）：双端对等长期只靠人记。本测试把四类漂移逐一点成红：
// 注册页漏登记、安卓屏目录漏登记、上架身份不一致、豁免缺理由/缺复核方式。
// 另有两个已踩过的解析坑：`\|` 转义把表格行切碎、路径带中文括注取不到值。
//
// 运行：node --test tools/check-parity.test.mjs（cwd = apps/harmony）

import { test } from 'node:test'
import assert from 'node:assert/strict'

import {
  parseParityDoc,
  parseApplicationId,
  parseBundleName,
  checkParity
} from './check-parity.mjs'

/** 造一份最小对等文档：parity 4 列、豁免 5 列。 */
function makeDoc(parityRows, exemptionRows) {
  const parityHead = [
    '## 对等清单',
    '',
    '| # | 鸿蒙页 | 安卓 Screen | 对等 |',
    '|---|---|---|---|'
  ]
  const parityBody = parityRows.map((row, i) =>
    `| ${i + 1} | \`${row.harmony}\` | \`${row.android}\` | ✅ |`
  )
  const exemptHead = [
    '',
    '## 已知不对称',
    '',
    '| # | 项 | 不对称内容 | 理由 | 复核方式 |',
    '|---|---|---|---|---|'
  ]
  const exemptBody = exemptionRows.map((row, i) =>
    `| ${i + 1} | ${row.item} | ${row.content ?? '示意'} | ${row.reason} | ${row.verify} |`
  )
  return [...parityHead, ...parityBody, ...exemptHead, ...exemptBody].join('\n')
}

const BASE_PARITY = [{ harmony: 'features\\pencil\\pages\\PencilHomePage', android: 'home\\HomeScreen' }]
const BASE_EXEMPT = [{ item: '应用壳', reason: '框架差异', verify: '人工核对' }]

test('parseParityDoc：区分对等清单与豁免表，跳过待裁决表', function () {
  const text = [
    makeDoc(BASE_PARITY, BASE_EXEMPT),
    '',
    '## 待裁决项',
    '',
    '| # | 问题 | 为什么现在不能定 | 裁决方式 |',
    '|---|---|---|---|',
    '| 1 | 某问题 | 待测 | 读代码 |'
  ].join('\n')

  const { parity, exemptions } = parseParityDoc(text)

  assert.equal(parity.length, 1)
  assert.equal(parity[0].harmony, 'features/pencil/pages/PencilHomePage', '反斜杠应归一为正斜杠')
  assert.equal(parity[0].android, 'home\\HomeScreen')
  assert.equal(exemptions.length, 1, '待裁决表不应混入豁免')
})

test('parseParityDoc：表内 `\\|` 转义不切碎整行（实测漏过一条豁免）', function () {
  const text = makeDoc(BASE_PARITY, [
    ...BASE_EXEMPT,
    {
      item: '训练偏好',
      content: "grep '训练偏好\\|TrainingPreference' 零命中",
      reason: '鸿蒙侧未实现',
      verify: '补齐后移除'
    }
  ])

  const { exemptions } = parseParityDoc(text)

  assert.equal(exemptions.length, 2, '带 \\| 的行必须仍被解析，不能静默丢弃')
  assert.match(exemptions[1].content ?? '', /训练偏好\|TrainingPreference/)
})

test('parseParityDoc：路径带中文括注时取行内代码片段', function () {
  const text = [
    '| # | 鸿蒙页 | 安卓 Screen | 对等 |',
    '|---|---|---|---|',
    '| 19 | `app\\PencilAppShell`（应用壳，非内容页） | `FtApp.kt`（根） | ⚠️ |',
    '',
    '| # | 项 | 不对称内容 | 理由 | 复核方式 |',
    '|---|---|---|---|---|',
    '| 1 | 壳 | 示意 | 框架差异 | 人工核对 |'
  ].join('\n')

  const { parity } = parseParityDoc(text)

  assert.equal(parity[0].harmony, 'app/PencilAppShell', '必须剥掉括注只取反引号内容')
})

test('parseApplicationId / parseBundleName：从真实格式里取值', function () {
  const gradle = 'defaultConfig {\n    applicationId = "com.earthrhythm.fittracker"\n    minSdk = 24\n}'
  const app = '{\n  "app": {\n    "bundleName": "com.earthrhythm.fittracker"\n  }\n}'

  assert.equal(parseApplicationId(gradle), 'com.earthrhythm.fittracker')
  assert.equal(parseBundleName(app), 'com.earthrhythm.fittracker')
  assert.equal(parseApplicationId('没有这行'), null)
})

function facts(overrides = {}) {
  return {
    pages: ['features/pencil/pages/PencilHomePage'],
    screenDirs: ['home'],
    applicationId: 'com.earthrhythm.fittracker',
    bundleName: 'com.earthrhythm.fittracker',
    ...overrides
  }
}

test('checkParity：完整 fixture 全绿', function () {
  const parsed = parseParityDoc(makeDoc(BASE_PARITY, BASE_EXEMPT))
  const findings = checkParity(parsed, facts())
  assert.deepEqual(findings, [], `应无 finding，实际：${findings.join(' / ')}`)
})

test('checkParity：鸿蒙注册页漏登记对等关系 → 红', function () {
  const parsed = parseParityDoc(makeDoc(BASE_PARITY, BASE_EXEMPT))
  const findings = checkParity(parsed, facts({ pages: [...facts().pages, 'features/body/pages/BodyDataPage'] }))

  assert.equal(findings.length, 1)
  assert.match(findings[0], /未登记对等关系/)
  assert.match(findings[0], /BodyDataPage/)
})

test('checkParity：安卓屏目录漏登记 → 红', function () {
  const parsed = parseParityDoc(makeDoc(BASE_PARITY, BASE_EXEMPT))
  const findings = checkParity(parsed, facts({ screenDirs: ['home', 'settings'] }))

  assert.equal(findings.length, 1)
  assert.match(findings[0], /安卓屏目录未登记：settings/)
})

test('checkParity：豁免表提到该目录时视为已登记（绿）', function () {
  const parsed = parseParityDoc(
    makeDoc(BASE_PARITY, [{ item: 'preferences', reason: '鸿蒙侧未实现', verify: '补齐后移除' }])
  )
  const findings = checkParity(parsed, facts({ screenDirs: ['home', 'preferences'] }))

  assert.deepEqual(findings, [])
})

test('checkParity：上架身份不一致 → 红', function () {
  const parsed = parseParityDoc(makeDoc(BASE_PARITY, BASE_EXEMPT))
  const findings = checkParity(parsed, facts({ bundleName: 'com.example.other' }))

  assert.equal(findings.length, 1)
  assert.match(findings[0], /上架身份不一致/)
  assert.match(findings[0], /com\.example\.other/)
})

test('checkParity：豁免缺理由或复核方式 → 红', function () {
  const parsed = parseParityDoc(
    makeDoc(BASE_PARITY, [
      { item: '应用壳', reason: '—', verify: '人工核对' },
      { item: '训练预览', reason: '框架差异', verify: '—' }
    ])
  )
  const findings = checkParity(parsed, facts())

  assert.equal(findings.length, 2)
  assert.match(findings[0], /缺理由/)
  assert.match(findings[1], /缺复核方式/)
})
