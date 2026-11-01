// 用户旅程站点数据 + 帧映射纯函数的契约测试。
//
// 为什么要有它：`journey/stops.ts` 既是 App.tsx（窄屏竖排图文）与 JourneyFilm.tsx（Remotion 编排）
// 的唯一数据源，也是时间轴高亮 / 进度条 / 点击跳站的唯一口径。组件里不内联重算帧映射，
// 因此这份单测绿 = 组件消费的口径绿。
//
// 直跑（不需要构建）：
//   node --test web/tools/journey-stops.test.mjs
// Node v24 原生 strip-types 直接 import 上游 .ts，无额外依赖、不触网络、不触设备。

import test from 'node:test'
import assert from 'node:assert/strict'

import {
  JOURNEY_STOPS,
  JOURNEY_FRAMES,
  FRAMES_PER_STOP,
  activeIndexAt,
  localProgressAt
} from '../src/journey/stops.ts'

const STOP_COUNT = 7
const LAST_INDEX = STOP_COUNT - 1

test('站点表：恰 7 站，首站 plan、末站 profile，id 与截图不重复', () => {
  assert.equal(JOURNEY_STOPS.length, STOP_COUNT, `站点数应为 ${STOP_COUNT}，实际 ${JOURNEY_STOPS.length}`)
  assert.equal(JOURNEY_STOPS[0].id, 'plan')
  assert.equal(JOURNEY_STOPS[LAST_INDEX].id, 'profile')

  const ids = JOURNEY_STOPS.map((s) => s.id)
  assert.equal(new Set(ids).size, ids.length, `站点 id 重复：${ids.join(',')}`)

  const imgs = JOURNEY_STOPS.map((s) => s.img)
  assert.equal(new Set(imgs).size, imgs.length, `站点截图重复：${imgs.join(',')}`)

  for (const stop of JOURNEY_STOPS) {
    assert.match(stop.img, /^\/[\w-]+\.jpg$/, `截图路径应指向 public 根：${stop.img}`)
    for (const field of ['label', 'title', 'line']) {
      assert.equal(typeof stop[field], 'string', `${stop.id}.${field} 应为字符串`)
      assert.ok(stop[field].length > 0, `${stop.id}.${field} 不应为空`)
    }
  }
})

test('总帧数：JOURNEY_FRAMES = FRAMES_PER_STOP × 站数 = 546', () => {
  assert.equal(FRAMES_PER_STOP, 78)
  assert.equal(JOURNEY_FRAMES, 546)
  assert.equal(JOURNEY_FRAMES, FRAMES_PER_STOP * JOURNEY_STOPS.length)
})

test('activeIndexAt：站首取该站、站尾不越到下一站', () => {
  for (let i = 0; i < STOP_COUNT; i += 1) {
    const head = i * FRAMES_PER_STOP
    assert.equal(activeIndexAt(head), i, `站首帧 ${head} 应属第 ${i} 站`)
    assert.equal(activeIndexAt(head + FRAMES_PER_STOP - 1), i, `站尾帧 ${head + FRAMES_PER_STOP - 1} 应属第 ${i} 站`)
  }
})

test('activeIndexAt：越界帧 clamp 到首/尾站', () => {
  assert.equal(activeIndexAt(0), 0)
  assert.equal(activeIndexAt(-1), 0)
  assert.equal(activeIndexAt(-78), 0)
  assert.equal(activeIndexAt(JOURNEY_FRAMES - 1), LAST_INDEX)
  assert.equal(activeIndexAt(JOURNEY_FRAMES), LAST_INDEX)
  assert.equal(activeIndexAt(JOURNEY_FRAMES * 10), LAST_INDEX)
})

test('localProgressAt：已过站=1、未到站=0、当前站=站内帧比例', () => {
  const mid = 3 * FRAMES_PER_STOP + FRAMES_PER_STOP / 2

  // 当前站 = 第 3 站，进度 0.5
  assert.equal(localProgressAt(mid, 3), 0.5)
  // 已过站
  assert.equal(localProgressAt(mid, 0), 1)
  assert.equal(localProgressAt(mid, 2), 1)
  // 未到站
  assert.equal(localProgressAt(mid, 4), 0)
  assert.equal(localProgressAt(mid, LAST_INDEX), 0)

  // 站首 0 / 站尾贴近 1
  assert.equal(localProgressAt(0, 0), 0)
  assert.equal(localProgressAt(FRAMES_PER_STOP - 1, 0), (FRAMES_PER_STOP - 1) / FRAMES_PER_STOP)
  // 越界帧：首帧为负不过 -0、末帧不过 1
  assert.equal(localProgressAt(-5, 0), 0)
  assert.equal(localProgressAt(JOURNEY_FRAMES, LAST_INDEX), 1)
  assert.equal(localProgressAt(JOURNEY_FRAMES * 10, LAST_INDEX), 1)
})
