# web —— 官网（React + Vite）

React 19 + Vite 8 + Tailwind 4 + framer-motion 构建的官网，最终产物由 Caddy 直接 serve。

## 目录

```text
web/
├── index.html            入口（Vite 的 HTML 入口）
├── vite.config.ts        构建配置（base: './'，产物到 dist/）
├── src/
│   ├── main.tsx          React 挂载
│   ├── App.tsx           页面主体（导航 / Hero / 各区块 / 页脚）
│   ├── index.css         Tailwind 入口 + @theme 设计令牌（转录自 DesignTokens）
│   ├── legacy.css        ★ 从 site/assets/site.css 复制而来，保留原有 class
│   ├── app-demo.css      App 原型样式（540 逻辑基准 + transform 缩放）
│   └── components/
│       ├── Aurora.tsx    裸 WebGL FBM 极光（无 WebGL / reduced-motion 降级）
│       ├── AppDemo.tsx   可交互 App 原型：五屏 + 底部 Tab，全 React state
│       └── PointerFx.tsx 光标光环 + 全站聚光
├── public/               原样复制到 dist/（截图、法务页、独立 CSS）
│   ├── *.jpg             7 张实机截图
│   ├── legal/            隐私政策 / 用户协议（由 tools/build-site.mjs 生成）
│   └── assets/site.css   法务页专用样式
└── dist/                 构建产物（.gitignore 忽略）
```

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

产物在 `web/dist/`，需要同步到服务器的 `/opt/fittracker/web/`：

```bash
# 1) 本地构建
cd web && npm run build

# 2) 同步（建议先删旧文件，否则 hash 命名的旧 assets 会累积）
rsync -av --delete web/dist/ root@<server>:/opt/fittracker/web/

# 3) 重启 Caddy（Caddyfile 是单文件 bind mount，必须 restart 不能 reload）
ssh root@<server> 'docker restart fittracker-caddy'

# 4) 验证
curl -sI https://earthrhythm.cloud/ | head -3
curl -sI https://earthrhythm.cloud/legal/privacy.html | head -3
```

Caddyfile 里的站点块 `root * /opt/fittracker/web`（`server/deploy/Caddyfile`）。

**公开前的合规前置**：确认根域 `earthrhythm.cloud` 的 **ICP 网站备案**状态。
`docs/release/beian-materials.md` 记的是 **APP 备案**流程，两者不是一回事。

## 与 site/ 的关系

`site/` 是迁移前的纯静态版，**保留作为兜底**：它的 `index.html` + `site.css` + `site.js` 仍是完整可跑的站点。
`web/` 验证稳定后，可以删除 `site/`，届时需要同步清理：

- `tools/serve-site.mjs`（静态预览服务）
- `tools/check-site.mjs` + `tests`（静态站门禁，检查的是 `site/*.html`）
- `server/deploy/Caddyfile` 里已指向 `web/`，无需再改
