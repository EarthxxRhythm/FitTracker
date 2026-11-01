import { defineConfig } from 'vite'
import type { Plugin, ResolvedConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { mkdirSync, writeFileSync } from 'node:fs'
import type { IncomingMessage } from 'node:http'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { collectBoardData } from './tools/board-data.mjs'
import type { BoardOperation } from './tools/board-projects.mjs'
import { applyOperation, loadProjects, saveProjects } from './tools/board-projects.mjs'

// 开发看板独立配置 —— 与官网 vite.config.ts 完全隔离：
//   · 独立配置/入口（board.html）/输出目录（board-dist/）/端口（4175）
//   · 官网 `npm run build` 走 vite.config.ts，产物 dist/ 不含任何看板文件
//
// 绑定 127.0.0.1（不沿用官网的 host: true）：看板暴露内部分支状态、未提交改动与
// 签名材料文件名，属局域网信息暴露风险，只允许本机访问。
const here = dirname(fileURLToPath(import.meta.url))
const DATA_ENDPOINT = '/api/board-data'
const SNAPSHOT_FILE = 'board-data.json'

// 写端点（dev-only）：.rivet/board-projects.json 是本地不入库的项目管理状态。
const PROJECTS_ENDPOINT = '/api/board-projects'
const MAX_BODY_BYTES = 64 * 1024

// 同源白名单：dev server 只绑 127.0.0.1:4175 / localhost:4175。
// CORS 只拦「读响应」，不拦「简单写请求」的发出——副作用在响应被拦之前就已落盘，
// 所以来源校验必须在 handler 内自己做，不能指望浏览器。
const ALLOWED_HOSTS = new Set(['127.0.0.1:4175', 'localhost:4175'])

function isAllowedOrigin(url: string): boolean {
  try {
    return ALLOWED_HOSTS.has(new URL(url).host)
  } catch {
    return false
  }
}

// 浏览器跨源 POST 必带 Origin；非浏览器客户端（curl / 门禁脚本）不带。
// 因此：带 Origin 就必须命中白名单；不带 Origin 时退而校验 Referer；两者皆无视为本机脚本。
function isTrustedWrite(req: IncomingMessage): boolean {
  const site = req.headers['sec-fetch-site']
  if (typeof site === 'string' && site === 'cross-site') return false
  const origin = req.headers.origin
  if (typeof origin === 'string' && origin) return isAllowedOrigin(origin)
  const referer = req.headers.referer
  if (typeof referer === 'string' && referer) return isAllowedOrigin(referer)
  return true
}

function readJsonBody(req: IncomingMessage): Promise<unknown> {
  return new Promise((resolveBody, rejectBody) => {
    const chunks: Buffer[] = []
    let size = 0
    req.on('data', (chunk: Buffer) => {
      size += chunk.length
      if (size > MAX_BODY_BYTES) {
        rejectBody(new Error('request body too large'))
        req.destroy()
        return
      }
      chunks.push(chunk)
    })
    req.on('end', () => {
      const text = Buffer.concat(chunks).toString('utf8').trim()
      try {
        resolveBody(text ? JSON.parse(text) : {})
      } catch {
        rejectBody(new Error('body is not valid JSON'))
      }
    })
    req.on('error', rejectBody)
  })
}

// dev：中间件每请求实时聚合（改了 .rivet/COMMAND.md 刷新即见）
// build：closeBundle 时把同一份数据落成 board-data.json —— 静态产物自带数据源，
//        否则「可选的 board:build」会产出一个没有数据的空壳。
function boardDataPlugin(): Plugin {
  let outDir = 'board-dist'
  return {
    name: 'board-data',
    configResolved(config: ResolvedConfig) {
      outDir = config.build.outDir
    },
    configureServer(server) {
      server.middlewares.use(DATA_ENDPOINT, (_req, res) => {
        res.setHeader('Content-Type', 'application/json; charset=utf-8')
        res.setHeader('Cache-Control', 'no-store')
        try {
          res.end(JSON.stringify(collectBoardData()))
        } catch (err) {
          res.statusCode = 500
          res.end(JSON.stringify({ error: String(err) }))
        }
      })
    },
    closeBundle() {
      const target = resolve(here, outDir)
      mkdirSync(target, { recursive: true })
      writeFileSync(resolve(target, SNAPSHOT_FILE), JSON.stringify(collectBoardData(), null, 2))
    }
  }
}

// 项目管理写端点：只在 dev server 存在——静态产物（board-dist）没有中间件，
// 写入口在那里静默不可用，项目管理因此明确定位为 dev-only 工具。
// 独立成 plugin 而非塞进 boardDataPlugin：board-data 的契约是「只读聚合、容错绝不抛错」，
// 写语义与它相悖，混进同一个 plugin 会让两个职责的边界消失。
function boardProjectsPlugin(): Plugin {
  return {
    name: 'board-projects',
    configureServer(server) {
      server.middlewares.use(PROJECTS_ENDPOINT, (req, res) => {
        res.setHeader('Content-Type', 'application/json; charset=utf-8')
        res.setHeader('Cache-Control', 'no-store')
        // 读路径：GET 只回状态（无副作用）；写路径只走 POST
        if (req.method === 'GET') {
          res.end(JSON.stringify(loadProjects()))
          return
        }
        if (req.method !== 'POST') {
          res.statusCode = 405
          res.end(JSON.stringify({ error: 'GET or POST only' }))
          return
        }
        if (!isTrustedWrite(req)) {
          res.statusCode = 403
          res.end(JSON.stringify({ error: 'cross-origin write rejected' }))
          return
        }
        void (async () => {
          try {
            const op = (await readJsonBody(req)) as BoardOperation
            res.end(JSON.stringify(saveProjects(applyOperation(loadProjects(), op))))
          } catch (err) {
            res.statusCode = 400
            res.end(JSON.stringify({ error: err instanceof Error ? err.message : String(err) }))
          }
        })()
      })
    }
  }
}

export default defineConfig({
  root: here,
  base: './',
  plugins: [react(), boardDataPlugin(), boardProjectsPlugin()],
  // 看板不继承官网 public/（图片、legal 页），产物保持最小
  publicDir: false,
  build: {
    outDir: 'board-dist',
    emptyOutDir: true,
    rollupOptions: {
      input: { board: resolve(here, 'board.html') }
    }
  },
  server: {
    host: '127.0.0.1',
    port: 4175,
    strictPort: true
  },
  preview: {
    host: '127.0.0.1',
    port: 4176,
    strictPort: true
  }
})
