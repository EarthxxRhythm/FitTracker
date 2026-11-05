#!/usr/bin/env node
// 跨端设备冒烟：安卓（MuMu）与鸿蒙（DevEco 模拟器）各跑一遍就绪检查，产出统一摘要。
//
// 为什么需要它：两端验证过去是两套互不相干的手工流程，谁跑了谁没跑只有人脑记着。
// 这里把两端收敛到一条命令，并且强制三态——PASS / FAIL / SKIP（设备没起）。
// SKIP 绝不等同于 PASS：设备没启动却算通过，会让"双端都验过"变成假账。
//
// 用法：
//   node tools/device-smoke.mjs                # 两端就绪检查（安卓额外取一张图）
//   node tools/device-smoke.mjs --android-install   # 安卓安装 debug APK + 启动应用 + 等待渲染后截图
//   node tools/device-smoke.mjs --android-launch    # 只启动应用 + 截图（APK 已装）
//   node tools/device-smoke.mjs --android-any-device # 允许用实体机（默认只认 MuMu 模拟器）
//   node tools/device-smoke.mjs --harmony-start "Pura 90"           # 起模拟器（须与后续动作同一次调用）
//   node tools/device-smoke.mjs --harmony-start "Pura 90" --harmony-install  # 鸿蒙全链路：起 → 装 HAP → 启动 → 解锁 → 判读 → 截图
//   node tools/device-smoke.mjs --harmony-launch    # 鸿蒙只启动应用 + 判读 + 截图（HAP 已装）
//   node tools/device-smoke.mjs --harmony-test      # 鸿蒙额外跑 ohosTest（需已构建测试包）

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const androidDir = path.join(repoRoot, 'apps', 'android');

// HAP 产物与测试包的构建不属于本脚本：先 devecocli build --product default。
// 三态口径：显式请求了动作（--harmony-start/--harmony-install/--harmony-launch/--harmony-test）时，
// 动作链上任一步失败一律 FAIL——显式请求的失败不是「环境现状」；只有裸跑（未请求任何动作）
// 且无设备才 SKIP，且 details 首项是机器可判标记串 SKIP:HARMONY_NO_TARGET（CI 可 grep）。

const PASS = 'PASS';
const FAIL = 'FAIL';
const SKIP = 'SKIP';

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function checkAndroid(flags, log) {
  // 复用 android-device.mjs 的执行层，避免第二套设备发现逻辑
  const mod = await import(pathToFileURL(path.join(androidDir, 'tools', 'android-device.mjs')).href);
  // 这一行报告标题写的就是「安卓 (MuMu)」：机器上插着实体机时不能静默把真机当成 MuMu 验，
  // 否则 APK 装到真机、截图截真机，摘要却写 MuMu —— 正是本文件自己反对的假账。
  const requireEmulator = !flags['android-any-device'];
  const shouldLaunch = Boolean(flags['android-install'] || flags['android-launch']);
  const waitMs = Number(flags['android-wait']) > 0 ? Number(flags['android-wait']) : 3000;
  try {
    const { serial, source, adbPath } = await mod.ensureTarget({ log, requireEmulator });
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

    if (shouldLaunch) {
      // 启动必须在截图之前：不启动就截，图上是桌面或锁屏，「有截图」不能当「应用起来了」的证据。
      const launched = mod.launchApp(adbPath, serial, {}, log);
      details.push(`启动 ${launched.component}（组件名来源 ${launched.source}，Status ok）`);
      log(`等待首帧渲染 ${waitMs}ms`);
      await sleep(waitMs);
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
    // 只有实体机、没有 MuMu：本次「安卓 (MuMu)」无从验证 → SKIP，不计为通过
    if (error && error.code === 'EMULATOR_REQUIRED') {
      return { status: SKIP, details: ['未找到可用的 MuMu 实例（仅检测到实体机）', error.message] };
    }
    return { status: FAIL, details: [`${error.code || 'ERROR'}: ${error.message}`] };
  }
}

/**
 * 鸿蒙端检查。执行层复用 apps\harmony\tools\harmony-device.mjs（动态 import，与安卓端形态同构）。
 *
 * 为什么执行层单独成文件：解析/判读纯函数要能被 node --test 覆盖、且 CLI/冒烟/测试三处
 * 共用一套判据——「有没有装、起没起来、画面在哪」不能有第二套口径。
 */
async function checkHarmony(flags, log) {
  const mod = await import(pathToFileURL(path.join(repoRoot, 'apps', 'harmony', 'tools', 'harmony-device.mjs')).href);
  const waitSeconds = Number(flags['harmony-wait']) > 0 ? Number(flags['harmony-wait']) : 60;
  const explicitAction = Boolean(
    flags['harmony-start'] || flags['harmony-install'] || flags['harmony-launch'] || flags['harmony-test'],
  );
  const startName = typeof flags['harmony-start'] === 'string' ? flags['harmony-start'] : '';
  const details = [];

  try {
    // 起模拟器（可选）：必须与后续动作同一次调用——模拟器随启动它的进程树回收（文档三次实测）。
    if (startName) {
      log(`启动模拟器 "${startName}"（约 50-70s，起+用须同一次调用）…`);
      const started = await mod.startEmulator(startName, { timeoutSeconds: Math.max(waitSeconds, 120) });
      details.push(`模拟器已起：${started.target.id}（${started.target.transport}/${started.target.state}）`);
    }

    const { target } = await mod.ensureTarget({ timeoutSeconds: waitSeconds });
    details.push(`目标 ${target.id}（${target.transport}/${target.state}）`);

    if (flags['harmony-install']) {
      const installed = mod.installHap({});
      details.push(`安装：${path.basename(installed.hap)}`);
    }

    if (flags['harmony-install'] || flags['harmony-launch']) {
      // 启动 + 判读：launchApp 只在 classifyPagePath === 'app' 时正常返回；
      // 锁屏/桌面/未知一律 LAUNCH_FAILED——「aa start 返回 ok」不构成「应用已启动」的证据。
      const launched = await mod.launchApp({ unlock: !flags['harmony-no-unlock'] });
      details.push(
        `启动：判读 ${launched.verdict}（pagePath=${launched.pagePath || '（空）'}${launched.unlocked ? '，经解锁' : ''}）`,
      );
      const out = path.join(
        repoRoot,
        'apps',
        'harmony',
        'test_run',
        'harmony-smoke',
        `device-smoke-${Date.now()}.jpeg`,
      );
      const shot = mod.shoot({ out });
      details.push(`截图 ${path.relative(repoRoot, shot.path)}（${shot.bytes} 字节，${shot.format}）`);
    }

    if (flags['harmony-test']) {
      log('执行 ohosTest（ohos-test.ps1）…');
      mod.runOhosTest({ extraArgs: [] });
      details.push('ohosTest：通过（只代表用例绿，不含应用内启动判读）');
    }

    return { status: PASS, details };
  } catch (error) {
    const code = error && error.code ? error.code : 'ERROR';
    const message = error && error.message ? error.message : String(error);
    // 裸跑且无设备 → SKIP（环境现状，不计为通过）；显式请求动作后失败 → FAIL。
    if (code === 'NO_TARGETS' && !explicitAction) {
      return {
        status: SKIP,
        details: ['SKIP:HARMONY_NO_TARGET', `等待 ${waitSeconds}s 后仍无可用鸿蒙设备/模拟器`, message],
      };
    }
    return { status: FAIL, details: [...details, `${code}: ${message}`] };
  }
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
