// cdp.test.mjs — tools/cloud-debug/cdp.mjs 的冒烟测试
// 覆盖：语法、CLI 用法路径（不依赖真实 CDP 连接）、CDP 不可达时的错误路径。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const cdpPath = join(here, 'cdp.mjs');

test('cdp.mjs 语法检查通过', () => {
  const r = spawnSync(process.execPath, ['--check', cdpPath], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
});

test('无参数：输出用法并以退出码 2 结束（不尝试连接 CDP）', () => {
  const r = spawnSync(process.execPath, [cdpPath], { encoding: 'utf8' });
  assert.equal(r.status, 2);
  assert.match(r.stderr, /usage: cdp\.mjs/);
});

test('未知命令：输出用法并以退出码 2 结束', () => {
  const r = spawnSync(process.execPath, [cdpPath, 'bogus-command'], { encoding: 'utf8' });
  assert.equal(r.status, 2);
  assert.match(r.stderr, /usage: cdp\.mjs/);
});

test('CDP 端口不可达时：给出明确错误并以退出码 1 结束', () => {
  const r = spawnSync(process.execPath, [cdpPath, 'pages'], {
    encoding: 'utf8',
    env: { ...process.env, CDP_PORT: '59999' },
    timeout: 30000,
  });
  assert.equal(r.status, 1);
  assert.match(r.stderr, /无法连接 CDP/);
});
