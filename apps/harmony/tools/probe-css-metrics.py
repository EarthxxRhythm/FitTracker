#!/usr/bin/env python3
"""
probe-css-metrics.py —— 从 headless Chrome 取回原型元素的**渲染后**布局值。

背景
----
诊断 UI 还原差异时，「尺寸不符」常源于字体度量而非 CSS 声明：
原型大量使用 `line-height: normal`，其计算值取决于字体，**在 CSS 里读不到**。
`tools/spec-bounds-diff.py` 只能读 left/top/width/height 的声明值，读不到这类计算值，
导致「Chrome 与 ArkUI 的行高差多少」只能靠猜。

本工具让浏览器自己回答：在原型页面上执行后 `--dump-dom`，从 `<title>` 取回
`getBoundingClientRect()` 的实测结果。

与 spec-bounds-diff.py 的分工
----------------------------
  spec-bounds-diff.py   CSS 声明值  ×  scale  vs  设备 a11y bounds   —— 查「坐标是否偏移」
  probe-css-metrics.py  Chrome 渲染值（含 line-height/gap 计算）    —— 查「尺寸为何不符」
两者互补，判据不同源。

用法
----
  python tools/probe-css-metrics.py \
      --html design/06_prototype_redraw/src/fittracker-welcome-home.html \
      --frame 1 \
      --selector ".today-id .label" --selector ".today-id .muscle"

  # 不传 --selector 时使用一组通用选择器（首页兜底集）

输出
----
  每行 `选择器|top=<vp>|h=<vp>`；`|MISSING` 表示该选择器在当前 frame 中不存在。
  top 以手机画布左上角为原点（.phone 的 padding box）。

退出码
------
  0 = 取到指标；1 = 未取到（页面未注入成功或浏览器未执行脚本）；2 = 环境失败（无浏览器）

注意
----
- 需要本机安装 Edge 或 Chrome（自动探测常见安装路径）。
- 只渲染指定 frame（`--frame` 从 0 起），不截全图，因此很快（<2s）。
- Windows 上 dump-dom 输出按 UTF-8 解码，避免 GBK 报错。
"""

import argparse
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

DEFAULT_SELECTORS = [
    '.home-content',
    '.home-head',
    '.home-head .date',
    '.home-head .greet',
    '.today',
    '.today-top',
    '.today-id',
    '.today-id .label',
    '.today-id .title-row',
    '.today-id .title',
    '.today-id .rec',
    '.today-id .muscle',
    '.today-id .day',
    '.today-ring',
    '.today-divider',
    '.today-metrics',
    '.metric',
    '.week',
    '.week .week-head',
    '.week-days',
    '.today .btn-primary',
    '.today .btn-ghost',
]

BROWSER_CANDIDATES = (
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
)

_INJECT = """
<script>
window.addEventListener('DOMContentLoaded', function () {
  var frames = document.querySelectorAll('figure.frame-card');
  var target = null;
  if (frames.length) {
    var f = frames[Math.min(%(frame)d, frames.length - 1)];
    target = f.querySelector('.phone') || f.querySelector('.viewport') || f.querySelector('.appshell') || f;
  }
  if (!target) { target = document.querySelector('.phone, .viewport, .appshell'); }
  if (!target) { document.title = 'METRICS::NO_TARGET'; return; }
  document.body.innerHTML = '';
  document.body.appendChild(target);
  document.body.style.margin = '0';
  document.body.style.padding = '0';
  document.body.style.background = '#000';
  document.documentElement.style.overflow = 'hidden';
  var sels = %(sels)s;
  var out = [];
  sels.forEach(function (s) {
    var els = document.querySelectorAll(s);
    if (!els.length) { out.push(s + '|MISSING'); return; }
    var r = els[0].getBoundingClientRect();
    out.push(s + '|top=' + r.top.toFixed(2) + '|h=' + r.height.toFixed(2));
  });
  document.title = 'METRICS::' + out.join(' ;; ');
});
</script>
"""


def find_browser():
    for c in BROWSER_CANDIDATES:
        if os.path.isfile(c):
            return c
    return None


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--html', required=True, help='prototype HTML path')
    ap.add_argument('--frame', type=int, default=0, help='frame index (0-based)')
    ap.add_argument('--selector', action='append', default=[], metavar='CSS',
                    help='selector to measure; repeatable. Omit for the built-in default set.')
    args = ap.parse_args(argv)

    if not os.path.isfile(args.html):
        print('ERROR: html not found: %s' % args.html, file=sys.stderr)
        return 2

    browser = find_browser()
    if not browser:
        print('ERROR: no Chromium-based browser found (Chrome/Edge)', file=sys.stderr)
        return 2

    selectors = args.selector if args.selector else DEFAULT_SELECTORS
    html = open(args.html, encoding='utf-8', errors='replace').read()
    inject = _INJECT % {'frame': args.frame, 'sels': json.dumps(selectors)}
    if '</body>' in html:
        html = html.replace('</body>', inject + '</body>', 1)
    else:
        html = html + inject

    tmp = tempfile.NamedTemporaryFile('w', suffix='.html', delete=False, encoding='utf-8')
    tmp.write(html)
    tmp.close()

    cmd = [
        browser, '--headless=new', '--disable-gpu', '--no-sandbox',
        '--force-device-scale-factor=1', '--hide-scrollbars',
        '--virtual-time-budget=4000', '--dump-dom',
        pathlib.Path(tmp.name).as_uri(),
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, timeout=120,
                             encoding='utf-8', errors='replace')
    finally:
        try:
            os.remove(tmp.name)
        except OSError:
            pass

    m = re.search(r'<title>(METRICS::.*?)</title>', res.stdout, re.S)
    if not m:
        print('ERROR: metrics not found (rc=%d)' % res.returncode, file=sys.stderr)
        print(res.stderr[-600:], file=sys.stderr)
        return 1

    for part in m.group(1)[len('METRICS::'):].split(' ;; '):
        print(part)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
