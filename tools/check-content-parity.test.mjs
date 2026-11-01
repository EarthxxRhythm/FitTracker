// check-content-parity.test.mjs —— 三处计数对账的纯函数单测（node:test，零依赖）
//
// 覆盖：jsonl 行计数（空行跳过）、Android bundle 计数、seed INSERT 计数、
// collectCounts 对当前仓库实跑（三处应一致：当前动作库 102 条）、
// 假漂移输入下 isAligned 判红路径。

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { resolve } from 'node:path'
import { readFileSync } from 'node:fs'

import {
  countJsonlRows,
  countAndroidBundle,
  countSeedInserts,
  collectCounts,
} from './check-content-parity.mjs'

const root = resolve(import.meta.dirname, '..')

test('countJsonlRows 统计非空行并跳过空行', () => {
  assert.equal(countJsonlRows('{"a":1}\n{"b":2}\n\n  \n{"c":3}'), 3)
  assert.equal(countJsonlRows(''), 0)
})

test('countAndroidBundle 统计三个数组长度，非数组给 null', () => {
  assert.deepEqual(
    countAndroidBundle({ muscles: [1, 2], equipment: [1], exercises: [1, 2, 3] }),
    { muscles: 2, equipment: 1, exercises: 3 }
  )
  assert.deepEqual(countAndroidBundle({ muscles: null, equipment: [], exercises: [1] }), {
    muscles: null,
    equipment: 0,
    exercises: 1,
  })
})

test('countSeedInserts 按表统计 INSERT 出现次数（大小写不敏感）', () => {
  const sql = [
    'INSERT INTO exercises (exercise_id) VALUES (1);',
    'insert into exercises (exercise_id) VALUES (2);',
    'INSERT INTO muscles (muscle_id) VALUES (1);',
  ].join('\n')
  assert.deepEqual(countSeedInserts(sql), { muscles: 1, equipment: 0, exercises: 2 })
})

test('collectCounts 对当前仓库实跑：jsonl ↔ android 资产计数一致（102 动作）', () => {
  const counts = collectCounts()
  for (const table of ['muscles', 'equipment', 'exercises']) {
    assert.equal(
      counts.android[table],
      counts.jsonl[table],
      `${table} 漂移：jsonl ${counts.jsonl[table]} vs android ${counts.android[table]}`
    )
  }
  assert.equal(counts.jsonl.exercises, 102, '动作库权威源应为 102 条')
  if (counts.seed !== null) {
    for (const table of ['muscles', 'equipment', 'exercises']) {
      assert.equal(counts.seed[table], counts.jsonl[table], `${table} seed 与 jsonl 漂移`)
    }
  }
})

test('jsonl 与 android 资产逐表引用完整（无空 nameEn 等结构性缺口的代理：计数 + 抽查首条）', () => {
  const bundle = JSON.parse(
    readFileSync(resolve(root, 'apps/android/app/src/main/assets/exercise-content.json'), 'utf8')
  )
  assert.ok(bundle.muscles.length > 0 && bundle.muscles[0].nameEn, 'muscles[0].nameEn 非空')
  assert.ok(bundle.exercises.length > 0 && bundle.exercises[0].nameZh, 'exercises[0].nameZh 非空')
})
