/**
 * 在线体验的独立入口（被官网 Hero 用 iframe 挂载）。
 *
 * 为什么单独成一个入口而不是嵌在官网 bundle 里：
 *   1. 官网首屏不必为 app 的 9 屏 UI 买单，bundle 小一截；
 *   2. app 内部崩了不会把落地页一起带崩；
 *   3. 这个地址能独立全屏打开（/app/），分享给别人也成立。
 *
 * 等价做法参考 opengym.ch 的 /demo/（iframe + 懒加载 + 小屏降级）。
 *
 * 只引 tokens.css（tailwind + 设计令牌），**不引** index.css ——
 * 后者带着官网落地页那 41KB 的 legacy.css，搬进 iframe 纯属浪费。
 * app 自己的样式由 AppShell 内部 import 的 app.css 负责。
 */

import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import AppShell from '../src/app/AppShell'
import '../src/tokens.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AppShell />
  </StrictMode>
)
