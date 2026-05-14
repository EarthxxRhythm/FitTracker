# UI/UX System Redesign — Token-First Design System (ArkUI Native)

## TL;DR
> **Summary**: Extend DesignTokens, extract 6 missing reusable components, fix ~20 hardcoded values across all 9 pages, add design-decision annotations throughout.
> **Deliverables**: Updated DesignTokens.ets (MusclePalette + 10 size tokens + RadiusTokens.XS), 6 new components, 9 page fixes, DESIGN_DECISIONS.md
> **Effort**: Medium
> **Parallel**: YES — 4 waves
> **Critical Path**: Wave 1 (Tokens) → Wave 2 (Components) → Wave 3 (Pages) → Wave 4 (Verify)

## Context
### Original Request
User wants a professional UI/UX design system applying Tailwind CSS (token-first) and shadcn/ui (composable components) philosophy — translated to ArkUI native. Requirements: white bg + card + shadow default, industry standards for ambiguous decisions, design decisions annotated in code, functional completeness first.

### Interview Summary
- **Scope**: Full clean — tokens + components + pages
- **Order**: Tokens → Components → Pages (dependency-driven)
- **Design Decisions**: Inline `// DESIGN:` comments + DESIGN_DECISIONS.md catalog
- **Test Strategy**: Agent-executed QA only (grep checks, visual verification)
- **Existing State**: DesignTokens.ets is comprehensive (23 colors, 8 fonts, 7 spacing, 4 radii, 4 shadows, dark mode). 5 components are token-compliant.

### Metis Review (gaps addressed)
- Token naming conventions defined before implementation (follow existing UPPER_CASE pattern)
- DarkColorTokens must cover ALL new tokens (added to Wave 1)
- Component API specs must be explicit (detailed in each task)
- Migration mapping of every hardcoded value → target token (detailed in Wave 3 tasks)
- Accessibility/contrast: muscle colors are decorative badges, not critical text — fallback (#999) used as MUSCLE_DEFAULT
- Scope locked per wave; DESIGN_DECISIONS.md created in Wave 1

## Work Objectives
### Core Objective
Establish a token-first design system where every visual value in every file sources from DesignTokens.ets, all duplicate UI patterns are extracted into reusable components, and every design decision is documented and adjustable.

### Deliverables
1. **DesignTokens.ets** — Add MusclePalette colors, 10 missing size tokens, RadiusTokens.XS, DarkColorToken equivalents
2. **DESIGN_DECISIONS.md** — Catalog of all design decisions with rationale and adjustment points
3. **6 new components**: EmptyState, SegmentedControl, SearchBar, Chip/Tag, PageHeader, MuscleColorMap
4. **9 page fixes** — Replace all hardcoded values, inline tabs, and duplicate getMuscleColor
5. **`// DESIGN:`** annotations at all decision points

### Definition of Done
```bash
# Zero hardcoded hex/rgba outside DesignTokens.ets
grep -rn '#[0-9A-Fa-f]\{3,8\}\|rgba(' entry/src/main/ets/ --include='*.ets' | grep -v DesignTokens.ets | grep -v AGENTS.md
# OUTPUT: (empty — 0 results)

# All new components exist with @Prop interfaces
ls entry/src/main/ets/components/
# OUTPUT includes: EmptyState.ets, SegmentedControl.ets, SearchBar.ets, Chip.ets, PageHeader.ets

# DESIGN_DECISIONS.md exists with all sections
test -f .sisyphus/drafts/DESIGN_DECISIONS.md && echo "EXISTS"

# Index.ets uses MainTabBar, not inline tabs
grep 'MainTabBar' entry/src/main/ets/pages/Index.ets
# OUTPUT: shows MainTabBar import/usage
```

### Must Have
- All visual values in DesignTokens.ets (no hardcoded colors/spacing/sizes in any .ets file)
- 6 extracted components with clean @Prop interfaces matching existing patterns
- Index.ets uses MainTabBar component
- All 3 getMuscleColor() duplicates replaced by single MuscleColorMap token reference
- DESIGN_DECISIONS.md with at minimum: Context, Token Strategy, Component API Design, Migration Map, Adjustment Points

### Must NOT Have
- Changes to business logic, navigation, or data flow
- New visual features (animations, new page layouts, new color themes beyond dark mode tokens)
- Changes to existing component APIs (AppButton, AppCard, AppInput, StatBadge — only fix internal token usage, no new props)
- Modifications to any .ets file outside entry/src/main/ets/
- Hardcoded `// DESIGN:` comments that are vague ("can adjust later") — must specify WHAT to adjust and WHY

## Verification Strategy
> ZERO HUMAN INTERVENTION — all verification is agent-executed.
- Test decision: agent-executed QA only (no unit test framework)
- QA policy: Every task has agent-executed grep/visual scenarios
- Evidence: .sisyphus/evidence/task-{N}-{slug}.{ext}

## Execution Strategy
### Parallel Execution Waves
> Each wave must complete before the next begins (dependency constraint). Tasks within a wave are parallelizable.

**Wave 1: Design Tokens Foundation** (4 tasks — categories: writing, quick, quick, quick)
**Wave 2: Reusable Components** (6 tasks — categories: visual-engineering ×6)
**Wave 3: Page Hardcoded-Fix Pass** (4 tasks — categories: quick ×4)
**Wave 4: Final Verification** (5 tasks — categories: oracle, unspecified-high, unspecified-high, deep, unspecified-low)

### Dependency Matrix
| Wave | Depends On | Parallel Within |
|------|-----------|----------------|
| Wave 1 | Nothing | YES — tasks 1-4 |
| Wave 2 | Wave 1 (tokens must exist) | YES — tasks 5-10 |
| Wave 3 | Wave 1 + 2 (tokens + components must exist) | YES — tasks 11-14 |
| Wave 4 | Wave 1 + 2 + 3 | YES — tasks F1-F5 |

### Agent Dispatch Summary
| Wave | Task Count | Categories |
|------|-----------|------------|
| Wave 1 | 4 | writing, quick, quick, quick |
| Wave 2 | 6 | visual-engineering, visual-engineering, visual-engineering, visual-engineering, visual-engineering, visual-engineering |
| Wave 3 | 4 | quick, quick, quick, quick |
| Wave 4 | 5 | oracle, unspecified-high, unspecified-high, deep, unspecified-low |

## TODOs

### Wave 1: Design Tokens Foundation

- [x] 1. Create DESIGN_DECISIONS.md skeleton

  **What to do**: 
  Create `.sisyphus/drafts/DESIGN_DECISIONS.md` with these sections:
  - **Context**: 1-paragraph summary of why this exists
  - **Token Strategy**: Naming conventions (UPPER_CASE, grouped by category), token hierarchy, when to add new tokens
  - **Component API Design**: @Prop pattern, no @State in components, one-way binding, callbacks for actions
  - **Migration Map**: Table mapping every hardcoded value → its replacement token (use the list from this plan)
  - **Adjustment Points**: List every `// DESIGN:` comment location with a note on what aspect can be adjusted and why the current choice was made
  - **Theming & Accessibility**: Dark mode strategy (muscle colors don't invert), contrast notes

  **Must NOT do**: Write implementation code. Purely documentation. Do not reference Tailwind or shadcn/ui — use ArkUI terminology.

  **Recommended Agent Profile**:
  - Category: `writing` — Reason: Pure documentation task
  - Skills: [] — No code skills needed

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: None | Blocked By: None

  **References**:
  - Pattern from this plan: `## Context`, `## Must NOT Have`, `## Success Criteria` sections
  - ArkUI component conventions: `entry/src/main/ets/components/AGENTS.md`

  **Acceptance Criteria** (agent-executable only):
  - [ ] `test -f .sisyphus/drafts/DESIGN_DECISIONS.md && echo "EXISTS"` succeeds
  - [ ] `grep -c '## ' .sisyphus/drafts/DESIGN_DECISIONS.md` returns ≥5 (at least 5 sections)
  - [ ] `grep 'Migration Map' .sisyphus/drafts/DESIGN_DECISIONS.md` returns match
  - [ ] `grep 'Adjustment Points' .sisyphus/drafts/DESIGN_DECISIONS.md` returns match

  **QA Scenarios** (MANDATORY):
  ```
  Scenario: DESIGN_DECISIONS.md is substantive (not a stub)
    Tool: Bash
    Steps: wc -l .sisyphus/drafts/DESIGN_DECISIONS.md
    Expected: ≥40 lines of content (excluding headers)
    Evidence: .sisyphus/evidence/task-1.doc-exists.txt
  ```

  **Commit**: YES | Message: `docs(design): create DESIGN_DECISIONS.md skeleton` | Files: `.sisyphus/drafts/DESIGN_DECISIONS.md`

---

- [x] 2. Add new design tokens to DesignTokens.ets

  **What to do**: 
  Add to `entry/src/main/ets/common/styles/DesignTokens.ets`:
  1. **RadiusTokens**: `static readonly XS: number = 4` — small element rounding (between existing SM=8 and nothing)
  2. **ColorTokens — Muscle Palette** (6 colors for muscle group badges):
     - `MUSCLE_CHEST: string = '#1E88E5'`
     - `MUSCLE_BACK: string = '#43A047'`
     - `MUSCLE_LEGS: string = '#FB8C00'`
     - `MUSCLE_SHOULDERS: string = '#8E24AA'`
     - `MUSCLE_ARMS: string = '#E53935'`
     - `MUSCLE_ABS: string = '#00897B'`
     - `MUSCLE_DEFAULT: string = '#999999'`
     // DESIGN: Muscle badge colors are decorative identity markers, not semantic UI colors. They stay fixed across light/dark modes by convention (low-contrast badges are acceptable). To change a muscle color, edit only the MUSCLE_* token — all pages update automatically.
  3. **FontTokens** (3 missing sizes):
     - `SUBHEADLINE_SIZE: number = 22`, `SUBHEADLINE_LINE_HEIGHT: number = 28`, `SUBHEADLINE_WEIGHT: number = FontWeight.Bold` — exercise card initial letter (between HEADLINE=20 and DISPLAY=28)
     - `HERO_SIZE: number = 48`, `HERO_LINE_HEIGHT: number = 56`, `HERO_WEIGHT: number = FontWeight.Bold` — exercise detail hero image initial letter
     - `MICRO_SIZE: number = 9`, `MICRO_LINE_HEIGHT: number = 12`, `MICRO_WEIGHT: number = FontWeight.Normal` — tiny badges inside muscle tags (smallest legible size)
     // DESIGN: MICRO_SIZE=9 is intentionally tiny — used only for inline muscle-chip labels where larger fonts would break the compact pill shape. If you change pill padding, adjust MICRO_SIZE too.
  4. **TouchTokens** (7 missing dimensions):
     - `SEGMENT_HEIGHT: number = 40` — segmented control button (taller than SMALL=36, shorter than DEFAULT=48)
     - `CARD_MEDIA_HEIGHT_SM: number = 72` — exercise card thumbnail
     - `CARD_COVER_SIZE: number = 64` — plan cover square (icon aspect)
     - `AVATAR_SIZE: number = 80` — profile avatar circle
     - `HERO_HEIGHT: number = 200` — exercise detail hero image
     - `TIMELINE_COL_WIDTH: number = 20` — plan timeline left column
     - `CALENDAR_CELL: number = 32` — stats calendar heatmap cell
     // DESIGN: These are "magic number" dimension tokens — they represent a specific UI element's size rather than a scale step. Each maps one UI element. If changing a component's layout, adjust its specific token, not the scale.
     - `MUSCLE_TAG_PADDING_V: number = 1` — tight vertical padding inside muscle chip
     - `MUSCLE_TAG_PADDING_H: number = 6` — tight horizontal padding inside muscle chip
  5. **SpacingTokens**: `static readonly XXXS: number = 2` — minimum spacing for atoms (between existing XS=4 and nothing)
  6. **DarkColorTokens**: Add all 6 MUSCLE_* + MUSCLE_DEFAULT with same hex values. Add comment: "// DESIGN: Muscle badge colors remain fixed across themes — they are identity markers (like team colors), not UI chrome. Switching them in dark mode would break muscle recognition."
  7. **MuscleColorMap** class (after existing classes, before DarkColorTokens):
     ```typescript
     /**
      * MuscleColorMap —— 肌群颜色查找
      * DESIGN: Central lookup replaces 3 duplicate getMuscleColor() functions.
      * Maps Chinese muscle names to ColorTokens.MUSCLE_* values.
      * To add a new muscle: add its color to ColorTokens, then add the name→token mapping here.
      */
     export class MuscleColorMap {
       static getColor(muscle: string): string {
         if (muscle === '胸') return ColorTokens.MUSCLE_CHEST
         if (muscle === '背') return ColorTokens.MUSCLE_BACK
         if (muscle === '腿') return ColorTokens.MUSCLE_LEGS
         if (muscle === '肩') return ColorTokens.MUSCLE_SHOULDERS
         if (muscle === '臂') return ColorTokens.MUSCLE_ARMS
         if (muscle === '腹') return ColorTokens.MUSCLE_ABS
         return ColorTokens.MUSCLE_DEFAULT
       }
     }
     ```
     // Note: Uses if/else chain (not Record) for ArkTS compatibility — no computed property access.

  **Must NOT do**: Change any existing token value. Only ADD new tokens. Do not remove or rename existing tokens. Do not use `{ [key: string]: string }` index signature — ArkTS forbids it; use if/else chain.

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: Single-file edit, purely additive, mechanical token addition
  - Skills: [] — Follow exact token specifications above

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [3-7] | Blocked By: None

  **References**:
  - Pattern: `entry/src/main/ets/common/styles/DesignTokens.ets:1-210` — Follow existing static class structure exactly
  - ArkTS constraint: No index signatures — `entry/src/main/ets/common/styles/DesignTokens.ets` uses only static readonly members

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep 'RadiusTokens\.XS' entry/src/main/ets/common/styles/DesignTokens.ets` returns 1 match
  - [ ] `grep -c 'MUSCLE_' entry/src/main/ets/common/styles/DesignTokens.ets` returns ≥14 (7 ColorTokens + 7 DarkColorTokens)
  - [ ] `grep 'SUBHEADLINE_SIZE' entry/src/main/ets/common/styles/DesignTokens.ets` returns 1 match
  - [ ] `grep 'HERO_SIZE' entry/src/main/ets/common/styles/DesignTokens.ets` returns 1 match
  - [ ] `grep 'MICRO_SIZE' entry/src/main/ets/common/styles/DesignTokens.ets` returns 1 match
  - [ ] `grep -c 'SEGMENT_HEIGHT\|CARD_MEDIA_HEIGHT_SM\|CARD_COVER_SIZE\|AVATAR_SIZE\|HERO_HEIGHT\|TIMELINE_COL_WIDTH\|CALENDAR_CELL\|MUSCLE_TAG_PADDING' entry/src/main/ets/common/styles/DesignTokens.ets` returns ≥9
  - [ ] `grep 'MuscleColorMap' entry/src/main/ets/common/styles/DesignTokens.ets` returns match
  - [ ] `grep 'SpacingTokens\.XXXS' entry/src/main/ets/common/styles/DesignTokens.ets` returns match

  **QA Scenarios** (MANDATORY):
  ```
  Scenario: MuscleColorMap returns correct hex for each muscle
    Tool: Bash
    Steps: grep -A2 "MUSCLE_CHEST" DesignTokens.ets; grep -A2 "MUSCLE_BACK" DesignTokens.ets; grep -A2 "MUSCLE_LEGS" DesignTokens.ets; grep -A2 "MUSCLE_SHOULDERS" DesignTokens.ets; grep -A2 "MUSCLE_ARMS" DesignTokens.ets; grep -A2 "MUSCLE_ABS" DesignTokens.ets
    Expected: Each token matches its spec hex exactly (#1E88E5, #43A047, #FB8C00, #8E24AA, #E53935, #00897B)
    Evidence: .sisyphus/evidence/task-2-muscle-hex.txt

  Scenario: Every new token has DESIGN comment
    Tool: Bash
    Steps: grep -B1 "MUSCLE_" DesignTokens.ets | grep "DESIGN"; grep -B1 "MICRO_SIZE" DesignTokens.ets | grep "DESIGN"; grep -B1 "SEGMENT_HEIGHT" DesignTokens.ets | grep "DESIGN"
    Expected: DESIGN comments present for MUSCLE_*, MICRO_SIZE, SEGMENT_HEIGHT, and other "magic number" tokens
    Evidence: .sisyphus/evidence/task-2-design-comments.txt
  ```

  **Commit**: YES | Message: `feat(design): add MusclePalette, size tokens, XS radius, MuscleColorMap` | Files: `entry/src/main/ets/common/styles/DesignTokens.ets`

---

### Wave 2: Reusable Components

- [x] 3. Extract EmptyState component from page duplicates

  **What to do**: 
  Create `entry/src/main/ets/components/EmptyState.ets`. Props: `@Prop icon: string = '📋'`, `@Prop title: string = ''`, `@Prop subtitle: string = ''`, `@BuilderParam action?: () => void`. Layout: Column centered with emoji icon, title (TITLE_SIZE), subtitle (CAPTION_SIZE), optional action slot.
  Pattern source: Index.ets lines 325-339 ("暂无启用计划"), ExerciseLibraryPage.ets lines 215-223 ("未找到匹配动作"), ExerciseDetailPage.ets lines 255-263 ("尚未记录").
  Add `// DESIGN: Center-aligned empty state pattern. Icon, title, subtitle in vertical stack. To add a call-to-action, use the action builder slot.`

  **Must NOT do**: Hardcode any text. Props only. Do not import from pages.

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: Component creation with ArkUI @Component + @BuilderParam pattern
  - Skills: [`frontend-ui-ux`] — Reason: UI component design

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: [8-11] | Blocked By: [2]

  **References**:
  - Pattern: `entry/src/main/ets/components/AppCard.ets:1-37` — @Component with @Prop + @BuilderParam
  - Source: `entry/src/main/ets/pages/Index.ets:325-339` — "暂无启用计划" pattern
  - Source: `entry/src/main/ets/pages/ExerciseLibraryPage.ets:215-223` — "未找到匹配动作" pattern

  **Acceptance Criteria** (agent-executable only):
  - [ ] `test -f entry/src/main/ets/components/EmptyState.ets && echo "EXISTS"`
  - [ ] `grep '@Component' entry/src/main/ets/components/EmptyState.ets` returns match
  - [ ] `grep '@Prop' entry/src/main/ets/components/EmptyState.ets | wc -l` returns ≥3 (icon, title, subtitle)
  - [ ] `grep '@BuilderParam' entry/src/main/ets/components/EmptyState.ets` returns match
  - [ ] `grep 'DESIGN' entry/src/main/ets/components/EmptyState.ets` returns match

  **QA Scenarios**:
  ```
  Scenario: EmptyState renders title and subtitle
    Tool: Bash (static check)
    Steps: grep 'fontSize(FontTokens.TITLE_SIZE)' entry/src/main/ets/components/EmptyState.ets; grep 'fontSize(FontTokens.CAPTION_SIZE)' entry/src/main/ets/components/EmptyState.ets
    Expected: Title uses TITLE_SIZE, subtitle uses CAPTION_SIZE
    Evidence: .sisyphus/evidence/task-3-empty-state.txt
  ```

  **Commit**: YES | Message: `feat(ui): extract EmptyState component` | Files: `entry/src/main/ets/components/EmptyState.ets`

---

- [x] 4. Extract SegmentedControl component from page duplicates

  **What to do**: 
  Create `entry/src/main/ets/components/SegmentedControl.ets`. Props: `@Link selectedIndex: number`, `@Prop options: string[]` (labels), `@Prop size: 'small' | 'medium' = 'medium'`. Layout: Row of pill-shaped buttons. Selected = PRIMARY bg + White text, unselected = SURFACE_SECONDARY bg + TEXT_SECONDARY text. Height: SEGMENT_HEIGHT for medium, BUTTON_HEIGHT_SMALL for small.
  Pattern source: Index.ets lines 229-259 ("预置计划|我的计划"), StatsPage.ets lines 117-145 ("本周|本月"), ExerciseDetailPage.ets lines 112-140 ("动作要领|参与肌群").
  Add `// DESIGN: Segmented control uses pill-shaped buttons. Selected state = solid primary, unselected = muted surface. Height from TouchTokens.SEGMENT_HEIGHT (40vp). To change the selected/unselected visual, adjust the backgroundColor ternary.`

  **Must NOT do**: Support more than 5 options. Do not add icons. Keep it text-only.

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: Component with ForEach + Button pattern
  - Skills: [`frontend-ui-ux`]

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: [8-11] | Blocked By: [2]

  **References**:
  - Pattern: `entry/src/main/ets/pages/Index.ets:229-259` — Index segment control
  - Pattern: `entry/src/main/ets/pages/StatsPage.ets:117-145` — Stats period switcher
  - Tokens: `entry/src/main/ets/common/styles/DesignTokens.ets` — new SEGMENT_HEIGHT, BUTTON_HEIGHT_SMALL

  **Acceptance Criteria** (agent-executable only):
  - [ ] `test -f entry/src/main/ets/components/SegmentedControl.ets && echo "EXISTS"`
  - [ ] `grep '@Link selectedIndex' entry/src/main/ets/components/SegmentedControl.ets` returns match
  - [ ] `grep 'ColorTokens.PRIMARY' entry/src/main/ets/components/SegmentedControl.ets` returns match
  - [ ] `grep 'SEGMENT_HEIGHT' entry/src/main/ets/components/SegmentedControl.ets` returns match
  - [ ] `grep 'DESIGN' entry/src/main/ets/components/SegmentedControl.ets` returns match

  **QA Scenarios**:
  ```
  Scenario: SegmentedControl uses tokens, not hardcoded heights
    Tool: Bash
    Steps: grep 'height(' entry/src/main/ets/components/SegmentedControl.ets | grep -v 'layoutWeight'
    Expected: All height() calls reference TouchTokens (SEGMENT_HEIGHT or BUTTON_HEIGHT_SMALL), no numeric literals
    Evidence: .sisyphus/evidence/task-4-segmented.txt
  ```

  **Commit**: YES | Message: `feat(ui): extract SegmentedControl component` | Files: `entry/src/main/ets/components/SegmentedControl.ets`

---

- [x] 5. Extract SearchBar component from page duplicate

  **What to do**: 
  Create `entry/src/main/ets/components/SearchBar.ets`. Props: `@Link query: string`, `@Prop placeholder: string = '搜索...'`. Layout: Row with TextInput (flex 1) + bottom border. Height: 44vp. Background: SURFACE_PRIMARY. Border: NEUTRAL_100 bottom.
  Pattern source: ExerciseLibraryPage.ets lines 112-124.
  Add `// DESIGN: Search bar with bottom border, no container box. Height 44vp (slightly shorter than standard INPUT_HEIGHT 48 — designed for toolbar placement). To change the search bar style (e.g. rounded box instead of underline), replace the border-bottom with backgroundColor + borderRadius.`

  **Must NOT do**: Add a search icon or button. Keep it minimal — just the TextInput with placeholder.

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: Component with TextInput + @Link binding
  - Skills: [`frontend-ui-ux`]

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: [8-11] | Blocked By: [2]

  **References**:
  - Pattern: `entry/src/main/ets/components/AppInput.ets:1-79` — @Link value binding pattern
  - Source: `entry/src/main/ets/pages/ExerciseLibraryPage.ets:112-124` — search bar implementation

  **Acceptance Criteria** (agent-executable only):
  - [ ] `test -f entry/src/main/ets/components/SearchBar.ets && echo "EXISTS"`
  - [ ] `grep '@Link query' entry/src/main/ets/components/SearchBar.ets` returns match
  - [ ] `grep 'TextInput' entry/src/main/ets/components/SearchBar.ets` returns match
  - [ ] `grep 'DESIGN' entry/src/main/ets/components/SearchBar.ets` returns match

  **QA Scenarios**:
  ```
  Scenario: SearchBar has no hardcoded colors
    Tool: Bash
    Steps: grep 'ColorTokens' entry/src/main/ets/components/SearchBar.ets
    Expected: All colors from ColorTokens (SURFACE_PRIMARY, NEUTRAL_100), no hex values
    Evidence: .sisyphus/evidence/task-5-searchbar.txt
  ```

  **Commit**: YES | Message: `feat(ui): extract SearchBar component` | Files: `entry/src/main/ets/components/SearchBar.ets`

---

- [x] 6. Extract Chip component from page duplicates

  **What to do**: 
  Create `entry/src/main/ets/components/Chip.ets`. Props: `@Prop label: string`, `@Prop color: string` (background hex from MuscleColorMap or plan coverColor), `@Prop chipSize: 'sm' | 'md' = 'sm'`. Layout: Text with padding (MUSCLE_TAG_PADDING), fontSize MICRO_SIZE for sm / CAPTION_SIZE for md, fontColor White, backgroundColor from prop, borderRadius FULL.
  Pattern source: Index.ets lines 111-116 (muscle pill), ExerciseLibraryPage.ets lines 131-138 (filter pill), PlanDetailPage.ets lines 181-186 (muscle chip).
  Add `// DESIGN: Chip component for inline tags. Two sizes: sm (9sp micro text, tight padding) for muscle badges inside cards, md (14sp caption) for standalone filter pills. Background color passed as prop — typically from MuscleColorMap.getColor() or plan.coverColor. To change chip shape from pill to rounded-rect, change borderRadius from FULL to SM.`

  **Must NOT do**: Accept color name strings — accept raw ColorTokens values. Component doesn't know about muscles. Do not import MuscleColorMap; that's the page's responsibility.

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: Simple presentational component
  - Skills: [`frontend-ui-ux`]

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: [8-11] | Blocked By: [2]

  **References**:
  - Pattern: `entry/src/main/ets/components/StatBadge.ets:1-42` — simple Text + backgroundColor component
  - Tokens: `MUSCLE_TAG_PADDING_V`, `MUSCLE_TAG_PADDING_H`, `MICRO_SIZE` from DesignTokens

  **Acceptance Criteria** (agent-executable only):
  - [ ] `test -f entry/src/main/ets/components/Chip.ets && echo "EXISTS"`
  - [ ] `grep '@Component' entry/src/main/ets/components/Chip.ets` returns match
  - [ ] `grep 'MUSCLE_TAG_PADDING\|MICRO_SIZE\|CAPTION_SIZE' entry/src/main/ets/components/Chip.ets` returns match
  - [ ] `grep 'DESIGN' entry/src/main/ets/components/Chip.ets` returns match

  **QA Scenarios**:
  ```
  Scenario: Chip sm uses MICRO_SIZE, md uses CAPTION_SIZE
    Tool: Bash
    Steps: grep 'MICRO_SIZE' entry/src/main/ets/components/Chip.ets; grep 'CAPTION_SIZE' entry/src/main/ets/components/Chip.ets
    Expected: Both size references present with conditional logic
    Evidence: .sisyphus/evidence/task-6-chip.txt
  ```

  **Commit**: YES | Message: `feat(ui): extract Chip component` | Files: `entry/src/main/ets/components/Chip.ets`

---

- [x] 7. Extract PageHeader component from all 9 page duplicates

  **What to do**: 
  Create `entry/src/main/ets/components/PageHeader.ets`. Props: `@Prop title: string`, `@Prop showBack: boolean = true`,
  `onBackClick?: () => void`. Layout: Row with back arrow (←) + title (HEADLINE_SIZE, Bold, TEXT_PRIMARY), Blank() spacer to right. Padding: `{ left: MD, right: MD, top: LG, bottom: MD }`. Background: SURFACE_PRIMARY.
  Pattern source: ALL 9 pages use identical header (Index.ets:208-216, StatsPage.ets:98-114, ProfilePage.ets:80-99, ExerciseLibraryPage.ets:92-109, ExerciseDetailPage.ets:54-72, WorkoutRecorderPage.ets:290-313 / simplified variant, PlanDetailPage.ets:74-96, LoginPage has no header, RegisterPage has no header).
  Add `// DESIGN: Standard page header. Back arrow uses ← character (no icon dependency). Title truncated with ellipsis if too long. Padding top: LG (24vp) accounts for status bar clearance on HarmonyOS. To add a right action button, extend with a @BuilderParam rightAction slot.`

  **Must NOT do**: Support arbitrary content. Title + back button only. Do not add a subtitle or action slot yet.

  **Recommended Agent Profile**:
  - Category: `visual-engineering` — Reason: Cross-cutting UI component used by all pages
  - Skills: [`frontend-ui-ux`]

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: [8-11] | Blocked By: [2]

  **References**:
  - Pattern: `entry/src/main/ets/pages/Index.ets:208-216` — standard header
  - Pattern: `entry/src/main/ets/pages/StatsPage.ets:98-114` — header with router.back()

  **Acceptance Criteria** (agent-executable only):
  - [ ] `test -f entry/src/main/ets/components/PageHeader.ets && echo "EXISTS"`
  - [ ] `grep '@Prop title' entry/src/main/ets/components/PageHeader.ets` returns match
  - [ ] `grep 'HEADLINE_SIZE' entry/src/main/ets/components/PageHeader.ets` returns match
  - [ ] `grep 'SURFACE_PRIMARY' entry/src/main/ets/components/PageHeader.ets` returns match
  - [ ] `grep 'router.back' entry/src/main/ets/components/PageHeader.ets` returns match (default back behavior)
  - [ ] `grep 'DESIGN' entry/src/main/ets/components/PageHeader.ets` returns match

  **QA Scenarios**:
  ```
  Scenario: PageHeader padding matches existing page headers
    Tool: Bash
    Steps: grep 'padding' entry/src/main/ets/components/PageHeader.ets
    Expected: left: MD, right: MD, top: LG, bottom: MD (matching all existing pages)
    Evidence: .sisyphus/evidence/task-7-pageheader.txt
  ```

  **Commit**: YES | Message: `feat(ui): extract PageHeader component` | Files: `entry/src/main/ets/components/PageHeader.ets`

---

### Wave 3: Page Hardcoded-Fix Pass

- [x] 8. Fix Index.ets — replace hardcoded values + inline tabs

  **What to do**: 
  Fix `entry/src/main/ets/pages/Index.ets`:
  1. **Line 115**: `borderRadius(4)` → `borderRadius(RadiusTokens.XS)`
  2. **Line 115**: `backgroundColor(this.currentPlan?.coverColor || '#999')` → `backgroundColor(this.currentPlan?.coverColor || ColorTokens.MUSCLE_DEFAULT)`
  3. **Lines 229-259**: Replace inline SegmentedControl with `<SegmentedControl>` component (props: selectedIndex: $activeSegment, options: ['预置计划', '我的计划'], size: 'medium')
  4. **Lines 238, 251**: Remove explicit `height(40)` (handled by SegmentedControl internally)
  5. **Lines 270-276**: Plan cover `width(64)`/`height(64)` → `width(TouchTokens.CARD_COVER_SIZE)`/`height(TouchTokens.CARD_COVER_SIZE)`
  6. **Lines 121, 186**: Muscle chip with hardcoded padding `{ left: SM, right: SM, top: 1, bottom: 1 }` → Replace with `<Chip>` component (label: exercise.targetMuscle, color: MuscleColorMap.getColor(exercise.targetMuscle), chipSize: 'sm')
  7. **Lines 325-339**: "暂无启用计划" empty state → Replace with `<EmptyState>` component (icon: '📋', title: '暂无启用计划', subtitle: '从预置计划中选择一套开始训练')
  8. **Lines 429-464**: Remove inline tab bar (4 Text elements with router.pushUrl). Import and use `<MainTabBar>` component (currentTab: $currentTab).
     - Add `@State currentTab: string = 'training'` to Index struct
     - Replace the Row containing Text('训练')...Text('我的') with `MainTabBar({ currentTab: $currentTab })`
  9. **Line 116**: `borderRadius(4)` → `borderRadius(RadiusTokens.XS)`
  Add import for MainTabBar, SegmentedControl, EmptyState, Chip, MuscleColorMap at top.
  Add `// DESIGN: Index page uses MainTabBar for bottom navigation (single source of truth). Plan covers use CARD_COVER_SIZE (64vp × 64vp). Muscle chips use Chip component with sm size — tight pill shape for inline display.`

  **Must NOT do**: Change any business logic (plan loading, navigation, swipe delete). Change only UI styling and component references.

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: Mechanical find-and-replace fixes across one file
  - Skills: []

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: None | Blocked By: [2, 3, 4, 6, 7]

  **References**:
  - Target file: `entry/src/main/ets/pages/Index.ets:1-470` — all line references above
  - Components: MainTabBar at `entry/src/main/ets/components/MainTabBar.ets`

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep 'MainTabBar' entry/src/main/ets/pages/Index.ets` returns match (import + usage)
  - [ ] `grep 'SegmentedControl' entry/src/main/ets/pages/Index.ets` returns match
  - [ ] `grep 'EmptyState' entry/src/main/ets/pages/Index.ets` returns match
  - [ ] `grep 'Chip' entry/src/main/ets/pages/Index.ets` returns match
  - [ ] `grep 'MuscleColorMap' entry/src/main/ets/pages/Index.ets` returns match
  - [ ] `grep 'borderRadius(RadiusTokens.XS)' entry/src/main/ets/pages/Index.ets` returns ≥2 matches
  - [ ] `grep '#999' entry/src/main/ets/pages/Index.ets` returns 0 matches (no hardcoded fallback)
  - [ ] `grep 'height(40)\|height(64)\|height(80)' entry/src/main/ets/pages/Index.ets` returns 0 matches (all tokenized)

  **QA Scenarios**:
  ```
  Scenario: Index page renders with MainTabBar (not inline tabs)
    Tool: Bash
    Steps: grep -c "Text('训练')\|Text('动作库')\|Text('统计')\|Text('我的')" entry/src/main/ets/pages/Index.ets
    Expected: 0 results (inline tab Texts removed; MainTabBar handles labels)
    Evidence: .sisyphus/evidence/task-8-index.txt

  Scenario: No hardcoded numeric dimensions remain
    Tool: Bash
    Steps: grep -nE '(height|width|borderRadius|fontSize)\([0-9]+\)' entry/src/main/ets/pages/Index.ets | grep -v 'FontTokens\|TouchTokens\|SpacingTokens\|RadiusTokens\|ColorTokens'
    Expected: 0 results
    Evidence: .sisyphus/evidence/task-8-index-dims.txt
  ```

  **Commit**: YES | Message: `fix(ui): tokenize Index.ets — replace hardcoded values, inline tabs, muscle colors` | Files: `entry/src/main/ets/pages/Index.ets`

---

- [x] 9. Fix WorkoutRecorderPage.ets + StatsPage.ets

  **What to do**: 
  Fix 2 pages for hardcoded values + component extraction:

  **WorkoutRecorderPage.ets**:
  1. **Line 305**: `height(36)` → `height(TouchTokens.BUTTON_HEIGHT_SMALL)`. Add `// DESIGN: Discard button uses BUTTON_HEIGHT_SMALL (36vp) — shorter than AppButton default (48vp) to visually de-emphasize destructive action.`
  2. **Line 353**: `fontSize(9)` → `fontSize(FontTokens.MICRO_SIZE)`. Add `// DESIGN: 1RM sub-label uses MICRO_SIZE (9sp) — intentionally compact to fit beside weight/reps inputs without taking space from input fields.`
  3. **Summary view (lines 237-286)**: Replace manual stat display with `<EmptyState>` for the "training complete" content? No — summary is custom. Just add `// DESIGN: Training summary uses centered layout with DISPLAY_SIZE primary heading. Notes TextArea constrained to minHeight 80 maxHeight 200. To change summary card max height, adjust constraintSize.`
  4. **Line 348-355**: Replace inline 1RM stat display → add `// DESIGN: 1RM estimate shown as compact vertical stack (value + '1RM' label) at 40vp width. NUMBERS ONLY. To change from vertical to horizontal layout, modify the Column→Row and remove fixed width.`

  **StatsPage.ets**:
  1. **Line 125**: `height(36)` → `height(TouchTokens.BUTTON_HEIGHT_SMALL)`
  2. **Lines 117-145**: Replace inline period switcher ("本周|本月") with `<SegmentedControl>` (props: selectedIndex: $activePeriod, options: ['本周', '本月'], size: 'small')
  3. **Line 229**: `height(32)` → `height(TouchTokens.CALENDAR_CELL)`. Add `// DESIGN: Calendar cell height 32vp balances readability with 7-column × 5-row grid fitting on typical phone screen. If you increase cell height, reduce rows or enable scroll.`
  4. **Line 233**: `borderRadius(4)` → `borderRadius(RadiusTokens.XS)`
  5. **Line 73**: `getHeatColor()` hardcoded hex array `['#E8E8E8', '#C8E6C9', ...]` → No change (heatmap colors are data-driven visualization, not UI chrome). Add `// DESIGN: Calendar heatmap colors are visualization data, not UI tokens. The 5-level green scale is specific to the calendar heatmap feature. To change heatmap intensity, modify the colors array. Do NOT tokenize — these are chart data, not application chrome.`

  **Must NOT do**: Change heatmap color logic or the Epley formula. Touch only UI layout values.

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: Two-file mechanical fix with component substitution
  - Skills: []

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: None | Blocked By: [2, 4]

  **References**:
  - `entry/src/main/ets/pages/WorkoutRecorderPage.ets:1-467`
  - `entry/src/main/ets/pages/StatsPage.ets:1-269`

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep 'BUTTON_HEIGHT_SMALL' entry/src/main/ets/pages/WorkoutRecorderPage.ets` returns match
  - [ ] `grep 'MICRO_SIZE' entry/src/main/ets/pages/WorkoutRecorderPage.ets` returns match
  - [ ] `grep 'DESIGN' entry/src/main/ets/pages/WorkoutRecorderPage.ets | wc -l` returns ≥3 (at least 3 DESIGN comments)
  - [ ] `grep 'SegmentedControl' entry/src/main/ets/pages/StatsPage.ets` returns match
  - [ ] `grep 'CALENDAR_CELL' entry/src/main/ets/pages/StatsPage.ets` returns match
  - [ ] `grep 'RadiusTokens.XS' entry/src/main/ets/pages/StatsPage.ets` returns match
  - [ ] `grep 'DESIGN' entry/src/main/ets/pages/StatsPage.ets | wc -l` returns ≥2

  **QA Scenarios**:
  ```
  Scenario: StatsPage has no hardcoded dimensions
    Tool: Bash
    Steps: grep -nE '(height|width|borderRadius)\([0-9]+\)' entry/src/main/ets/pages/StatsPage.ets | grep -v 'layoutWeight\|DESIGN\|getHeatColor\|colors\[' 
    Expected: 0 results (all dimensions from tokens)
    Evidence: .sisyphus/evidence/task-9-stats.txt
  ```

  **Commit**: YES | Message: `fix(ui): tokenize WorkoutRecorderPage + StatsPage, add DESIGN comments` | Files: `entry/src/main/ets/pages/WorkoutRecorderPage.ets`, `entry/src/main/ets/pages/StatsPage.ets`

---

- [x] 10. Fix ExerciseLibraryPage.ets + ExerciseDetailPage.ets

  **What to do**: 
  Fix 2 pages — major changes: replace getMuscleColor, extract components, tokenize sizes.

  **ExerciseLibraryPage.ets**:
  1. **Lines 16-24**: Delete entire `getMuscleColor()` function. Import `MuscleColorMap` from DesignTokens instead.
  2. **Lines 112-124**: Replace inline search Row with `<SearchBar>` component (props: query: $searchQuery, placeholder: '搜索动作名称...')
  3. **Lines 128-147**: Replace inline muscle filter Row → Refactor to use `<Chip>` components in horizontal Scroll. Each muscle chip: `<Chip label={muscle} color={muscle === activeMuscle ? ColorTokens.PRIMARY : MuscleColorMap.getColor(muscle)} chipSize="md" />`. Add `// DESIGN: Muscle filter chips use md size (14sp) for better tap targets. Active chip shows PRIMARY color instead of muscle color for clear selection state.`
  4. **Lines 154-175**: Replace inline equipment filter Row → Same pattern as muscle filter but uses NEUTRAL_400 for active state
  5. **Lines 244-245**: `height(72)` → `height(TouchTokens.CARD_MEDIA_HEIGHT_SM)`
  6. **Lines 244**: `fontSize(22)` → `fontSize(FontTokens.SUBHEADLINE_SIZE)`
  7. **Line 252**: `getMuscleColor(x) || '#999'` → `MuscleColorMap.getColor(x)`
  8. **Lines 239-278**: `exerciseCard` @Builder — replace inline muscle chip with `<Chip>` component
  9. **Lines 215-223**: "未找到匹配动作" → Replace with `<EmptyState>` (icon: '🔍', title: '未找到匹配动作')

  **ExerciseDetailPage.ets**:
  1. **Lines 13-21**: Delete `getMuscleColor()` function. Import `MuscleColorMap`.
  2. **Line 80**: `fontSize(48)` → `fontSize(FontTokens.HERO_SIZE)`
  3. **Line 89**: `height(200)` → `height(TouchTokens.HERO_HEIGHT)`
  4. **Line 90**: `getMuscleColor(x) || '#999'` → `MuscleColorMap.getColor(x)`
  5. **Line 100**: Same replacement
  6. **Line 183**: Same replacement
  7. **Line 268**: Same replacement
  8. **Lines 96-101**: Replace inline muscle chip with `<Chip>` component (color: MuscleColorMap.getColor(this.exercise.primaryMuscle))
  9. **Lines 179-184**: Replace inline muscle chip with `<Chip>`
  10. **Lines 112-140**: Replace inline tab switcher with `<SegmentedControl>` (props: selectedIndex: $activeTab, options: ['动作要领', '参与肌群'], size: 'small')
  11. **Lines 120, 132**: Remove explicit `height(36)` (handled by SegmentedControl)
  12. **Lines 255-263**: "尚未记录" → Replace with `<EmptyState>` (icon: '📊', title: '尚未记录', subtitle: '完成一次训练后系统将自动记录')
  13. Add `// DESIGN: Exercise detail hero uses HERO_SIZE (48sp) initial letter + HERO_HEIGHT (200vp) image area. Muscle chip tags display in the content area using Chip component with sm size.`

  **Must NOT do**: Change exercise data loading or the getMuscleColor mapping logic in MuscleColorMap. Do not change the exercise card grid layout (2-column alternating pattern).

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: Two-file fix with component substitution, well-defined replacements
  - Skills: []

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: None | Blocked By: [2, 4, 5, 6]

  **References**:
  - `entry/src/main/ets/pages/ExerciseLibraryPage.ets:1-284`
  - `entry/src/main/ets/pages/ExerciseDetailPage.ets:1-281`

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep 'function getMuscleColor' entry/src/main/ets/pages/ExerciseLibraryPage.ets` returns 0 matches (deleted)
  - [ ] `grep 'function getMuscleColor' entry/src/main/ets/pages/ExerciseDetailPage.ets` returns 0 matches (deleted)
  - [ ] `grep 'MuscleColorMap' entry/src/main/ets/pages/ExerciseLibraryPage.ets` returns match
  - [ ] `grep 'MuscleColorMap' entry/src/main/ets/pages/ExerciseDetailPage.ets` returns match
  - [ ] `grep 'SearchBar' entry/src/main/ets/pages/ExerciseLibraryPage.ets` returns match
  - [ ] `grep 'Chip' entry/src/main/ets/pages/ExerciseLibraryPage.ets` returns match
  - [ ] `grep 'CARD_MEDIA_HEIGHT_SM' entry/src/main/ets/pages/ExerciseLibraryPage.ets` returns match
  - [ ] `grep 'SUBHEADLINE_SIZE' entry/src/main/ets/pages/ExerciseLibraryPage.ets` returns match
  - [ ] `grep 'HERO_SIZE' entry/src/main/ets/pages/ExerciseDetailPage.ets` returns match
  - [ ] `grep 'HERO_HEIGHT' entry/src/main/ets/pages/ExerciseDetailPage.ets` returns match
  - [ ] `grep 'SegmentedControl' entry/src/main/ets/pages/ExerciseDetailPage.ets` returns match
  - [ ] `grep 'EmptyState' entry/src/main/ets/pages/ExerciseDetailPage.ets` returns match
  - [ ] `grep '#999\|#1E88E5\|#43A047\|#FB8C00\|#8E24AA\|#E53935\|#00897B' entry/src/main/ets/pages/ExerciseLibraryPage.ets` returns 0 matches (no hardcoded muscle hex)
  - [ ] `grep '#999\|#1E88E5\|#43A047\|#FB8C00\|#8E24AA\|#E53935\|#00897B' entry/src/main/ets/pages/ExerciseDetailPage.ets` returns 0 matches

  **QA Scenarios**:
  ```
  Scenario: All muscle color references use MuscleColorMap
    Tool: Bash
    Steps: grep 'getMuscleColor' entry/src/main/ets/pages/ExerciseLibraryPage.ets entry/src/main/ets/pages/ExerciseDetailPage.ets
    Expected: 0 results (no old function — all use MuscleColorMap.getColor)
    Evidence: .sisyphus/evidence/task-10-muscle.txt

  Scenario: ExerciseLibraryPage filter chips use md size
    Tool: Bash
    Steps: grep 'Chip' entry/src/main/ets/pages/ExerciseLibraryPage.ets -A5 | grep 'md'
    Expected: Chip chipSize references include 'md'
    Evidence: .sisyphus/evidence/task-10-chips.txt
  ```

  **Commit**: YES | Message: `fix(ui): tokenize ExerciseLibraryPage + ExerciseDetailPage, replace getMuscleColor, extract components` | Files: `entry/src/main/ets/pages/ExerciseLibraryPage.ets`, `entry/src/main/ets/pages/ExerciseDetailPage.ets`

---

- [x] 11. Fix PlanDetailPage.ets + ProfilePage.ets + RegisterPage.ets + LoginPage.ets

  **What to do**: 
  Fix 4 remaining pages:

  **PlanDetailPage.ets**:
  1. **Lines 13-21**: Delete `getMuscleColorFn()`. Delete `getMuscleColor()` method (line 68-70). Import `MuscleColorMap`.
  2. **Line 28**: `coverColor: string = '#CCCCCC'` → `coverColor: string = ColorTokens.MUSCLE_DEFAULT`. Add `// DESIGN: Plan coverColor defaults to MUSCLE_DEFAULT (#999) when plan data is loading. This matches the fallback used by MuscleColorMap for unknown muscles.`
  3. **Line 160**: `width(20)` → `width(TouchTokens.TIMELINE_COL_WIDTH)`
  4. **Line 182**: `fontSize(9)` → `fontSize(FontTokens.MICRO_SIZE)`
  5. **Line 184**: `padding({ left: 6, right: 6, top: 1, bottom: 1 })` → `padding({ left: TouchTokens.MUSCLE_TAG_PADDING_H, right: TouchTokens.MUSCLE_TAG_PADDING_H, top: TouchTokens.MUSCLE_TAG_PADDING_V, bottom: TouchTokens.MUSCLE_TAG_PADDING_V })`
  6. **Line 185**: `backgroundColor(this.getMuscleColor(x))` → `backgroundColor(MuscleColorMap.getColor(x))`
  7. **Line 186**: `borderRadius(4)` → `borderRadius(RadiusTokens.XS)`
  8. **Lines 74-96**: Replace header with `<PageHeader>` (props: title: this.planName || '计划详情', showBack: true)
  9. Add `// DESIGN: PlanDetailPage timeline uses 20vp left column with colored circles (plan.coverColor) connected by 2vp wide lines. To change timeline appearance: adjust TIMELINE_COL_WIDTH for spacing, Circle width/height (12vp currently) for node size.`

  **ProfilePage.ets**:
  1. **Lines 107**: `width(80)` / `height(80)` → `width(TouchTokens.AVATAR_SIZE)` / `height(TouchTokens.AVATAR_SIZE)`. Add `// DESIGN: Profile avatar uses AVATAR_SIZE (80vp) circle with user's first initial inside. To change avatar to photo mode: replace Circle()+Text() with Image(). To resize: change only AVATAR_SIZE token.`
  2. **Line 112**: `fontSize(32)` → Use display-level font — `fontSize(FontTokens.DISPLAY_SIZE)` (28sp is close enough, or this is actually the avatar initial which should use a dedicated token). Actually, since DISPLAY_SIZE=28 and the current value is 32, let's add a comment: `// DESIGN: Avatar initial uses DISPLAY_SIZE (28sp) — smaller than the original 32sp but consistent with the display token scale. To restore 32sp, add a dedicated AVATAR_FONT_SIZE token.`
  3. **Lines 80-99**: Replace header with `<PageHeader>` (props: title: '个人资料', showBack: true)

  **RegisterPage.ets**:
  1. Add `// DESIGN: Register/Login pages use centered layout with brand logo (DISPLAY_SIZE, PRIMARY color) + form inputs. No page header — brand acts as header. To add a back button, wrap in PageHeader or add a top-left arrow.`
  2. Page is mostly token-compliant already. Add `// DESIGN:` comment block at top of build() summarizing layout strategy.

  **LoginPage.ets**:
  1. Same as RegisterPage: add `// DESIGN:` comment. Both are token-compliant. No hardcoded values found.

  **Must NOT do**: Change auth logic, form validation, or navigation flow. Touch only the values listed.

  **Recommended Agent Profile**:
  - Category: `quick` — Reason: Four-file mechanical fix, most changes are find-replace
  - Skills: []

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: None | Blocked By: [2, 7]

  **References**:
  - `entry/src/main/ets/pages/PlanDetailPage.ets:1-244`
  - `entry/src/main/ets/pages/ProfilePage.ets:1-222`
  - `entry/src/main/ets/pages/RegisterPage.ets:1-132`
  - `entry/src/main/ets/pages/LoginPage.ets:1-139`

  **Acceptance Criteria** (agent-executable only):
  - [ ] `grep 'function getMuscleColor' entry/src/main/ets/pages/PlanDetailPage.ets` returns 0 matches (deleted)
  - [ ] `grep 'MuscleColorMap' entry/src/main/ets/pages/PlanDetailPage.ets` returns match
  - [ ] `grep '#CCCCCC' entry/src/main/ets/pages/PlanDetailPage.ets` returns 0 matches
  - [ ] `grep 'TIMELINE_COL_WIDTH' entry/src/main/ets/pages/PlanDetailPage.ets` returns match
  - [ ] `grep 'MUSCLE_TAG_PADDING' entry/src/main/ets/pages/PlanDetailPage.ets` returns match
  - [ ] `grep 'RadiusTokens.XS' entry/src/main/ets/pages/PlanDetailPage.ets` returns match
  - [ ] `grep 'PageHeader' entry/src/main/ets/pages/PlanDetailPage.ets` returns match
  - [ ] `grep 'AVATAR_SIZE' entry/src/main/ets/pages/ProfilePage.ets` returns match
  - [ ] `grep 'PageHeader' entry/src/main/ets/pages/ProfilePage.ets` returns match
  - [ ] `grep 'DESIGN' entry/src/main/ets/pages/RegisterPage.ets` returns match
  - [ ] `grep 'DESIGN' entry/src/main/ets/pages/LoginPage.ets` returns match

  **QA Scenarios**:
  ```
  Scenario: PlanDetailPage has zero hardcoded hex colors
    Tool: Bash
    Steps: grep -nE '#[0-9A-Fa-f]{3,8}' entry/src/main/ets/pages/PlanDetailPage.ets
    Expected: 0 results
    Evidence: .sisyphus/evidence/task-11-plan-hex.txt

  Scenario: All 4 remaining files have DESIGN comments
    Tool: Bash
    Steps: grep -l 'DESIGN' entry/src/main/ets/pages/PlanDetailPage.ets entry/src/main/ets/pages/ProfilePage.ets entry/src/main/ets/pages/RegisterPage.ets entry/src/main/ets/pages/LoginPage.ets
    Expected: All 4 files listed
    Evidence: .sisyphus/evidence/task-11-design-comments.txt
  ```

  **Commit**: YES | Message: `fix(ui): tokenize PlanDetailPage, ProfilePage, RegisterPage, LoginPage` | Files: `entry/src/main/ets/pages/PlanDetailPage.ets`, `entry/src/main/ets/pages/ProfilePage.ets`, `entry/src/main/ets/pages/RegisterPage.ets`, `entry/src/main/ets/pages/LoginPage.ets`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.** Rejection or user feedback -> fix -> re-run -> present again -> wait for okay.
- [x] F1. Plan Compliance Audit — PASS (all 6 checks passed)
- [x] F2. Code Quality Review — PASS with notes: onBackClick pattern matches AppButton convention; empty catch blocks are pre-existing (not from plan tasks); stray HTML comment in SearchBar.ets remediated.
- [x] F3. Real Manual QA — PASS: all 5 checks passed; imports correct, tokens consistent, getMuscleColor replaced, component props verified, zero hardcoded hex outside heatmap.
- [x] F4. Scope Fidelity Check — PASS with note: reviewer flagged pre-existing repo changes (services/utils/ShadowConfig) as scope creep; actual plan changes are correctly scoped to DesignTokens.ets (additions only), 5 new components, 9 page token fixes. No business logic changed.

## Commit Strategy
- Wave 1: 1 commit (DesignTokens.ets + DESIGN_DECISIONS.md)
- Wave 2: 1 commit per component, OR 1 squash commit for all 6
- Wave 3: 1 commit per page group (3-4 pages per commit)
- Wave 4: No commits (verification only, unless fixes needed)

## Success Criteria
1. `grep -rn '#[0-9A-Fa-f]\{3,8\}' entry/src/main/ets/ --include='*.ets' | grep -v DesignTokens.ets | grep -v AGENTS.md` returns 0 results
2. All 6 new components exist in `components/` with `// DESIGN:` comments
3. Index.ets imports and uses MainTabBar (no inline tabs)
4. All 3 getMuscleColor() duplicates replaced with MuscleColorMap.getColor()
5. DESIGN_DECISIONS.md documents all major design choices
6. Zero `// DESIGN:` comments use vague language ("can adjust later") — all specify WHAT and WHY
