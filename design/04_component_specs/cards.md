# Card Spec

## Role
Cards are the primary structural surfaces in FitTracker. They should create hierarchy, focus, and containment.

Cards must not feel like a pile of interchangeable dark rectangles. They should behave like a disciplined layered system.

---

## Core Principles

1. Cards exist to create structure, not noise.
2. Different card levels must communicate different levels of importance.
3. The user should be able to visually identify which card matters most on the screen.
4. Card styling should support the app’s identity as a premium training system.

---

## Card Types

### 1. Standard Card
Use for regular information blocks.

Visual rules:
- Background: `SURFACE_PRIMARY`
- Border: `BORDER_SUBTLE` or `BORDER_DEFAULT`
- Radius: `RADIUS_MD`
- Shadow: subtle or none

Use cases:
- secondary stats
- supporting info
- action groups
- review summary blocks

### 2. Secondary/Floating Card
Use for supporting or layered content that should feel slightly elevated.

Visual rules:
- Background: `SURFACE_SECONDARY`
- Border: `BORDER_DEFAULT`
- Radius: `RADIUS_MD` or `RADIUS_LG`
- Shadow: slightly stronger than standard card, still restrained

Use cases:
- pop-out info areas
- layered summary areas
- secondary panels under a dominant focus section

### 3. Strong Focus Card
Use for the most important panel on a page.

Visual rules:
- Background: `SURFACE_STRONG`
- Border: slightly stronger edge definition if needed
- Radius: `RADIUS_LG`
- Optional very light emerald emphasis around the edge or internal element, not full glow

Use cases:
- today’s workout card on Home
- current training summary panel
- high-value session summary panel

---

## Hierarchy Rules
A page should usually have:
- one visually dominant card
- several supporting cards
- no more than two high-emphasis surfaces in the first viewport

If every card is equally strong, hierarchy is broken.

---

## Surface Feel
Cards should feel like:
- refined dark panels
- premium instrument surfaces
- controlled and intentional layers

Cards should not feel like:
- toy tiles
- floating game HUD blocks
- random rounded boxes
- cheap shadows on dark backgrounds

---

## Spacing Rules Inside Cards
Cards should breathe, but remain efficient.

Recommended internal structure:
- title area
- support copy or metadata
- key action or key metric
- optional footer / secondary action

Avoid stuffing too many unrelated elements into the same card.

---

## Color Rules
- Use green only when the card contains a primary action or a key active state.
- Do not make all cards green-tinted.
- Use silver or muted tones for structure.
- Use gold only for rare/high-value emphasis such as PR or milestone moments.

---

## Content Rules
Cards should not rely on decoration to feel premium.
They should rely on:
- hierarchy
- typography
- spacing
- density control
- one clear purpose per card

If a card tries to do too much, split it.

---

## Success Criteria
A card system is correct if:
- one can quickly spot the most important surface on a page
- supporting surfaces feel quieter and more structural
- the layout feels premium and not noisy
- cards across the app feel like members of one family

---

## Failure Signs
The card system is not acceptable if:
- the page looks like equal-weight dashboard blocks
- cards compete for attention
- all cards have the same background and same emphasis
- card styling depends on heavy shadows instead of clear hierarchy
- cards look improved only because they are darker, not because they are better structured
