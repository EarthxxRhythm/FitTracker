# 菲特 Design Base

> **层级**：L2 展开
> **最后核对**：2026-10-27
> **上位文档**：仓库根 `AGENTS.md`（L1）；视觉 token 的实际实现以 `apps\harmony\entry\src\main\ets\common\styles\DesignTokens.ets` 与安卓 `ui\theme\DuTokens.kt` 为准
> **状态**：现行
> **路径基准**：文中 `design\…` 相对仓库根
> **适用端**：双端

This directory is the design foundation for AI-assisted UI/UX and visual refactoring.

It exists to prevent the project from drifting into:
- generic dark-mode UI
- inconsistent component styling
- page-by-page aesthetic guessing
- engineering-clean but visually mediocre redesigns

## Current priority files
Start with these files before making visible UI changes:

1. `01_brief/product_vision.md`
2. `01_brief/visual_direction.md`
3. `03_design_system/colors.md`
4. `05_page_specs/home.md`

## Working rule
For user-visible changes, AI should read:
- brief first
- references second
- design-system rules third
- component specs fourth
- page spec fifth

Then implement and verify.

---

## Third-party skill boundary: `ui-ux-pro-max`

Installed at `.rivet\skills\ui-ux-pro-max\` and **callable** — but only via its audit layer.

**Do not use its `--design-system` output for this project.** Measured 2026-10-28 with
`"fitness training tracker dark performance"`: it returns Primary `#F97316` (orange),
Accent `#22C55E`, typography Barlow Condensed / Barlow. That is the **opposite** direction
from the frozen Cold Emerald `#50ECA7` + HarmonyOS Sans, and applying it would discard the
locked decisions in `01_brief/visual_direction.md` and the 15-screen convergence baseline.
Its stack table also ships `jetpack-compose` but **no ArkUI** entry.

**Use it as an audit ruler, not a source of design direction:**

- `references/quick-reference.md` — 119 UX rules over 10 categories (accessibility, touch,
  typography/color, motion, forms, navigation, charts)
- `references/pro-rules.md` — canonical pre-delivery checklist for native/mobile app UI
  (icon discipline, tap feedback, dark-mode contrast, safe areas)

Judgement authority stays with this repository: frozen prototype → `TOKENS.md` → this file.

**Running it.** System `python` on this machine is a Windows Store execution-alias stub
(`AppData\Local\Microsoft\WindowsApps\python.exe`), not a real interpreter. Use `uv`:

```bash
uv run --no-project --python 3.12 python \
  .rivet/skills/ui-ux-pro-max/scripts/search.py "<query>" --domain ux
```

Prefer one observable outcome per query (`"error summary validation" --domain ux`) over an
audit checklist. Treat every result as a recommendation to weigh against the prototype.

