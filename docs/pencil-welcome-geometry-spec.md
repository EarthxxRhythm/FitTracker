# FitTracker Welcome Geometry Specification

Source read through Pencil MCP:
`C:/Users/Administrator/.pencil/documents/795de57e-5aaa-452a-9b7e-f35f95cb6277/pencil-welcome-desktop.pen`

Reference node: `x8cHBq` / `FitTracker Welcome`.

## Fixed viewport mapping

| Property | Pencil source | ArkUI target |
|---|---:|---:|
| viewport | `430 x 900` | `390 x 844` |
| fixed scale | — | `390 / 430 = 0.9069767442` |
| rendered frame | `430 x 900` | `390 x 816.2791` |
| vertical offset | `0` | `0` |
| outer viewport background | not specified by node | `#000000` to preserve outside-frame pixels |

No responsive rules are introduced. All source geometry is multiplied by the fixed scale.

## Root frame `x8cHBq`

- `x=-1065`, `y=0`, `width=430`, `height=900`
- `clip=true`, `layout=none`, `cornerRadius=38`
- `stroke=#FFFFFF1F`, `strokeWidth=1`
- outer shadow: blur/radius `72`, color `#00000057`, offset `(0,28)`
- fill: radial gradient centered at `(0.18,0.12)`, `#50ECA72B → #50ECA700`; then linear gradient `180°`, `#10171B → #0A0D12`

## Visible nodes and computed geometry

| Node | x | y | width | height | Typography / fill / stroke |
|---|---:|---:|---:|---:|---|
| `SvZra` Notch | 152 | 10 | 126 | 28 | fill `#090C11`, radius `999` |
| `h7GvWs` Status Bar | 18 | 48 | 394 | 24 | `space-between`, icon gap `8` |
| `PFi9v` Time | 0 | 4.5 | 35 | 15 | Inter `12`, weight `500`, `#FFFFFFB8` |
| `h5TP8` Status Icons | 331 | 3.5 | 63 | 17 | gap `8` |
| `fqUKl` Signal | 0 | 1 | 15 | 15 | Lucide `signal`, `#FFFFFFB8` |
| `RrFig` Wifi | 23 | 1 | 15 | 15 | Lucide `wifi`, `#FFFFFFB8` |
| `AEgRx` Battery | 46 | 0 | 17 | 17 | Lucide `battery-medium`, `#FFFFFFB8` |
| `Nvvyf` Brand Lockup | 24 | 118 | 382 | 42 | gap `10`, align center |
| `RHHYc` Brand Mark | 0 | 4 | 34 | 34 | fill `#50ECA71A`, stroke `#50ECA74D`, radius `12` |
| `CwRB8` Activity | 8 | 8 | 18 | 18 | Lucide `activity`, `#50ECA7` |
| `OwBRP` Brand Name | 44 | 12.5 | 107 | 17 | Inter `14`, weight `700`, letter spacing `1.8`, `#F7FBF8` |
| `oLiPi` Eyebrow | 24 | 196 | 182 | 14 | Geist Mono `11`, weight `600`, letter spacing `1.3`, `#50ECA7` |
| `g4X2r` Headline | 24 | 224 | 382 | 82 | Geist `42`, weight `700`, line height `0.98`, `#F7FBF8` |
| `IWITB` Description | 24 | 336 | 346 | 46 | Inter `16`, line height `1.45`, `#FFFFFFA6` |
| `AFtyU` Training Visual | 24 | 420 | 382 | 208 | radius `30`, stroke `#FFFFFF14`, shadow `(0,18), blur36`, gradient fills |
| `K4ujY` Outer Ring | 190 | 10 | 150 | 150 | fill `#50ECA708`, stroke `#50ECA733` |
| `Qvmbg` Inner Ring | 220 | 40 | 90 | 90 | fill `#50ECA712`, stroke `#50ECA766` |
| `pLBcv` Training Figure | 156 | 26 | 92 | 92 | Lucide `person-standing`, `#F7FBF8`, shadow `(0,8), blur18` |
| `OqxAP` Dumbbell | 42 | 92 | 44 | 44 | Lucide `dumbbell`, `#50ECA7` |
| `HoYuS` Sparkles | 300 | 118 | 28 | 28 | Lucide `sparkles`, `#FFFFFFA6` |
| `W4mIQ2` Visual Caption | 24 | 168 | 142 | 13 | Geist Mono `10`, weight `600`, letter spacing `1.1`, `#FFFFFF66` |
| `rqY8W` Actions | 24 | 684 | 382 | 128 | vertical layout, gap `12` |
| `cQhqI` Start Button | 0 | 0 | 382 | 52 | radius `18`, gradient `#47D994 → #53E7A5`, shadow `(0,10), blur24` |
| `x83cFa` Start Label | 158.5 | 14.5 | 65 | 23 | Inter `16`, weight `700`, `#07100B` |
| `wDaMy` Footer Note | 24 | 852 | 382 | 16 | Inter `11`, centered, `#FFFFFF52` |

## Z-order

The root background layers render first. Content follows source order: status bar, brand lockup, eyebrow, headline, description, training visual, actions, footer. Within `AFtyU`, the base gradients render below the rings, figure, accents, and caption. The button label renders above its button gradient.

## Assets

All Pencil MCP `lucide` icons are preserved as local SVG assets with their original Lucide path geometry and the exact source stroke colors. No system icon or substitute glyph is used.

## ArkUI color encoding

Pencil MCP returns translucent colors in `#RRGGBBAA` form. ArkUI accepts eight-digit colors in `#AARRGGBB` form, so implementation-only color values are reordered without changing their rendered RGBA meaning. For example, Pencil `#50ECA71A` becomes ArkUI `#1A50ECA7`.
