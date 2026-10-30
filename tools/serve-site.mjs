#!/usr/bin/env node
// serve-site.mjs —— 官网本地预览服务（零依赖，只用 node: 内置模块）
//
// 为什么需要它：site/ 里的页面用相对路径引用 assets/，直接 file:// 打开时
// 部分浏览器会对 <dialog>、fetch 与 MIME 严格校验，预览效果与线上不一致。
// 这个服务只做一件事：把 site/ 当站点根目录 serve 出来。
//
// 用法：
//   node tools/serve-site.mjs               # http://127.0.0.1:4173
//   node tools/serve-site.mjs --port 8080
//
// 边界：仅监听回环地址，不做目录列表，不处理写请求。

import { createServer } from 'node:http'
import { createReadStream, existsSync, statSync } from 'node:fs'
import { dirname, extname, join, normalize, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const siteRoot = join(repoRoot, 'site')

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8'
}

function parsePort(argv) {
  const index = argv.indexOf('--port')
  if (index === -1) return 4173
  const value = Number(argv[index + 1])
  return Number.isInteger(value) && value > 0 && value < 65536 ? value : 4173
}

/** 把请求路径解析成 siteRoot 之内的绝对路径；越界返回 null。 */
function resolveTarget(urlPath) {
  const clean = decodeURIComponent(urlPath.split('?')[0].split('#')[0])
  const candidate = resolve(siteRoot, '.' + normalize(clean))
  if (candidate !== siteRoot && !candidate.startsWith(siteRoot + sep)) return null
  return candidate
}

/** 文件不存在时按目录/扩展名尝试补全，模拟静态站常见的 clean URL 行为。 */
function findFile(target) {
  if (existsSync(target) && statSync(target).isFile()) return target
  if (existsSync(target) && statSync(target).isDirectory()) {
    const index = join(target, 'index.html')
    if (existsSync(index)) return index
  }
  if (!extname(target)) {
    const html = target + '.html'
    if (existsSync(html)) return html
    const nested = join(target, 'index.html')
    if (existsSync(nested)) return nested
  }
  return null
}

const port = parsePort(process.argv)

if (!existsSync(siteRoot)) {
  console.error(`[serve-site] 站点目录不存在：${siteRoot}`)
  process.exit(1)
}

const server = createServer((req, res) => {
  const target = resolveTarget(req.url || '/')
  if (target === null) {
    res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' })
    res.end('403 Forbidden')
    return
  }

  const file = findFile(target)
  if (file === null) {
    const notFound = join(siteRoot, '404.html')
    res.writeHead(404, { 'Content-Type': MIME['.html'] })
    if (existsSync(notFound)) {
      createReadStream(notFound).pipe(res)
    } else {
      res.end('<!DOCTYPE html><meta charset="utf-8"><title>404</title><p>404 · 页面不存在')
    }
    return
  }

  const type = MIME[extname(file).toLowerCase()] || 'application/octet-stream'
  res.writeHead(200, {
    'Content-Type': type,
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff'
  })
  createReadStream(file).pipe(res)
})

server.listen(port, '127.0.0.1', () => {
  console.log(`[serve-site] http://127.0.0.1:${port}  →  ${siteRoot}`)
})
