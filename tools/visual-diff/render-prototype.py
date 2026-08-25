#!/usr/bin/env python3
"""Render an HTML design prototype to a PNG at a phone viewport using a headless browser.

Usage:
    python render-prototype.py <html_path> <out.png> [--width 390 --height 844] [--screen 0]

The prototype HTML from "Open Design" is usually a single-file gallery that embeds one
or more phone frames (`.phone` / `.viewport`). This script:
  1. auto-detects the phone viewport size from CSS (`.phone`, `.viewport`, `.appshell`),
  2. auto-detects how many screens (`.frame-card` figures) the file contains,
  3. renders only the chosen screen into a clean viewport, so the output PNG is exactly
     the phone canvas rather than the whole gallery page.

Viewport detection priority: a fixed `width`/`height` declared in a `.phone` block wins;
otherwise the `--width`/`--height` defaults (390x844) are used.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

DEFAULT_WIDTH = 390
DEFAULT_HEIGHT = 844

# Script injected into the page before it is screenshotted. It isolates the Nth phone
# frame so the capture is the phone canvas only (no gallery header / sibling frames).
_INJECT_TEMPLATE = """
<script>
window.addEventListener('DOMContentLoaded', function () {
  var INDEX = {screen_index};
  var target = null;

  var frames = document.querySelectorAll('figure.frame-card');
  if (frames.length) {
    var f = frames[Math.min(INDEX, frames.length - 1)];
    target = f.querySelector('.phone') || f.querySelector('.viewport') || f.querySelector('.appshell') || f;
  }
  if (!target) {
    var phones = document.querySelectorAll('.phone, .viewport, .appshell');
    if (phones.length) { target = phones[Math.min(INDEX, phones.length - 1)]; }
  }

  if (target) {
    // Detach everything, then re-attach only the chosen frame.
    var clone = target;
    document.body.innerHTML = '';
    document.body.appendChild(clone);
  }

  document.body.style.margin = '0';
  document.body.style.padding = '0';
  document.body.style.background = '#000';
  document.documentElement.style.overflow = 'hidden';
  document.body.style.overflow = 'hidden';
  window.scrollTo(0, 0);
});
</script>
"""


def find_browser():
    """Return a path to a Chromium-based browser, or None."""
    for name in ('msedge', 'chrome', 'chromium', 'chromium-browser', 'chrome.exe', 'msedge.exe'):
        p = shutil.which(name)
        if p:
            return p
    candidates = [
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files\Chromium\Application\chrome.exe",
    ]
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None


def _css_block(html, selector):
    m = re.search(re.escape(selector) + r'\s*\{([^{}]*)\}', html, re.S)
    return m.group(1) if m else ''


def detect_viewport(html):
    """Detect the phone canvas width/height from CSS, else fall back to defaults."""
    w, h = DEFAULT_WIDTH, DEFAULT_HEIGHT
    for sel in ('.phone', '.viewport', '.appshell'):
        blk = _css_block(html, sel)
        if not blk:
            continue
        mw = re.search(r'width:\s*(\d+(?:\.\d+)?)px', blk)
        mh = re.search(r'height:\s*(\d+(?:\.\d+)?)px', blk)
        if mw:
            w = int(round(float(mw.group(1))))
        if mh:
            h = int(round(float(mh.group(1))))
        if w != DEFAULT_WIDTH or h != DEFAULT_HEIGHT:
            break
    # Clamp to something plausible for a phone canvas.
    w = max(240, min(w, 600))
    h = max(400, min(h, 1600))
    return w, h


def count_screens(html):
    """Return the number of full-screen frames in the prototype."""
    n = len(re.findall(r'<figure\b[^>]*class="[^"]*frame-card', html))
    if n == 0:
        n = len(re.findall(r'class="phone"', html))
    if n == 0:
        n = len(re.findall(r'data-od-id="screen-', html))
    return max(n, 1)


def build_page(html, screen_index):
    """Inject the isolation script right before </body> (or at end)."""
    inject = _INJECT_TEMPLATE.replace('{screen_index}', str(screen_index))
    if '</body>' in html:
        return html.replace('</body>', inject + '</body>', 1)
    return html + inject


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('html_path', help='path to the prototype HTML file')
    ap.add_argument('out', help='output PNG path')
    ap.add_argument('--width', type=int, default=None, help='override viewport width (default: auto)')
    ap.add_argument('--height', type=int, default=None, help='override viewport height (default: auto)')
    ap.add_argument('--screen', type=int, default=0, help='which screen/frame to render (0-based)')
    ap.add_argument('--hide-scrollbars', action='store_true', default=True,
                    help='hide scrollbars (default: on)')
    args = ap.parse_args(argv)

    if not os.path.isfile(args.html_path):
        print('ERROR: html not found: %s' % args.html_path, file=sys.stderr)
        return 2

    with open(args.html_path, 'r', encoding='utf-8', errors='replace') as fh:
        html = fh.read()

    width, height = detect_viewport(html)
    if args.width:
        width = args.width
    if args.height:
        height = args.height
    screens = count_screens(html)

    browser = find_browser()
    if not browser:
        print('ERROR: no Chromium-based browser found (Edge/Chrome)', file=sys.stderr)
        return 2

    page = build_page(html, args.screen)
    with tempfile.NamedTemporaryFile('w', suffix='.html', delete=False,
                                     encoding='utf-8') as tf:
        tf.write(page)
        tmp_html = tf.name

    out_abs = os.path.abspath(args.out)
    os.makedirs(os.path.dirname(out_abs), exist_ok=True)

    import pathlib
    uri = pathlib.Path(tmp_html).as_uri()

    cmd = [
        browser,
        '--headless=new',
        '--disable-gpu',
        '--no-sandbox',
        '--force-device-scale-factor=1',
        '--hide-scrollbars',
        '--virtual-time-budget=4000',
        '--window-size=%d,%d' % (width, height),
        '--screenshot=%s' % out_abs,
        uri,
    ]

    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    finally:
        try:
            os.remove(tmp_html)
        except OSError:
            pass

    if res.returncode != 0:
        print('ERROR: browser failed (rc=%d)' % res.returncode, file=sys.stderr)
        print(res.stderr[-2000:], file=sys.stderr)
        return 2

    if not os.path.isfile(out_abs) or os.path.getsize(out_abs) == 0:
        print('ERROR: browser produced no screenshot', file=sys.stderr)
        return 2

    print('rendered %s -> %s  (%dx%d, screen %d of %d, browser=%s)'
          % (args.html_path, out_abs, width, height, args.screen, screens, browser))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
