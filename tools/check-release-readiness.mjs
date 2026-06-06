import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { resolve, join, relative } from 'node:path'

const repoRoot = process.cwd()
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

function readText(path) {
  return readFileSync(path, 'utf8')
}

function addResult(results, level, title, detail) {
  results.push({ level, title, detail })
}

function hasReleaseMode(buildProfileText) {
  return /"buildModeSet"\s*:\s*\[[\s\S]*?"name"\s*:\s*"release"/.test(buildProfileText)
}

function hasEmptySigningConfigs(buildProfileText) {
  return /"signingConfigs"\s*:\s*\[\s*\]/.test(buildProfileText)
}

function hasSigningConfigReference(buildProfileText) {
  return /"signingConfig"\s*:\s*"[^"]+"/.test(buildProfileText)
}

function hasModuleReleaseBlock(entryBuildProfileText) {
  return /"buildOptionSet"\s*:\s*\[[\s\S]*?"name"\s*:\s*"release"/.test(entryBuildProfileText)
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
          found.push(relative(rootDir, fullPath))
          break
        }
      }
    }
  }

  walk(rootDir)
  return found
}

function main() {
  const results = []
  let ready = true

  const buildProfilePath = resolve(repoRoot, 'build-profile.json5')
  const entryBuildProfilePath = resolve(repoRoot, 'entry/build-profile.json5')
  const appScopePath = resolve(repoRoot, 'AppScope/app.json5')
  const devecoEnvPath = resolve(repoRoot, 'tools/deveco-env.ps1')
  const javaShimPath = resolve(repoRoot, 'tools/java.cmd')
  const nodeJavaShimPath = resolve(repoRoot, 'tools/node-java-shim.cjs')
  const defaultHapPath = resolve(repoRoot, 'entry/build/default/outputs/default/entry-default-unsigned.hap')
  const ohosTestHapPath = resolve(repoRoot, 'entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap')

  const buildProfileText = readText(buildProfilePath)
  const entryBuildProfileText = readText(entryBuildProfilePath)
  const appScope = JSON.parse(readText(appScopePath))
  const bundleName = appScope.app.bundleName
  const vendor = appScope.app.vendor

  if (hasReleaseMode(buildProfileText)) {
    addResult(results, 'PASS', '根配置已声明 release build mode', 'build-profile.json5 中存在 release buildModeSet。')
  } else {
    addResult(results, 'FAIL', '根配置缺少 release build mode', 'release 构建模式未声明，无法继续推进正式发布。')
    ready = false
  }

  if (hasModuleReleaseBlock(entryBuildProfileText)) {
    addResult(results, 'PASS', '模块配置已声明 release 构建块', 'entry/build-profile.json5 中已有 release buildOptionSet。')
  } else {
    addResult(results, 'FAIL', '模块配置缺少 release 构建块', '模块级 release 构建选项缺失。')
    ready = false
  }

  if (hasSigningConfigReference(buildProfileText)) {
    addResult(results, 'PASS', 'product 已预留 signingConfig 引用', '当前 product 已绑定 signingConfig 名称，后续可直接接入真实配置。')
  } else {
    addResult(results, 'WARN', 'product 尚未绑定 signingConfig 引用', '后续接签名时需先为 product 指定 signingConfig。')
    ready = false
  }

  if (hasEmptySigningConfigs(buildProfileText)) {
    addResult(results, 'FAIL', 'signingConfigs 仍为空', '当前 release 仍未配置真实 signing material。')
    ready = false
  } else {
    addResult(results, 'PASS', 'signingConfigs 非空', '仓库中已存在 signingConfigs 定义，请继续人工核对敏感信息来源。')
  }

  if (bundleName.startsWith('com.example.') || vendor === 'example') {
    addResult(
      results,
      'FAIL',
      '应用身份仍是样板值',
      `当前 bundleName=${bundleName}，vendor=${vendor}；正式发布前需替换为真实应用身份。`
    )
    ready = false
  } else {
    addResult(results, 'PASS', '应用身份不是样板值', `当前 bundleName=${bundleName}，vendor=${vendor}。`)
  }

  if (existsSync(devecoEnvPath) && existsSync(javaShimPath) && existsSync(nodeJavaShimPath)) {
    addResult(results, 'PASS', 'DevEco 环境脚本与 Java shim 齐备', '可继续沿用现有 PackageHap 环境修复链路。')
  } else {
    addResult(results, 'FAIL', 'DevEco 环境脚本或 Java shim 缺失', '需先恢复 tools/deveco-env.ps1、tools/java.cmd、tools/node-java-shim.cjs。')
    ready = false
  }

  if (existsSync(defaultHapPath) && existsSync(ohosTestHapPath)) {
    addResult(results, 'PASS', '已有最近一次 unsigned HAP 产物', 'default 与 ohosTest unsigned HAP 路径都存在。')
  } else {
    addResult(results, 'WARN', '未发现完整 unsigned HAP 产物', '建议先复跑当前 unsigned 构建，再推进 release signing。')
  }

  const signingFiles = findSigningFiles(repoRoot)
  if (signingFiles.length === 0) {
    addResult(results, 'FAIL', '仓库内未发现签名材料文件', '这是预期的安全现状，但也意味着 release signing 尚未具备落地材料。')
    ready = false
  } else {
    addResult(results, 'WARN', '仓库内发现疑似签名材料文件', signingFiles.join(', '))
  }

  console.log('FitTracker release readiness')
  console.log('')
  for (const result of results) {
    console.log(`[${result.level}] ${result.title}`)
    console.log(`  ${result.detail}`)
  }
  console.log('')

  if (ready) {
    console.log('结论：release signing 前置条件已基本就绪，可以开始接正式签名配置。')
    process.exit(0)
  }

  console.log('结论：release signing 前置条件未就绪，当前仍应维持 unsigned HAP 交付口径。')
  process.exit(1)
}

main()
