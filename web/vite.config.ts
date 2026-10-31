import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

const entry = (path: string) => fileURLToPath(new URL(path, import.meta.url))

// 官网构建：产物到 dist/，由 Caddy 直接 serve。
// base 用相对路径，站点可部署在任意子路径。
//
// 两个入口：
//   index.html     官网落地页（首屏不再打包 app 的九屏 UI）
//   app/index.html 在线体验，独立产物 → dist/app/，由 Hero 用 iframe 挂载
// 两者共享 vendor（React），但 app 的代码不会被落地页入口引用。
//
// 注意：Vite 8 底层换成 rolldown，不再支持 rollup 的 manualChunks 对象写法
//（实测报 "manualChunks is not a function"）。站点体积小，用默认分包即可，
// 需要手工分包时写 manualChunks(id) 函数形式。
export default defineConfig({
  base: './',
  plugins: [react(), tailwindcss()],
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    rollupOptions: {
      input: {
        main: entry('./index.html'),
        app: entry('./app/index.html')
      }
    }
  },
  server: {
    port: 4174,
    host: true
  }
})
