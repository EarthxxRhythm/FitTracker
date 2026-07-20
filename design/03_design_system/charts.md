# Charts Spec

## Role
Charts in FitTracker are not decorative analytics. They exist to help the user understand training progress quickly and trust the data.

A good chart in FitTracker should feel:
- calm
- premium
- readable
- credible
- purposeful

---

## Core Principles

1. A chart must answer a training question, not just visualize data because it exists.
2. Readability is more important than visual novelty.
3. Trend direction matters more than visual ornament.
4. High-value events like PRs should be recognizable without becoming flashy.
5. Dark-mode charts must still feel refined, not generic dashboard-like.

---

## Visual Tone
Charts should feel like part of a high-end personal performance system.
Not a startup analytics dashboard. Not a finance terminal clone. Not a sports broadcast overlay.

They should feel:
- restrained
- analytical
- precise
- integrated into the product’s visual language

---

## Color Rules
### Main trend lines
- Use `ACCENT_PRIMARY` for the main trend line.
- Use `ACCENT_HOVER` or `ACCENT_SOFT` only for active selection or highlighted peaks.

### Supporting structure
- Use muted silver/green-neutral tones for axes, labels, and guides.
- Grid lines should stay subtle and quiet.

### High-value points
- Use `ACCENT_GOLD` or `ACCENT_GOLD_SOFT` only for rare importance such as PR or peak milestone emphasis.
- Gold must be rare enough to retain value.

### Negative or weak states
- Use muted warning or neutral tones, not aggressive red by default.

---

## Heatmap Rules
The heatmap should communicate consistency and intensity at a glance.

Recommended progression:
- no activity: very dark neutral-green cell
- low activity: subdued deep green
- medium activity: richer green
- strong activity: saturated emerald-green
- peak activity: bright cool emerald highlight

The heatmap should remain readable in dark mode and should not look radioactive.

---

## Trend Panel Rules
Trend panels should prioritize:
- one main signal
- one supporting context layer
- minimal clutter

Do not combine too many metrics into one chart.
If necessary, separate them into smaller, focused panels.

---

## Labeling Rules
Labels should be sparse and intentional.
Show labels where they help interpretation, not on every point.

Good labels:
- peak marker
- latest value
- significant PR marker
- visible time range reference

Bad labels:
- every dot
- every bar
- too many legends for obvious data

---

## Motion Rules
If charts animate:
- animation should clarify transitions
- animation must be short and calm
- no flashy sweeping motion
- avoid drawing attention away from reading the data

---

## Review Page Chart Goal
The Review page should use charts to answer:
- am I training consistently?
- am I improving?
- what changed recently?
- where is the strongest signal?

If the user only sees “pretty charts” but no insight, the chart design failed.

---

## Failure Signs
Charts are not acceptable if:
- they look like generic admin analytics widgets
- too many colors are used
- the green is too loud or too frequent
- gold is used everywhere
- labels are cluttered
- the user cannot quickly read the main trend

---

## Success Criteria
Charts are correct when:
- the main trend is readable immediately
- the screen feels premium and analytical
- the chart integrates with the dark emerald visual system
- the user can interpret progress without excessive reading
