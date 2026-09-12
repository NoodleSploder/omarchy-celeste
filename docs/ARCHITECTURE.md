# Architecture

## Layout

```
manifest.json              kind: "bar", entryPoints.bar = Bar.qml
Bar.qml                    host contract + per-monitor PanelWindows
core/                      singletons (qmldir required)
  Tokens.qml               design system: rounding, spacing, type, motion, sizes
  Colours.qml              full Material 3 scheme synthesised from Omarchy themes
  Config.qml               defaults deep-merged with the user's JSON
  Time.qml                 one shared clock
components/                shared primitives (qmldir required)
modules/bar/components/    bar entries (qmldir required)
```

## The host contract

`configureBar()` in `/usr/share/omarchy/shell/shell.qml` assigns `omarchyPath`,
`shell`, `manifest`, `barWidgetRegistry`, `pluginRegistry` and `barConfig` onto
the bar root if those properties exist. The host then reads back `barSize`,
`barHidden`, `position` and `fontFamily`, binding them into `PluginBarApi` so
panels and overlays can anchor themselves to whichever bar is active.

`summonBarWidget()`, `hideBarWidget()` and `isBarWidgetOpen()` are called by
`shell.summon()` / `hide()` / `isOpen()`. A full bar that does not implement them
makes the system panels log `no live bar widget` and fail to open.

## Two QML mechanics worth knowing

**Plugin-local singletons work.** Put a `qmldir` in the directory with
`singleton Tokens 1.0 Tokens.qml` and import the directory relatively
(`import "core"`). No native import path registration is needed.

**A `qmldir` is required even for plain components.** A relative directory
import without one resolves no types, and the failure reads as
`StyledRect is not a type` — which looks like a missing file rather than a
missing `qmldir`.

## Colour derivation

Omarchy themes expose a handful of flat tokens (`background`, `foreground`,
`accent`, `urgent`, `muted`). Material 3 components expect ~50 named roles.
`Colours.qml` derives the full scheme, expressing every step as *contrast away
from the surface* rather than "lighter" or "darker", so one set of numbers works
in both light and dark themes. `light` is decided by WCAG relative luminance of
the background, and `lift()` flips polarity from it.

## Testing in isolation

`qs.Commons` only resolves inside the Omarchy shell's import path, so loading
`Bar.qml` standalone requires staging it:

```sh
PROBE=$(mktemp -d)
cp -r /usr/share/omarchy/shell/Commons /usr/share/omarchy/shell/Ui "$PROBE/"
cp -r . "$PROBE/plugin"
cat > "$PROBE/shell.qml" <<'QML'
import Quickshell
import QtQuick
ShellRoot {
  Loader {
    source: Qt.resolvedUrl("plugin/Bar.qml")
    onStatusChanged: if (status === Loader.Ready) console.log("OK barSize=" + item.barSize)
  }
  Timer { running: true; interval: 4000; onTriggered: Qt.quit() }
}
QML
qs -p "$PROBE"
```

Kill a probe **by pid**, never with `pkill -f` — the pattern matches the
invoking shell's own command line and kills it mid-command.

## Roadmap

1. Remaining bar entries: `resources`, `media`, `tray`, `statusIcons`, `logo`, `power`
2. Drawer windows owned by `Bar.qml`: dashboard, launcher, sidebar, utilities
3. Edge-drag / hover gesture layer that opens them
4. Workspace overview, including cross-monitor window drag
