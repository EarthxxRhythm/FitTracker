import { defineConfig } from 'vite'
import type { Plugin, ResolvedConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { collectBoardData } from './tools/board-data.mjs'

// 开发看板独立配置 —— 与官网 vite.config.ts 完全隔离：
//   · 独立配置/入口（board.html）/输出目录（board-dist/）/端口（4175）
//   · 官网 `npm run build` 走 vite.config.ts，产物 dist/ 不含任何看板文件
//
// 绑定 127.0.0.1（不沿用官网的 host: true）：看板暴露内部分支状态、未提交改动与
// 签名材料文件名，属局域网信息暴露风险，只允许本机访问。
//
// 看板是纯只读聚合：数据全部来自 git 与 .rivet/ 下的文件，没有任何写端点。
const here = dirname(fileURLToPath(import.meta.url))
const DATA_ENDPOINT = '/api/board-data'
const SNAPSHOT_FILE = 'board-data.json'

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

export default defineConfig({
  root: here,
  base: './',
  plugins: [react(), boardDataPlugin()],
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
