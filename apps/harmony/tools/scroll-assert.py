#!/usr/bin/env python3
"""
scroll-assert.py —— 断言页面的「固定区 / 滚动区」是否符合原型语义。

背景
----
原生 UI 的滚动边界此前只能人工确认（静态截图看不出页头会不会跟着滚走）。
devecocli ui 提供了 swipe 手势，使这件事可以脚本化断言。

原理（三步骤）
--------------
  1. devecocli ui layout --format json  →  T0：记录目标元素的 bounds
  2. devecocli ui swipe                 →  滚动一次
  3. devecocli ui layout --format json  →  T1：再取 bounds

判定
----
  --fixed    元素在 T1 的 bounds 与 T0 相同          → PASS（该元素固定）
  --scrolled 元素在 T1 的 bounds 变化 / 或已不可见   → PASS（随内容滚动）
  --probe    只看本屏是否可滚：swipe 前后可见文本集合是否有变化

为什么需要 --probe
------------------
实测发现「内容不足一屏」的屏占多数（login / register / active 都是），
对它们跑 --scrolled 会得到**假 FAIL**（元素本就不该动）。
断言前先用 --probe 判断该屏能否滚动，可避免误读。

用法
----
  # 先探测本屏能不能滚
  python tools/scroll-assert.py --probe

  # 再按结果选断言方向
  python tools/scroll-assert.py --fixed "身体数据" --scrolled "当前体重"
  python tools/scroll-assert.py --fixed "FITTRACKER,欢迎回来,登录"   # 不可滚的屏：全 fixed

  # 自定义滑动轨迹（默认 660,1900,660,700）与设备
  python tools/scroll-assert.py --probe --swipe 660,1800,660,800 --device 127.0.0.1:5555

退出码
------
  0 = 全部符合预期；1 = 存在不符合；2 = 环境/取景失败（拿不到 layout 或 swipe 失败）

注意
----
- 前置：设备已连、App 已导航到目标屏。本脚本**不负责导航**。
- `--depth` 默认 10；目标元素嵌套较深时需调大（曾出现 depth 8 找不到、10 才找到的情况）。
"""

import argparse
import json
import subprocess
import sys


def run_layout(depth, device):
    """调用 devecocli ui layout，返回解析后的 JSON 树。"""
    cmd = ['devecocli', 'ui', 'layout', '--format', 'json', '--depth', str(depth)]
    if device:
        cmd += ['--device', device]
    # Windows 上 devecocli 是 .cmd，subprocess 必须经 shell 才解析得到
    proc = subprocess.run(' '.join(cmd), capture_output=True, text=True, encoding='utf-8', shell=True)
    if proc.returncode != 0:
        raise RuntimeError('ui layout 失败（exit %d）：%s' % (proc.returncode, proc.stderr.strip()))
    raw = proc.stdout.strip()
    if not raw:
        raise RuntimeError('ui layout 无输出')
    # devecocli 会在 JSON 之后追加版本升级提示等非 JSON 行（内容随 CLI 版本变化），
    # 直接 json.loads 整段会报 "Extra data"；只截取首个 '[' 到末个 ']' 之间的主体再解析。
    start = raw.find('[')
    end = raw.rfind(']')
    if start < 0 or end < start:
        raise RuntimeError('ui layout 输出未包含 JSON 数组：%s' % raw[:200])
    try:
        return json.loads(raw[start:end + 1])
    except json.JSONDecodeError as exc:
        raise RuntimeError('ui layout 输出不是合法 JSON：%s' % exc)


def run_swipe(coords, device):
    """调用 devecocli ui swipe 滚动。"""
    cmd = ['devecocli', 'ui', 'swipe'] + [str(c) for c in coords]
    if device:
        cmd += ['--device', device]
    proc = subprocess.run(' '.join(cmd), capture_output=True, text=True, encoding='utf-8', shell=True)
    out = (proc.stdout or '') + (proc.stderr or '')
    if proc.returncode != 0:
        raise RuntimeError('ui swipe 失败（exit %d）：%s' % (proc.returncode, out.strip()))
    return out.strip()


def find_bounds(node, text, acc=None):
    """在 JSON 树里递归找包含 text 的节点，返回 [(text, bounds), ...]。"""
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


def collect_texts(node, acc=None):
    """收集整棵树里的非空文本，用于判断页面是否可滚。"""
    if acc is None:
        acc = set()
    if isinstance(node, dict):
        item_text = (node.get('text') or '').strip()
        if item_text:
            acc.add(item_text)
        for value in node.values():
            collect_texts(value, acc)
    elif isinstance(node, list):
        for item in node:
            collect_texts(item, acc)
    return acc


def describe(found):
    if not found:
        return '不可见'
    return ' | '.join('%s @ %s' % (t, b) for t, b in found)


def main():
    parser = argparse.ArgumentParser(description='断言页面固定区/滚动区是否符合原型语义')
    parser.add_argument('--fixed', default='', help='应保持固定的元素文本，逗号分隔')
    parser.add_argument('--scrolled', default='', help='应随内容滚动的元素文本，逗号分隔')
    parser.add_argument('--probe', action='store_true',
                        help='只探测本屏是否可滚（比对 swipe 前后可见文本集合）')
    parser.add_argument('--swipe', default='660,1900,660,700', help='滑动轨迹 x1,y1,x2,y2')
    parser.add_argument('--device', default='', help='目标设备（名称或序列号）')
    parser.add_argument('--depth', type=int, default=10, help='layout 树深度（默认 10）')
    args = parser.parse_args()

    fixed_items = [s.strip() for s in args.fixed.split(',') if s.strip()]
    scrolled_items = [s.strip() for s in args.scrolled.split(',') if s.strip()]
    if not fixed_items and not scrolled_items and not args.probe:
        parser.error('至少提供 --probe / --fixed / --scrolled 之一')

    try:
        coords = [int(x) for x in args.swipe.split(',')]
        if len(coords) != 4:
            raise ValueError
    except ValueError:
        parser.error('--swipe 需为 x1,y1,x2,y2 四个整数')

    try:
        print('[1/3] T0：记录滚动前 bounds')
        tree_t0 = run_layout(args.depth, args.device)
        print('[2/3] 滚动：swipe %s' % ','.join(str(c) for c in coords))
        run_swipe(coords, args.device)
        print('[3/3] T1：记录滚动后 bounds')
        tree_t1 = run_layout(args.depth, args.device)
    except RuntimeError as exc:
        print('环境/取景失败：%s' % exc)
        return 2

    # --probe：只判断本屏能否滚动，供选择断言方向
    if args.probe:
        texts0 = collect_texts(tree_t0)
        texts1 = collect_texts(tree_t1)
        print()
        if texts0 != texts1:
            print('本屏可滚：swipe 前后可见文本集合有变化（%d → %d 条）' % (len(texts0), len(texts1)))
            print('  建议：对内容区元素用 --scrolled 断言')
            return 0
        print('本屏不可滚：swipe 前后可见文本集合完全相同（%d 条）' % len(texts0))
        print('  建议：对页内元素用 --fixed 断言（内容不足一屏，元素本就不该动）')
        return 0

    failures = []
    print()
    print('%-4s %-14s %-26s %-26s %s' % ('判定', '元素', 'T0', 'T1', '预期'))
    print('-' * 100)

    for text in fixed_items:
        b0 = find_bounds(tree_t0, text)
        b1 = find_bounds(tree_t1, text)
        same = bool(b0) and bool(b1) and b0[0][1] == b1[0][1]
        verdict = 'PASS' if same else 'FAIL'
        if not same:
            failures.append('固定元素「%s」在滚动后 bounds 发生变化（或不可见）' % text)
        print('%-4s %-14s %-26s %-26s %s' % (
            verdict, text, describe(b0)[:24], describe(b1)[:24], '应固定不变'))

    for text in scrolled_items:
        b0 = find_bounds(tree_t0, text)
        b1 = find_bounds(tree_t1, text)
        moved = bool(b0) and (not b1 or b0[0][1] != b1[0][1])
        verdict = 'PASS' if moved else 'FAIL'
        if not moved:
            failures.append('滚动元素「%s」在滚动后 bounds 未变化' % text)
        print('%-4s %-14s %-26s %-26s %s' % (
            verdict, text, describe(b0)[:24], describe(b1)[:24], '应随内容滚动'))

    print()
    if failures:
        print('结论：不符合预期 %d 项' % len(failures))
        for item in failures:
            print('  - %s' % item)
        print('  提示：若元素本就不该动，先用 --probe 确认本屏是否可滚')
        return 1

    print('结论：全部符合预期')
    return 0


if __name__ == '__main__':
    sys.exit(main())
