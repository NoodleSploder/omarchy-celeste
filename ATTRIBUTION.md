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

## What is not

- `core/Colours.qml` is original: Caelestia derives a Material 3 scheme from the
  wallpaper via a native image analyser, whereas Celeste synthesises the same
  role names from the active Omarchy theme's flat tokens.
- `core/Config.qml` is original: Caelestia uses a native reactive
  schema/settings framework; Celeste uses a defaults tree merged with JSON.
- `Bar.qml`'s host integration is specific to Omarchy's plugin contract.

Celeste requires **no native code**. Caelestia's C++ plugin is not used, ported,
or needed.
