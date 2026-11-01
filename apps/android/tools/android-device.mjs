#!/usr/bin/env node
// 安卓端设备层：发现 MuMu 实例 → 断言就绪 → 构建安装 → 取图 → 可选 instrumented 用例。
//
// 为什么需要它：鸿蒙侧有 hdc-targets.ps1 做就绪断言、ohos-test.ps1 跑用例，安卓侧此前
// 一个脚本都没有（见 docs/process/test-environments.md 的 MuMu 段）。每次设备验证都从零
// 摸索端口，成本高于收益，于是验证被跳过。
//
// 设计原则：
// 1. 发现优先，绝不硬编码端口。MuMu 15 的实例端口写在
//    <MuMuHome>/vms/<vm>/configs/vm_config.json 的 vm.nat.port_forward.adb.host_port
//    （2026-10-27 本机实测：MuMuPlayer-15.0-0 → 16384）。
// 2. fail-closed：连不上就说清是"没启动实例 / 端口未监听 / unauthorized"哪一种，并给下一步。
// 3. 纯解析逻辑与执行分离，解析部分可被 node --test 覆盖（不触设备）。

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

// ---------------------------------------------------------------------------
// 纯函数区（单测目标）
// ---------------------------------------------------------------------------

export class AdbTargetError extends Error {
  /** @param {string} code @param {string} message */
  constructor(code, message) {
    super(message);
    this.name = 'AdbTargetError';
    this.code = code;
  }
}

/**
 * 解析 `adb devices -l` 输出。
 * 忽略表头 "List of devices attached"、空行、`* daemon ... *` 这类噪声行。
 * @param {string} raw
 * @returns {{serial: string, state: string, attrs: Record<string,string>}[]}
 */
export function parseAdbDevices(raw) {
  const out = [];
  if (typeof raw !== 'string' || raw.length === 0) return out;

  for (const rawLine of raw.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line.length === 0) continue;
    if (/^List of devices attached/i.test(line)) continue;
    if (/^\*/.test(line)) continue;

    const parts = line.split(/\s+/);
    if (parts.length < 2) continue;
    const serial = parts[0];
    const state = parts[1];
    // 只接受 adb 已知状态，避免把日志行误当设备
    const known = ['device', 'offline', 'unauthorized', 'bootloader', 'recovery', 'sideload'];
    const isNoPermissions = state === 'no' && parts[2] === 'permissions';
    if (!known.includes(state) && !isNoPermissions) continue;

    const attrs = {};
    for (const token of parts.slice(isNoPermissions ? 4 : 2)) {
      const idx = token.indexOf(':');
      if (idx > 0) attrs[token.slice(0, idx)] = token.slice(idx + 1);
    }
    out.push({ serial, state: isNoPermissions ? 'no permissions' : state, attrs });
  }
  return out;
}

/**
 * 断言存在可用目标；不满足时抛出指名原因的错（对齐 hdc-targets.ps1 的 Assert-HdcTargetsReady）。
 * @param {{serial: string, state: string}[]} entries
 * @param {string} [preferredSerial]
 * @returns {{serial: string, state: string}}
 */
export function assertAdbReady(entries, preferredSerial = '') {
  const list = Array.isArray(entries) ? entries : [];

  if (list.length === 0) {
    throw new AdbTargetError(
      'NO_TARGETS',
      '没有连接的安卓设备。请先启动 MuMu 实例（确认进入桌面且「设置 → 其他 → ADB 调试」已开启），再重试。',
    );
  }

  const usable = list.filter((e) => e.state === 'device');

  if (preferredSerial && preferredSerial.length > 0) {
    const match = list.find((e) => e.serial === preferredSerial);
    if (!match) {
      const available = list.map((e) => `${e.serial}(${e.state})`).join(', ');
      throw new AdbTargetError(
        'SERIAL_NOT_FOUND',
        `指定的设备 ${preferredSerial} 不在列表中。当前可用：${available}`,
      );
    }
    if (match.state !== 'device') {
      throw new AdbTargetError(
        'SERIAL_NOT_READY',
        `设备 ${preferredSerial} 存在但状态是 ${match.state}。若是 unauthorized，请在模拟器内确认 USB 调试授权；若是 offline，重启 adb server 后重试。`,
      );
    }
    return match;
  }

  if (usable.length > 0) return usable[0];

  const detail = list.map((e) => `${e.serial}=${e.state}`).join(', ');
  throw new AdbTargetError(
    'NO_READY_TARGET',
    `设备已列出但都不可用：${detail}。unauthorized 需在设备上授权调试；offline 需 adb kill-server 后重连。`,
  );
}

/**
 * 候选 adb 端口（启发式兜底，仅在读不到 MuMu 配置时使用；非契约）。
 * @param {{base?: number, count?: number, step?: number}} [opts]
 * @returns {number[]}
 */
export function adbPortCandidates(opts = {}) {
  const base = Number.isInteger(opts.base) ? opts.base : 16384;
  const count = Number.isInteger(opts.count) && opts.count > 0 ? opts.count : 8;
  const step = Number.isInteger(opts.step) && opts.step > 0 ? opts.step : 16;
  const ports = [];
  for (let i = 0; i < count; i += 1) ports.push(base + i * step);
  return ports;
}

/**
 * 由 getprop 汇总文本判定目标是否为模拟器（防止误把物理真机当 MuMu）。
 * @param {string} propsText
 * @returns {boolean}
 */
export function classifyEmulator(propsText) {
  if (typeof propsText !== 'string' || propsText.length === 0) return false;
  return /(mumu|nemu|qemu|goldfish|ro\.boot\.qemu\s*[=:]\s*1|emulator)/i.test(propsText);
}

/**
 * 由串号判定是否为本地模拟器（免一次 getprop）。
 * 只认回环目标与 emulator-<n>：`192.168.x.x:5555` 这类是无线真机，不能当模拟器。
 * @param {string} serial
 * @returns {boolean}
 */
export function isEmulatorSerial(serial) {
  if (typeof serial !== 'string' || serial.length === 0) return false;
  return /^(emulator-\d+|(127\.0\.0\.1|localhost):\d+)$/.test(serial);
}

/**
 * 从 adb devices 结果里挑出已就绪的模拟器；没有则 null。
 * @param {{serial: string, state: string}[]} entries
 * @returns {{serial: string, state: string}|null}
 */
export function pickEmulator(entries) {
  const list = Array.isArray(entries) ? entries : [];
  return list.find((e) => e && e.state === 'device' && isEmulatorSerial(e.serial)) || null;
}

/**
 * 解析 `cmd package resolve-activity --brief <pkg>` 的输出，取最后一行组件名。
 * 实测输出形如：`priority=0` 换行 `com.earthrhythm.fittracker/com.fittracker.app.MainActivity`；
 * 无匹配时是 `No activity found`（含空格，会被排除）。
 * @param {string} raw
 * @returns {string|null}
 */
export function parseResolvedComponent(raw) {
  if (typeof raw !== 'string' || raw.length === 0) return null;
  const lines = raw.split(/\r?\n/).map((l) => l.trim()).filter((l) => l.length > 0);
  for (let i = lines.length - 1; i >= 0; i -= 1) {
    const line = lines[i];
    if (/^priority=\d+$/i.test(line)) continue;
    if (!line.includes('/')) continue;
    if (/\s/.test(line)) continue;
    return line;
  }
  return null;
}

/**
 * 从 MuMu 实例的 vm_config.json 取出 adb 转发端口。
 * 结构（2026-10-27 本机实测）：vm.nat.port_forward.adb.host_port
 * @param {unknown} config
 * @returns {number|null}
 */
export function parseMumuConfig(config) {
  if (!config || typeof config !== 'object') return null;
  const forward = config.vm && config.vm.nat && config.vm.nat.port_forward;
  if (!forward || typeof forward !== 'object') return null;
  const adb = forward.adb;
  if (!adb || typeof adb !== 'object') return null;
  const port = Number(adb.host_port);
  return Number.isInteger(port) && port > 0 && port < 65536 ? port : null;
}

// ---------------------------------------------------------------------------
// 执行区
// ---------------------------------------------------------------------------

const isWindows = process.platform === 'win32';

/** 依次尝试的 adb 路径来源；全部失败时抛错并点名应设的环境变量。 */
export function resolveAdb() {
  const candidates = [];
  if (process.env.FT_ADB) candidates.push(process.env.FT_ADB);
  for (const root of [process.env.ANDROID_HOME, process.env.ANDROID_SDK_ROOT]) {
    if (root) candidates.push(path.join(root, 'platform-tools', isWindows ? 'adb.exe' : 'adb'));
  }
  if (process.env.LOCALAPPDATA) {
    candidates.push(path.join(process.env.LOCALAPPDATA, 'Android', 'Sdk', 'platform-tools', isWindows ? 'adb.exe' : 'adb'));
  }
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return candidate;
  }
  // 最后依赖 PATH
  const probe = spawnSync(isWindows ? 'where' : 'which', ['adb'], { encoding: 'utf8' });
  if (probe.status === 0 && probe.stdout.trim().length > 0) {
    return probe.stdout.split(/\r?\n/)[0].trim();
  }
  throw new AdbTargetError(
    'ADB_NOT_FOUND',
    '找不到 adb。请设置 FT_ADB 指向 adb 可执行文件，或配置 ANDROID_HOME / ANDROID_SDK_ROOT。',
  );
}

/** MuMu 安装根目录候选（不硬编码盘符：本机在 D 盘，别的机器可能在 C 盘）。 */
function mumuHomeCandidates() {
  const list = [];
  if (process.env.FT_MUMU_HOME) list.push(process.env.FT_MUMU_HOME);
  if (isWindows) {
    for (const drive of ['C', 'D', 'E']) {
      for (const programFiles of ['Program Files', 'Program Files (x86)']) {
        list.push(`${drive}:\\${programFiles}\\Netease\\MuMu`);
      }
    }
  }
  return list;
}

export function resolveMumuHome() {
  for (const candidate of mumuHomeCandidates()) {
    if (candidate && fs.existsSync(path.join(candidate, 'vms'))) return candidate;
  }
  return null;
}

/**
 * 扫描 MuMu 实例配置，返回 [{ index, name, adbPort }]。
 * index 取自目录名末尾数字（MuMuPlayer-15.0-0 → 0）。
 */
export function discoverMumuInstances(mumuHome) {
  if (!mumuHome) return [];
  const vmsDir = path.join(mumuHome, 'vms');
  if (!fs.existsSync(vmsDir)) return [];

  const instances = [];
  for (const entry of fs.readdirSync(vmsDir, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const configPath = path.join(vmsDir, entry.name, 'configs', 'vm_config.json');
    if (!fs.existsSync(configPath)) continue;
    let port = null;
    try {
      port = parseMumuConfig(JSON.parse(fs.readFileSync(configPath, 'utf8')));
    } catch {
      port = null;
    }
    const tail = /-(\d+)$/.exec(entry.name);
    instances.push({
      index: tail ? Number(tail[1]) : null,
      name: entry.name,
      adbPort: port,
      configPath,
    });
  }
  return instances;
}

function runAdb(adbPath, args, opts = {}) {
  return spawnSync(adbPath, args, { encoding: 'utf8', ...opts });
}

export function listTargets(adbPath) {
  const res = runAdb(adbPath, ['devices', '-l']);
  if (res.error) throw new AdbTargetError('ADB_SPAWN_FAILED', `执行 adb 失败：${res.error.message}`);
  return parseAdbDevices(res.stdout || '');
}

function probeTcp(host, port, timeoutMs = 400) {
  return new Promise((resolve) => {
    const socket = net.connect({ host, port });
    let settled = false;
    const done = (ok) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolve(ok);
    };
    socket.setTimeout(timeoutMs);
    socket.once('connect', () => done(true));
    socket.once('timeout', () => done(false));
    socket.once('error', () => done(false));
  });
}

/**
 * 发现并确保有一个可用目标。
 * 顺序：已有 device → MuMu 配置端口（TCP 探测通过才 connect）→ 候选端口兜底。
 * @returns {Promise<{serial: string, source: string}>}
 */
export async function ensureTarget({ preferredSerial = '', requireEmulator = false, log = () => {} } = {}) {
  const adbPath = resolveAdb();

  let entries = listTargets(adbPath);
  const readyEntries = entries.filter((e) => e.state === 'device');

  // 不要求模拟器：已有就绪设备直接可用（短路，省一次 connect）。
  if (!requireEmulator && readyEntries.length > 0) {
    const target = assertAdbReady(entries, preferredSerial);
    return { serial: target.serial, source: 'existing', adbPath };
  }

  // 要求模拟器：只在回环目标已在列时才复用。
  // 为什么不能沿用上面的短路：机器上插着实体机时 adb devices 一定非空，
  // 短路会把真机当成验证目标——APK 装到真机、截图截真机，而摘要仍写「安卓 (MuMu)」，
  // 正是 device-smoke 自己反对的假账。
  if (requireEmulator) {
    const emulator = pickEmulator(entries);
    if (emulator && (!preferredSerial || emulator.serial === preferredSerial)) {
      return { serial: emulator.serial, source: 'existing-emulator', adbPath };
    }
  }

  const mumuHome = resolveMumuHome();
  const instances = discoverMumuInstances(mumuHome);
  const ports = [];
  for (const inst of instances) {
    if (inst.adbPort && !ports.includes(inst.adbPort)) ports.push(inst.adbPort);
  }
  if (ports.length === 0) {
    for (const port of adbPortCandidates()) ports.push(port);
    log('未能从 MuMu 配置读到 adb 端口，退化为候选端口探测。');
  }

  for (const port of ports) {
    const open = await probeTcp('127.0.0.1', port);
    if (!open) continue;
    log(`端口 ${port} 有监听，尝试 adb connect…`);
    runAdb(adbPath, ['connect', `127.0.0.1:${port}`]);
    entries = listTargets(adbPath);
    if (requireEmulator) {
      const emulator = pickEmulator(entries);
      if (emulator && (!preferredSerial || emulator.serial === preferredSerial)) {
        return { serial: emulator.serial, source: `mumu:${port}`, adbPath };
      }
      continue;
    }
    if (entries.some((e) => e.state === 'device')) {
      const target = assertAdbReady(entries, preferredSerial);
      return { serial: target.serial, source: `mumu:${port}`, adbPath };
    }
  }

  // 全部失败：给可执行的诊断，而不是泛化报错
  const detail = instances.length
    ? instances.map((i) => `${i.name}(adbPort=${i.adbPort ?? '未知'})`).join(', ')
    : '未发现 MuMu 实例配置';
  if (requireEmulator && readyEntries.length > 0) {
    throw new AdbTargetError(
      'EMULATOR_REQUIRED',
      `要求模拟器目标，但当前就绪的只有非模拟器设备：${readyEntries.map((e) => e.serial).join(', ')}。` +
        `MuMu 实例：${detail}；已尝试端口 [${ports.join(', ')}]。` +
        '要改用实体机验证，去掉 --emulator（device-smoke 用 --android-any-device）。',
    );
  }
  throw new AdbTargetError(
    'MUMU_NOT_REACHABLE',
    `MuMu 实例未就绪：${detail}。已尝试端口 [${ports.join(', ')}]。` +
      '请确认 MuMu 实例已启动并进入桌面；若端口未监听，说明实例未真正开机（control launch 返回 0 不代表已开机）。',
  );
}

/** 抓设备属性并判定是否模拟器（防误连物理真机）。 */
export function describeTarget(adbPath, serial) {
  const getprop = runAdb(adbPath, ['-s', serial, 'shell', 'getprop']);
  const propsText = getprop.stdout || '';
  const read = (key) => {
    const m = new RegExp(`\\[${key}\\]:\\s*\\[([^\\]]*)\\]`).exec(propsText);
    return m ? m[1] : '';
  };
  return {
    serial,
    isEmulator: classifyEmulator(propsText),
    androidRelease: read('ro.build.version.release'),
    abi: read('ro.product.cpu.abi'),
    model: read('ro.product.model'),
  };
}

export function installApk(adbPath, serial, apkPath) {
  if (!fs.existsSync(apkPath)) {
    throw new AdbTargetError('APK_MISSING', `找不到 APK：${apkPath}。先跑 gradlew :app:assembleDebug。`);
  }
  const res = runAdb(adbPath, ['-s', serial, 'install', '-r', apkPath], { timeout: 180000 });
  const output = `${res.stdout || ''}${res.stderr || ''}`;
  if (res.status !== 0 || !/Success/i.test(output)) {
    throw new AdbTargetError('INSTALL_FAILED', `安装失败：${output.trim()}`);
  }
  return output.trim();
}

export function screenshot(adbPath, serial, outPath) {
  // 必须拿原始字节：runAdb 默认 encoding:'utf8'，会把 PNG 二进制非法 UTF-8 字节
  // 解成 U+FFFD，再以 'binary' 写盘时塌缩成 0xFD —— 截图文件被静默损坏。
  const res = runAdb(adbPath, ['-s', serial, 'exec-out', 'screencap', '-p'], {
    encoding: 'buffer',
    timeout: 60000,
    maxBuffer: 32 * 1024 * 1024,
  });
  if (res.status !== 0 || !res.stdout || res.stdout.length === 0) {
    throw new AdbTargetError('SCREENSHOT_FAILED', `截图失败（exit=${res.status}）`);
  }
  const buf = Buffer.isBuffer(res.stdout) ? res.stdout : Buffer.from(res.stdout, 'binary');
  if (buf.length < 8 || buf[0] !== 0x89 || buf.subarray(1, 4).toString('latin1') !== 'PNG') {
    throw new AdbTargetError(
      'SCREENSHOT_CORRUPT',
      `截图不是合法 PNG（前 4 字节 ${buf.subarray(0, 4).toString('hex')}）——stdout 被当文本解码所致`,
    );
  }
  fs.mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
  fs.writeFileSync(outPath, buf);
  const bytes = fs.statSync(outPath).size;
  if (bytes < 8) throw new AdbTargetError('SCREENSHOT_EMPTY', `截图文件过小：${outPath}`);
  return { path: outPath, bytes };
}

// ---------------------------------------------------------------------------
// 启动应用
// ---------------------------------------------------------------------------

/**
 * 启动应用并等待首帧（am start -W）。
 * 组件名顺序：--component 显式值 → 设备侧 resolve-activity（已装 APK 时准确）→ namespace 兜底。
 * 为什么不能拿 applicationId 拼相对名：build.gradle.kts 里 namespace=com.fittracker.app、
 * applicationId=com.earthrhythm.fittracker，相对名 `.MainActivity` 会被解析成
 * com.earthrhythm.fittracker.MainActivity（不存在）→ 启动失败、截图停在桌面。
 * @returns {{component: string, source: string, output: string}}
 */
export function launchApp(
  adbPath,
  serial,
  { pkg = DEFAULT_APP_ID, activity = DEFAULT_ACTIVITY, component = '' } = {},
  log = () => {},
) {
  let target = typeof component === 'string' ? component.trim() : '';
  let source = 'component-flag';

  if (!target) {
    const probe = runAdb(adbPath, ['-s', serial, 'shell', 'cmd', 'package', 'resolve-activity', '--brief', pkg], {
      timeout: 30000,
    });
    const resolved = parseResolvedComponent(`${probe.stdout || ''}${probe.stderr || ''}`);
    if (resolved) {
      target = resolved;
      source = 'resolve-activity';
    } else {
      target = `${pkg}/${activity}`;
      source = 'fallback-namespace';
      log(`resolve-activity 未返回组件名，回退到 ${target}（若启动失败请用 --component 指定）`);
    }
  }

  const res = runAdb(adbPath, ['-s', serial, 'shell', 'am', 'start', '-W', '-n', target], { timeout: 60000 });
  const output = `${res.stdout || ''}${res.stderr || ''}`.trim();
  const started = /Status:\s*ok/i.test(output) || /Activity not started.*brought to the front/i.test(output);
  if (res.status !== 0 || !started) {
    throw new AdbTargetError('LAUNCH_FAILED', `启动失败（exit=${res.status}，组件 ${target}）：${output || '（无输出）'}`);
  }
  return { component: target, source, output };
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

// 基准取脚本自身位置（apps/android/tools/..），不取 cwd：
// 从仓库根跑 `node apps/android/tools/android-device.mjs install` 时，
// 旧的 path.resolve(process.cwd()) 会拼出 <repo>/app/build/... → 误报 APK_MISSING。
const ANDROID_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DEFAULT_APK = path.join(ANDROID_ROOT, 'app', 'build', 'outputs', 'apk', 'debug', 'app-debug.apk');

/** 应用身份（build.gradle.kts：namespace=com.fittracker.app，applicationId=com.earthrhythm.fittracker）。 */
const DEFAULT_APP_ID = 'com.earthrhythm.fittracker';
const DEFAULT_ACTIVITY = 'com.fittracker.app.MainActivity';

function parseArgs(argv) {
  const flags = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const next = argv[i + 1];
    if (next && !next.startsWith('--')) {
      flags[key] = next;
      i += 1;
    } else {
      flags[key] = true;
    }
  }
  return flags;
}

async function main() {
  const [command] = process.argv.slice(2);
  const flags = parseArgs(process.argv.slice(3));
  const log = (msg) => console.log(`[android-device] ${msg}`);

  try {
    switch (command) {
      case 'check': {
        const { serial, source, adbPath } = await ensureTarget({
          preferredSerial: flags.serial || '',
          requireEmulator: Boolean(flags.emulator),
          log,
        });
        const info = describeTarget(adbPath, serial);
        log(`目标串号 ${serial}（来源 ${source}）`);
        log(`Android ${info.androidRelease} / ABI ${info.abi} / model ${info.model}`);
        log(info.isEmulator ? '判定为模拟器 ✅' : '⚠️ 未识别为模拟器，可能是物理真机');
        break;
      }
      case 'install': {
        const { serial, adbPath } = await ensureTarget({
          preferredSerial: flags.serial || '',
          requireEmulator: Boolean(flags.emulator),
          log,
        });
        const apk = flags.apk || DEFAULT_APK;
        log(`安装 ${apk} → ${serial}`);
        log(installApk(adbPath, serial, apk));
        break;
      }
      case 'launch': {
        const { serial, adbPath } = await ensureTarget({
          preferredSerial: flags.serial || '',
          requireEmulator: Boolean(flags.emulator),
          log,
        });
        const launched = launchApp(
          adbPath,
          serial,
          {
            pkg: typeof flags.pkg === 'string' ? flags.pkg : DEFAULT_APP_ID,
            activity: typeof flags.activity === 'string' ? flags.activity : DEFAULT_ACTIVITY,
            component: typeof flags.component === 'string' ? flags.component : '',
          },
          log,
        );
        log(`已启动 ${launched.component}（组件名来源 ${launched.source}）`);
        log(launched.output.split(/\r?\n/).filter((l) => /Status|Error|Warning/i.test(l)).join(' | '));
        break;
      }
      case 'shoot': {
        const { serial, adbPath } = await ensureTarget({
          preferredSerial: flags.serial || '',
          requireEmulator: Boolean(flags.emulator),
          log,
        });
        const out = flags.out || path.join('test_run', `android-${Date.now()}.png`);
        const shot = screenshot(adbPath, serial, out);
        log(`截图 ${shot.path}（${shot.bytes} 字节）`);
        break;
      }
      case 'test': {
        // 走 gradle connectedDebugAndroidTest。它默认跑「所有已连接设备」——必须先用
        // ensureTarget 收敛到一台并用 ANDROID_SERIAL 钉住，否则会把 instrumented 包装到
        // 用户真机上（实测教训：未限设备时同时跑了真机 PKB110 与 MuMu）。
        // 未显式给 --serial 时强制模拟器（防假账，同 requireEmulator 语义）。
        const { serial } = await ensureTarget({
          preferredSerial: flags.serial || '',
          requireEmulator: !flags.serial,
          log,
        });
        const args = [isWindows ? '.\\gradlew.bat' : './gradlew', ':app:connectedDebugAndroidTest'];
        if (flags.class) {
          args.push(`-Pandroid.testInstrumentationRunnerArguments.class=${flags.class}`);
        }
        log(`在 ${serial} 上执行 ${args.join(' ')}（ANDROID_SERIAL 已钉住）`);
        const res = spawnSync(args[0], args.slice(1), {
          stdio: 'inherit',
          cwd: ANDROID_ROOT,
          env: { ...process.env, ANDROID_SERIAL: serial },
          // Windows 下 node 无 shell 不能直接执行 .bat（status=null spawn 失败）；
          // shell: true 走 cmd /c，与 Git Bash 里 ./gradlew.bat 语义一致。
          shell: isWindows,
        });
        if (res.status !== 0) {
          const detail = res.status === null ? `spawn 失败：${res.error?.message ?? '未知'}` : `exit=${res.status}`;
          throw new AdbTargetError('INSTRUMENTED_FAILED', `connectedDebugAndroidTest 失败（${detail}）`);
        }
        break;
      }
      default:
        console.error(
          '用法：node android-device.mjs <check|install|launch|shoot|test> [--serial <s>] [--emulator] [--apk <path>] [--out <png>] [--class <FQCN>] [--component <pkg/cls>] [--pkg <id>] [--activity <cls>]',
        );
        process.exit(2);
    }
  } catch (error) {
    if (error instanceof AdbTargetError) {
      console.error(`[android-device] ❌ ${error.code}: ${error.message}`);
      process.exit(1);
    }
    throw error;
  }
}

if (process.argv[1] && import.meta.url === new URL(`file:///${path.resolve(process.argv[1]).replace(/\\/g, '/')}`).href) {
  main();
}
