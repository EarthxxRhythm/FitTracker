// inject-net-retry.js — 网络层重试补丁（云调试自动化通道专用）
//
// 背景（必须如实记录）：本机环境对「新建的 TLS 连接」存在间歇性干扰——
//   每次新连接会话的头 1-2 发请求可能被中断
//   （net::ERR_SSL_BAD_RECORD_MAC_ALERT / ERR_CONNECTION_RESET），
//   重试或复用连接则恢复正常。而 AGC 前端页面自身没有请求重试逻辑，
//   任何一个关键请求撞上该窗口都会让页面流程永久卡死。
//
// 本补丁只做一件事：页面内 fetch / XMLHttpRequest 因「网络层故障」
//   （抛错 / error / timeout）失败时，自动原样重试（最多 3 次，退避 250ms 起）。
//   —— 不伪造响应、不修改参数、不重试 4xx/5xx 应用层响应、不触碰凭据。
//   语义等价于「弱网环境下给浏览器配一个重试代理」。
//
// 安装方式：CDP Page.addScriptToEvaluateOnNewDocument（每次新文档自动注入）。
// 观测：重试记录在 window.__netRetryLog（数组），供探针/证据收集。

(() => {
  if (window.__netRetryInstalled) return;
  window.__netRetryInstalled = true;

  const MAX_RETRIES = 3;
  const BASE_DELAY_MS = 250;
  const log = [];
  window.__netRetryLog = log;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  // ---- fetch 补丁 ----
  const origFetch = window.fetch.bind(window);
  window.fetch = async function patchedFetch(input, init) {
    let lastErr;
    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      try {
        if (attempt > 0) {
          log.push({ t: Date.now(), kind: 'fetch', attempt, url: String(input).slice(0, 160) });
        }
        return await origFetch(input, init);
      } catch (e) {
        lastErr = e;
        if (attempt < MAX_RETRIES) await sleep(BASE_DELAY_MS * (attempt + 1));
      }
    }
    throw lastErr;
  };

  // ---- XMLHttpRequest 补丁 ----
  const origOpen = XMLHttpRequest.prototype.open;
  const origSend = XMLHttpRequest.prototype.send;

  XMLHttpRequest.prototype.open = function patchedOpen(method, url, ...rest) {
    this.__netRetryOpenArgs = [method, url, ...rest];
    return origOpen.call(this, method, url, ...rest);
  };

  XMLHttpRequest.prototype.send = function patchedSend(body) {
    let attempts = 0;
    const xhr = this;
    const args = xhr.__netRetryOpenArgs;
    const onFailure = () => {
      if (!args || attempts >= MAX_RETRIES) return;
      attempts++;
      log.push({ t: Date.now(), kind: 'xhr', attempt: attempts, url: String(args[1]).slice(0, 160) });
      setTimeout(() => {
        try {
          origOpen.apply(xhr, args);
          origSend.call(xhr, body);
        } catch (e) { /* 放弃 */ }
      }, BASE_DELAY_MS * attempts);
    };
    xhr.addEventListener('error', onFailure);
    xhr.addEventListener('timeout', onFailure);
    return origSend.call(this, body);
  };
})();
