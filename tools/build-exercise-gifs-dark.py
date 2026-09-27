#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""生成训练演示用的深色化动作 GIF。

动机：rawfile/exercise-gifs 的动作演示素材是**白底**方图（动作库页在浅色媒体区里使用）。
训练执行页的动作卡是整块深色界面，直接铺白底 GIF 会形成一整块高亮白。
改为离线预烘焙而非在 ArkUI 侧叠加 grayscale/invert/brightness：预烘焙结果确定、
可逐帧离线核对，也不让页面依赖多个图像效果叠加时的生效顺序。

处理：去色 -> 反相（白底翻黑底、深色线条翻浅色线条）-> 提亮（反相后线条偏暗，
2.1 倍增益把动作线稿抬到可读亮度，黑底不受影响）。

产物：entry/src/main/resources/rawfile/exercise-gifs-dark/<gifId>.gif
消费方：shared/services/ExerciseGifCatalog.resolveDemoSource()

用法：python tools/build-exercise-gifs-dark.py
"""

import os
import sys

from PIL import Image, ImageEnhance, ImageOps

GAIN = 2.1

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(REPO, 'entry/src/main/resources/rawfile/exercise-gifs')
OUT_DIR = os.path.join(REPO, 'entry/src/main/resources/rawfile/exercise-gifs-dark')



def convert_frame(frame):
    gray = ImageOps.grayscale(frame.convert('RGB'))
    inverted = ImageOps.invert(gray.convert('RGB'))
    brightened = ImageEnhance.Brightness(inverted).enhance(GAIN)
    return brightened.convert('P', palette=Image.ADAPTIVE, colors=256)


def convert_file(name):
    src_path = os.path.join(SRC_DIR, name)
    out_path = os.path.join(OUT_DIR, name)
    with Image.open(src_path) as im:
        durations = []
        frames = []
        try:
            while True:
                durations.append(im.info.get('duration', 80))
                frames.append(convert_frame(im))
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
    print('共 %d 个，源 %.1f MB -> 深色 %.1f MB' % (len(names), total_src / 1048576.0, total_out / 1048576.0))
    return 0


if __name__ == '__main__':
    sys.exit(main())
