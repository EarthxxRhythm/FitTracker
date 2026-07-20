# FitTracker Design Base

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
