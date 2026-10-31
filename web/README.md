# web —— 官网（React + Vite）

React 19 + Vite 8 + Tailwind 4 + framer-motion 构建的官网，最终产物由 Caddy 直接 serve。

## 目录

```text
web/
├── index.html            官网入口（Vite HTML entry 1）
├── app/                  在线体验入口（Vite HTML entry 2 → dist/app/）
├── vite.config.ts        构建配置（base: './'，产物到 dist/）
├── src/
│   ├── main.tsx          React 挂载
│   ├── App.tsx           页面主体（导航 / Hero / 各区块 / 页脚）
│   ├── index.css         Tailwind 入口 + @theme 设计令牌（转录自 DesignTokens）
│   ├── legacy.css        ★ 从 site/assets/site.css 复制而来，保留原有 class
│   ├── tokens.css      ★ Tailwind + @theme 设计令牌（官网与 app 共用）
│   └── components/
│       ├── Aurora.tsx    裸 WebGL FBM 极光（无 WebGL / reduced-motion 降级）
│       ├── DemoSlot.tsx   Hero 里的在线体验挂载点（懒加载 iframe + 兜底）
│       ├── demo-slot.css  iframe 容器 / 骨架 / 兜底样式
│       └── PointerFx.tsx 光标光环 + 全站聚光
├── public/               原样复制到 dist/（截图、法务页、独立 CSS）
│   ├── *.jpg             7 张实机截图
│   ├── legal/            隐私政策 / 用户协议（由 tools/build-site.mjs 生成）
│   └── assets/site.css   法务页专用样式
└── dist/                 构建产物（.gitignore 忽略）
```

## 在线体验（/app/ 独立入口）

Hero 右侧那个手机壳里跑的不是截图，也不是嵌在落地页 bundle 里的组件，而是
**独立构建的一份产物**：`app/index.html` → `dist/app/`，用 iframe 挂上去。

```text
官网 /               → dist/index.html   （只加载 main-*.js，不含 app 代码）
     └─ iframe ./app/ → dist/app/index.html（加载 app-*.js）
```

为什么这么拆（做法参照 opengym.ch 的 #demo）：

1. **落地页不必为九屏 UI 买单**——官网首屏 gzip 从 159 kB 降到约 123 kB；
2. **隔离**——app 内部崩了不会把落地页一起带崩；
3. **可独立分享**——`/app/` 全屏直接打开，不需要官网外壳。

细节：

- `src/components/DemoSlot.tsx`：IntersectionObserver 提前 600px 观察，进入视口才挂 iframe；
  容器不可见（`offsetParent` 为 null）时跳过，`resize` 后补挂；12s 未加载完给兜底出口。
- app 入口只引 `tokens.css`（tailwind + 令牌），**不引** `index.css`——后者带着落地页的
  41KB `legacy.css`，搬进 iframe 纯属浪费。
- 两边共享 React vendor chunk（`jsx-runtime-*.js`），但 app 的九屏代码只在 app 入口出现。
- iframe 内是独立文档：官网的 CSS 与 React 状态都不共享。要跨文档通信得走 `postMessage`。

## 样式策略（重要）

**没有把 1180 行 CSS 翻译成 Tailwind class**。`legacy.css` 保留了原 `site/assets/site.css` 的全部 class，
React 组件原样复用（`className="hero-grid"`、`className="card wide"` 等），因此视觉与静态版一致。

- 新增/改造的部分用 Tailwind（`@theme` 里定义了 `--color-brand` 等令牌）
- 动效：区块入场用 framer-motion `whileInView`，滚动进度用 `useScroll` + `useSpring`
- 微交互（按钮按下、卡片 hover）仍在 legacy.css 里用 CSS transition

这样既拿到了 React 的状态管理能力，又不承担大规模 CSS 翻译的回归风险。
后续要逐个组件 Tailwind 化，可以按组件推进，不影响构建。

## 命令

```bash
npm install          # 首次
npm run dev          # 开发服务器 :4174（predev 会自动生成法务页）
npm run build        # 生产构建到 dist/（prebuild 会自动生成法务页）
npm run preview      # 预览 dist/ :4175
npm run legal        # 只生成法务页（从 docs/legal/*.md 渲染）
npm run typecheck    # tsc --noEmit
```

法务页的单一事实源仍是 `docs/legal/*.md`，由 `tools/build-site.mjs` 渲染，
`--legal-out` 指定输出目录（相对**执行时的 cwd**）。

## 部署

产物在 `web/dist/`，同步到服务器的 `/opt/fittracker/web/`（`ubuntu@106.55.37.80`）。

**日常发版只需两步，不碰 Caddy 配置、不重启容器**——Caddy 每次请求读磁盘：

```bash
# 1) 本地构建（prebuild 会重新渲染法务页）
cd web && npm run build

# 2) 同步（Windows 无 rsync 时用 tar over ssh；Git Bash 自带 GNU tar）
tar -czf - -C web/dist . | ssh ubuntu@106.55.37.80 \
  'mkdir -p /opt/fittracker/web && tar -xzf - -C /opt/fittracker/web && chmod -R a+rX /opt/fittracker/web'

# 3) 验证
curl -s https://earthrhythm.cloud/ | grep -o 'assets/index-[A-Za-z0-9_-]*\.js'
```

需要 `rsync --delete` 清理旧 hash 产物时，先 `ssh ... ls -la /opt/fittracker/web` 确认再删。

**只有 Caddy 配置变更才重启**（`root` 指向、安全头、缓存头）：

```bash
ssh ubuntu@106.55.37.80 'cp /opt/fittracker/caddy/Caddyfile /opt/fittracker/caddy/Caddyfile.bak-$(date +%Y%m%d%H%M%S)'
# 改完先校验，再 restart——Caddy 是 fail-closed，配置错会连 api 一起起不来
ssh ubuntu@106.55.37.80 "sg docker -c 'docker run --rm \
  -v /opt/fittracker/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
  caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile'"
ssh ubuntu@106.55.37.80 "sg docker -c 'docker restart fittracker-caddy'"
# 双域名探活：官网 + api 都要看
curl -sI https://earthrhythm.cloud/ | head -1
curl -sS -o /dev/null -w '%{http_code}\n' https://api.earthrhythm.cloud/auth/v1/health
```

### 两个必须知道的运维事实

1. **`--network host` 只共享网络，不共享文件系统。** 容器启动时必须带
   `-v /opt/fittracker/web:/opt/fittracker/web:ro`，否则容器内没有这个路径，
   `root` 指向虚空，官网全站 404——而 Caddy 不会报"目录不存在"，只会回 404，
   极易误判成权限或 `try_files` 问题。
2. **官网与 api 共用同一个 Caddy 容器**（`api.earthrhythm.cloud` 与
   `earthrhythm.cloud` 两个站点块）。Caddy 挂了是两个一起挂，所以上面的
   `caddy validate` 前置校验不能省。

Caddyfile 里的站点块 `root * /opt/fittracker/web`（`server/deploy/Caddyfile`）。

**公开前的合规前置**：确认根域 `earthrhythm.cloud` 的 **ICP 网站备案**状态。
`docs/release/beian-materials.md` 记的是 **APP 备案**流程，两者不是一回事。

## 与 site/ 的关系

`site/` 是迁移前的纯静态版，**保留作为兜底**：它的 `index.html` + `site.css` + `site.js` 仍是完整可跑的站点。
`web/` 验证稳定后，可以删除 `site/`，届时需要同步清理：

- `tools/serve-site.mjs`（静态预览服务）
- `tools/check-site.mjs` + `tests`（静态站门禁，检查的是 `site/*.html`）
- `server/deploy/Caddyfile` 里已指向 `web/`，无需再改
