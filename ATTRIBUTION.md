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

`core/MenuModel.js` is copied verbatim from Omarchy's own root menu
(`shell/plugins/menu/MenuModel.js`), which is **MIT** licensed and pure JS
with no Qt/QML dependency — parsing/merging `omarchy-menu.jsonc`, the
`when:`/`checked:` shell-guard batch script, route/alias resolution and
search scoring. `modules/menu/MenuPanel.qml` and `services/OmarchyMenu.qml`
are original: they render the same menu data as a border-attached panel
growing up from the bottom of the screen instead of Omarchy's own floating
`KeyboardPanel`. If Omarchy changes its menu data model, Celeste's copy of
`MenuModel.js` will not follow automatically.

`modules/menu/MenuContent.qml`'s layout follows **Caelestia's** launcher
(`modules/launcher/Content.qml` and `items/AppItem.qml`): list anchored
above a bottom-pinned search field, two-line rows sized from the
`launcher.itemWidth`/`itemHeight` tokens, icon over name over dim subtitle.
The `"apps"` provider is filled from Quickshell's own `DesktopEntries`
rather than Omarchy's `AppLibrary` — that service is handed only to plugins
declaring kind `"menu"`, and Celeste declares `"bar"` — so the fuzzy
scoring is Celeste's own, not Omarchy's.

`services/PluginCatalog.qml`'s `isEnabled()`/`isDisabled()`/`isReferenced()`
are a plain-JS reimplementation (not a copy — different output shape, no
clone resolution) of the enabled-plugin logic in Omarchy's own
`shell/services/PluginRegistry.qml` (**MIT** licensed), adapted because that
object is not one a third-party bar is handed: `services/
PluginRegistryApi.qml` (also MIT), what Celeste actually receives as
`root.pluginRegistry`, is deliberately scoped to the bar's own manifest only.
Its plugin-directory scan (`scan_fp`/`scan_tp` in the `Process` command) is
likewise adapted from that file's `rescan()` — same directories, same
`find`/`mindepth`/`maxdepth` shape, different output framing (one JSON array
via `jq`, rather than the original's textual `===kind::dir===` markers). If
Omarchy changes how plugins are enabled/disabled, this copy will not follow
automatically.

`services/AgentUsage.qml`'s formatting/derivation helpers
(`formatTokenCount`, `friendlyModelName`, `windowTitle`, `limitWindows`,
`bindingWindow`, `formatDuration`, `weekPeak`, `modelRows`, `heroMeta`,
`balanceDetailText`/`formatMoney`/`currencyPrefix`, `dayName`/`dayLabel`)
are ported line-for-line from the JS functions in Omarchy's own
`shell/plugins/agents/Panel.qml` (**MIT** licensed) — the session/weekly
window classification and reset-countdown math specifically, which would
have been easy to get subtly wrong by reimplementing from behavior alone.
The data source itself is not ported at all: both this service and the
real plugin's own `Main.qml` read the same `omarchy-agent-usage-update`
CLI output (`$XDG_STATE_HOME/omarchy/agents/usage/*.json`), the same
"shell out to the same tool Omarchy uses" approach already used for
network/battery/bluetooth data. `modules/bar/popouts/AgentsPopout.qml` is
original: a from-scratch layout in Celeste's own `ColumnLayout`/
`StyledText` vocabulary matching the real panel's section order (hero,
provider tabs, limits, balance, tokens by day, tokens by model), not a
copy of that panel's own QML, which is built on Omarchy's `qs.Ui` component
library Celeste does not use. If Omarchy changes the usage JSON schema or
the window/reset classification rules, this copy will not follow
automatically.

`modules/sidepanel/NotifList.qml`'s layout follows **Caelestia's** sidebar
notification list (`modules/sidebar/Notif.qml` + `NotifGroupList.qml`): a
count header with list controls, compact summary-over-body rows with a
relative timestamp, critical entries lifted onto the secondary-container
colour, and swipe-sideways-to-dismiss with a fractional-width release
threshold. None of the machinery under it is ported — `LazyListView`,
`ScriptModel`, `TransformWatcher`, `Props` and `ScreenState` are all from
Caelestia's native C++ plugin, so a plain `ListView` replaces them.

`services/Notifs.qml` is original, and reads Omarchy's own persisted
notification records directly (one JSON file per notification under
`$XDG_STATE_HOME/omarchy/notifications/`, written by
`shell/plugins/notifications/Service.qml`, **MIT** licensed). Celeste runs no
`NotificationServer` of its own: Omarchy's shell already owns the
`org.freedesktop.Notifications` name, and a second server would compete for
it. Actions go through Omarchy's own `IpcHandler { target: "notifications" }`
(`toggleDnd`, `clear`, `dismissAll`) via `omarchy-shell`, the same
"shell out to the real tool" approach used for network/battery/bluetooth.
The record schema and the file layout are Omarchy's; if either changes, this
reader will not follow automatically.

## What is not

- `core/Colours.qml` is original: Caelestia derives a Material 3 scheme from the
  wallpaper via a native image analyser, whereas Celeste synthesises the same
  role names from the active Omarchy theme's flat tokens.
- `core/Config.qml` is original: Caelestia uses a native reactive
  schema/settings framework; Celeste uses a defaults tree merged with JSON.
- `Bar.qml`'s host integration is specific to Omarchy's plugin contract.

Celeste requires **no native code**. Caelestia's C++ plugin is not used, ported,
or needed.
