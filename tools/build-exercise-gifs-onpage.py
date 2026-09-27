#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""生成"落在页面底色上"的动作演示 GIF（合成而非抠图）。

背景：训练执行页的动作卡要求图片背景跟随页面底色，且动作要看得清。
走过的两条弯路与其根因：
  ① 直接铺白底素材 —— 深色页面上是一整块刺眼的白；
  ② 把白底抠成透明 —— GIF 只有 1 bit 透明，抗锯齿边被阈值化成硬边，锯齿明显。
本方案不走 alpha 通道：**把原图按亮度软过渡合成到页面底色上**，输出不透明 GIF。
- 颜色不动（不做反相、不抬暗部），人体浅色与红色高光保持原样；
- 白底区合成后即页面底色，与卡面/页面无缝；
- 边缘是逐像素插值得到的连续过渡，没有 1 bit 阈值，故无锯齿。

注意：背景色被烘进素材，页面底色一变就要重跑本脚本（PAGE_BG 需与
ActiveContent 根容器底色一致）。

产物：entry/src/main/resources/rawfile/exercise-gifs-onpage/<gifId>.gif
消费方：shared/services/ExerciseGifCatalog.resolveDemoSource()
        （配合 ActiveContent.demoVisual 的卡面不设底色）

用法：python tools/build-exercise-gifs-onpage.py
"""

import os
import sys

from PIL import Image

# 页面底色，须与 ActiveContent 根容器 backgroundColor 一致
PAGE_BG = (11, 15, 19)  # #0B0F13
# 白底判定与软过渡宽度：亮度 >= WHITE 视为纯背景；到 SOFT 之间线性过渡。
WHITE = 250
SOFT = 45

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(REPO, 'entry/src/main/resources/rawfile/exercise-gifs')
OUT_DIR = os.path.join(REPO, 'entry/src/main/resources/rawfile/exercise-gifs-onpage')


def compose_on_page(frame):
    rgb = frame.convert('RGB')
    pixels = list(rgb.getdata())
    out = []
    for r, g, b in pixels:
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        if lum >= WHITE:
            out.append(PAGE_BG)
            continue
        k = 1.0
        if lum > WHITE - SOFT:
            k = (WHITE - lum) / float(SOFT)
        out.append((
            int(PAGE_BG[0] + (r - PAGE_BG[0]) * k),
            int(PAGE_BG[1] + (g - PAGE_BG[1]) * k),
            int(PAGE_BG[2] + (b - PAGE_BG[2]) * k),
        ))
    composed = Image.new('RGB', rgb.size)
    composed.putdata(out)
    return composed.convert('P', palette=Image.ADAPTIVE, colors=256)


def convert_file(name):
    src_path = os.path.join(SRC_DIR, name)
    out_path = os.path.join(OUT_DIR, name)
    with Image.open(src_path) as im:
        durations = []
        frames = []
        try:
            while True:
                durations.append(im.info.get('duration', 80))
                frames.append(compose_on_page(im))
                im.seek(im.tell() + 1)
        except EOFError:
            pass
        loop = im.info.get('loop', 0)
    frames[0].save(
        out_path,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=loop,
        disposal=2,
        optimize=True,
    )
    return len(frames), os.path.getsize(out_path)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    names = sorted(n for n in os.listdir(SRC_DIR) if n.endswith('.gif'))
    if not names:
        print('未找到源 GIF：' + SRC_DIR)
        return 1
    total_src = 0
    total_out = 0
    for name in names:
        frames, size = convert_file(name)
        total_src += os.path.getsize(os.path.join(SRC_DIR, name))
        total_out += size
        print('  %-24s frames=%-3d out=%6.1f KB' % (name, frames, size / 1024.0))
    print('共 %d 个，源 %.1f MB -> 合成 %.1f MB' % (len(names), total_src / 1048576.0, total_out / 1048576.0))
    return 0


if __name__ == '__main__':
    sys.exit(main())
