#!/usr/bin/env python
"""
accept-screen.py — 一条命令产出整屏客观验收摘要。

把「渲染参照图 → 装包 → 深链 → 语义树(dump) → 截图 → 并排合成 → 像素探针」串成一次调用，
让逐屏验收的判据从「读图看着像」变成可计算的数值。这是 goal 自治循环能自我判定
的基础设施（没有它，每屏都要重新手写一次探针，且判绿标准会漂移）。

用法：
    python tools/accept-screen.py \
        --route plan \
        --frame screen-plan \
        --html design/06_prototype_redraw/src/fittracker-plan.html

可选：
    --apk <path>       默认 app/build/outputs/apk/debug/app-debug.apk
    --skip-install     跳过 adb install（重复跑同一 APK 时省时间）
    --out <path>       摘要 JSON 落盘位置，默认 .rivet/scratch/accept-<route>.json

判据（阈值写死在此处，避免每屏各自判断）：
    BG_TOLERANCE = 4            背景色 |ΔRGB|，容忍渲染器舍入
    POSITION_SHIFT_TOLERANCE = 8   相邻锚点间距差的中位数（px，见 position_shift；
                                绝对 y 偏移与 spread 仅作诊断，不判绿）
    X_MARGIN_TOLERANCE = 8      内容左右边距（锚点横向极值到画布边缘）之差（px）。
                                兜住「整屏被等比缩放/平移」——相邻间距对整屏缩放是盲的。
    文本：missing 必须为空才判绿；extra 允许（Android 状态栏/手势条等环境文本）。
         比对前对两侧做同一套归一化——空白折叠 + 时刻字面量归一（见 normalize_clock，
         `active` 屏的计时器每秒自增，参照态 `00:00` 与设备态必不相同）。

用法示例（Wave B 起每屏跑一次）：
    python tools/accept-screen.py --route plans --frame screen-plan-detail \\
        --html design/06_prototype_redraw/src/fittracker-plan-detail.html

退出码：0 = 三项判据全绿；1 = 有判据不过；2 = 环境/参数错误。
"""

import argparse
import collections
import html
import json
import os
import re
import subprocess
import sys
import time

try:
    from PIL import Image
except ImportError:
    sys.exit("需要 Pillow：pip install pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BG_TOLERANCE = 4
# 同一文案在两套渲染下的纵向中心差（px）容忍上限
POSITION_SHIFT_TOLERANCE = 8
# 内容的左右边距（锚点横向极值到画布边缘的距离）容忍上限（px）。
# 相邻间距对「整屏等比缩放」是盲的——缩放会等比缩放所有间距，间距差反而趋近 0
# （complete 屏实测 gapMedian 恰为 0.0，而整屏实际小了 9.3%）。横向边距会被缩放/
# 平移直接改变，故用它兜住这一类缺陷。见 HANDOFF 坑 #27。
X_MARGIN_TOLERANCE = 8
# 逐行「非背景像素数」超过该值即视为该行有内容；现仅用于块计数诊断
BLOCK_ROW_THRESHOLD = 8
# 内容块最短行数（短于此的碎块丢弃，避免抗锯齿噪点）
BLOCK_MIN_RUN = 3

SCREEN_W, SCREEN_H = 390, 844


def run(cmd, **kw):
    """执行命令，返回 (returncode, stdout_text, stderr_text)。"""
    p = subprocess.run(cmd, capture_output=True, **kw)
    return (
        p.returncode,
        p.stdout.decode("utf-8", errors="replace"),
        p.stderr.decode("utf-8", errors="replace"),
    )


def adb(*args, binary=False):
    cmd = ["adb"] + list(args)
    if binary:
        p = subprocess.run(cmd, capture_output=True)
        return p.returncode, p.stdout, p.stderr.decode("utf-8", errors="replace")
    return run(cmd)


def render_ref(html, frame, route):
    out = os.path.join(ROOT, ".rivet", "scratch", f"ref-{route}.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    rc, _, err = run(
        ["node", os.path.join(ROOT, "tools", "render-prototype.mjs"),
         "--html", html, "--frame", frame, "--out", out],
        cwd=ROOT,
    )
    if rc != 0:
        sys.exit(f"渲染参照图失败：{err.strip()}")
    return out


def _screen_landed(expected, dev_texts, min_ratio=0.6):
    """
    设备语义树里是否已出现**足够比例**的原型文案（宽松包含），用于判断深链是否真的落地。

    只要求「任意一条命中」不够：welcome/home 同源一个 HTML、login/register、
    plans/planGroup 之间的文案有交集，停在兄弟屏也会命中一两条（实测：home 深链停在
    welcome 时漏检，因为两张屏共享同一 HTML）。正常落地时 missingLoose 本应为空
    （命中率 1.0），故阈取 0.6 有充足余量。本校验只服务重试决策，不作判绿判据。
    """
    if not expected:
        return True
    devs = [normalize_clock(re.sub(r"\s+", " ", d)).strip() for d in dev_texts]
    hits = 0
    for t in expected:
        nt = normalize_clock(re.sub(r"\s+", " ", t)).strip()
        if any(nt in d or d in nt for d in devs):
            hits += 1
    return hits >= max(1, int(len(expected) * min_ratio))


def capture_device(route, apk, skip_install, expected=None, attempts=3):
    """
    装包 → 深链 → 语义树(dump) → 截图。返回 (shot_path, ui_xml, dev_texts, dev_nodes)。

    **落地校验 + 重试**（`expected` 传该屏原型文案）：`am force-stop` 是**异步**的，
    紧接的 `am start` 可能被投递给尚未退出的旧 Activity，新 intent 不触发 Navigation
    深链——表现是 dump/screencap 拿到的是**上一屏**。连跑多屏回归时实测复现：
    plans/planGroup/workout 三屏在同一 shell 循环里都被 dump 成了前一屏（devTextCount
    三屏同为 48，即上一屏 plan 的文案数），逐条单跑则全绿。故深链后校验语义树里是否
    出现了本屏原型文案，未出现则重试（最多 [attempts] 次；等 1.5s 让 force-stop 生效）。
    """
    if not skip_install:
        rc, out, err = adb("install", "-r", apk)
        if rc != 0 or "Success" not in out:
            sys.exit(f"adb install 失败：{out.strip()} {err.strip()}")

    shot = os.path.join(ROOT, ".rivet", "scratch", "android", f"shot-{route}.png")
    ui_xml = os.path.join(ROOT, ".rivet", "scratch", f"ui-{route}.xml")
    os.makedirs(os.path.dirname(shot), exist_ok=True)

    dev_texts, dev_nodes = [], []
    for attempt in range(1, attempts + 1):
        # 深链直达目标路由（scheme 已在 AndroidManifest 声明）
        adb("shell", "am", "force-stop", "com.earthrhythm.fittracker")
        time.sleep(1.5)  # force-stop 是异步的：不等它完成，下面的 am start 会被旧 Activity 吞掉
        adb("shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", f"fittracker://{route}")
        time.sleep(4)

        # 先 dump 再截图：uiautomator dump 会等待 UI 空闲，起同步作用。
        # 反序会在冷启动尚未完成时抓到白屏——workout 屏实测 bgShot=(255,255,255)，
        # 而同一时刻的语义树已完整（19 条文本全部匹配）。
        adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")

        rc, data, err = adb("exec-out", "screencap", "-p", binary=True)
        if rc != 0 or not data:
            sys.exit(f"截图失败：{err.strip()}")
        with open(shot, "wb") as f:
            f.write(data)
        rc, xml_bytes, _ = adb("exec-out", "cat", "/sdcard/ui.xml", binary=True)
        xml = xml_bytes.decode("utf-8", errors="replace")
        with open(ui_xml, "w", encoding="utf-8") as f:
            f.write(xml)

        dev_texts, dev_nodes = [], []
        for node in re.findall(r"<node[^>]*>", xml):
            bounds = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', node)
            cx = cy = None
            if bounds:
                x1, y1, x2, y2 = (int(v) for v in bounds.groups())
                cx, cy = (x1 + x2) / 2.0, (y1 + y2) / 2.0
            for attr in ("text", "content-desc"):
                m = re.search(attr + r'="([^"]*)"', node)
                if m and m.group(1).strip():
                    # dump 是 XML：&gt; &amp; &#10; 等实体必须反转义，否则同一句文案
                    # 在原型侧是 "A > B"、设备侧是 "A &gt; B"，比对会假红
                    # （welcome 屏实测：3 条多行/含符号文案被误报缺失）。
                    t = html.unescape(m.group(1)).strip()
                    dev_texts.append(t)
                    if cx is not None:
                        dev_nodes.append({"text": t, "cx": cx, "cy": cy})

        if _screen_landed(expected, dev_texts):
            break
        if attempt < attempts:
            print(f"    [深链疑似未落地 → 重试 {attempt}/{attempts - 1}] 语义树里没有 {route} 屏的原型文案")

    return shot, ui_xml, dev_texts, dev_nodes


def proto_texts(html, frame):
    rc, out, err = run(
        ["node", os.path.join(ROOT, "tools", "proto-text.mjs"),
         "--html", html, "--frame", frame],
        cwd=ROOT,
    )
    if rc != 0:
        sys.exit(f"原型文本提取失败：{err.strip()}")
    return json.loads(out.strip().splitlines()[-1])


def background_color(im):
    """
    取画布四角邻域的众数作为背景色。

    不用「整屏众数」：当卡片等大块内容占多数面积时，众数会选到**内容色**而非底色
    （plan 屏实测众数为卡片底 (21,27,32)，而页面底是 (11,15,19)，造成 bgDelta 假红）。
    四角在 15 屏里恒为底色——缩放画布屏的四角也落在画布内，同为底色。
    """
    im = im.convert("RGB")
    w, h = im.size
    px = im.load()
    # 采样点避开四角：参照图是带 54px 圆角的 .phone 元素，四角落在圆角**外**的
    # 页面底色上（实测 ref 四角为 (5,7,9)、画布底色是 (11,15,19)，造成 bgDelta 假红）。
    # 改取左右边缘 1/4、1/2、3/4 高度与上下边缘中点。
    anchors = [
        (3, h // 4), (w - 4, h // 4),
        (3, h // 2), (w - 4, h // 2),
        (3, 3 * h // 4), (w - 4, 3 * h // 4),
        (w // 2, 3), (w // 2, h - 4),
    ]
    samples = []
    for cx, cy in anchors:
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                samples.append(px[min(max(cx + dx, 0), w - 1), min(max(cy + dy, 0), h - 1)])
    return collections.Counter(samples).most_common(1)[0][0]


def content_blocks(im, bg):
    """逐行统计非背景像素，切成内容块：[(y0, y1), ...]。"""
    px = im.convert("RGB").load()
    w, h = im.size
    rows = []
    for y in range(h):
        n = 0
        for x in range(20, w - 20, 2):
            r, g, b = px[x, y]
            if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) > 24:
                n += 1
        rows.append(n)

    blocks, start = [], None
    for y, n in enumerate(rows):
        if n > BLOCK_ROW_THRESHOLD and start is None:
            start = y
        elif n <= BLOCK_ROW_THRESHOLD and start is not None:
            if y - start >= BLOCK_MIN_RUN:
                blocks.append((start, y - 1))
            start = None
    if start is not None and h - start >= BLOCK_MIN_RUN:
        blocks.append((start, h - 1))
    return blocks


def position_shift(proto_items, dev_nodes, shot_size):
    """
    版式对齐度量：同一文案在两套渲染下的纵向中心差。返回 (medianAbs, spread, gapMedian, detail)。

    三个量的分工：
      - medianAbs = |dy| 的中位数 → **信息**（不判绿）。设备侧底栏要为手势导航条留位
        （FtBottomTabBar 比原型 .tabbar 高约 22px），Tab 屏的内容区因此矮 22px，
        再按权重分配，形成「顶部几乎不动、底部上移 22px」的梯度偏移。
      - spread = dy 的 p90−p10 → **信息**。Tab 屏的梯度会把 spread 撑到 20-40px。
      - gapMedian = **判据**。相邻锚点的间距差中位数 |Δgap|。间距对整体平移与
        梯度分配都不敏感（两者对相邻两项的影响近似抵消），只有局部版式错乱
        （某元素单独跑偏、区内间距被改）才会把它撑大。这才是要找的病。

    为什么不用图像块对齐：内容块的切分对阴影渲染差异极敏感——Compose 的 shadow
    比 CSS box-shadow 更实，卡片与外框在 shot 里连成一片、ref 里被空白行分开
    （plan 屏实测 ref 11 块 vs shot 4 块），块数不等时配对无意义。
    """
    empty = {
        "yMedian": None, "ySpread": None, "gapMedian": None, "detail": [],
        "xMedian": None, "xSpanRatio": None, "leftGap": None, "rightGap": None,
    }
    if not proto_items or not dev_nodes:
        return empty

    sy = shot_size[1] / float(SCREEN_H)
    sx = shot_size[0] / float(SCREEN_W)
    detail, dys, dxs, ref_xs = [], [], [], []
    for item in proto_items:
        cands = [n for n in dev_nodes if n["text"] == item["text"]]
        if not cands:
            cands = [n for n in dev_nodes
                     if item["text"] in n["text"] or n["text"] in item["text"]]
        if not cands:
            continue
        best = min(cands, key=lambda n: abs(n["cy"] / sy - item["y"]))
        dev_y, dev_x = best["cy"] / sy, best["cx"] / sx
        dy, dx = dev_y - item["y"], dev_x - item["x"]
        dys.append(dy)
        dxs.append(dx)
        ref_xs.append(item["x"])
        detail.append([item["text"], item["y"], round(dev_y, 1), round(dy, 1),
                       item["x"], round(dev_x, 1), round(dx, 1)])

    if not dys:
        return empty

    ordered = sorted(dys)
    p10 = ordered[int(len(ordered) * 0.1)]
    p90 = ordered[min(int(len(ordered) * 0.9), len(ordered) - 1)]

    seq = sorted(detail, key=lambda r: r[1])
    gaps = [abs((seq[i][2] - seq[i - 1][2]) - (seq[i][1] - seq[i - 1][1]))
            for i in range(1, len(seq))]

    # 横向：先取 dx 的**中位数**作稳健基准，再**剔除离群锚点**后取左右边距。
    #
    # 必须剔除的原因：原型里不少元素是整宽块（rect 中心 = 容器中心），而设备侧同一个
    # Text 是紧贴文字的窄盒——两者盒中心能差上百 px（login 屏「密码」实测 dx=-162.5，
    # register 屏四个字段标签同理）。那是**标记差异**，不是几何错位；不剔除就会把
    # 它当成版式缺陷，让判据对「真实整屏位移」失去分辨力。
    #
    # 剔除后仍能抓「整屏缩放/平移」：平移让所有锚点 dx 同号同量（中位数即为该量），
    # 等比缩放让 dx 随 x 线性变化（中位数附近的那批锚点的极值随之改变）。
    x_median = sorted(dxs)[len(dxs) // 2]
    kept = [(rx, dx) for rx, dx in zip(ref_xs, dxs)
            if abs(dx - x_median) <= X_MARGIN_TOLERANCE]
    if len(kept) < 2:
        kept = list(zip(ref_xs, dxs))
    ref_kept = [rx for rx, _ in kept]
    dev_kept = [rx + dx for rx, dx in kept]
    ref_span, dev_span = max(ref_kept) - min(ref_kept), max(dev_kept) - min(dev_kept)
    return {
        "yMedian": round(sorted(abs(d) for d in dys)[len(dys) // 2], 1),
        "ySpread": round(p90 - p10, 1),
        "gapMedian": round(sorted(gaps)[len(gaps) // 2], 1) if gaps else None,
        "detail": detail,
        "xMedian": round(abs(x_median), 1),
        "xSpanRatio": round(dev_span / ref_span, 3) if ref_span > 0 else None,
        "leftGap": round(abs(min(dev_kept) - min(ref_kept)), 1),
        "rightGap": round(abs(max(dev_kept) - max(ref_kept)), 1),
        "xAnchorsKept": len(kept),
    }


# 时刻字面量：`mm:ss` 或 `h:mm:ss`（如「总时长」的计时器）。
# 它是**随时间变化**的文本，两侧天然不同时刻取值，逐字比对没有意义。
CLOCK_RE = re.compile(r"\b\d{1,3}:\d{2}(?::\d{2})?\b")


def normalize_clock(s):
    """把时刻字面量替换为固定记号 `<clock>`，用于跨时刻的文本集合比对。"""
    return CLOCK_RE.sub("<clock>", s)


def match_texts(protos, devs):
    """
    双向包含匹配（宽松）：原型文案与设备文案只要一方包含另一方即算命中。
    原因：同一句文案在原型里可能被行内元素拆成多个文本节点、或含 `<br>`，
    而 Compose 侧是一个 Text，精确相等会误报缺失（假红）。

    比对前先归一化：
    1. 空白（连续空白 → 单个空格）：原型 `<h1>A<br>B</h1>` 的直接文本节点被
       join 成 "A B"，设备侧同一个 Text 里是 "A\\nB"。
    2. **时刻字面量**（见 [normalize_clock]）：`active` 屏的「总时长」每秒自增，
       参照图取的是加载态 `00:00`、设备在截图时刻已是 `00:02`，逐字比对必假红。
       归一为同一记号后仍保留**存在性**检查（设备若根本没有时钟，该条依旧缺失）。
    另给出精确匹配的缺失清单（严格），供人工判断用。
    """
    def norm(s):
        return normalize_clock(re.sub(r"\s+", " ", s).strip())

    dev_norm = [norm(d) for d in devs]
    proto_norm = [norm(p) for p in protos]

    missing_strict, missing_loose = [], []
    for t in protos:
        nt = norm(t)
        if nt in dev_norm:
            continue
        if any(nt in d or d in nt for d in dev_norm):
            continue
        missing_loose.append(t)
        missing_strict.append(t)

    extra = [d for d in dev_norm
             if d and d not in proto_norm
             and not any(p in d or d in p for p in proto_norm)]
    return missing_strict, missing_loose, extra


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--route", required=True)
    ap.add_argument("--frame", required=True)
    ap.add_argument("--html", required=True)
    ap.add_argument("--apk", default=os.path.join(ROOT, "app", "build", "outputs", "apk", "debug", "app-debug.apk"))
    ap.add_argument("--skip-install", action="store_true")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    html = args.html if os.path.isabs(args.html) else os.path.join(ROOT, args.html)
    if not os.path.isfile(html):
        sys.exit(f"原型 HTML 不存在：{html}")

    print(f"[1/5] 渲染参照图 … {args.frame}")
    ref_path = render_ref(html, args.frame, args.route)

    # 先取原型文本：capture_device 用它做「深链是否真的落地」的校验与重试
    print("[2/5] 提取原型文本 …")
    proto = proto_texts(html, args.frame)

    print(f"[3/5] 设备截图 … fittracker://{args.route}")
    shot_path, ui_xml, dev_texts, dev_nodes = capture_device(
        args.route, args.apk, args.skip_install, expected=proto["texts"])

    print("[4/5] 合成并排图 + 像素探针 …")
    ref_img = Image.open(ref_path).convert("RGB")
    shot_img = Image.open(shot_path).convert("RGB")
    shot_scaled = shot_img.resize(ref_img.size, Image.LANCZOS) if shot_img.size != ref_img.size else shot_img

    cmp_dir = os.path.join(ROOT, ".rivet", "scratch", "cmp")
    os.makedirs(cmp_dir, exist_ok=True)
    side_path = os.path.join(cmp_dir, f"side2-{args.route}.png")
    w, h = ref_img.size
    canvas = Image.new("RGB", (w * 2 + 16, h), (24, 24, 24))
    canvas.paste(ref_img, (0, 0))
    canvas.paste(shot_scaled, (w + 16, 0))
    canvas.save(side_path)

    bg_ref = background_color(ref_img)
    bg_shot = background_color(shot_scaled)
    bg_delta = max(abs(a - b) for a, b in zip(bg_ref, bg_shot))

    # 内容块计数仅作诊断（判据已改用文案坐标对齐，见 position_shift 的说明）
    ref_blocks = content_blocks(ref_img, bg_ref)
    shot_blocks = content_blocks(shot_scaled, bg_shot)
    shift = position_shift(proto["items"], dev_nodes, shot_img.size)

    print("[5/5] 文本集合比对 …")
    missing_strict, missing_loose, extra = match_texts(proto["texts"], dev_texts)

    x_ok = (shift["leftGap"] is not None and shift["rightGap"] is not None
            and shift["leftGap"] <= X_MARGIN_TOLERANCE
            and shift["rightGap"] <= X_MARGIN_TOLERANCE)
    verdict = {
        "bg": "PASS" if bg_delta <= BG_TOLERANCE else "FAIL",
        "position": "PASS" if (shift["gapMedian"] is not None
                               and shift["gapMedian"] <= POSITION_SHIFT_TOLERANCE) else "FAIL",
        "x-margin": "PASS" if x_ok else "FAIL",
        "texts": "PASS" if not missing_loose else "FAIL",
    }
    summary = {
        "route": args.route,
        "frame": args.frame,
        "refSize": list(ref_img.size),
        "shotSize": list(shot_img.size),
        "bgRef": list(bg_ref),
        "bgShot": list(bg_shot),
        "bgDelta": bg_delta,
        "posShiftMedian": shift["yMedian"],
        "posShiftSpread": shift["ySpread"],
        "posGapMedian": shift["gapMedian"],
        "posAnchorPairs": shift["detail"],
        "posXShiftMedian": shift["xMedian"],
        "posXSpanRatio": shift["xSpanRatio"],
        "posLeftGap": shift["leftGap"],
        "posRightGap": shift["rightGap"],
        "posXAnchorsKept": shift["xAnchorsKept"],
        "refBlocks": len(ref_blocks),
        "shotBlocks": len(shot_blocks),
        "refTextCount": len(proto["texts"]),
        "devTextCount": len(dev_texts),
        "missingStrict": missing_strict,
        "missingLoose": missing_loose,
        "extraTexts": extra,
        "sideBySide": os.path.relpath(side_path, ROOT).replace("\\", "/"),
        "shot": os.path.relpath(shot_path, ROOT).replace("\\", "/"),
        "uiXml": os.path.relpath(ui_xml, ROOT).replace("\\", "/"),
        "verdict": verdict,
        "overall": "GREEN" if all(v == "PASS" for v in verdict.values()) else "RED",
    }

    out_path = args.out or os.path.join(ROOT, ".rivet", "scratch", f"accept-{args.route}.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    print(json.dumps({k: summary[k] for k in
                      ("route", "bgDelta", "posGapMedian", "posShiftMedian", "posShiftSpread",
                       "posLeftGap", "posRightGap", "posXShiftMedian", "posXSpanRatio",
                       "refTextCount", "devTextCount")}, ensure_ascii=False))
    print(f"缺失(严格)：{missing_strict}")
    print(f"缺失(宽松)：{missing_loose}")
    print(f"多出(设备侧)：{extra[:8]}{' …' if len(extra) > 8 else ''}")
    print(f"判据：{verdict}  →  {summary['overall']}")
    print(f"摘要落盘：{os.path.relpath(out_path, ROOT)}")
    print(f"并排图：{summary['sideBySide']}")

    return 0 if summary["overall"] == "GREEN" else 1


if __name__ == "__main__":
    sys.exit(main())
