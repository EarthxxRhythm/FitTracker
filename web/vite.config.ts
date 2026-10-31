import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// 官网构建：产物到 dist/，由 Caddy 直接 serve。
// base 用相对路径，站点可部署在任意子路径。
//
// 注意：Vite 8 底层换成 rolldown，不再支持 rollup 的 manualChunks 对象写法
//（实测报 "manualChunks is not a function"）。站点体积小，用默认分包即可，
// 需要手工分包时写 manualChunks(id) 函数形式。
export default defineConfig({
  base: './',
  plugins: [react(), tailwindcss()],
  build: {
    outDir: 'dist',
    assetsDir: 'assets'
  },
  server: {
    port: 4174,
    host: true
  }
})
