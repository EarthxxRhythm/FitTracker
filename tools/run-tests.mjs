#!/usr/bin/env node
// 统一测试入口：与调用方的 cwd 无关，所有路径都从本文件位置解析。
//
// 为什么需要它：`.rivet-config.json` 的 verify 命令曾直接列出各测试文件路径，
// 而本仓库的测试分布在两个根（仓库根 `tools/` 与鸿蒙工程根 `apps/harmony/tools/`）。
// 自动运行器（run_tests）在隔离快照里会把文件路径相对化到子工程根，再在仓库根执行，
// 于是报 `Could not find 'tools/cloud-debug/cdp.test.mjs, ...'`。
// 收敛成一个存在于仓库根的单文件入口后，运行器只需解析一个路径，分组与 cwd 由本脚本负责。

import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const groups = [
  {
    cwd: repoRoot,
    files: ['tools/sync-content-to-android.test.mjs'],
  },
  {
    cwd: path.join(repoRoot, 'apps', 'harmony'),
    files: [
      'tools/cloud-debug/cdp.test.mjs',
      'tools/cloud-debug/inject-net-retry.test.mjs',
      'tools/check-gates.test.mjs',
      'tools/check-dead-refs.test.mjs',
    ],
  },
];

let failedGroups = 0;

for (const group of groups) {
  const label = path.relative(repoRoot, group.cwd) || '.';
  console.log(`\n=== node --test @ ${label} (${group.files.length} file(s)) ===`);
  const result = spawnSync(process.execPath, ['--test', ...group.files], {
    cwd: group.cwd,
    stdio: 'inherit',
  });
  if (result.error) {
    console.error(`spawn failed: ${result.error.message}`);
    failedGroups += 1;
    continue;
  }
  if (result.status !== 0) failedGroups += 1;
}

if (failedGroups > 0) {
  console.error(`\n${failedGroups} of ${groups.length} test group(s) failed.`);
  process.exit(1);
}
console.log(`\nAll ${groups.length} test group(s) passed.`);
