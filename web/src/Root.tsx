/**
 * 顶层路由：#/app 进在线体验，其余走官网。
 *
 * 为什么用 hash 而不是路径路由：
 *  - 站点 base 是 './'（vite.config.ts:12），部署在任意子路径都安全；
 *    路径路由需要服务端 rewrite，Caddy 那边要改配置，超出本次范围。
 *  - 不引路由库：两个视图不值得加依赖（package.json 运行时依赖保持 3 个）。
 * 代价：不存在独立的 /app URL，SEO 上不如独立页面——对「在线体验」入口可接受。
 */

import { useEffect, useState } from 'react'

import App from './App'
import AppShell from './app/AppShell'

export default function Root() {
  const [hash, setHash] = useState(() => (typeof window === 'undefined' ? '' : window.location.hash))

  useEffect(() => {
    const onChange = () => setHash(window.location.hash)
    window.addEventListener('hashchange', onChange)
    return () => window.removeEventListener('hashchange', onChange)
  }, [])

  if (hash.startsWith('#/app')) {
    return <AppShell />
  }

  return <App />
}
