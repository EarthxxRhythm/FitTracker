// inject-net-retry.test.mjs — 网络重试补丁的核心行为测试（vm 沙盒，不依赖浏览器）
// 验证补丁的关键承诺：fetch 网络层失败时自动原样重试（≤3 次），成功照常、失败原样抛出。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, 'inject-net-retry.js'), 'utf8');

function makeXHRStub() {
  function XMLHttpRequest() {}
  XMLHttpRequest.prototype.open = function open() {};
  XMLHttpRequest.prototype.send = function send() {};
  XMLHttpRequest.prototype.addEventListener = function addEventListener() {};
  return XMLHttpRequest;
}

function loadPatch(originalFetch) {
  const sandbox = { console, Date, setTimeout, clearTimeout };
  sandbox.window = { fetch: originalFetch };
  sandbox.XMLHttpRequest = makeXHRStub();
  vm.createContext(sandbox);
  vm.runInContext(src, sandbox);
  return sandbox.window;
}

test('网络失败自动重试：第 3 次成功时正常 resolve，重试记录 2 条', async () => {
  let calls = 0;
  const win = loadPatch(async () => {
    calls += 1;
    if (calls < 3) throw new Error('net fail');
    return { ok: true, status: 200 };
  });
  const res = await win.fetch('https://example.test/x');
  assert.equal(res.status, 200);
  assert.equal(calls, 3);
  assert.equal(win.__netRetryLog.length, 2);
  assert.equal(win.__netRetryLog[0].kind, 'fetch');
  assert.equal(win.__netRetryLog[0].url, 'https://example.test/x');
});

test('重试达上限后：原样抛出（不吞错），总调用次数 = 首次 + 3 次重试', async () => {
  let calls = 0;
  const win = loadPatch(async () => {
    calls += 1;
    throw new Error('still down');
  });
  await assert.rejects(win.fetch('https://example.test/y'), /still down/);
  assert.equal(calls, 4);
  assert.equal(win.__netRetryLog.length, 3);
});

test('一次成功：不产生重试记录，调用次数为 1', async () => {
  let calls = 0;
  const win = loadPatch(async () => {
    calls += 1;
    return { ok: true };
  });
  await win.fetch('https://example.test/z');
  assert.equal(calls, 1);
  assert.equal(win.__netRetryLog.length, 0);
});
