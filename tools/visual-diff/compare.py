#!/usr/bin/env python3
"""Compare a rendered prototype PNG against an emulator screenshot PNG.

Usage:
    python compare.py <prototype.png> <screenshot.png> [--out report.md] [--density 3.3846]

The prototype is assumed to be at logical viewport size (e.g. 390x844). The screenshot is
assumed to be at physical resolution (logical * density). This script resizes the screenshot
down to the prototype's logical size, then produces:

  * a structured Markdown TEXT report (primary artifact, for image-less consumers):
      - image dimensions + density factor
      - overall mean absolute error (per channel, 0-255)
      - % of pixels differing beyond a threshold (default 16/255)
      - per-row-band difference table (~10 horizontal bands) to localize vertically
      - per-quadrant difference table to localize horizontally
  * two human-readable PNGs saved next to the report:
      <out>.sidebyside.png   (prototype | screenshot)
      <out>.heatmap.png      (difference heatmap)

Requires Pillow only (no numpy).
"""

import argparse
import os
import sys

from PIL import Image, ImageChops, ImageStat, ImageOps


def load_rgb(path):
    with Image.open(path) as im:
        return im.convert('RGB')


def region_stats(gray, threshold):
    """Return (mean_diff_0_255, percent_pixels_beyond_threshold) for a grayscale crop."""
    hist = gray.histogram()
    total = sum(hist)
    if total == 0:
        return 0.0, 0.0
    mean = sum(i * h for i, h in enumerate(hist)) / float(total)
    beyond = sum(hist[threshold + 1:])
    return mean, 100.0 * beyond / float(total)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('prototype', help='rendered prototype PNG (logical size)')
    ap.add_argument('screenshot', help='emulator screenshot PNG (physical size)')
    ap.add_argument('--out', default='report.md', help='report path (default: report.md)')
    ap.add_argument('--density', type=float, default=3.3846, help='px/vp density factor')
    ap.add_argument('--threshold', type=int, default=16, help='diff threshold (0-255)')
    ap.add_argument('--bands', type=int, default=10, help='number of row bands')
    ap.add_argument('--crop', default=None,
                    help='logical-row crop as y0,y1 (e.g. 100,740) to measure a content region only')
    ap.add_argument('--ignore-rect', action='append', default=[], metavar='x0,y0,x1,y1',
                    help='logical rect(s) to ignore in stats/artifacts (e.g. seed-value text zones). Repeatable.')
    args = ap.parse_args(argv)

    for p in (args.prototype, args.screenshot):
        if not os.path.isfile(p):
            print('ERROR: file not found: %s' % p, file=sys.stderr)
            return 2

    proto = load_rgb(args.prototype)
    shot = load_rgb(args.screenshot)

    pw, ph = proto.size
    sw, sh = shot.size

    # Align: bring the screenshot down to the prototype's logical pixel size.
    aligned = shot if (sw, sh) == (pw, ph) else shot.resize((pw, ph), Image.LANCZOS)

    # Optional content-region crop (logical rows). All metrics then describe only that band.
    if args.crop is not None:
        try:
            y0, y1 = [int(v) for v in args.crop.split(',')]
        except Exception:
            print('ERROR: --crop expects y0,y1 integers', file=sys.stderr)
            return 2
        y0 = max(0, min(y0, ph))
        y1 = max(y0 + 1, min(y1, ph))
        proto = proto.crop((0, y0, pw, y1))
        aligned = aligned.crop((0, y0, pw, y1))
        ph = y1 - y0

    # Optional ignore rects (logical px in the final, possibly cropped, space).
    ignore_boxes = []
    for spec in args.ignore_rect:
        try:
            x0, y0, x1, y1 = [int(v) for v in spec.split(',')]
        except Exception:
            print('ERROR: --ignore-rect expects x0,y0,x1,y1 integers', file=sys.stderr)
            return 2
        ignore_boxes.append((x0, y0, x1, y1))
    if ignore_boxes:
        from PIL import ImageDraw
        black = Image.new('RGB', (pw, ph), (0, 0, 0))
        mask = Image.new('L', (pw, ph), 0)
        dr = ImageDraw.Draw(mask)
        for (x0, y0, x1, y1) in ignore_boxes:
            x0 = max(0, min(x0, pw))
            x1 = max(x0 + 1, min(x1, pw))
            y0 = max(0, min(y0, ph))
            y1 = max(y0 + 1, min(y1, ph))
            dr.rectangle([x0, y0, x1, y1], fill=255)
        proto = Image.composite(black, proto, mask)
        aligned = Image.composite(black, aligned, mask)

    diff = ImageChops.difference(proto, aligned)   # per-channel abs diff
    gray = diff.convert('L')                        # luminance-weighted single channel

    # Overall mean absolute error (average across the 3 channels, 0-255).
    stat = ImageStat.Stat(diff)
    mae = sum(stat.mean) / 3.0

    # % pixels beyond threshold.
    overall_mean, overall_pct = region_stats(gray, args.threshold)

    # Per-row-band stats.
    bands = []
    band_h = ph // args.bands
    for i in range(args.bands):
        y0 = i * band_h
        y1 = ph if i == args.bands - 1 else (i + 1) * band_h
        crop = gray.crop((0, y0, pw, y1))
        mean, pct = region_stats(crop, args.threshold)
        bands.append((i, y0, y1, mean, pct))

    # Per-quadrant stats.
    midx, midy = pw // 2, ph // 2
    quads = [
        ('top-left', (0, 0, midx, midy)),
        ('top-right', (midx, 0, pw, midy)),
        ('bottom-left', (0, midy, midx, ph)),
        ('bottom-right', (midx, midy, pw, ph)),
    ]
    quad_stats = []
    for name, box in quads:
        crop = gray.crop(box)
        mean, pct = region_stats(crop, args.threshold)
        quad_stats.append((name, mean, pct))

    # Human-readable artifacts.
    base = os.path.splitext(args.out)[0]
    side_path = base + '.sidebyside.png'
    heat_path = base + '.heatmap.png'

    gap = 4
    side = Image.new('RGB', (pw * 2 + gap, ph), (20, 20, 20))
    side.paste(proto, (0, 0))
    side.paste(aligned, (pw + gap, 0))
    side.save(side_path)

    heat = ImageOps.colorize(gray, black=(8, 8, 40), white=(255, 0, 0), mid=(255, 220, 0))
    heat.save(heat_path)

    # Build the Markdown report.
    sorted_bands = sorted(bands, key=lambda b: -b[4])
    sorted_quads = sorted(quad_stats, key=lambda q: -q[2])
    lines = []
    lines.append('# Visual Diff Report')
    lines.append('')
    lines.append('## Inputs')
    lines.append('')
    lines.append('| Field | Value |')
    lines.append('| --- | --- |')
    lines.append('| Prototype | `%s` (%dx%d) |' % (args.prototype, pw, ph))
    lines.append('| Screenshot (raw) | `%s` (%dx%d) |' % (args.screenshot, sw, sh))
    lines.append('| Screenshot (aligned) | %dx%d |' % (pw, ph))
    lines.append('| Density factor | %g px/vp |' % args.density)
    lines.append('| Diff threshold | %d / 255 |' % args.threshold)
    lines.append('')
    lines.append('## Overall')
    lines.append('')
    lines.append('- Mean absolute error (per channel): **%.2f / 255**' % mae)
    lines.append('- Pixels differing beyond threshold: **%.2f %%**' % overall_pct)
    lines.append('')
    lines.append('## Row-band differences (top -> bottom)')
    lines.append('')
    lines.append('| Band | Y range (vp) | Mean diff | % beyond threshold |')
    lines.append('| --- | --- | --- | --- |')
    for i, y0, y1, mean, pct in bands:
        lines.append('| %d | %d-%d | %.2f | %.2f %% |' % (i, y0, y1, mean, pct))
    lines.append('')
    lines.append('## Quadrant differences')
    lines.append('')
    lines.append('| Quadrant | Mean diff | % beyond threshold |')
    lines.append('| --- | --- | --- |')
    for name, mean, pct in quad_stats:
        lines.append('| %s | %.2f | %.2f %% |' % (name, mean, pct))
    lines.append('')
    lines.append('## Localization summary')
    lines.append('')
    lines.append('- Largest row-bands: %s'
                 % ', '.join('band %d (%.1f%%)' % (i, pct) for i, _, _, _, pct in sorted_bands[:3]))
    lines.append('- Largest quadrant: %s (%.1f%%)' % (sorted_quads[0][0], sorted_quads[0][2]))
    lines.append('')
    lines.append('## Artifacts')
    lines.append('')
    lines.append('- Side-by-side: `%s`' % side_path)
    lines.append('- Heatmap: `%s`' % heat_path)
    lines.append('')

    report = '\n'.join(lines)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, 'w', encoding='utf-8') as fh:
        fh.write(report)

    print('overall MAE=%.2f  beyond-threshold=%.2f%%' % (mae, overall_pct))
    print('report: %s' % args.out)
    print('side-by-side: %s' % side_path)
    print('heatmap: %s' % heat_path)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
