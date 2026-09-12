// check-release-readiness.mjs 判据回归测试。
//
// 背景（RED 用例的来源）：旧判据是「仓库内存在签名材料文件才可能通过」，
// 这与「签名材料不入库」这一安全要求互斥——两条同时成立时门禁永远 FAIL（死锁）。
// 修正后的判据改为「signingConfigs 引用的材料路径真实存在」（仓库内外皆可），
// 并额外把「材料在仓库内且被 git 追踪」判为 FAIL。
//
// 运行：node --test tools/check-release-readiness.test.mjs

import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

import { evaluateReleaseReadiness } from './check-release-readiness.mjs'

function jsonString(value) {
  return JSON.stringify(value)
}

function buildProfileText(signingConfigs, productSigningConfig) {
  const configsText =
    signingConfigs.length === 0
      ? '[]'
      : '[\n' +
        signingConfigs
          .map(function (config) {
            return (
              '    {\n' +
              '      "name": ' + jsonString(config.name) + ',\n' +
              '      "type": "HarmonyOS",\n' +
              '      "material": {\n' +
              '        "storeFile": ' + jsonString(config.material.storeFile) + ',\n' +
              '        "certpath": ' + jsonString(config.material.certpath) + ',\n' +
              '        "profile": ' + jsonString(config.material.profile) + ',\n' +
              '        "storePassword": "encrypted:store-secret",\n' +
              '        "keyAlias": "fittracker",\n' +
              '        "keyPassword": "encrypted:key-secret",\n' +
              '        "signAlg": "SHA256withECDSA"\n' +
              '      }\n' +
              '    },'
            )
          })
          .join('\n') +
        '\n  ]'

  return (
    '{\n' +
    '  "app": {\n' +
    '    "signingConfigs": ' + configsText + ',\n' +
    '    "products": [\n' +
    '      {\n' +
    '        "name": "default",\n' +
    '        "signingConfig": ' + jsonString(productSigningConfig) + ',\n' +
    '      },\n' +
    '    ],\n' +
    '    "buildModeSet": [\n' +
    '      {\n' +
    '        "name": "debug",\n' +
    '      },\n' +
    '      {\n' +
    '        "name": "release"\n' +
    '      }\n' +
    '    ],\n' +
    '  },\n' +
    '  "modules": [],\n' +
    '}\n'
  )
}

function makeRoot() {
  const root = mkdtempSync(join(tmpdir(), 'fittracker-readiness-'))

  const entryDir = join(root, 'entry')
  mkdirSync(entryDir, { recursive: true })
  writeFileSync(
    join(entryDir, 'build-profile.json5'),
    '{\n' +
      '  "apiType": "stageMode",\n' +
      '  "buildOptionSet": [\n' +
      '    {\n' +
      '      "name": "release",\n' +
      '      "arkOptions": {\n' +
      '        "obfuscation": {\n' +
      '          "ruleOptions": {\n' +
      '            "enable": true,\n' +
      '            "files": ["./obfuscation-rules.txt"]\n' +
      '          }\n' +
      '        }\n' +
      '      }\n' +
      '    },\n' +
      '  ],\n' +
      '  "targets": [\n' +
      '    {\n' +
      '      "name": "default"\n' +
      '    }\n' +
      '  ]\n' +
      '}\n',
    'utf8'
  )

  const appScopeDir = join(root, 'AppScope')
  mkdirSync(appScopeDir, { recursive: true })
  writeFileSync(
    join(appScopeDir, 'app.json5'),
    '{\n' +
      '  "app": {\n' +
      '    "bundleName": "com.earthrhythm.fittracker",\n' +
      '    "vendor": "EarthRhythm",\n' +
      '    "versionCode": 1000000,\n' +
      '    "versionName": "1.0.0"\n' +
      '  }\n' +
      '}\n',
    'utf8'
  )

  const toolsDir = join(root, 'tools')
  mkdirSync(toolsDir, { recursive: true })
  writeFileSync(join(toolsDir, 'deveco-env.ps1'), '', 'utf8')
  writeFileSync(join(toolsDir, 'java.cmd'), '', 'utf8')
  writeFileSync(join(toolsDir, 'node-java-shim.cjs'), '', 'utf8')

  return root
}

function writeRootProfile(root, signingConfigs, productSigningConfig) {
  writeFileSync(
    join(root, 'build-profile.json5'),
    buildProfileText(signingConfigs, productSigningConfig),
    'utf8'
  )
}

function findResult(report, id) {
  return report.results.find(function (item) {
    return item.id === id
  })
}

function cleanup(root) {
  rmSync(root, { recursive: true, force: true })
}

test('signingConfigs 为空时判 FAIL（真实缺料，不是判据死锁）', function () {
  const root = makeRoot()
  try {
    writeRootProfile(root, [], 'default')
    const report = evaluateReleaseReadiness(root, { isTracked: function () { return false } })
    const result = findResult(report, 'signing-materials')
    assert.ok(result, '应产出 signing-materials 结果项')
    assert.equal(result.level, 'FAIL')
    assert.equal(report.ready, false)
  } finally {
    cleanup(root)
  }
})

test('signingConfigs 引用的材料路径缺失时判 FAIL', function () {
  const root = makeRoot()
  try {
    writeRootProfile(
      root,
      [
        {
          name: 'default',
          material: {
            storeFile: join(root, 'signature', 'missing.p12'),
            certpath: join(root, 'signature', 'missing.cer'),
            profile: join(root, 'signature', 'missing.p7b')
          }
        }
      ],
      'default'
    )
    const report = evaluateReleaseReadiness(root, { isTracked: function () { return false } })
    const result = findResult(report, 'signing-materials')
    assert.equal(result.level, 'FAIL')
    assert.match(result.detail, /missing/)
    assert.equal(report.ready, false)
  } finally {
    cleanup(root)
  }
})

test('材料真实存在且位于仓库外时判 PASS（旧判据在此死锁）', function () {
  const root = makeRoot()
  const materialDir = mkdtempSync(join(tmpdir(), 'fittracker-material-'))
  try {
    const storeFile = join(materialDir, 'release.p12')
    const certpath = join(materialDir, 'release.cer')
    const profile = join(materialDir, 'release.p7b')
    writeFileSync(storeFile, 'material', 'utf8')
    writeFileSync(certpath, 'material', 'utf8')
    writeFileSync(profile, 'material', 'utf8')

    writeRootProfile(
      root,
      [
        {
          name: 'default',
          material: { storeFile: storeFile, certpath: certpath, profile: profile }
        }
      ],
      'default'
    )

    const report = evaluateReleaseReadiness(root, { isTracked: function () { return false } })
    const result = findResult(report, 'signing-materials')
    assert.equal(result.level, 'PASS')
    assert.equal(report.ready, true)
  } finally {
    cleanup(materialDir)
    cleanup(root)
  }
})

test('材料在仓库内且被 git 追踪时判 FAIL', function () {
  const root = makeRoot()
  try {
    const signatureDir = join(root, 'signature')
    mkdirSync(signatureDir, { recursive: true })
    const storeFile = join(signatureDir, 'release.p12')
    const certpath = join(signatureDir, 'release.cer')
    const profile = join(signatureDir, 'release.p7b')
    writeFileSync(storeFile, 'material', 'utf8')
    writeFileSync(certpath, 'material', 'utf8')
    writeFileSync(profile, 'material', 'utf8')

    writeRootProfile(
      root,
      [
        {
          name: 'default',
          material: { storeFile: storeFile, certpath: certpath, profile: profile }
        }
      ],
      'default'
    )

    const report = evaluateReleaseReadiness(root, { isTracked: function () { return true } })
    const result = findResult(report, 'signing-materials')
    assert.equal(result.level, 'FAIL')
    assert.equal(report.ready, false)
  } finally {
    cleanup(root)
  }
})

test('product 的 signingConfig 引用解析不到定义时判 FAIL', function () {
  const root = makeRoot()
  const materialDir = mkdtempSync(join(tmpdir(), 'fittracker-material-'))
  try {
    const storeFile = join(materialDir, 'release.p12')
    const certpath = join(materialDir, 'release.cer')
    const profile = join(materialDir, 'release.p7b')
    writeFileSync(storeFile, 'material', 'utf8')
    writeFileSync(certpath, 'material', 'utf8')
    writeFileSync(profile, 'material', 'utf8')

    writeRootProfile(
      root,
      [
        {
          name: 'release-key',
          material: { storeFile: storeFile, certpath: certpath, profile: profile }
        }
      ],
      'default'
    )

    const report = evaluateReleaseReadiness(root, { isTracked: function () { return false } })
    const result = findResult(report, 'product-signing-ref')
    assert.ok(result, '应产出 product-signing-ref 结果项')
    assert.equal(result.level, 'FAIL')
    assert.equal(report.ready, false)
  } finally {
    cleanup(materialDir)
    cleanup(root)
  }
})


test('signingConfigs 非空但未引用任何材料路径时判 FAIL（空壳配置不得变绿）', function () {
  const root = makeRoot()
  try {
    writeRootProfile(
      root,
      [
        {
          name: 'default',
          material: { storeFile: '', certpath: '', profile: '' }
        }
      ],
      'default'
    )
    const report = evaluateReleaseReadiness(root, { isTracked: function () { return false } })
    const result = findResult(report, 'signing-materials')
    assert.ok(result, '应产出 signing-materials 结果项')
    assert.equal(result.level, 'FAIL')
    assert.match(result.detail, /没有任何/)
    assert.equal(report.ready, false)
  } finally {
    cleanup(root)
  }
})
