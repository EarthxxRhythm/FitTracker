// android-device.mjs 的纯解析层单测：不触碰设备、不启动 adb。
// 依据：agent-device 的失败几乎都发生在"把 adb 文本输出解析错"这一步，
// 而这层完全可以用固定字符串覆盖，不必上设备。

import test from 'node:test';
import assert from 'node:assert/strict';

import {
  AdbTargetError,
  adbPortCandidates,
  assertAdbReady,
  classifyEmulator,
  parseAdbDevices,
  parseMumuConfig,
} from './android-device.mjs';

test('parseAdbDevices：空输入与仅表头都返回空数组', () => {
  assert.deepEqual(parseAdbDevices(''), []);
  assert.deepEqual(parseAdbDevices('List of devices attached\n'), []);
  assert.deepEqual(parseAdbDevices(null), []);
  assert.deepEqual(parseAdbDevices(undefined), []);
});

test('parseAdbDevices：daemon 噪声行被忽略', () => {
  const raw = ['* daemon not running; starting now at tcp:5037 *', '* daemon started successfully *', 'List of devices attached', ''].join('\n');
  assert.deepEqual(parseAdbDevices(raw), []);
});

test('parseAdbDevices：device 行带 -l 长属性时正确拆出 serial/state/attrs', () => {
  const raw = [
    'List of devices attached',
    '127.0.0.1:16384\tdevice product:MuMuAndroid model:MuMuAndroid device:MuMuAndroid transport_id:3',
    'emulator-5554\toffline transport_id:9',
    '',
  ].join('\n');
  const entries = parseAdbDevices(raw);
  assert.equal(entries.length, 2);
  assert.equal(entries[0].serial, '127.0.0.1:16384');
  assert.equal(entries[0].state, 'device');
  assert.equal(entries[0].attrs.transport_id, '3');
  assert.equal(entries[1].serial, 'emulator-5554');
  assert.equal(entries[1].state, 'offline');
});

test('parseAdbDevices：unauthorized 与 no permissions 都保留', () => {
  const unauthorized = parseAdbDevices('List of devices attached\nabc123\tunauthorized\n');
  assert.equal(unauthorized[0].state, 'unauthorized');

  const noPerm = parseAdbDevices('List of devices attached\nabc123\tno permissions (user in plugdev group); see [http://developer.android.com]\n');
  assert.equal(noPerm[0].state, 'no permissions');
});

test('parseAdbDevices：非设备日志行不被误当设备', () => {
  const raw = ['List of devices attached', 'adb server version (41) does not match this client (39)', 'error: more than one device/emulator'].join('\n');
  assert.deepEqual(parseAdbDevices(raw), []);
});

test('assertAdbReady：无目标时抛 NO_TARGETS 且消息含可操作指引', () => {
  assert.throws(
    () => assertAdbReady([]),
    (err) => {
      assert.ok(err instanceof AdbTargetError);
      assert.equal(err.code, 'NO_TARGETS');
      assert.match(err.message, /MuMu/);
      assert.match(err.message, /ADB 调试/);
      return true;
    },
  );
});

test('assertAdbReady：只有 offline/unauthorized 时抛 NO_READY_TARGET 并点名状态', () => {
  assert.throws(
    () =>
      assertAdbReady([
        { serial: '127.0.0.1:16384', state: 'offline' },
        { serial: 'abc', state: 'unauthorized' },
      ]),
    (err) => {
      assert.equal(err.code, 'NO_READY_TARGET');
      assert.match(err.message, /127\.0\.0\.1:16384=offline/);
      assert.match(err.message, /abc=unauthorized/);
      return true;
    },
  );
});

test('assertAdbReady：preferredSerial 不存在时列出可用项', () => {
  assert.throws(
    () => assertAdbReady([{ serial: 'A', state: 'device' }], 'MISSING'),
    (err) => {
      assert.equal(err.code, 'SERIAL_NOT_FOUND');
      assert.match(err.message, /A\(device\)/);
      return true;
    },
  );
});

test('assertAdbReady：preferredSerial 存在但未就绪时抛 SERIAL_NOT_READY', () => {
  assert.throws(
    () => assertAdbReady([{ serial: 'S', state: 'offline' }], 'S'),
    (err) => {
      assert.equal(err.code, 'SERIAL_NOT_READY');
      return true;
    },
  );
});

test('assertAdbReady：正常可用时返回该条目（默认取第一个 device）', () => {
  const first = assertAdbReady([
    { serial: 'off1', state: 'offline' },
    { serial: 'dev1', state: 'device' },
  ]);
  assert.equal(first.serial, 'dev1');

  const picked = assertAdbReady([{ serial: 'dev1', state: 'device' }], 'dev1');
  assert.equal(picked.serial, 'dev1');
});

test('adbPortCandidates：默认从 16384 起、8 个、步长 16', () => {
  const ports = adbPortCandidates();
  assert.equal(ports.length, 8);
  assert.equal(ports[0], 16384);
  assert.equal(ports[1], 16400);
  assert.equal(ports[7], 16384 + 7 * 16);
});

test('adbPortCandidates：参数可覆盖且非法值回落默认', () => {
  assert.deepEqual(adbPortCandidates({ base: 20000, count: 3, step: 32 }), [20000, 20032, 20064]);
  const fallback = adbPortCandidates({ count: 0, step: -1 });
  assert.equal(fallback.length, 8);
  assert.equal(fallback[1] - fallback[0], 16);
});

test('classifyEmulator：MuMu/qemu/goldfish 判为模拟器', () => {
  assert.equal(classifyEmulator('[ro.product.model]: [MuMuAndroid]'), true);
  assert.equal(classifyEmulator('[ro.boot.qemu]: [1]'), true);
  assert.equal(classifyEmulator('[ro.hardware]: [goldfish]'), true);
  assert.equal(classifyEmulator('[ro.product.name]: [nemu64]'), true);
});

test('classifyEmulator：物理机属性与空输入不被误判', () => {
  assert.equal(classifyEmulator('[ro.product.model]: [PKB110]'), false);
  assert.equal(classifyEmulator('[ro.product.model]: [PGT-AN00]'), false);
  assert.equal(classifyEmulator(''), false);
  assert.equal(classifyEmulator(null), false);
});

test('parseMumuConfig：从实测结构 vm.nat.port_forward.adb.host_port 取端口', () => {
  // 结构依据 2026-10-27 本机 MuMuPlayer-15.0-0/configs/vm_config.json 实测
  const cfg = {
    vm: {
      nat: {
        port_forward: {
          adb: { host_port: '16384', guest_port: '5555' },
          api: { host_port: '17439' },
        },
      },
    },
  };
  assert.equal(parseMumuConfig(cfg), 16384);

  // 数字型 host_port 同样接受
  assert.equal(parseMumuConfig({ vm: { nat: { port_forward: { adb: { host_port: 16385 } } } } }), 16385);
});

test('parseMumuConfig：结构缺失或端口非法时返回 null', () => {
  assert.equal(parseMumuConfig(null), null);
  assert.equal(parseMumuConfig({}), null);
  assert.equal(parseMumuConfig({ vm: {} }), null);
  assert.equal(parseMumuConfig({ vm: { nat: { port_forward: { adb: { host_port: 'abc' } } } } }), null);
  assert.equal(parseMumuConfig({ vm: { nat: { port_forward: { adb: { host_port: 99999 } } } } }), null);
});
