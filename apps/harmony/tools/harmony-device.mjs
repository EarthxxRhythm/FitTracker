#!/usr/bin/env node
// 鸿蒙端设备层：发现目标 → 起模拟器 → 装 HAP → 启动应用 → 解锁 → 取图 → 跑 ohosTest。
//
// 为什么需要它：与安卓侧 `apps/android/tools/android-device.mjs` 同构——设备验证此前只有
// 一堆 .ps1 手工步骤，谁跑了谁没跑只有人脑记着；「应用内启动」长期停在锁屏截图（见
// docs/process/test-environments.md「本文的验证边界」）。这里把发现/就绪/安装/启动/解锁/取图
// 收敛成可组合的子命令，并把「画面到底在哪」变成可判读的结论而不是"有张截图"。
//
// 本文件的每条执行语义都有实测出处（2026-11-01 探针，产物 apps/harmony/test_run/harmony-smoke/unlock-probe/）：
// 1. `devecocli emulator start "Pura 90"` 前台约 73s 返回 exit 0，且**会打印**
//    `Emulator "Pura 90" was launched but did not appear in hdc list targets within the timeout.`
//    这条黄色警告——但同进程内紧接着 `hdc list targets -v` 已是 `127.0.0.1:5555 TCP Connected`。
//    所以：start 的退出码/警告都**不是**就绪判据，就绪判据只有 hdc 目标出现。
// 2. 模拟器存活绑定启动它的进程树，因此 start 与后续动作必须落在同一个 node 进程里
//    （这就是本文件把六个子命令做成"可组合"而不是"一次只跑一步"的原因，见 docs 已知坑）。
// 3. 解锁：`hdc shell uitest uiInput swipe <cx> <0.9h> <cx> <0.3h> 500` 在本机锁屏上
//    一次即成（其后 dumpLayout 从「无 pagePath + com.ohos.sceneboard + 无服务/星期几」
//    变为「无 pagePath + com.ohos.sceneboard + 设置/图库/文件管理/日历 + Swiper/Grid」= 桌面）。
//    `devecocli ui swipe` 子命令确实存在且可执行（探针实测 exit 0），故保留为次选手段。
// 4. 判读：`hdc shell uitest dumpLayout` 在应用前台**能**返回可解析的 pagePath
//    （实测 `app/PencilAppShell` + bundle `com.earthrhythm.fittracker`），锁屏/桌面则 pagePath 为空。
//    ⇒ 「一条命令闭环」的 PASS 出口依赖的这条前提已被证成。
// 5. 取图：本机固件只接受 `.jpeg` 后缀（`hdc shell snapshot_display -f <remote>.jpeg` +
//    `hdc file recv`），实测落盘 1320x2856、魔数 FF D8 FF。
//
// 设计原则（与安卓层同构）：
// - 纯解析/判读逻辑与执行分离，纯函数可被 node --test 覆盖且不触设备；
// - fail-closed：报不清就报 `unknown`，绝不把"不知道"读成"通过"；
// - 错误统一 `HdcTargetError`，CLI 以 `❌ <CODE>: <消息>` 收尾。

import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { resolveDevecoCliInvocation } from './check-gates.mjs'

// ---------------------------------------------------------------------------
// 常量
// ---------------------------------------------------------------------------

/** 应用身份（app.json5：bundleName）。 */
export const DEFAULT_BUNDLE = 'com.earthrhythm.fittracker'
/** 入口 ability（module.json5：EntryAbility）。 */
export const DEFAULT_ABILITY = 'EntryAbility'
/** 默认模拟器实例名（本机 `devecocli emulator list` 实测存在）。 */
export const DEFAULT_EMULATOR = 'Pura 90'
/** 系统桌面/锁屏的宿主 bundle（探针实测：锁屏与桌面都报这个，属系统 UI 不是应用）。 */
export const SYSTEM_UI_BUNDLE = 'com.ohos.sceneboard'
/** 远端临时目录（hdc shell / file recv 的中转）。 */
const REMOTE_TMP = '/data/local/tmp'

const HARMONY_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const DEFAULT_HAP_DIR = path.join(HARMONY_ROOT, 'entry', 'build', 'default', 'outputs', 'default')
const DEFAULT_SHOT_DIR = path.join(HARMONY_ROOT, 'test_run', 'harmony-smoke')

// ---------------------------------------------------------------------------
// 纯函数区（单测目标：不读磁盘、不 spawn）
// ---------------------------------------------------------------------------

export class HdcTargetError extends Error {
  /**
   * @param {string} code HDC_NOT_FOUND | DEVECOCLI_NOT_FOUND | NO_TARGETS | EMULATOR_START_FAILED |
   *                      HAP_NOT_FOUND | INSTALL_FAILED | LAUNCH_FAILED | SCREEN_LOCKED |
   *                      SCREENSHOT_FAILED
   * @param {string} message 面向人的说明（含下一步）
   * @param {{detail?: string, exitCode?: number}} [extra]
   */
  constructor(code, message, extra = {}) {
    super(message)
    this.name = 'HdcTargetError'
    this.code = code
    this.detail = extra.detail || ''
    this.exitCode = typeof extra.exitCode === 'number' ? extra.exitCode : 1
  }
}

/**
 * 解析 `hdc list targets -v`。
 * 行形如：`127.0.0.1:5555\t\tTCP\tConnected\tlocalhost\thdc`
 * 忽略 `[Empty]`、`[List of devices attached]` 表头与空行。
 * @param {string} raw
 * @returns {{id: string, transport: string, state: string, raw: string}[]}
 */
export function parseHdcTargets(raw) {
  const out = []
  if (typeof raw !== 'string') return out
  for (const rawLine of raw.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (line.length === 0) continue
    if (line === '[Empty]') continue
    if (line.startsWith('[List')) continue
    const parts = line.split(/\s+/)
    if (parts.length < 3) continue
    out.push({ id: parts[0], transport: parts[1], state: parts[2], raw: line })
  }
  return out
}

/**
 * 挑出可用于自动化的目标。
 * UART 目标（本机 `COM1 UART Ready`）是串口占位，不能 shell 执行——2026-11-01 探针实测
 * `hdc list targets -v` 同时出现 COM1 与 127.0.0.1:5555，若按 Ready 优先会选错。
 * @param {{id: string, transport: string, state: string}[]} targets
 * @param {string} [preferred] 优先目标 id（命中即返回）
 * @returns {{id: string, transport: string, state: string}|null}
 */
export function pickHdcTarget(targets, preferred = '') {
  const list = Array.isArray(targets) ? targets.filter((t) => t.transport !== 'UART') : []
  if (preferred) {
    const hit = list.find((t) => t.id === preferred)
    if (hit && isReadyState(hit.state)) return hit
  }
  return list.find((t) => isReadyState(t.state)) || null
}

function isReadyState(state) {
  return state === 'Ready' || state === 'Connected'
}

/**
 * 从 dumpLayout JSON 汇总判读特征。
 * dumpLayout 输出是节点树，属性挂在 `attributes` 上（workout-chain-smoke.ps1:87-91 同口径）。
 * @param {unknown} json
 * @returns {{nodeCount: number, pagePath: string, pagePaths: string[], bundleNames: string[],
 *            texts: string[], types: string[], rootBounds: string, width: number, height: number}}
 */
export function summarizeLayout(json) {
  const nodes = []
  const walk = (node) => {
    if (!node || typeof node !== 'object') return
    if (node.attributes) nodes.push(node.attributes)
    if (Array.isArray(node.children)) node.children.forEach(walk)
  }
  walk(json)

  const pagePaths = []
  const bundleNames = []
  const texts = []
  const types = []
  for (const attrs of nodes) {
    if (typeof attrs.pagePath === 'string' && attrs.pagePath.length > 0 && !pagePaths.includes(attrs.pagePath)) {
      pagePaths.push(attrs.pagePath)
    }
    if (typeof attrs.bundleName === 'string' && attrs.bundleName.length > 0 && !bundleNames.includes(attrs.bundleName)) {
      bundleNames.push(attrs.bundleName)
    }
    const text = typeof attrs.text === 'string' ? attrs.text : attrs.originalText
    if (typeof text === 'string' && text.length > 0 && !texts.includes(text)) texts.push(text)
    if (typeof attrs.type === 'string' && !types.includes(attrs.type)) types.push(attrs.type)
  }

  const rootBounds = json && json.attributes && typeof json.attributes.bounds === 'string' ? json.attributes.bounds : ''
  const size = parseBoundsCenter(rootBounds)
  return {
    nodeCount: nodes.length,
    pagePath: pagePaths[0] || '',
    pagePaths,
    bundleNames,
    texts,
    types,
    rootBounds,
    width: size ? size.maxX : 0,
    height: size ? size.maxY : 0,
  }
}

function parseBoundsCenter(bounds) {
  const match = /^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/.exec(typeof bounds === 'string' ? bounds : '')
  if (!match) return null
  return {
    minX: Number(match[1]),
    minY: Number(match[2]),
    maxX: Number(match[3]),
    maxY: Number(match[4]),
  }
}

/** 桌面特征文案（2026-11-01 探针实测桌面 dumpLayout 命中 设置/图库/文件管理/日历）。 */
export const LAUNCHER_TEXT_SIGNALS = ['设置', '图库', '文件管理', '日历', '相机', '联系人', '时钟', '备忘录', '音乐']
/**
 * 桌面特征控件类型。锁屏样本只有 Column/Text/SymbolGlyph，桌面多出 Swiper/Grid/GridItem/List——
 * 这是两类系统界面之间唯一稳定的结构差异（文案可能随版本变化，控件结构不会）。
 */
export const LAUNCHER_TYPE_SIGNALS = ['Swiper', 'Grid', 'GridItem', 'ListItem']
/** 锁屏特征文案（2026-11-01 探针实测锁屏命中 无服务 + 星期日/九月廿三）。 */
export const LOCKSCREEN_TEXT_SIGNALS = ['无服务', '星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']
/** 路径口径兜底（pagePath 若能直接表达系统界面时用它，优先于特征集）。 */
export const LOCKSCREEN_PAGE_PATTERN = /lock/i
export const LAUNCHER_PAGE_PATTERN = /launcher|desktop|sceneboard/i

/**
 * 判读当前画面属于哪一类。
 *
 * 双向口径（task 硬约束）：
 * - 正判据：pagePath 非空且 classify === 'app' 才算「在应用前台」；
 * - deny-list：classify ∈ {lockscreen, launcher} 或 empty/unknown 一律判读失败。
 *
 * fail-closed：特征集为空（拿不到 texts/types）时返回 'unknown'，绝不默认放行。
 * 该语义由 hd-tests 的空特征集哨兵用例守护。
 *
 * @param {string} pagePath dumpLayout 里的 pagePath（可为空字符串）
 * @param {{bundleNames?: string[], bundleName?: string, texts?: string[], types?: string[]}} [hints]
 * @returns {'app'|'lockscreen'|'launcher'|'unknown'}
 */
export function classifyPagePath(pagePath, hints = {}) {
  const p = typeof pagePath === 'string' ? pagePath.trim() : ''
  const bundleNames = Array.isArray(hints.bundleNames)
    ? hints.bundleNames
    : typeof hints.bundleName === 'string' && hints.bundleName
      ? [hints.bundleName]
      : []
  const texts = Array.isArray(hints.texts) ? hints.texts : []
  const types = Array.isArray(hints.types) ? hints.types : []
  const systemUi = bundleNames.includes(SYSTEM_UI_BUNDLE)

  if (p.length > 0) {
    if (LOCKSCREEN_PAGE_PATTERN.test(p)) return 'lockscreen'
    if (LAUNCHER_PAGE_PATTERN.test(p)) return 'launcher'
    // 正判据：pagePath 非空即应用页面。不能因为 dump 里同时含系统 UI bundle 就否掉它——
    // 实测应用前台的 dumpLayout 同时带 com.earthrhythm.fittracker 与 com.ohos.sceneboard
    // （WindowScene 节点属系统窗口），按 bundle 判会把真 app 判成 unknown。
    return 'app'
  }

  // pagePath 为空：只能靠特征集。特征集空 → 不知道 → unknown（deny）
  if (texts.length === 0 && types.length === 0) return 'unknown'
  // 出现了非系统 bundle 却没有 pagePath：判读输入自相矛盾，不猜 → unknown（deny）
  if (bundleNames.some((name) => name && name !== SYSTEM_UI_BUNDLE)) return 'unknown'

  const launcherTypeHits = LAUNCHER_TYPE_SIGNALS.filter((t) => types.includes(t)).length
  const launcherTextHits = LAUNCHER_TEXT_SIGNALS.filter((t) => texts.includes(t)).length
  const lockHits = LOCKSCREEN_TEXT_SIGNALS.filter((t) => texts.some((x) => typeof x === 'string' && x.includes(t))).length

  if (launcherTypeHits >= 1 || launcherTextHits >= 2) return 'launcher'
  if (lockHits >= 1) return 'lockscreen'
  if (launcherTextHits >= 1) return 'launcher'
  if (systemUi) return 'lockscreen'
  return 'unknown'
}

/**
 * 判定「锁屏拦住了操作」——输入是**命令输出**（`hdc shell aa start`）。
 *
 * 为什么不能只靠画面判读：2026-11-01 实测，锁屏态执行启动会得到
 *   `error: failed to start ability.` +
 *   `Error Code:10106102  Error Message:The device screen is locked during the application launch, unlock screen failed.` +
 *   `Error cause: The current mode is developer mode, and the screen cannot be unlocked automatically`
 * 而**此时 dumpLayout 已判为 launcher**（系统把锁屏顶掉了），画面判读看不出「刚才被锁屏拦了」。
 * 所以锁屏要两条通道取证：命令输出的 10106102 / screen is locked，与画面判读的 lockscreen。
 * @param {string} raw 任意命令输出
 * @returns {boolean}
 */
export function detectLockedOutput(raw) {
  if (typeof raw !== 'string' || raw.trim().length === 0) return false
  return /10106102|screen is locked|unlock screen failed|锁屏/i.test(raw)
}

/**
 * 由输出目录里实际存在的文件名解析 HAP 候选，signed 优先。
 * 为什么要 signed 优先：设备上已装 signed 包时再装 unsigned 会以 `code:9568332` 失败
 * （docs/process/test-environments.md「已知坑」首条，实测）。
 * @param {string[]} availableFiles 目录中的文件名（不必含路径）
 * @param {string} [dir] 拼到结果前（纯函数：不校验存在性）
 * @returns {{file: string, signed: boolean}[]}
 */
export function resolveHapCandidates(availableFiles, dir = '') {
  const files = (Array.isArray(availableFiles) ? availableFiles : []).filter(
    (name) => typeof name === 'string' && /\.hap$/i.test(name),
  )
  const signed = files.filter((name) => /-signed\.hap$/i.test(name))
  const unsigned = files.filter((name) => !/-signed\.hap$/i.test(name))
  return [...signed, ...unsigned].map((name) => ({
    file: dir ? path.join(dir, name) : name,
    signed: /-signed\.hap$/i.test(name),
  }))
}

/**
 * 解析 `hdc install -r` 的输出。
 * 成功口径：`msg:install bundle successfully`；失败口径：非 0 退出或含 failed/error。
 * code 9568332 = 设备上已装 signed 包却要装 unsigned —— 需要人看的指引，不是普通失败。
 * @param {string} raw
 * @param {number|null} status
 * @returns {{ok: boolean, signedBundleConflict: boolean, message: string}}
 */
export function parseInstallOutput(raw, status = null) {
  const text = typeof raw === 'string' ? raw : ''
  const conflict = /9568332/.test(text)
  const success = /install bundle successfully/i.test(text)
  const failure = /failed|error|exception/i.test(text)
  const ok = (!failure && success) || (status === 0 && success)
  return {
    ok,
    signedBundleConflict: conflict,
    message: text.trim().replace(/\s+/g, ' ').slice(0, 400),
  }
}

/**
 * 由字节头判图片格式。魔数：JPEG `FF D8 FF`、PNG `89 50 4E 47`。
 * 为什么要校验：截图命令 exit 0 不代表落盘的是图（远端路径不可写、固件改名都会留下空文件），
 * 空文件/错文件被当成证据就是假账。
 * @param {Uint8Array|Buffer|null} bytes
 * @returns {'jpeg'|'png'|'unknown'}
 */
export function detectImageFormat(bytes) {
  if (!bytes || typeof bytes.length !== 'number' || bytes.length < 4) return 'unknown'
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'jpeg'
  if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) return 'png'
  return 'unknown'
}

/**
 * 由屏宽高算解锁上滑手势坐标（锁屏上滑：屏幕下沿附近 → 上部）。
 * 比例来自 2026-11-01 探针实测可用手势：1320x2856 上 (660,2570) → (660,856)，即 0.5w/0.9h → 0.5w/0.3h。
 * @param {number} width
 * @param {number} height
 * @returns {{x1: number, y1: number, x2: number, y2: number}}
 */
export function swipeUpGesture(width, height) {
  const w = Number(width) > 0 ? Number(width) : 1320
  const h = Number(height) > 0 ? Number(height) : 2856
  return {
    x1: Math.floor(w / 2),
    y1: Math.floor(h * 0.9),
    x2: Math.floor(w / 2),
    y2: Math.floor(h * 0.3),
  }
}

/** 生成 hdc `-t <id>` 前缀；不传 id 时为空（单目标下 hdc 自行选择，探针即如此）。 */
function targetPrefix(targetId) {
  return targetId ? ['-t', targetId] : []
}

// ---------------------------------------------------------------------------
// 执行区
// ---------------------------------------------------------------------------

/** 一次 hdc 调用；spawn 层错误重试一次（记忆 mem_muk0z6l9：hdc.exe 路径间歇不可访问）。 */
function runHdc(hdcPath, args, { timeout = 60000, targetId = '' } = {}) {
  const fullArgs = [...targetPrefix(targetId), ...args]
  let last = null
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const t0 = Date.now()
    const result = spawnSync(hdcPath, fullArgs, { encoding: 'utf8', timeout })
    last = {
      cmd: `${hdcPath} ${fullArgs.join(' ')}`,
      status: result.status,
      signal: result.signal || '',
      error: result.error ? result.error.message : '',
      stdout: result.stdout || '',
      stderr: result.stderr || '',
      ms: Date.now() - t0,
    }
    const spawnFailed = Boolean(last.error) || last.status === null
    if (!spawnFailed) return last
    if (attempt === 1) return last
    log(`hdc 调用失败（${last.error || 'status=null'}），重试一次`)
  }
  return last
}

function commandExists(command) {
  const result = spawnSync(command, ['--version'], { encoding: 'utf8', timeout: 20000 })
  return !result.error && result.status === 0
}

/**
 * 解析 hdc 路径：FT_HDC → PATH → DevEco 安装目录候选。
 * 全失败时抛 HDC_NOT_FOUND 并点名应设的环境变量（fail-closed，绝不"假装没有目标"）。
 * @returns {string}
 */
export function resolveHdc() {
  const override = typeof process.env.FT_HDC === 'string' ? process.env.FT_HDC.trim() : ''
  if (override) {
    if (fs.existsSync(override)) return override
    throw new HdcTargetError(
      'HDC_NOT_FOUND',
      `FT_HDC 指向的路径不存在：${override}。改为指向 hdc 可执行文件，或清空该变量让脚本自行发现。`,
    )
  }

  if (commandExists('hdc')) return 'hdc'

  const exe = process.platform === 'win32' ? 'hdc.exe' : 'hdc'
  const roots = [
    process.env.DEVECO_SDK_HOME,
    process.env.DEVECOSTUDIO_HOME,
    process.env.ProgramFiles ? path.join(process.env.ProgramFiles, 'Huawei', 'DevEco Studio') : '',
    process.env['ProgramFiles(x86)'] ? path.join(process.env['ProgramFiles(x86)'], 'Huawei', 'DevEco Studio') : '',
    'D:\\Program Files\\Huawei\\DevEco Studio',
  ].filter((root) => typeof root === 'string' && root.length > 0)
  for (const root of roots) {
    const candidate = path.join(root, 'sdk', 'default', 'openharmony', 'toolchains', exe)
    if (fs.existsSync(candidate)) return candidate
  }

  throw new HdcTargetError(
    'HDC_NOT_FOUND',
    '找不到 hdc。请把 DevEco Studio 的 sdk/default/openharmony/toolchains 加入 PATH，或设 FT_HDC 指向 hdc 可执行文件。',
  )
}

/** devecocli 调用方式（复用 check-gates.mjs 的解析策略，绕开 Windows .cmd shim 的已知误报）。 */
export function resolveDevecoCli() {
  const invocation = resolveDevecoCliInvocation()
  return invocation
}

function runDevecoCli(invocation, args, { timeout = 180000 } = {}) {
  const t0 = Date.now()
  const result = spawnSync(invocation.command, [...invocation.prefixArgs, ...args], {
    encoding: 'utf8',
    timeout,
    shell: invocation.useShell,
  })
  return {
    cmd: [invocation.command, ...invocation.prefixArgs, ...args].join(' '),
    status: result.status,
    error: result.error ? result.error.message : '',
    stdout: result.stdout || '',
    stderr: result.stderr || '',
    ms: Date.now() - t0,
  }
}

function assertDevecoCliAvailable(invocation) {
  const probe = runDevecoCli(invocation, ['--version'], { timeout: 30000 })
  if (probe.error || probe.status !== 0) {
    throw new HdcTargetError(
      'DEVECOCLI_NOT_FOUND',
      `devecocli 不可用（已尝试：${probe.cmd}）。确认 npm i -g @deveco/deveco-cli，或设 FT_DEVECOCLI 指向 cli.js。` +
        (probe.stdout || probe.stderr ? `\n输出：${(probe.stdout + probe.stderr).trim().slice(0, 400)}` : ''),
    )
  }
}

function log(message) {
  console.log(`[harmony-device] ${message}`)
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

/**
 * 目标发现 + 就绪断言。
 * @param {{preferred?: string, timeoutSeconds?: number, pollSeconds?: number, hdcPath?: string}} [opts]
 * @returns {Promise<{hdcPath: string, target: {id: string, transport: string, state: string}, waitedMs: number}>}
 */
export async function ensureTarget({
  preferred = process.env.FT_HDC_TARGET || '',
  timeoutSeconds = 60,
  pollSeconds = 3,
  hdcPath = '',
  // 注入点（测试专用，生产走默认）：council 契约要求 now/sleep/fetchTargets 三注入，
  // 否则 fake sleep 立即 resolve 会与真实 Date.now() 的 deadline 死锁、CI 挂死。
  fetchTargets = null,
  sleepFn = sleep,
  now = Date.now,
} = {}) {
  const hdc = hdcPath || resolveHdc()
  const deadline = now() + Math.max(0, timeoutSeconds) * 1000
  const fetch = fetchTargets || ((h) => runHdc(h, ['list', 'targets', '-v'], { timeout: 30000 }))
  let lastTargets = []
  let lastRaw = ''

  for (;;) {
    const result = fetch(hdc)
    if (result.error) {
      throw new HdcTargetError('HDC_NOT_FOUND', `hdc 调用失败：${result.error}`, { detail: result.cmd })
    }
    lastRaw = `${result.stdout}${result.stderr}`
    lastTargets = parseHdcTargets(result.stdout)
    const target = pickHdcTarget(lastTargets, preferred)
    if (target) return { hdcPath: hdc, target, waitedMs: 0 }
    if (now() >= deadline) break
    log(`等待鸿蒙目标就绪…（剩余 ${Math.max(0, Math.round((deadline - now()) / 1000))}s）`)
    await sleepFn(pollSeconds * 1000)
  }

  const seen = lastTargets.length
    ? lastTargets.map((t) => `${t.id}/${t.transport}/${t.state}`).join(', ')
    : '（空）'
  throw new HdcTargetError(
    'NO_TARGETS',
    `等待 ${timeoutSeconds}s 后仍无可用鸿蒙目标。当前 hdc 目标：${seen}。\n` +
      `下一步：node tools/harmony-device.mjs start --name "${DEFAULT_EMULATOR}"（boot 约 50-70s，` +
      '且必须与后续动作在同一次调用内——模拟器随启动它的进程树一起被回收）。',
    { detail: lastRaw.trim().slice(0, 400) },
  )
}

/**
 * 起模拟器并等就绪（spawnSync 等待自行返回——探针 A 实测该策略可用）。
 *
 * 三处实测反例都已被这里吸收：
 * - `emulator start` 打印 `did not appear in hdc list targets within the timeout` 却仍在 73s 返回 exit 0，
 *   随后 hdc 目标已 Connected ⇒ 不据警告判失败；
 * - exit 0 也不等于就绪 ⇒ 就绪判据只有 hdc 目标出现；
 * - boot 期间 `Connected → Offline` 抖动 ⇒ 轮询而不是单次采样。
 * @param {string} [name]
 * @param {{timeoutSeconds?: number, startTimeoutMs?: number}} [opts]
 */
export async function startEmulator(name = DEFAULT_EMULATOR, { timeoutSeconds = 120, startTimeoutMs = 180000 } = {}) {
  const invocation = resolveDevecoCli()
  assertDevecoCliAvailable(invocation)

  log(`启动模拟器 "${name}"（前台等待，约 50-70s）…`)
  const started = runDevecoCli(invocation, ['emulator', 'start', name], { timeout: startTimeoutMs })
  const output = `${started.stdout}${started.stderr}`.trim()
  if (started.error || started.status !== 0) {
    throw new HdcTargetError(
      'EMULATOR_START_FAILED',
      `devecocli emulator start "${name}" 失败（exit ${started.status ?? 'null'}${started.error ? `，${started.error}` : ''}）。\n${output.slice(0, 800)}`,
      { exitCode: 1 },
    )
  }
  // 警告文本是已知现象，不当失败；但要记下来，方便人看出"这是被 hdc 兜住了"。
  if (/did not appear in hdc list targets/i.test(output)) {
    log('注意：start 打印了「did not appear in hdc list targets within the timeout」——这是已知现象，继续以 hdc 目标出现为准。')
  }

  const hdc = resolveHdc()
  const deadline = Date.now() + timeoutSeconds * 1000
  let lastTargets = []
  for (;;) {
    const result = runHdc(hdc, ['list', 'targets', '-v'], { timeout: 30000 })
    lastTargets = parseHdcTargets(result.stdout)
    const target = pickHdcTarget(lastTargets)
    if (target) {
      log(`模拟器就绪：${target.id}（${target.transport}/${target.state}，start 后 ${Math.round(started.ms / 1000)}s 起算）`)
      return { target, hdcPath: hdc, startOutput: output, startMs: started.ms }
    }
    if (Date.now() >= deadline) break
    await sleep(3000)
  }

  const seen = lastTargets.length ? lastTargets.map((t) => `${t.id}/${t.transport}/${t.state}`).join(', ') : '（空）'
  throw new HdcTargetError(
    'EMULATOR_START_FAILED',
    `模拟器已启动但 ${timeoutSeconds}s 内未在 hdc 中就绪。当前目标：${seen}。\n` +
      '慢机器上 boot 可能超过 2min：加大 timeoutSeconds 或先确认 Log\\Emulator.log 出现 `Guest OS Boot Completed!!`。\n' +
      `devecocli 输出：${output.slice(0, 400)}`,
  )
}

/**
 * 装 HAP。默认目录 `entry/build/default/outputs/default`，signed 优先。
 * @param {{hapPath?: string, hapDir?: string}} [opts]
 */
export function installHap({ hapPath = '', hapDir = DEFAULT_HAP_DIR } = {}) {
  const hdc = resolveHdc()
  const { target } = requireTargetSync(hdc)

  let hap = hapPath
  if (!hap) {
    if (!fs.existsSync(hapDir)) {
      throw new HdcTargetError('HAP_NOT_FOUND', `HAP 目录不存在：${hapDir}。先构建：cd apps/harmony && devecocli build --product default`)
    }
    const candidates = resolveHapCandidates(fs.readdirSync(hapDir), hapDir)
    if (candidates.length === 0) {
      throw new HdcTargetError('HAP_NOT_FOUND', `${hapDir} 下没有 .hap 产物。先构建：devecocli build --product default`)
    }
    hap = candidates[0].file
    if (!candidates[0].signed) log('注意：未找到 signed HAP，使用 unsigned——若设备已装 signed 包会撞 code:9568332')
  }
  if (!fs.existsSync(hap)) {
    throw new HdcTargetError('HAP_NOT_FOUND', `HAP 不存在：${hap}`)
  }

  log(`安装 ${path.relative(HARMONY_ROOT, hap) || hap}`)
  const result = runHdc(hdc, ['install', '-r', hap], { timeout: 180000, targetId: target.id })
  const parsed = parseInstallOutput(`${result.stdout}${result.stderr}`, result.status)
  if (!parsed.ok) {
    const hint = parsed.signedBundleConflict
      ? '\n提示：code:9568332 = 设备上已装 signed 包，不能再装 unsigned。改用 entry-default-signed.hap（本命令默认已 signed 优先）。'
      : ''
    throw new HdcTargetError('INSTALL_FAILED', `HAP 安装失败（exit ${result.status ?? 'null'}）：${parsed.message}${hint}`)
  }
  log('安装成功（install bundle successfully）')
  return { hap, message: parsed.message }
}

/** 同步就绪检查（安装/启动等单步命令用；不轮询，没有目标就直接 NO_TARGETS）。 */
function requireTargetSync(hdcPath) {
  const result = runHdc(hdcPath, ['list', 'targets', '-v'], { timeout: 30000 })
  if (result.error) throw new HdcTargetError('HDC_NOT_FOUND', `hdc 调用失败：${result.error}`)
  const targets = parseHdcTargets(result.stdout)
  const target = pickHdcTarget(targets, process.env.FT_HDC_TARGET || '')
  if (!target) {
    const seen = targets.length ? targets.map((t) => `${t.id}/${t.transport}/${t.state}`).join(', ') : '（空）'
    throw new HdcTargetError(
      'NO_TARGETS',
      `没有可用鸿蒙目标（现有：${seen}）。单步命令不轮询：请在同一次调用内先 start，或用 device-smoke --harmony-start。`,
    )
  }
  return { hdcPath, target }
}

/** 取一份 dumpLayout 到本地并解析（判读的唯一输入）。 */
function readLayout(hdcPath, targetId, { timeout = 60000 } = {}) {
  const remote = `${REMOTE_TMP}/harmony_device_layout.json`
  const dump = runHdc(hdcPath, ['shell', 'uitest', 'dumpLayout', '-p', remote], { timeout, targetId })
  if (dump.error) throw new HdcTargetError('LAUNCH_FAILED', `dumpLayout 调用失败：${dump.error}`)

  const localDir = path.join(HARMONY_ROOT, 'test_run', 'harmony-smoke', 'layouts')
  fs.mkdirSync(localDir, { recursive: true })
  const local = path.join(localDir, `layout-${Date.now()}.json`)
  const pull = runHdc(hdcPath, ['file', 'recv', remote, local], { timeout: 60000, targetId })
  const raw = fs.existsSync(local) ? fs.readFileSync(local, 'utf8') : ''

  let summary = null
  try {
    summary = summarizeLayout(JSON.parse(raw))
  } catch {
    summary = null
  }
  return {
    raw,
    summary,
    localPath: raw ? local : '',
    verdict: summary ? classifyPagePath(summary.pagePath, summary) : 'unknown',
    outputs: { dump: `${dump.stdout}${dump.stderr}`.trim().slice(0, 300), pull: `${pull.stdout}${pull.stderr}`.trim().slice(0, 300) },
  }
}

/**
 * 解锁：尝试解锁 → 判读 → 失败重试一次 → 仍锁屏报 SCREEN_LOCKED。
 *
 * 手段序（探针 B 实测导出，不是猜的）：
 * 1. 首选 `hdc shell uitest uiInput swipe`（repo 内唯一有实证的输入原语，本次锁屏实测一次即成）；
 * 2. 次选 `devecocli ui swipe`（子命令实测存在且 exit 0；但"解锁生效"未独立验证——首选手势失效时才用它）。
 * 坐标由 dumpLayout 的 rootBounds 算出，不硬编码分辨率。
 *
 * @param {{maxAttempts?: number}} [opts]
 * @returns {{unlocked: boolean, attempts: {primitive: string, verdict: string, output: string}[]}}
 */
export function unlockScreen({ maxAttempts = 2 } = {}) {
  const hdc = resolveHdc()
  const { target } = requireTargetSync(hdc)
  const attempts = []

  const readSize = () => {
    const layout = readLayout(hdc, target.id)
    const width = layout.summary ? layout.summary.width : 0
    const height = layout.summary ? layout.summary.height : 0
    return { layout, gesture: swipeUpGesture(width, height) }
  }

  const first = readSize()
  if (first.layout.verdict === 'app' || first.layout.verdict === 'launcher') {
    log(`无需解锁：当前判读为 ${first.layout.verdict}`)
    return { unlocked: true, attempts }
  }

  for (let attempt = 1; attempt <= Math.max(1, maxAttempts); attempt += 1) {
    const { gesture } = readSize()
    const useDeveco = attempt > 1
    let primitive = 'uitest uiInput swipe'
    let output = ''

    if (!useDeveco) {
      const duration = attempt === 1 ? 500 : 1000
      const result = runHdc(
        hdc,
        ['shell', 'uitest', 'uiInput', 'swipe', String(gesture.x1), String(gesture.y1), String(gesture.x2), String(gesture.y2), String(duration)],
        { timeout: 60000, targetId: target.id },
      )
      output = `${result.stdout}${result.stderr}`.trim()
      if (result.error || result.status !== 0) primitive = 'uitest uiInput swipe(失败)'
    } else {
      primitive = 'devecocli ui swipe'
      try {
        const invocation = resolveDevecoCli()
        const result = runDevecoCli(
          invocation,
          ['ui', 'swipe', String(gesture.x1), String(gesture.y1), String(gesture.x2), String(gesture.y2), '--speed', '1500'],
          { timeout: 90000 },
        )
        output = `${result.stdout}${result.stderr}`.trim()
      } catch (error) {
        output = error instanceof Error ? error.message : String(error)
        primitive = 'devecocli ui swipe(不可用)'
      }
    }

    sleepSync(1500)
    const after = readSize().layout
    attempts.push({ primitive, verdict: after.verdict, output: output.slice(0, 300) })
    log(`解锁尝试 ${attempt}（${primitive}）→ 判读 ${after.verdict}`)
    if (after.verdict !== 'lockscreen' && after.verdict !== 'unknown') {
      return { unlocked: true, attempts }
    }
  }

  throw new HdcTargetError(
    'SCREEN_LOCKED',
    `尝试解锁 ${maxAttempts} 次后仍判读为锁屏/未知（尝试序列：${attempts.map((a) => `${a.primitive}→${a.verdict}`).join('，')}）。\n` +
      '下一步：人工在模拟器窗口上滑解锁后重跑；或先 `node tools/harmony-device.mjs shoot --out <path>` 留证再排查手势坐标。',
  )
}

/** 同步等待（解锁手势后需要等动画落定，但本文件不需要异步 API）。 */
function sleepSync(ms) {
  const buffer = new Int32Array(new SharedArrayBuffer(4))
  Atomics.wait(buffer, 0, 0, ms)
}

/**
 * 取图：`hdc shell snapshot_display -f <remote>.jpeg` + `hdc file recv`（本机固件只认 .jpeg）。
 * 落盘后校验魔数，不是 JPEG/PNG 一律 SCREENSHOT_FAILED（空文件/错文件不能当证据）。
 * @param {{out?: string}} [opts]
 */
export function shoot({ out = '' } = {}) {
  const hdc = resolveHdc()
  const { target } = requireTargetSync(hdc)

  const local = out
    ? path.resolve(process.cwd(), out)
    : path.join(DEFAULT_SHOT_DIR, `shot-${Date.now()}.jpeg`)
  fs.mkdirSync(path.dirname(local), { recursive: true })
  const remote = `${REMOTE_TMP}/harmony_device_shot.jpeg`

  const shot = runHdc(hdc, ['shell', 'snapshot_display', '-f', remote], { timeout: 60000, targetId: target.id })
  const shotOut = `${shot.stdout}${shot.stderr}`.trim()
  const pull = runHdc(hdc, ['file', 'recv', remote, local], { timeout: 60000, targetId: target.id })
  if (pull.error || !fs.existsSync(local)) {
    throw new HdcTargetError(
      'SCREENSHOT_FAILED',
      `截图未落盘（远端 ${remote} → 本地 ${local}）。\n截图输出：${shotOut.slice(0, 400)}\n传输输出：${`${pull.stdout}${pull.stderr}`.trim().slice(0, 400)}`,
    )
  }

  const bytes = fs.readFileSync(local)
  const format = detectImageFormat(bytes.subarray(0, 4))
  if (format === 'unknown') {
    throw new HdcTargetError(
      'SCREENSHOT_FAILED',
      `落盘文件不是 JPEG/PNG（${bytes.length} 字节，魔数 ${bytes.subarray(0, 4).toString('hex')}）。` +
        '本机固件只接受 .jpeg 远端后缀；确认 remote 路径可写。',
    )
  }
  log(`截图 ${local}（${bytes.length} 字节，${format}）`)
  return { path: local, bytes: bytes.length, format }
}

/**
 * 启动应用并判读前台。
 *
 * 判读双向口径：只有 classify === 'app' 才算启动成功。锁屏有两条通道取证——
 * ① `aa start` 输出的 10106102 / screen is locked；② 画面判读 lockscreen。
 * 任一命中 → 自动解锁并重试一次；重试后仍非 app → LAUNCH_FAILED。
 * launcher / unknown → LAUNCH_FAILED（「有截图」「aa start 返回 ok」都不构成证据）。
 * @param {{bundle?: string, ability?: string, unlock?: boolean, waitMs?: number}} [opts]
 */
export async function launchApp({
  bundle = DEFAULT_BUNDLE,
  ability = DEFAULT_ABILITY,
  unlock = true,
  waitMs = 4000,
} = {}) {
  const hdc = resolveHdc()
  const { target } = requireTargetSync(hdc)

  const start = () =>
    runHdc(hdc, ['shell', 'aa', 'start', '-a', ability, '-b', bundle], { timeout: 60000, targetId: target.id })

  const first = start()
  const startOut = `${first.stdout}${first.stderr}`.trim()
  await sleep(waitMs)
  let layout = readLayout(hdc, target.id)
  log(`启动后判读：${layout.verdict}${layout.summary && layout.summary.pagePath ? `（pagePath=${layout.summary.pagePath}）` : ''}`)

  if (layout.verdict === 'app') return { verdict: 'app', pagePath: layout.summary.pagePath, unlocked: false, layout }

  // 锁屏拦截：命令输出与画面判读两条通道任一命中即按锁屏处理。
  // 实测形态：aa start 报 10106102（screen is locked），而 dumpLayout 此时已判 launcher——
  // 只看画面会把「被锁屏拦住」误报成「应用没拉起来」。
  if (detectLockedOutput(startOut) || layout.verdict === 'lockscreen') {
    if (!unlock) {
      throw new HdcTargetError(
        'SCREEN_LOCKED',
        '启动被锁屏拦住且已指定 --no-unlock。人工解锁后重跑，或去掉 --no-unlock（脚本会用 uitest uiInput swipe 上滑解锁并重试一次）。\n' +
          `aa start 输出：${startOut.slice(0, 400)}`,
      )
    }
    log(`启动被锁屏拦住（${detectLockedOutput(startOut) ? 'aa start 报 10106102' : '画面判读 lockscreen'}），先解锁再重试…`)
    unlockScreen()
    const retry = start()
    log(`重试启动：${`${retry.stdout}${retry.stderr}`.trim().slice(0, 200)}`)
    await sleep(waitMs)
    layout = readLayout(hdc, target.id)
    if (layout.verdict === 'app') return { verdict: 'app', pagePath: layout.summary.pagePath, unlocked: true, layout }
    throw new HdcTargetError(
      'LAUNCH_FAILED',
      `解锁后重试启动仍未进入应用前台（判读 ${layout.verdict}）。\n` +
        `aa start 输出：${startOut.slice(0, 400)}\n` +
        '下一步：node tools/harmony-device.mjs shoot --out test_run/harmony-smoke/launch-failed.jpeg 留证后核对 bundle/ability 与 HAP 是否装对。',
    )
  }

  throw new HdcTargetError(
    'LAUNCH_FAILED',
    `启动命令返回但画面判读为 ${layout.verdict}（未进入应用前台）。\n` +
      `aa start 输出：${startOut.slice(0, 400)}\n` +
      (layout.verdict === 'launcher'
        ? '画面停在桌面：应用未拉到前台——核对 bundle/ability（默认 com.earthrhythm.fittracker / EntryAbility）与 HAP 是否已安装。'
        : '判读为 unknown：dumpLayout 未给出可用特征（可能取图/dump 失败），本工具不把"不知道"当通过。'),
  )
}

/** 转发 ohos-test.ps1（ohosTest 用例），与 device-smoke 的 --harmony-test 等价。 */
export function runOhosTest({ extraArgs = [] } = {}) {
  const script = path.join(HARMONY_ROOT, 'tools', 'ohos-test.ps1')
  if (!fs.existsSync(script)) {
    throw new HdcTargetError('HAP_NOT_FOUND', `找不到 ${script}`)
  }
  log('执行 ohos-test.ps1…')
  const result = spawnSync('powershell', ['-ExecutionPolicy', 'Bypass', '-File', script, ...extraArgs], {
    stdio: 'inherit',
    cwd: HARMONY_ROOT,
  })
  if (result.error) throw new HdcTargetError('HAP_NOT_FOUND', `无法执行 ohos-test.ps1：${result.error.message}`)
  if (result.status !== 0) {
    throw new HdcTargetError('INSTALL_FAILED', `ohos-test.ps1 退出码 ${result.status}（详见其输出与 apps/harmony/test_run/ohosTest/）`)
  }
  return { status: 0 }
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

const HELP = `鸿蒙端设备层（与 apps/android/tools/android-device.mjs 同构）

用法：node tools/harmony-device.mjs <子命令> [选项]

子命令：
  check                    目标发现 + 就绪断言（无目标 → 退出码 1 + NO_TARGETS）
  start [--name 名]        起模拟器并等 boot（约 50-70s）；必须与后续动作同一次调用
  install [--hap 路径]     装 HAP（默认 signed 优先，--hap 可显式指定）
  launch [--no-unlock]     启动应用并判读前台（命中锁屏自动解锁重试一次）
  unlock                   只解锁（uitest uiInput swipe，失败重试一次）
  shoot [--out 路径]       截图（snapshot_display + file recv + 魔数校验）
  test [-- <附加参数>]     转发 ohos-test.ps1（ohosTest 用例）
  chain [--name 名]        同一次进程内跑完 start → install → launch → shoot（推荐形态）

选项：--target <id> 指定 hdc 目标；--out <路径> 相对当前目录。
`

function parseArgs(argv) {
  const options = { command: argv[0] || '', flags: {}, rest: [] }
  for (let i = 1; i < argv.length; i += 1) {
    const token = argv[i]
    if (token === '--') {
      options.rest = argv.slice(i + 1)
      break
    }
    if (!token.startsWith('--')) {
      options.rest.push(token)
      continue
    }
    const key = token.slice(2)
    const eq = key.indexOf('=')
    if (eq > 0) {
      options.flags[key.slice(0, eq)] = key.slice(eq + 1)
      continue
    }
    const next = argv[i + 1]
    if (next !== undefined && !next.startsWith('--')) {
      options.flags[key] = next
      i += 1
    } else {
      options.flags[key] = true
    }
  }
  return options
}

function reportTarget(result) {
  log(`目标 ${result.target.id}（${result.target.transport}/${result.target.state}）`)
  log(`hdc：${result.hdcPath}`)
}

async function main() {
  const { command, flags, rest } = parseArgs(process.argv.slice(2))
  if (!command || command === 'help' || flags.help) {
    process.stdout.write(HELP)
    return
  }
  if (typeof flags.target === 'string') process.env.FT_HDC_TARGET = flags.target

  switch (command) {
    case 'check': {
      const result = await ensureTarget({ timeoutSeconds: Number(flags.wait) > 0 ? Number(flags.wait) : 30 })
      reportTarget(result)
      const layout = (() => {
        try {
          return readLayout(result.hdcPath, result.target.id)
        } catch {
          return null
        }
      })()
      if (layout) log(`当前画面判读：${layout.verdict}${layout.summary && layout.summary.pagePath ? `（pagePath=${layout.summary.pagePath}）` : ''}`)
      return
    }
    case 'start': {
      const name = typeof flags.name === 'string' ? flags.name : DEFAULT_EMULATOR
      const result = await startEmulator(name, {
        timeoutSeconds: Number(flags.wait) > 0 ? Number(flags.wait) : 120,
      })
      reportTarget({ hdcPath: result.hdcPath, target: result.target })
      return
    }
    case 'install': {
      const hap = typeof flags.hap === 'string' ? path.resolve(process.cwd(), flags.hap) : ''
      const result = installHap({ hapPath: hap })
      log(`HAP：${result.hap}`)
      return
    }
    case 'launch': {
      const result = await launchApp({ unlock: !flags['no-unlock'] })
      log(`前台判读：${result.verdict}（pagePath=${result.pagePath}${result.unlocked ? '，经解锁重试' : ''}）`)
      return
    }
    case 'unlock': {
      const result = unlockScreen()
      log(`已离开锁屏（尝试 ${result.attempts.length} 次）`)
      return
    }
    case 'shoot': {
      const out = typeof flags.out === 'string' ? flags.out : ''
      const result = shoot({ out })
      log(`产物 ${result.path}`)
      return
    }
    case 'test': {
      runOhosTest({ extraArgs: rest })
      return
    }
    case 'chain': {
      // 同一次进程内串起全部动作：模拟器随进程树回收，跨调用复用一定拿不到设备。
      const name = typeof flags.name === 'string' ? flags.name : DEFAULT_EMULATOR
      const started = await startEmulator(name)
      reportTarget({ hdcPath: started.hdcPath, target: started.target })
      installHap({ hapPath: typeof flags.hap === 'string' ? path.resolve(process.cwd(), flags.hap) : '' })
      const launched = await launchApp({ unlock: !flags['no-unlock'] })
      log(`前台判读：${launched.verdict}（pagePath=${launched.pagePath}）`)
      const shot = shoot({ out: typeof flags.out === 'string' ? flags.out : '' })
      log(`产物 ${shot.path}`)
      return
    }
    default:
      process.stderr.write(`未知子命令：${command}\n\n${HELP}`)
      process.exitCode = 1
  }
}

const isDirectRun =
  process.argv[1] !== undefined && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))

if (isDirectRun) {
  main().catch((error) => {
    if (error instanceof HdcTargetError) {
      process.stderr.write(`❌ ${error.code}: ${error.message}\n`)
      if (error.detail) process.stderr.write(`   详情：${error.detail}\n`)
      process.exit(error.exitCode || 1)
    }
    process.stderr.write(`❌ UNEXPECTED: ${error instanceof Error ? (error.stack || error.message) : String(error)}\n`)
    process.exit(1)
  })
}
