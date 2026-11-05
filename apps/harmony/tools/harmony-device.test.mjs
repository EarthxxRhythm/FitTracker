// harmony-device.mjs 纯解析层单测（node:test，不触设备）。
//
// 为什么需要它：设备层把「解析/判读」与「执行」分离，解析层出错的代价是
// 「有设备却报没设备」「锁屏截图当应用前台」——都是假账。这里覆盖解析层的
// 每个纯函数，包括 council 契约要求的 now/sleep/fetchTargets 三注入矢量
// （只注入 sleep 不注入 now，fake sleep 立即 resolve 会与真实 deadline 死锁）。
import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

import {
  parseHdcTargets,
  pickHdcTarget,
  detectLockedOutput,
  resolveHapCandidates,
  parseInstallOutput,
  detectImageFormat,
  classifyPagePath,
  swipeUpGesture,
  ensureTarget,
  HdcTargetError,
} from './harmony-device.mjs'

// ---------------------------------------------------------------------------
// parseHdcTargets / pickHdcTarget
// ---------------------------------------------------------------------------

test('parseHdcTargets：标准输出解析，[Empty] 与表头跳过', () => {
  const raw = [
    '[Empty]',
    '[List of targets found]:',
    '127.0.0.1:5555\t\tTCP\tConnected\tlocalhost\thdc',
    'COM1\t\tUART\tReady\tunknown\t...\thdc',
    'FAKEDEVICE\t\tUSB\tOffline\t',
  ].join('\n')
  const out = parseHdcTargets(raw)
  assert.equal(out.length, 3)
  assert.equal(out[0].id, '127.0.0.1:5555')
  assert.equal(out[0].transport, 'TCP')
  assert.equal(out[0].state, 'Connected')
  assert.equal(out[1].id, 'COM1')
  assert.equal(out[2].state, 'Offline')
})

test('parseHdcTargets：CRLF 与空串', () => {
  const crlf = '127.0.0.1:5555\tTCP\tConnected\tx\thdc\r\nCOM1\tUART\tReady\tx\thdc\r\n'
  assert.equal(parseHdcTargets(crlf).length, 2)
  assert.deepEqual(parseHdcTargets(''), [])
  assert.deepEqual(parseHdcTargets(null), [])
})

test('pickHdcTarget：按列表顺序取第一个 Ready/Connected、UART 排除、空输入 null', () => {
  // 语义：find 第一个 state ∈ {Ready, Connected}（列表顺序优先，非 Ready 优先）
  const ready = [
    { id: 'A', transport: 'TCP', state: 'Connected' },
    { id: 'B', transport: 'USB', state: 'Ready' },
  ]
  assert.equal(pickHdcTarget(ready).id, 'A')
  assert.equal(pickHdcTarget([{ id: 'C', transport: 'TCP', state: 'Connected' }]).id, 'C')
  assert.equal(pickHdcTarget([{ id: 'COM1', transport: 'UART', state: 'Ready' }]), null)
  assert.equal(pickHdcTarget([]), null)
  assert.equal(pickHdcTarget(null), null)
})

// ---------------------------------------------------------------------------
// detectLockedOutput（锁屏双通道取证：命令输出侧）
// ---------------------------------------------------------------------------

test('detectLockedOutput：三种锁屏特征各命中，普通输出 false', () => {
  assert.equal(detectLockedOutput('error: failed to start ability. Error Code:10106102'), true)
  assert.equal(detectLockedOutput('Error Message:The device screen is locked during the application launch'), true)
  assert.equal(detectLockedOutput('unlock screen failed'), true)
  assert.equal(detectLockedOutput('start ability successfully.'), false)
  assert.equal(detectLockedOutput(''), false)
  assert.equal(detectLockedOutput(null), false)
})

// ---------------------------------------------------------------------------
// resolveHapCandidates（HAP 产物探测）
// ---------------------------------------------------------------------------

test('resolveHapCandidates：signed 优先、目录拼接、都无返回空', () => {
  assert.deepEqual(
    resolveHapCandidates(['entry-default-unsigned.hap']).map((c) => c.signed),
    [false],
  )
  assert.deepEqual(
    resolveHapCandidates(['entry-default-signed.hap', 'entry-default-unsigned.hap']).map((c) => c.signed),
    [true, false],
  )
  assert.equal(resolveHapCandidates(['readme.txt']).length, 0)
  assert.equal(resolveHapCandidates([]).length, 0)
  const withDir = resolveHapCandidates(['x-signed.hap'], path.join('a', 'b'))
  assert.equal(withDir[0].file, path.join('a', 'b', 'x-signed.hap'))
})

// ---------------------------------------------------------------------------
// parseInstallOutput
// ---------------------------------------------------------------------------

test('parseInstallOutput：success / 9568332 冲突 / 其他失败三分', () => {
  const ok = parseInstallOutput('msg:install bundle successfully.', 0)
  assert.equal(ok.ok, true)
  assert.equal(ok.signedBundleConflict, false)

  const conflict = parseInstallOutput('[FAIL]code:9568332 install failed.', 1)
  assert.equal(conflict.ok, false)
  assert.equal(conflict.signedBundleConflict, true)

  const fail = parseInstallOutput('error: something went wrong', 1)
  assert.equal(fail.ok, false)
  assert.equal(fail.signedBundleConflict, false)
})

// ---------------------------------------------------------------------------
// detectImageFormat
// ---------------------------------------------------------------------------

test('detectImageFormat：JPEG / PNG / 垃圾字节三分', () => {
  assert.equal(detectImageFormat(Buffer.from([0xff, 0xd8, 0xff, 0xe0])), 'jpeg')
  assert.equal(detectImageFormat(Buffer.from([0x89, 0x50, 0x4e, 0x47])), 'png')
  assert.equal(detectImageFormat(Buffer.from([0x00, 0x01, 0x02, 0x03])), 'unknown')
  assert.equal(detectImageFormat(Buffer.from([0xff, 0xd8])), 'unknown')
  assert.equal(detectImageFormat(null), 'unknown')
})

// ---------------------------------------------------------------------------
// classifyPagePath（前台判读双向口径：正判据 AND deny-list）
// ---------------------------------------------------------------------------

test('classifyPagePath：正判据——非空 pagePath 且非系统特征 → app', () => {
  assert.equal(classifyPagePath('features/pencil/pages/PencilLoginPage'), 'app')
  // 实测：应用前台的 dump 同时带应用 bundle 与 sceneboard（WindowScene 系统窗口），不得误判
  assert.equal(
    classifyPagePath('features/workout/pages/WorkoutPreviewPage', {
      bundleNames: ['com.earthrhythm.fittracker', 'com.ohos.sceneboard'],
    }),
    'app',
  )
})

test('classifyPagePath：deny-list——锁屏/桌面特征与空/unknown 不得放行', () => {
  // 锁屏路径兜底
  assert.equal(classifyPagePath('pages/lockscreen/Index'), 'lockscreen')
  assert.equal(classifyPagePath('com.ohos.sceneboard/launcher'), 'launcher')
  // 锁屏特征文案（探针实测：无服务 + 星期日）
  assert.equal(classifyPagePath('', { texts: ['无服务', '星期日', '九月廿三'] }), 'lockscreen')
  // 桌面特征控件类型（锁屏样本没有 Swiper/Grid 而桌面有——结构差异稳定）
  assert.equal(classifyPagePath('', { texts: ['设置', '图库'], types: ['Swiper', 'Grid', 'GridItem'] }), 'launcher')
  // fail-closed：特征集为空 → unknown，绝不默认放行
  assert.equal(classifyPagePath(''), 'unknown')
  // 自相矛盾输入不猜 → unknown
  assert.equal(classifyPagePath('', { bundleNames: ['com.other.app'], texts: ['x'] }), 'unknown')
  // 系统 UI bundle 但无 pagePath 且无特征 → 锁屏兜底
  assert.equal(classifyPagePath('', { bundleNames: ['com.ohos.sceneboard'], texts: ['无服务'] }), 'lockscreen')
})

// ---------------------------------------------------------------------------
// swipeUpGesture（解锁手势坐标纯函数）
// ---------------------------------------------------------------------------

test('swipeUpGesture：0.5w/0.9h → 0.5w/0.3h，缺省 1320x2856', () => {
  const g = swipeUpGesture(1320, 2856)
  assert.equal(g.x1, 660)
  assert.equal(g.y1, 2570)
  assert.equal(g.x2, 660)
  assert.equal(g.y2, 856)
  const d = swipeUpGesture(0, 0)
  assert.equal(d.x1, 660)
  assert.equal(d.y1, 2570)
})

// ---------------------------------------------------------------------------
// ensureTarget 三注入矢量（now/sleep/fetchTargets）——council 契约要求
// ---------------------------------------------------------------------------

test('ensureTarget：注入 fetcher 首次即 Ready → 立即返回 target', async () => {
  const fetcher = () => ({
    error: '',
    status: 0,
    stdout: '127.0.0.1:5555\t\tTCP\tConnected\tlocalhost\thdc\n',
    stderr: '',
  })
  const sleepCalls = []
  const result = await ensureTarget({
    hdcPath: 'fake-hdc',
    fetchTargets: fetcher,
    sleepFn: async (ms) => sleepCalls.push(ms),
    now: () => 1000,
  })
  assert.equal(result.target.id, '127.0.0.1:5555')
  assert.equal(sleepCalls.length, 0)
})

test('ensureTarget：注入 fake now 推进越过 deadline → 超时抛 NO_TARGETS（必然终止）', async () => {
  let t = 0
  const fetcher = () => ({ error: '', status: 0, stdout: '[Empty]\n', stderr: '' })
  await assert.rejects(
    () =>
      ensureTarget({
        hdcPath: 'fake-hdc',
        timeoutSeconds: 10,
        pollSeconds: 1,
        fetchTargets: fetcher,
        sleepFn: async () => {
          t += 1
        },
        now: () => t * 1000,
      }),
    (err) => err instanceof HdcTargetError && err.code === 'NO_TARGETS',
  )
})

test('ensureTarget：fetcher 持续报错 → 立即抛 HDC_NOT_FOUND（记录 lastError 形态）', async () => {
  const fetcher = () => ({ error: 'spawn ENOENT', status: null, stdout: '', stderr: '' })
  await assert.rejects(
    () =>
      ensureTarget({
        hdcPath: 'fake-hdc',
        fetchTargets: fetcher,
        sleepFn: async () => {},
        now: () => 1000,
      }),
    (err) => err instanceof HdcTargetError && err.code === 'HDC_NOT_FOUND',
  )
})
