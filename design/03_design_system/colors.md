# FitTracker Color System

## Theme Name
**Cold Emerald Performance / 冷感青翠绿**

## Usage Principle
The color system is built around three roles:

1. **Deep dark layers** create premium calm and structural hierarchy.
2. **Cool emerald accents** create focus, energy, and interaction emphasis.
3. **Metallic silver and soft gold** create precision and rare-value emphasis.

The system should never collapse into “just black with green buttons.”

---

## 1. Background Tokens

| Token | Value | Usage |
|---|---:|---|
| `BG_PRIMARY` | `#09100F` | App root background |
| `BG_SECONDARY` | `#0F1716` | Main section background |
| `BG_TERTIARY` | `#141F1D` | Secondary section background |
| `BG_ELEVATED` | `#1A2825` | High-emphasis surface backdrop |

### Notes
- Use `BG_PRIMARY` for the main screen canvas.
- Use `BG_SECONDARY` and `BG_TERTIARY` to create depth between stacked areas.
- Avoid using pure black; it makes the UI feel flatter and cheaper.

---

## 2. Surface Tokens

| Token | Value | Usage |
|---|---:|---|
| `SURFACE_PRIMARY` | `#16211F` | Standard cards |
| `SURFACE_SECONDARY` | `#1B2A27` | Floating or secondary cards |
| `SURFACE_STRONG` | `#20332E` | High-priority cards |
| `SURFACE_INPUT` | `#1A2623` | Input fields |
| `SURFACE_DISABLED` | `#121A18` | Disabled or inactive areas |

### Notes
- `SURFACE_STRONG` should be used sparingly for important functional panels such as the main workout focus card.
- Cards should feel layered and deliberate, not noisy.

---

## 3. Text Tokens

| Token | Value | Usage |
|---|---:|---|
| `TEXT_PRIMARY` | `#EDF6F2` | Primary copy |
| `TEXT_SECONDARY` | `#A3B3AD` | Secondary explanatory text |
| `TEXT_TERTIARY` | `#6E8078` | Low-emphasis labels |
| `TEXT_DISABLED` | `#55635D` | Disabled text |
| `TEXT_INVERTED` | `#08110E` | Dark text on bright green surfaces |

### Notes
- Primary text should stay soft-white rather than hard white.
- Secondary text should remain readable even on deep cards.
- Tertiary text is for metadata, not primary hierarchy.

---

## 4. Border and Divider Tokens

| Token | Value | Usage |
|---|---:|---|
| `BORDER_SUBTLE` | `#22302C` | Soft boundaries |
| `BORDER_DEFAULT` | `#2A3934` | Standard card/input border |
| `BORDER_STRONG` | `#355047` | Stronger active edge |
| `DIVIDER` | `#1E2B27` | Section separators |

### Notes
- Borders should create precision, not noise.
- Use thin borders and subtle contrast rather than large shadow reliance.

---

## 5. Accent Tokens

### Core Emerald Accent
| Token | Value | Usage |
|---|---:|---|
| `ACCENT_PRIMARY` | `#45C9A1` | Primary action / key focus |
| `ACCENT_HOVER` | `#61E0B5` | Hover / active state |
| `ACCENT_SOFT` | `#8CEBCC` | Glow / soft highlight |
| `ACCENT_DEEP` | `#287A63` | Deep support accent |
| `ACCENT_GLOW` | `rgba(69,201,161,0.18)` | Very subtle emphasis glow |

### Precision / Value Accent
| Token | Value | Usage |
|---|---:|---|
| `ACCENT_METAL` | `#7E8F96` | Silver precision accent |
| `ACCENT_GOLD` | `#B59869` | Rare premium emphasis |
| `ACCENT_GOLD_SOFT` | `#D3B487` | Soft PR/high-value detail |

---

## 6. Status Tokens

| Token | Value | Usage |
|---|---:|---|
| `STATE_SUCCESS` | `#78C99A` | Completed / success |
| `STATE_INFO` | `#61C8D0` | Informational status |
| `STATE_WARNING` | `#C59B63` | Warning / caution |
| `STATE_ERROR` | `#B56D6D` | Error / failure |
| `STATE_NEUTRAL` | `#6D7E78` | Neutral state |

---

## 7. Hard Rules For Green Usage

Green should be used only for emphasis and energy. Preferred uses:
- primary CTA
- active input state
- completion state
- trend increase
- PR improvement callout
- current progress indicator
- key chart line
- high-intensity heatmap cell

Green should not be used for:
- full-page backgrounds
- all cards
- long-form body text
- every badge simultaneously
- decorative visual noise

---

## 8. Quality Check
A screen is **not** on-theme if:
- it looks like generic dark mode with green buttons
- the green is too neon or too saturated
- the UI becomes gaming-like
- silver and gold are overused
- contrast is sacrificed for mood

A screen is on-theme when:
- hierarchy is clear before decoration
- green clearly marks what matters now
- surfaces feel premium and layered
- the interface feels calm, technical, and trustworthy
