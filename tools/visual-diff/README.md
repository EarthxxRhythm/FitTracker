# visual-diff — prototype vs. app screenshot comparator

Compares an HTML design prototype against an emulator screenshot of the running app, and
emits a **structured text (Markdown) report** with numeric localization. The consuming
agent has no image input, so the report (mean absolute error, % pixels beyond threshold,
per-row-band and per-quadrant differences) is the primary artifact; the PNGs are for humans.

## Files

| File | Purpose |
| --- | --- |
| `render-prototype.py` | Render an HTML prototype to a phone-viewport PNG via headless Edge/Chrome. |
| `capture-screenshot.ps1` | Capture the HarmonyOS emulator screen (hdc) and convert `.jpeg` → `.png`. |
| `compare.py` | Align the two images, emit the Markdown report + side-by-side + heatmap PNGs. |

## Pipeline

```powershell
# 1. Render the prototype (auto-detects 390x844 from `.phone`; `--screen 0` = first frame).
python tools/visual-diff/render-prototype.py "<html>" .omo/evidence/visual-diff/prototype.png

# 2. Capture the running app (emulator 127.0.0.1:5555).
.\tools\visual-diff\capture-screenshot.ps1 -Out .omo/evidence/visual-diff/app.png

# 3. Compare and produce the report.
python tools/visual-diff/compare.py .omo/evidence/visual-diff/prototype.png .omo/evidence/visual-diff/app.png --out .omo/evidence/visual-diff/report.md
```

## Render flags

- `--width/--height` override the auto-detected viewport (default 390x844).
- `--screen <index>` picks which frame to render (0-based). The Open Design HTML is a
  gallery of `.frame-card` figures; `--screen 0` is the first screen. Use `--screen 1` for
  the second (e.g. the home screen when the file bundles welcome + home).
- `--hide-scrollbars` is on by default.

## Compare flags

- `--density` px/vp factor (default 3.3846). The screenshot is resized down to the
  prototype's logical size before diffing.
- `--threshold` per-pixel diff threshold for the "% beyond threshold" metric (default 16).
- `--bands` number of horizontal row bands (default 10).

## Reading the report

- **Mean absolute error** and **% beyond threshold** = overall how different the two are.
- **Row-band table** tells you *vertically* where the biggest differences are (top band ≈
  status bar / header, bottom band ≈ tab bar).
- **Quadrant table** tells you *horizontally* where the biggest differences are.
- The largest bands/quadrants are summarized under **Localization summary**.

## Dependencies

- Python 3.11 + Pillow (`pip install pillow` if missing).
- Edge or Chrome headless (auto-detected; standard Windows install paths are checked).
- HarmonyOS `hdc` at
  `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`.
