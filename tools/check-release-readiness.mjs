import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { resolve, join, relative, isAbsolute, sep } from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const signingExtensions = new Set(['.p12', '.pfx', '.jks', '.keystore', '.cer', '.csr', '.pem', '.p7b'])
const skipDirs = new Set([
  '.git',
  '.hvigor',
  '.idea',
  '.worktrees',
  'build',
  'node_modules',
  'oh_modules',
  'midscene_run'
])

// DevEco build-profile.json5 的 signingConfigs[].material 中代表「文件路径」的字段。
// 密码类（storePassword / keyPassword）与别名（keyAlias / signAlg）不是路径，不参与存在性检查。
const signingMaterialPathKeys = ['storeFile', 'certpath', 'profile']

function readText(path) {
  return readFileSync(path, 'utf8')
}

function addResult(results, level, id, title, detail) {
  results.push({ level, id, title, detail })
}

function hasReleaseMode(buildProfileText) {
  return /"buildModeSet"\s*:\s*\[[\s\S]*?"name"\s*:\s*"release"/.test(buildProfileText)
}

function hasModuleReleaseBlock(entryBuildProfileText) {
  return /"buildOptionSet"\s*:\s*\[[\s\S]*?"name"\s*:\s*"release"/.test(entryBuildProfileText)
}

/**
 * 把 DevEco 的 .json5 文本降级为可 JSON.parse 的文本：
 * - 去掉 // 与 /* *\/ 注释
 * - 去掉对象/数组尾部的多余逗号
 * 只跟踪双引号字符串，避免把字符串内容里的 `//` 或 `,` 误处理。
 */
function stripJson5(text) {
  let out = ''
  let inString = false
  let escaped = false

  for (let i = 0; i < text.length; i++) {
    const ch = text[i]
    const next = text[i + 1]

    if (inString) {
      out += ch
      if (escaped) {
        escaped = false
      } else if (ch === '\\') {
        escaped = true
      } else if (ch === '"') {
        inString = false
      }
      continue
    }

    if (ch === '"') {
      inString = true
      out += ch
      continue
    }

    if (ch === '/' && next === '/') {
      while (i < text.length && text[i] !== '\n') {
        i++
      }
      out += '\n'
      continue
    }

    if (ch === '/' && next === '*') {
      i += 2
      while (i < text.length && !(text[i] === '*' && text[i + 1] === '/')) {
        i++
      }
      i++
      continue
    }

    out += ch
  }

  return out.replace(/,(\s*[}\]])/g, '$1')
}

function parseJson5(text) {
  return JSON.parse(stripJson5(text))
}

function isInsideRepo(rootDir, absolutePath) {
  const rel = relative(rootDir, absolutePath)
  return rel !== '' && !rel.startsWith('..' + sep) && rel !== '..' && !isAbsolute(rel)
}

function createGitTracker(rootDir) {
  return function isTracked(absolutePath) {
    try {
      execFileSync('git', ['ls-files', '--error-unmatch', '--', absolutePath], {
        cwd: rootDir,
        stdio: 'ignore'
      })
      return true
    } catch (error) {
      return false
    }
  }
}

function findSigningFiles(rootDir) {
  const found = []

  function walk(currentDir) {
    const entries = readdirSync(currentDir, { withFileTypes: true })
    for (const entry of entries) {
      if (entry.name === '.' || entry.name === '..') {
        continue
      }

      const fullPath = join(currentDir, entry.name)
      if (entry.isDirectory()) {
        if (skipDirs.has(entry.name)) {
          continue
        }
        walk(fullPath)
        continue
      }

      if (!entry.isFile()) {
        continue
      }

      const lowerName = entry.name.toLowerCase()
      for (const extension of signingExtensions) {
        if (lowerName.endsWith(extension)) {
          found.push(fullPath)
          break
        }
      }
    }
  }

  walk(rootDir)
  return found
}

/**
 * 评估 release readiness。
 *
 * @param {string} rootDir 仓库根目录（测试可注入 fixture 目录）
 * @param {{ isTracked?: (absolutePath: string) => boolean }} [options]
 * @returns {{ ready: boolean, results: Array<{level: string, id: string, title: string, detail: string}> }}
 */
export function evaluateReleaseReadiness(rootDir, options) {
  const opts = options || {}
  const isTracked = opts.isTracked || createGitTracker(rootDir)
  const results = []
  let ready = true

  const buildProfilePath = resolve(rootDir, 'build-profile.json5')
  const entryBuildProfilePath = resolve(rootDir, 'entry/build-profile.json5')
  const appScopePath = resolve(rootDir, 'AppScope/app.json5')
  const devecoEnvPath = resolve(rootDir, 'tools/deveco-env.ps1')
  const javaShimPath = resolve(rootDir, 'tools/java.cmd')
  const nodeJavaShimPath = resolve(rootDir, 'tools/node-java-shim.cjs')
  const defaultHapPath = resolve(rootDir, 'entry/build/default/outputs/default/entry-default-unsigned.hap')
  const ohosTestHapPath = resolve(rootDir, 'entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap')

  const buildProfileText = readText(buildProfilePath)
  const entryBuildProfileText = readText(entryBuildProfilePath)
  const appScope = parseJson5(readText(appScopePath))
  const bundleName = appScope.app.bundleName
  const vendor = appScope.app.vendor

  if (hasReleaseMode(buildProfileText)) {
    addResult(results, 'PASS', 'release-mode', '根配置已声明 release build mode', 'build-profile.json5 中存在 release buildModeSet。')
  } else {
    addResult(results, 'FAIL', 'release-mode', '根配置缺少 release build mode', 'release 构建模式未声明，无法继续推进正式发布。')
    ready = false
  }

  if (hasModuleReleaseBlock(entryBuildProfileText)) {
    addResult(results, 'PASS', 'module-release-block', '模块配置已声明 release 构建块', 'entry/build-profile.json5 中已有 release buildOptionSet。')
  } else {
    addResult(results, 'FAIL', 'module-release-block', '模块配置缺少 release 构建块', '模块级 release 构建选项缺失。')
    ready = false
  }

  // ---- 签名材料判据（本脚本的核心） ----
  // 旧判据是「仓库内存在签名材料文件」，与「签名材料不入库」互斥 —— 两者同时成立时永远 FAIL。
  // 新判据：只看 signingConfigs 引用的材料路径是否真实存在（resolve + existsSync，仓库内外皆可）；
  // 材料落在仓库内且被 git 追踪时判 FAIL（防止证书入库）。
  const buildProfile = parseJson5(buildProfileText)
  const appConfig = buildProfile.app || {}
  const signingConfigs = Array.isArray(appConfig.signingConfigs) ? appConfig.signingConfigs : []
  const products = Array.isArray(appConfig.products) ? appConfig.products : []

  if (signingConfigs.length === 0) {
    addResult(
      results,
      'FAIL',
      'signing-materials',
      'signingConfigs 为空，release 无可用签名配置',
      'build-profile.json5 的 app.signingConfigs 为空数组；需先执行 `devecocli auth login` 后 `devecocli signature generate --product default` 生成材料并写入配置。'
    )
    ready = false
  } else {
    const missingMaterials = []
    const trackedInRepo = []
    let checkedPaths = 0

    for (const config of signingConfigs) {
      const material = config.material || {}
      for (const key of signingMaterialPathKeys) {
        const value = material[key]
        if (typeof value !== 'string' || value.trim() === '') {
          continue
        }

        const absolutePath = isAbsolute(value) ? value : resolve(rootDir, value)
        checkedPaths++
        if (!existsSync(absolutePath)) {
          missingMaterials.push(`${config.name}.${key} → ${absolutePath}`)
          continue
        }

        if (isInsideRepo(rootDir, absolutePath) && isTracked(absolutePath)) {
          trackedInRepo.push(`${config.name}.${key} → ${relative(rootDir, absolutePath)}`)
        }
      }
    }

    if (checkedPaths === 0) {
      addResult(
        results,
        'FAIL',
        'signing-materials',
        'signingConfigs 未引用任何可校验的材料路径',
        `已定义 ${signingConfigs.length} 个 signingConfig，但没有任何 ${signingMaterialPathKeys.join(' / ')} 路径——空壳配置不得视为就绪。`
      )
      ready = false
    } else if (missingMaterials.length > 0) {
      addResult(
        results,
        'FAIL',
        'signing-materials',
        'signingConfigs 引用的签名材料路径不存在',
        missingMaterials.join('；')
      )
      ready = false
    } else if (trackedInRepo.length > 0) {
      addResult(
        results,
        'FAIL',
        'signing-materials',
        '签名材料被纳入仓库版本控制',
        `签名材料不得入库，请把下列路径移出 git 追踪（或改放仓库外/加入 .gitignore）：${trackedInRepo.join('；')}`
      )
      ready = false
    } else {
      addResult(
        results,
        'PASS',
        'signing-materials',
        'signingConfigs 引用的签名材料均真实存在且未入库',
        signingConfigs.map(function (config) { return config.name }).join(', ')
      )
    }
  }

  const productRefs = products
    .filter(function (product) { return typeof product.signingConfig === 'string' && product.signingConfig !== '' })
    .map(function (product) { return { product: product.name, ref: product.signingConfig } })

  if (productRefs.length === 0) {
    addResult(results, 'FAIL', 'product-signing-ref', 'product 未绑定 signingConfig 引用', '至少需要一个 product 指向 signingConfigs 中的定义。')
    ready = false
  } else {
    const danglingRefs = productRefs.filter(function (entry) {
      return !signingConfigs.some(function (config) { return config.name === entry.ref })
    })
    if (danglingRefs.length > 0) {
      addResult(
        results,
        'FAIL',
        'product-signing-ref',
        'product 的 signingConfig 引用无法解析',
        danglingRefs
          .map(function (entry) { return `${entry.product} → ${entry.ref}` })
          .join('；') + '（signingConfigs 中无同名定义）'
      )
      ready = false
    } else {
      addResult(
        results,
        'PASS',
        'product-signing-ref',
        'product 的 signingConfig 引用可解析',
        productRefs
          .map(function (entry) { return `${entry.product} → ${entry.ref}` })
          .join('；')
      )
    }
  }

  if (bundleName.startsWith('com.example.') || vendor === 'example') {
    addResult(
      results,
      'FAIL',
      'app-identity',
      '应用身份仍是样板值',
      `当前 bundleName=${bundleName}，vendor=${vendor}；正式发布前需替换为真实应用身份。`
    )
    ready = false
  } else {
    addResult(results, 'PASS', 'app-identity', '应用身份不是样板值', `当前 bundleName=${bundleName}，vendor=${vendor}。`)
  }

  if (existsSync(devecoEnvPath) && existsSync(javaShimPath) && existsSync(nodeJavaShimPath)) {
    addResult(results, 'PASS', 'deveco-env', 'DevEco 环境脚本与 Java shim 齐备', '可继续沿用现有 PackageHap 环境修复链路。')
  } else {
    addResult(results, 'FAIL', 'deveco-env', 'DevEco 环境脚本或 Java shim 缺失', '需先恢复 tools/deveco-env.ps1、tools/java.cmd、tools/node-java-shim.cjs。')
    ready = false
  }

  if (existsSync(defaultHapPath) && existsSync(ohosTestHapPath)) {
    addResult(results, 'PASS', 'unsigned-hap', '已有最近一次 unsigned HAP 产物', 'default 与 ohosTest unsigned HAP 路径都存在。')
  } else {
    addResult(results, 'WARN', 'unsigned-hap', '未发现完整 unsigned HAP 产物', '建议先复跑当前 unsigned 构建，再推进 release signing。')
  }

  // 额外的入库安全检查：仓库内出现的签名材料文件，只要被 git 追踪就是风险。
  const trackedSigningFiles = findSigningFiles(rootDir).filter(function (filePath) {
    return isTracked(filePath)
  })
  if (trackedSigningFiles.length > 0) {
    addResult(
      results,
      'FAIL',
      'signing-material-in-repo',
      '仓库内发现被追踪的签名材料文件',
      trackedSigningFiles
        .map(function (filePath) { return relative(rootDir, filePath) })
        .join('；')
    )
    ready = false
  } else {
    addResult(results, 'PASS', 'signing-material-in-repo', '仓库内没有被追踪的签名材料文件', '签名材料未入库。')
  }

  return { ready, results }
}

function runCli() {
  const rootDir = process.env.FITTRACKER_RELEASE_ROOT
    ? resolve(process.env.FITTRACKER_RELEASE_ROOT)
    : process.cwd()

  const report = evaluateReleaseReadiness(rootDir)

  console.log('FitTracker release readiness')
  console.log('')
  for (const result of report.results) {
    console.log(`[${result.level}] ${result.title}`)
    console.log(`  ${result.detail}`)
  }
  console.log('')

  if (report.ready) {
    console.log('结论：release signing 前置条件已就绪，可以开始产出已签名 release HAP。')
    process.exit(0)
  }

  console.log('结论：release signing 前置条件未就绪，当前仍应维持 unsigned HAP 交付口径。')
  process.exit(1)
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]) : ''
const modulePath = fileURLToPath(import.meta.url)
if (invokedPath.toLowerCase() === modulePath.toLowerCase()) {
  runCli()
}
