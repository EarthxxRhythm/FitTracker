#!/usr/bin/env python3
"""
spec-bounds-diff.py —— 原型 CSS 声明值 vs 设备实际 bounds 的对照器。

背景
----
诊断 UI 还原差异时，「坐标/尺寸是否偏移」是最常见的一类假设（计划中的 H2/H3），
但项目里没有对应工具：`design/06_prototype_redraw/scripts/extract_specs.py` 只产出
MANIFEST.md（路由清单）与 MOTION.md（动效声明），**不含坐标**。

本工具把「读原型 CSS → 换算 → 与设备 a11y bounds 对拍」自动化，
替代此前逐个元素手工核对的做法。

判据
----
  原型声明值（画布内 px） × scale  =  期望的屏幕 vp 坐标
  设备 bounds（物理 px） ÷ density =  实际的屏幕 vp 坐标
  两者（可选再减 crop 起点）取差，超容差即判 FAIL。

用法
----
  # 基本：一次比对多个「选择器=设备文本」对
  python tools/spec-bounds-diff.py \
      --html design/06_prototype_redraw/src/fittracker-welcome-home.html \
      --scale 0.90698 \
      --pair ".w-logo=FITTRACKER" \
      --pair ".w-cta=开始使用"

  # 指定已保存的 layout json（不现场调设备）
  python tools/spec-bounds-diff.py --html <path> --scale 0.90698 \
      --layout test_run/restore-accept/ui-welcome.json \
      --pair ".w-logo=FITTRACKER"

退出码
------
  0 = 全部在容差内；1 = 存在超差或未找到；2 = 环境失败（取不到 layout）

注意
----
- 选择器与设备文本无法自动配对（HTML 节点与 a11y 文本非一一对应），故由 `--pair` 手工指定。
- `.selector` 若在 CSS 中出现多次，取**首次**出现的 left/top/width/height 声明。
- crop 只作用于 left/top 的绝对位置；width/height 是尺寸，不受 crop 影响。
"""

import argparse
import json
import re
import subprocess
import sys

DENSITY_DEFAULT = 3.3846
PROPS = ('left', 'top', 'width', 'height')


def parse_decls(html_text, selector):
    """从 HTML 的 <style> 中提取 selector 的 left/top/width/height（单位 px）。

    返回 dict 或 None（未找到）。同名属性取首次出现。
    """
    pattern = re.compile(re.escape(selector) + r'\s*\{([^{}]*)\}')
    bodies = pattern.findall(html_text)
    if not bodies:
        return None
    decls = {}
    for body in bodies:
        for prop in PROPS:
            if prop in decls:
                continue
            found = re.search(prop + r'\s*:\s*(-?[\d.]+)px', body)
            if found:
                decls[prop] = float(found.group(1))
    return decls or None


def load_layout(args):
    """读 layout json：优先 --layout 文件，否则现场调 devecocli。"""
    if args.layout:
        with open(args.layout, encoding='utf-8') as handle:
            return json.load(handle)
    cmd = ['devecocli', 'ui', 'layout', '--format', 'json', '--depth', str(args.depth)]
    if args.device:
        cmd += ['--device', args.device]
    # Windows 上 devecocli 是 .cmd，须经 shell 解析
    proc = subprocess.run(' '.join(cmd), capture_output=True, text=True,
                          encoding='utf-8', shell=True)
    if proc.returncode != 0:
        raise RuntimeError('ui layout 失败：%s' % (proc.stderr or '').strip())
    if not proc.stdout.strip():
        raise RuntimeError('ui layout 无输出')
    return json.loads(proc.stdout)


def normalize_bounds(raw):
    """兼容两种 bounds 表示，返回 [x0,y0,x1,y1] 或 None。

    - `devecocli ui layout --format json`：数组 [x0, y0, x1, y1]
    - `uitest dumpLayout`：字符串 "[x0,y0][x1,y1]"
    实测两种格式在本项目都存在，混用会导致「bounds 不可用」的假失败。
    """
    if isinstance(raw, list) and len(raw) == 4:
        return [float(value) for value in raw]
    if isinstance(raw, str):
        found = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', raw)
        if found:
            return [float(value) for value in found.groups()]
    return None


def find_bounds(node, text, acc=None):
    """递归找包含 text 的节点，返回 [(文本, bounds), ...]。"""
    if acc is None:
        acc = []
    if isinstance(node, dict):
        node_text = node.get('text') or ''
        if text in node_text:
            acc.append((node_text.replace('\n', '/'), node.get('bounds')))
        for value in node.values():
            find_bounds(value, text, acc)
    elif isinstance(node, list):
        for item in node:
            find_bounds(item, text, acc)
    return acc


def compare_one(selector, text, decls, layout, args):
    """比对一对 (selector, text)，返回 (行列表, 是否全部通过)。"""
    rows = []
    ok = True

    found = find_bounds(layout, text)
    if not found:
        rows.append((selector, '-', '设备上未找到文本「%s」' % text, '', '', 'FAIL'))
        return rows, False

    bounds = normalize_bounds(found[0][1])
    if bounds is None:
        rows.append((selector, '-', '「%s」的 bounds 不可用' % text, '', '', 'FAIL'))
        return rows, False

    x0, y0, x1, y1 = bounds

    for prop in PROPS:
        if prop not in decls:
            continue
        declared = decls[prop]
        if prop in ('left', 'top'):
            expect = declared * args.scale - args.crop
            actual = (x0 if prop == 'left' else y0) / args.density - args.crop
        else:
            expect = declared * args.scale
            actual = ((x1 - x0) if prop == 'width' else (y1 - y0)) / args.density
        diff = actual - expect
        verdict = 'OK' if abs(diff) <= args.tolerance else 'FAIL'
        if verdict == 'FAIL':
            ok = False
        rows.append((selector, prop, '%.1f' % expect, '%.1f' % actual,
                     '%+.1f' % diff, verdict))
    return rows, ok


def main():
    parser = argparse.ArgumentParser(
        description='原型 CSS 声明值 vs 设备 a11y bounds 对照',
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--html', required=True, help='原型 HTML 路径')
    parser.add_argument('--pair', action='append', default=[], metavar='SEL=TEXT',
                        help='选择器与设备文本配对，可重复')
    parser.add_argument('--scale', type=float, default=1.0,
                        help='画布缩放（缩放屏传 0.90698，直绘屏省略）')
    parser.add_argument('--crop', type=float, default=0.0,
                        help='crop 起点 y（默认 0；用 100,740 口径时传 100）')
    parser.add_argument('--density', type=float, default=DENSITY_DEFAULT,
                        help='物理像素 / vp 密度（默认 %.4f）' % DENSITY_DEFAULT)
    parser.add_argument('--tolerance', type=float, default=2.0,
                        help='允许差值 vp（默认 2.0）')
    parser.add_argument('--layout', default='', help='已保存的 layout json 路径')
    parser.add_argument('--depth', type=int, default=10, help='layout 树深度（默认 10）')
    parser.add_argument('--device', default='', help='目标设备')
    args = parser.parse_args()

    if not args.pair:
        parser.error('至少提供一个 --pair ".selector=设备文本"')

    pairs = []
    for item in args.pair:
        if '=' not in item:
            parser.error('--pair 格式应为 ".selector=设备文本"，收到：%s' % item)
        selector, text = item.split('=', 1)
        pairs.append((selector.strip(), text.strip()))

    try:
        with open(args.html, encoding='utf-8') as handle:
            html_text = handle.read()
    except OSError as exc:
        print('读取原型失败：%s' % exc)
        return 2

    try:
        layout = load_layout(args)
    except (RuntimeError, json.JSONDecodeError, OSError) as exc:
        print('环境失败：%s' % exc)
        return 2

    print('原型: %s' % args.html)
    print('口径: scale=%s crop=%s density=%s tolerance=%s vp' % (
        args.scale, args.crop, args.density, args.tolerance))
    print()
    print('%-28s %-8s %8s %8s %8s  %s' % ('选择器', '属性', '期望', '实际', '差值', '判定'))
    print('-' * 78)

    all_ok = True
    any_row = False
    for selector, text in pairs:
        decls = parse_decls(html_text, selector)
        if not decls:
            print('%-28s %-8s %s' % (selector, '-', '未找到声明（检查选择器拼写）'))
            all_ok = False
            continue
        rows, ok = compare_one(selector, text, decls, layout, args)
        any_row = True
        if not ok:
            all_ok = False
        for row in rows:
            print('%-28s %-8s %8s %8s %8s  %s' % row)

    print()
    if not any_row:
        print('结论：没有任何可比对的行（全部未找到声明）')
        return 1
    print('结论：%s' % ('全部在容差内' if all_ok else '存在超差项'))
    return 0 if all_ok else 1


if __name__ == '__main__':
    sys.exit(main())
