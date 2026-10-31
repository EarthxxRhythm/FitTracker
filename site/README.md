# site —— 产品官网静态站（旧版，已被 web/ 取代）

> **状态（2026-10-31）**：线上站点已切到 `web/`（React + Vite），由服务器 Caddy 从
> `/opt/fittracker/web/` 提供服务。本目录**不再部署**，保留作两份用途：
> 1. 内容与文案的对照基线；
> 2. `apps/harmony/tools/check-site.mjs` 等门禁脚本的被检对象。
>
> 新的构建与部署流程见 [`web/README.md`](../web/README.md)。下文描述的是 `.mjs` 脚本链，
> **不适用于线上**——`web/` 用的是 Vite + `tools/build-site.mjs --legal-out`。

零依赖静态站点：`index.html` 手写，`assets/` 下是样式、脚本与图片，构建与本地预览都用仓库自带的
Node 脚本（只用 `node:` 内置模块，不装任何 npm 包）。

```text
site/
├── index.html              首页（手写，og:image 直接引用 assets/img/01-home.jpg）
├── privacy.html            隐私政策（由 tools/build-site.mjs 从 docs/legal/ 渲染）
├── terms.html              用户协议（同上）
└── assets/
    ├── site.css            站点样式
    ├── site.js             交互脚本（滚动揭示、顶栏状态）
    └── img/                截图与 logo（由 build-site.mjs 从 docs/screenshots/ 同步）
```

## 两条命令

```bash
# 构建：渲染法务页 + 同步截图，输出每个产物的 lines/bytes
node tools/build-site.mjs

# 预览：本地静态服务器（默认 8080，可用 --port 指定）
node tools/serve-site.mjs
```

`node tools/build-site.mjs --check` 只校验不写入：产物与源一致时 exit 0，出现漂移时 exit 1。

## 部署

三段，按顺序做：

1. **DNS**：把根域 `earthrhythm.cloud` 的 A 记录（以及 `www` 的 CNAME 或 A 记录）指向腾讯云服务器公网 IP。
   Caddy 靠 SNI/Host 分流，`server/deploy/Caddyfile` 里官网块与 `api.*` 块共用 443。
2. **同步站点**：把仓库 `site/` 目录同步到服务器的 `/opt/fittracker/site/`
   （Caddy 的 `root` 指向该路径）。同步完毕确认 `index.html` 与 `assets/` 都在位。
3. **重启容器**：`docker restart fittracker-caddy`。

> ⚠ 必须 `docker restart`，不能 `caddy reload`。`Caddyfile` 是单文件 bind mount：
> `sed -i` 之类写法会换 inode，容器仍挂旧文件，`reload` 返回成功但配置没变
> （见 `server/deploy/Caddyfile` 顶部注释「单文件 bind mount 陷阱」）。

## 截图更新流程

官网截图与文档截图同源，只改一处：

1. 用新设备实拍替换 `docs/screenshots/` 下的同名文件（文件名保持不变）；
2. 跑 `node tools/build-site.mjs`，把新图同步到 `site/assets/img/`；
3. `node tools/build-site.mjs --check` 确认无漂移，再按上面的「同步站点」重新发布 `site/`。

不要直接编辑 `site/assets/img/` 下的文件——下次构建会被覆盖。

## 备案前置提醒

公开 443 之前，先确认根域的 **ICP 网站备案**状态。仓库 `docs/release/beian-materials.md`
记录的是 APP 备案流程，与网站备案不是同一件事；根域未完成网站备案就把站点挂上公网 443 存在合规风险。
备案未完成期间只做本地预览（`node tools/serve-site.mjs`）或内网访问。
