#!/usr/bin/env node
// 跨端设备冒烟：安卓（MuMu）与鸿蒙（DevEco 模拟器）各跑一遍就绪检查，产出统一摘要。
//
// 为什么需要它：两端验证过去是两套互不相干的手工流程，谁跑了谁没跑只有人脑记着。
// 这里把两端收敛到一条命令，并且强制三态——PASS / FAIL / SKIP（设备没起）。
// SKIP 绝不等同于 PASS：设备没启动却算通过，会让"双端都验过"变成假账。
//
// 用法：
//   node tools/device-smoke.mjs                # 两端就绪检查（安卓额外取一张图）
//   node tools/device-smoke.mjs --android-install   # 安卓额外构建并安装 debug APK
//   node tools/device-smoke.mjs --harmony-test      # 鸿蒙额外跑 ohosTest（需已构建测试包）

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const androidDir = path.join(repoRoot, 'apps', 'android');

const PASS = 'PASS';
const FAIL = 'FAIL';
const SKIP = 'SKIP';

/** 解析 `hdc list targets -v`：UART 目标不可用于自动化（同 hdc-targets.ps1 的口径）。 */
export function parseHdcTargets(raw) {
  const out = [];
  if (typeof raw !== 'string') return out;
  for (const rawLine of raw.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line.length === 0) continue;
    if (line === '[Empty]') continue;
    if (line.startsWith('[List')) continue;
    const parts = line.split(/\s+/);
    if (parts.length < 3) continue;
    out.push({ id: parts[0], transport: parts[1], state: parts[2], raw: line });
  }
  return out;
}

/** 从 hdc 目标里挑出可用于自动化的（排除 UART，要求 Ready/Connected）。 */
export function pickHdcTarget(targets) {
  const usable = (targets || []).filter((t) => t.transport !== 'UART');
  return usable.find((t) => t.state === 'Ready' || t.state === 'Connected') || null;
}

function runHdc() {
  const res = spawnSync('hdc', ['list', 'targets', '-v'], { encoding: 'utf8' });
  if (res.error) return { ok: false, reason: `hdc 调用失败：${res.error.message}`, raw: '' };
  return { ok: true, raw: `${res.stdout || ''}${res.stderr || ''}` };
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * 轮询等待鸿蒙目标就绪。
 * 为什么必须轮询：模拟器 boot 完成前 hdc 会经历 `Offline → 短暂 Connected → Offline` 抖动
 * （实测：devecocli emulator start 后 10s 曾出现 Connected，随即转 Offline，boot 完成约需 50-60s）。
 * 单次采样会把这种抖动误判成"设备没起来"，从而把可用的设备报成 SKIP。
 */
async function waitForHdcTarget({ maxWaitSeconds = 60, pollSeconds = 5, log = () => {} } = {}) {
  const deadline = Date.now() + maxWaitSeconds * 1000;
  let lastTargets = [];
  let lastError = null;

  for (;;) {
    const hdc = runHdc();
    if (!hdc.ok) {
      lastError = hdc.reason;
    } else {
      lastTargets = parseHdcTargets(hdc.raw);
      const target = pickHdcTarget(lastTargets);
      if (target) return { target, targets: lastTargets, error: null };
    }

    if (Date.now() >= deadline) {
      return { target: null, targets: lastTargets, error: lastError };
    }
    log(`等待鸿蒙目标就绪…（剩余 ${Math.max(0, Math.round((deadline - Date.now()) / 1000))}s）`);
    await sleep(pollSeconds * 1000);
  }
}

async function checkAndroid(flags, log) {
  // 复用 android-device.mjs 的执行层，避免第二套设备发现逻辑
  const mod = await import(pathToFileURL(path.join(androidDir, 'tools', 'android-device.mjs')).href);
  try {
    const { serial, source, adbPath } = await mod.ensureTarget({ log });
    const info = mod.describeTarget(adbPath, serial);
    const details = [
      `串号 ${serial}（来源 ${source}）`,
      `Android ${info.androidRelease} / ABI ${info.abi} / model ${info.model}`,
      info.isEmulator ? '判定：模拟器' : '判定：⚠️ 非模拟器',
    ];

    if (flags['android-install']) {
      const apk = path.join(androidDir, 'app', 'build', 'outputs', 'apk', 'debug', 'app-debug.apk');
      log(`安装 ${apk}`);
      mod.installApk(adbPath, serial, apk);
      details.push('安装：Success');
    }

    const out = path.join(androidDir, 'test_run', `device-smoke-${Date.now()}.png`);
    const shot = mod.screenshot(adbPath, serial, out);
    details.push(`截图 ${path.relative(repoRoot, shot.path)}（${shot.bytes} 字节）`);

    return { status: PASS, details };
  } catch (error) {
    // 设备未就绪 → SKIP（不是 FAIL：没人承诺此刻模拟器在跑）
    if (error && error.code === 'MUMU_NOT_REACHABLE') {
      return { status: SKIP, details: ['MuMu 实例未启动或端口未监听', error.message] };
    }
    if (error && error.code === 'NO_TARGETS') {
      return { status: SKIP, details: ['没有连接的安卓设备', error.message] };
    }
    return { status: FAIL, details: [`${error.code || 'ERROR'}: ${error.message}`] };
  }
}

async function checkHarmony(flags, log) {
  const waitSeconds = Number(flags['harmony-wait']) > 0 ? Number(flags['harmony-wait']) : 60;
  const { target, targets, error } = await waitForHdcTarget({ maxWaitSeconds: waitSeconds, pollSeconds: 5, log });

  if (error) return { status: FAIL, details: [error] };

  if (!target) {
    const seen = targets.length ? targets.map((t) => `${t.id}/${t.transport}/${t.state}`).join(', ') : '（空）';
    return {
      status: SKIP,
      details: [
        `等待 ${waitSeconds}s 后仍无可用鸿蒙设备/模拟器`,
        `hdc 现有目标：${seen}`,
        '在持久终端里跑 devecocli emulator start "<name>"（本机可用：Pura 90），boot 约需 50-60s',
      ],
    };
  }

  const details = [`目标 ${target.id}（${target.transport}/${target.state}）`];
  if (flags['harmony-test']) {
    const script = path.join(repoRoot, 'apps', 'harmony', 'tools', 'ohos-test.ps1');
    log(`执行 ohosTest：${path.relative(repoRoot, script)}`);
    const res = spawnSync('powershell', ['-ExecutionPolicy', 'Bypass', '-File', script], {
      stdio: 'inherit',
      cwd: path.join(repoRoot, 'apps', 'harmony'),
    });
    if (res.status !== 0) {
      return { status: FAIL, details: [...details, `ohos-test.ps1 退出码 ${res.status}`] };
    }
    details.push('ohosTest：通过');
  }
  return { status: PASS, details };
}

function writeSummary(rows, outPath) {
  const lines = [
    '# 双端设备冒烟摘要',
    '',
    `生成时间：${new Date().toISOString()}`,
    '',
    '| 端 | 状态 | 证据 |',
    '|---|---|---|',
  ];
  for (const row of rows) {
    const evidence = row.details.join('<br/>').replace(/\|/g, '\\|');
    lines.push(`| ${row.platform} | **${row.status}** | ${evidence} |`);
  }
  lines.push('');
  if (rows.some((r) => r.status === SKIP)) {
    lines.push('> SKIP 表示该端设备未启动，**不计为通过**。需在该端启动模拟器后重跑。');
  }
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, `${lines.join('\n')}\n`, 'utf8');
  return outPath;
}

async function main() {
  const flags = {};
  // 支持 `--key value` 与 `--key=value` 两种写法。
  // 旧实现一律写 true，导致 `--harmony-wait 180` 被算成 Number(true) === 1：
  // 等待退化成 1 秒，而模拟器 boot 要 50–60s，脚本必然报「无可用鸿蒙设备」。
  for (let i = 2; i < process.argv.length; i += 1) {
    const token = process.argv[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const eq = key.indexOf('=');
    if (eq > 0) {
      flags[key.slice(0, eq)] = key.slice(eq + 1);
      continue;
    }
    const next = process.argv[i + 1];
    if (next !== undefined && !next.startsWith('--')) {
      flags[key] = next;
      i += 1;
    } else {
      flags[key] = true;
    }
  }
  const log = (msg) => console.log(`[device-smoke] ${msg}`);

  console.log('[device-smoke] 安卓（MuMu）与鸿蒙（DevEco 模拟器）依次检查…\n');
  const rows = [
    { platform: '安卓 (MuMu)', ...(await checkAndroid(flags, log)) },
    { platform: '鸿蒙 (DevEco)', ...(await checkHarmony(flags, log)) },
  ];

  for (const row of rows) {
    console.log(`\n=== ${row.platform}: ${row.status} ===`);
    for (const d of row.details) console.log(`  - ${d}`);
  }

  const summary = writeSummary(rows, path.join(repoRoot, 'test_run', 'device-smoke-summary.md'));
  console.log(`\n摘要：${path.relative(repoRoot, summary)}`);

  const failed = rows.filter((r) => r.status === FAIL);
  if (failed.length > 0) {
    console.error(`\n${failed.length} 端失败：${failed.map((r) => r.platform).join(', ')}`);
    process.exit(1);
  }
  const skipped = rows.filter((r) => r.status === SKIP);
  if (skipped.length > 0) {
    console.log(`\n注意：${skipped.length} 端 SKIP（设备未启动），不计为通过。`);
  } else {
    console.log('\n双端均 PASS。');
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
