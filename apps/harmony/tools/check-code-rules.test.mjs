// check-code-rules.mjs 判据回归测试。
//
// 每条规则至少一红一绿。重点覆盖两个易误判的边界：
//   - SV-01 必须放过工厂模式（new 本文件的实现类），只拦「import 单例后又 new」
//   - DS-01 必须放过命名常量，只拦属性方法实参位置的裸字面量
//
// 运行：node --test tools/check-code-rules.test.mjs（cwd = apps/harmony）

import { test } from 'node:test'
import assert from 'node:assert/strict'

import {
  parseMainPages,
  parseRouteConstants,
  checkRoutes,
  checkRouteLiterals,
  checkServiceSingles,
  checkLayering,
  collectInlineColors,
  diffAgainstBaseline,
  toBaselineEntries,
  setEtsRoot,
  getEtsRoot
} from './check-code-rules.mjs'

// ── RT-01 ───────────────────────────────────────────────────────────────

const MAIN_PAGES = JSON.stringify({
  src: ['features/pencil/pages/PencilHomePage', 'features/pencil/pages/PencilPreviewPage']
})
const ROUTES = [
  'export class AppRoutes {',
  "  static readonly HOME: string = 'features/pencil/pages/PencilHomePage'",
  "  static readonly WORKOUT_PREVIEW: string = 'features/pencil/pages/PencilPreviewPage'",
  '}'
].join('\n')

test('RT-01 绿：注册页与常量双向一致', function () {
  const pages = parseMainPages(MAIN_PAGES)
  const constants = parseRouteConstants(ROUTES)

  assert.deepEqual(checkRoutes(pages, constants), [])
})

test('RT-01 红：注册页没有常量指向', function () {
  const pages = [...parseMainPages(MAIN_PAGES), 'features/body/pages/BodyDataPage']
  const findings = checkRoutes(pages, parseRouteConstants(ROUTES))

  assert.equal(findings.length, 1)
  assert.match(findings[0].message, /没有任何 AppRoutes 常量指向它/)
  assert.match(findings[0].message, /BodyDataPage/)
})

test('RT-01 红：常量指向未注册的页面', function () {
  const routes = `${ROUTES}\n  static readonly GHOST: string = 'features/ghost/pages/GhostPage'`
  const findings = checkRoutes(parseMainPages(MAIN_PAGES), parseRouteConstants(routes))

  assert.equal(findings.length, 1)
  assert.match(findings[0].message, /未注册到 main_pages.json/)
})

test('RT-01 豁免：PencilPreviewPage 不报（bindContentCover 全模态，非路由页）', function () {
  const pages = parseMainPages('{"src":["features/pencil/pages/PencilHomePage"]}')
  const constants = parseRouteConstants(ROUTES)

  assert.deepEqual(checkRoutes(pages, constants), [], '豁免项不应产生 finding')
})

// ── RT-02 ───────────────────────────────────────────────────────────────

test('RT-02 红：pushUrl 直传字符串', function () {
  const findings = checkRouteLiterals([
    { path: 'features/x/Page.ets', text: "router.pushUrl('features/pencil/pages/PencilHomePage')" }
  ])

  assert.equal(findings.length, 1)
  assert.equal(findings[0].rule, 'RT-02')
})

test('RT-02 红：pushUrl 对象字段直传', function () {
  const findings = checkRouteLiterals([
    { path: 'features/x/Page.ets', text: "router.pushUrl({ url: 'features/pencil/pages/PencilHomePage' })" }
  ])

  assert.equal(findings.length, 1)
})

test('RT-02 绿：引用 AppRoutes 常量', function () {
  const findings = checkRouteLiterals([
    { path: 'features/x/Page.ets', text: 'router.pushUrl({ url: AppRoutes.HOME })' }
  ])

  assert.deepEqual(findings, [])
})

// ── SV-01 ───────────────────────────────────────────────────────────────

test('SV-01 红：import 单例后又 new 同名', function () {
  const findings = checkServiceSingles([
    {
      path: 'features/x/Page.ets',
      text: ["import BodyRecordService from '../../common/services/BodyRecordService'", 'const mine = new BodyRecordService()'].join('\n')
    }
  ])

  assert.equal(findings.length, 1)
  assert.match(findings[0].message, /禁止再次 new/)
})

test('SV-01 绿：export default new（服务定义本身）', function () {
  const findings = checkServiceSingles([
    { path: 'common/services/Foo.ets', text: 'class Foo {}\nexport default new Foo()' }
  ])

  assert.deepEqual(findings, [])
})

test('SV-01 绿：工厂模式 new 本文件内定义的实现类', function () {
  const findings = checkServiceSingles([
    {
      path: 'common/services/WorkoutSessionService.ets',
      text: [
        'class ArkPreferencesSessionStore {',
        '  constructor(prefs: string) {}',
        '}',
        'export class WorkoutSessionService {',
        '  build(prefs: string): ArkPreferencesSessionStore {',
        '    return new ArkPreferencesSessionStore(prefs)',
        '  }',
        '}'
      ].join('\n')
    }
  ])

  assert.deepEqual(findings, [], '工厂构造局部实现类属允许模式')
})

// ── AR-01/02/03 ─────────────────────────────────────────────────────────

function withEtsRoot(fn) {
  const original = getEtsRoot()
  const tmp = 'C:/tmp/fittracker-rules-fixture'
  setEtsRoot(tmp.replace(/\\/g, '/'))
  try {
    return fn()
  } finally {
    setEtsRoot(original)
  }
}

test('AR-01 红：common 依赖 features', function () {
  withEtsRoot(() => {
    const findings = checkLayering([
      {
        path: 'common/services/Foo.ets',
        text: "import Bar from '../../features/pencil/pages/PencilHomePage'"
      }
    ])

    assert.equal(findings.length, 1)
    assert.equal(findings[0].rule, 'AR-01')
  })
})

test('AR-02 豁免：UserDataBackupService 的反向依赖不报', function () {
  withEtsRoot(() => {
    const findings = checkLayering([
      {
        path: 'shared/services/UserDataBackupService.ets',
        text: "import Bridge from '../../features/workout/services/WorkoutSessionPersistenceBridgeService'"
      }
    ])

    assert.deepEqual(findings, [], '兼容层依赖属有意例外')
  })
})

test('AR-02 红：其他 shared 文件依赖 features', function () {
  withEtsRoot(() => {
    const findings = checkLayering([
      { path: 'shared/services/NewService.ets', text: "import X from '../../features/pencil/pages/PencilHomePage'" }
    ])

    assert.equal(findings.length, 1)
    assert.equal(findings[0].rule, 'AR-02')
  })
})

test('AR-01 绿：common 依赖 shared 是允许方向', function () {
  withEtsRoot(() => {
    const findings = checkLayering([
      { path: 'common/services/TrainingPlanService.ets', text: "import PlanEngine from '../../shared/services/PlanEngine'" }
    ])

    assert.deepEqual(findings, [])
  })
})

test('AR-03 红：components 依赖 features', function () {
  withEtsRoot(() => {
    const findings = checkLayering([
      { path: 'components/AppButton.ets', text: "import X from '../features/pencil/pages/PencilHomePage'" }
    ])

    assert.equal(findings.length, 1)
    assert.equal(findings[0].rule, 'AR-03')
  })
})

// ── DS-01 ───────────────────────────────────────────────────────────────

test('DS-01 红：不在基线内的内联色值', function () {
  const hits = collectInlineColors([
    { path: 'features/x/Page.ets', text: "Text('A').backgroundColor('#AABBCC')" }
  ])

  assert.equal(hits.length, 1)
  assert.equal(hits[0].snippet, '#AABBCC')

  const findings = diffAgainstBaseline(hits, [])
  assert.equal(findings.length, 1)
  assert.equal(findings[0].rule, 'DS-01')
})

test('DS-01 绿：基线内的色值不报', function () {
  const hits = collectInlineColors([
    { path: 'features/x/Page.ets', text: "Text('A').backgroundColor('#AABBCC')" }
  ])
  const baseline = toBaselineEntries(hits)

  assert.deepEqual(diffAgainstBaseline(hits, baseline), [])
})

test('DS-01 绿：命名常量声明不算内联', function () {
  const hits = collectInlineColors([
    { path: 'features/x/Page.ets', text: ["const CARD_BG: string = '#F00D1117'", "Text('A').backgroundColor(CARD_BG)"].join('\n') }
  ])

  assert.deepEqual(hits, [], 'const 赋值不是属性方法实参位置')
})

test('DS-01 基线计数：同文件同色值多出一处即报', function () {
  const one = [{ path: 'features/x/Page.ets', text: "Text('A').backgroundColor('#AABBCC')" }]
  const baseline = toBaselineEntries(collectInlineColors(one))

  const two = [
    {
      path: 'features/x/Page.ets',
      text: ["Text('A').backgroundColor('#AABBCC')", "Text('B').backgroundColor('#AABBCC')"].join('\n')
    }
  ]
  const findings = diffAgainstBaseline(collectInlineColors(two), baseline)

  assert.equal(findings.length, 1, '基线允许 1 处，实际 2 处 → 报第 2 处')
  assert.equal(findings[0].line, 2)
})
