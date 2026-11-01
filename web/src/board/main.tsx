// 看板入口：只挂 board.css —— 绝不 import index.css / legacy.css。
// legacy.css 有全局 `section { padding-block: var(--section-y) }`（HANDOFF 踩坑 #8：
// 实测 115.2px 漏进同页任何 <section>），官网样式一旦进来，看板就废了。
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import BoardApp from './BoardApp'
import './board.css'

const container = document.getElementById('board-root')
if (!container) {
  throw new Error('#board-root 缺失：board.html 与 main.tsx 不同源')
}

createRoot(container).render(
  <StrictMode>
    <BoardApp />
  </StrictMode>
)
