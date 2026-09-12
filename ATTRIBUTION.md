# Attribution

Celeste is a from-scratch Omarchy plugin, but it is derived from
[caelestia-dots/shell](https://github.com/caelestia-dots/shell) and is therefore
licensed **GPL-3.0-or-later**, the same licence as that project.

## What is derived

- **Design tokens** (`core/Tokens.qml`) — the rounding, spacing, padding, type
  scale, motion durations and bezier control points follow the Material 3
  Expressive specification, in the same arrangement Caelestia uses
  (`plugin/src/Caelestia/Config/tokens.hpp`).
- **Base components** (`components/`) — `StyledText`, `MaterialIcon`, `Anim`,
  `CAnim`, `StyledRect`, `StyledClippingRect` follow the structure of
  Caelestia's equivalents.
- **Bar components** (`modules/bar/components/`) — `Clock`, `Workspaces` and
  `ActiveWindow` are reimplementations of Caelestia's, including the
  per-monitor workspace-block derivation.

## Omarchy

`modules/bar/popouts/CalendarPopout.qml` and `ClockModel.js` are ported from
Omarchy's own calendar (`shell/plugins/panels/clock/`), which is **MIT**
licensed. Omarchy draws that calendar inside a `KeyboardPanel` — its own
floating window — which cannot be reparented into a panel that grows out of the
border, so the view and its state were ported rather than reused. It imports
`qs.Commons` and `qs.Ui` directly, so it renders with the same `Style`, `Color`
and controls as the original.

This is a fork: if Omarchy changes its calendar, Celeste will not follow.

## What is not

- `core/Colours.qml` is original: Caelestia derives a Material 3 scheme from the
  wallpaper via a native image analyser, whereas Celeste synthesises the same
  role names from the active Omarchy theme's flat tokens.
- `core/Config.qml` is original: Caelestia uses a native reactive
  schema/settings framework; Celeste uses a defaults tree merged with JSON.
- `Bar.qml`'s host integration is specific to Omarchy's plugin contract.

Celeste requires **no native code**. Caelestia's C++ plugin is not used, ported,
or needed.
