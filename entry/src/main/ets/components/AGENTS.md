# Components — Knowledge Base

## OVERVIEW

Reusable ArkUI `@Component` structs for consistent UI across all pages. Props use `@Prop` (one-way binding) for configuration. No internal state except presentation logic.

## STRUCTURE

```
components/
├── AppButton.ets    # primary | secondary | ghost, large | medium | small, loading/disabled/block
├── AppCard.ets      # elevated | outlined variant, default | compact padding
├── AppInput.ets     # TextInput wrapper with label, error state, icon prefix/suffix
├── MainTabBar.ets   # Bottom tab navigation (训练, 动作库, 统计, 我的)
└── StatBadge.ets    # Stat display badge (icon-like, small)
```

## WHERE TO LOOK

| Component | Props | Usage |
|-----------|-------|-------|
| `AppButton` | `text`, `type`, `size`, `disabled`, `loading`, `block`, `onButtonClick` | All pages — primary CTA, secondary action, ghost text button |
| `AppCard` | `variant` ('elevated'\|'outlined'), `padding` ('default'\|'compact') | Content containers — stats, records, plan cards |
| `AppInput` | `label`, `placeholder`, `type`, `value`, `error`, `onChange` | Forms — login, register, profile |
| `MainTabBar` | none (self-contained) | Bottom navigation |
| `StatBadge` | `label`, `value`, `color` | Stat highlights |

## CONVENTIONS

- **Props**: `@Prop` for config, callbacks as optional functions (`onXxx?: () => void`).
- **Sizing**: Height from `TouchTokens` (`BUTTON_HEIGHT_DEFAULT: 48`, `BUTTON_HEIGHT_SMALL: 36`). Min touch target 48vp.
- **Tokens**: ALL colors/spacing/radii from `DesignTokens.ets`. NO hardcoded values.
- **Layout**: `block` prop uses `width('100%')`, otherwise `width('auto')`.

## ANTI-PATTERNS

- **DO NOT** modify `AppButton` primary background color (`ColorTokens.PRIMARY`).
- **DO NOT** add shadows to ghost button variants.
- **DO NOT** add @State inside components — use @Prop or callbacks.
- **DO NOT** hardcode dimensions — use `TouchTokens`, `SpacingTokens`.
