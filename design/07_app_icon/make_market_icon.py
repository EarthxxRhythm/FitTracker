# -*- coding: utf-8 -*-
"""菲特 应用市场图标素材生成（可复现管线）

来源（与包内图标逐字节相同的两份分层图层）：
  AppScope/resources/base/media/background.png  1024x1024 RGB  满幅微光晕底
  AppScope/resources/base/media/foreground.png  1024x1024 RGBA 透明底进度环符号
  sha256(bg)=87de5373...  sha256(fg)=9d70d356...  与 design/07_app_icon/master/ 一致

合成口径：与 startIcon.png 相同——background + foreground 做 alpha 合成，再缩放。
产出（design/07_app_icon/market/）：
  icon-1024.png   1024x1024  不透明  PNG  <= 3 MB
  icon-216.png    216x216    不透明  PNG  <= 3 MB
  icon-1024.webp  1024x1024  不透明  WEBP <= 100 KB
  icon-216.webp   216x216    不透明  WEBP <= 100 KB
  icon-100.png    100x100    不透明  PNG  开放平台表单「上传移动应用图标 100X100(px)」用

市场规范：正方形；216x216 或 1024x1024；PNG(<=3MB) / WEBP(<=100KB)；
须与软件包内应用图标一致。提交满幅方图（不预切圆角），圆角由平台统一处理。

⚠ 100×100 的来历：QQ 互联 / 应用宝的「创建移动应用」表单明确要求
  「请上传 100*100（px）的应用图标」，与市场素材的 216/1024 口径不同，故单独产出。

用法：python design/07_app_icon/make_market_icon.py
"""
from pathlib import Path
import sys

from PIL import Image

# Windows 控制台默认 GBK，中文断言输出会乱码
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[2]
# ⚠ 2026-10-12 monorepo 重组后鸿蒙工程下移至 apps/harmony/，
# 图标源在 apps/harmony/AppScope/resources/base/media/（原仓库根 AppScope 已不存在）
SRC = ROOT / "apps" / "harmony" / "AppScope" / "resources" / "base" / "media"
OUT = Path(__file__).resolve().parent / "market"

# 1024/216 = 应用市场素材；100 = 开放平台注册表单要求的 100×100
SIZES = (1024, 216, 100)
PNG_LIMIT = 3 * 1024 * 1024
WEBP_LIMIT = 100 * 1024

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)
    print(("  OK   " if cond else "  FAIL ") + msg)


def main():
    bg = Image.open(SRC / "background.png").convert("RGBA")
    fg = Image.open(SRC / "foreground.png").convert("RGBA")
    check(bg.size == (1024, 1024), "background.png 尺寸 %s" % (bg.size,))
    check(fg.size == (1024, 1024), "foreground.png 尺寸 %s" % (fg.size,))
    check(bg.size == fg.size, "两图层尺寸一致")

    # 合成：底为不透明满幅，符号叠加于上；结果强制 RGB（无 alpha，市场不透明口径）
    master = Image.alpha_composite(bg, fg).convert("RGB")
    check(master.size == (1024, 1024), "合成母版 1024x1024")

    OUT.mkdir(exist_ok=True)
    for size in SIZES:
        img = master if size == 1024 else master.resize((size, size), Image.LANCZOS)
        # 正方形
        check(img.size[0] == img.size[1] == size,
              "icon-%d 正方形 %dx%d" % (size, size, size))

        png = OUT / ("icon-%d.png" % size)
        img.save(png, "PNG", optimize=True)
        check(png.stat().st_size <= PNG_LIMIT,
              "%s 大小 %d B <= 3 MB" % (png.name, png.stat().st_size))

        webp = OUT / ("icon-%d.webp" % size)
        img.save(webp, "WEBP", quality=90, method=6)
        check(webp.stat().st_size <= WEBP_LIMIT,
              "%s 大小 %d B <= 100 KB" % (webp.name, webp.stat().st_size))

    print()
    print("产出目录：%s" % OUT)
    if failures:
        print("失败 %d 项：" % len(failures))
        for f in failures:
            print("  - " + f)
        return 1
    print("全部断言通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
