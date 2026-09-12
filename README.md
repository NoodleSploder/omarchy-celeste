# Celeste

A Material 3 Expressive bar for the [Omarchy](https://omarchy.org) shell,
inspired by [Caelestia](https://github.com/caelestia-dots/shell) and built as a
native Omarchy plugin — **pure QML, no native code, no second Quickshell
instance**.

> Status: bar complete, with hover popouts and a workspace overview
> (click-and-drag windows between workspaces and across monitors). Dashboard,
> launcher and sidebar drawers are next.

## Why a plugin

Running Caelestia alongside Omarchy means two Quickshell processes, and the
Omarchy bar has to be parked off-screen so its widgets stay instantiated for the
system panels to anchor to. Celeste avoids all of that by *being* the Omarchy
bar.

Declaring `"kinds": ["bar"]` grants a plugin the full trusted-bar API — it can
summon, hide and toggle every bar-widget, panel, overlay and menu plugin, and
gets service proxies for idle, media, night light and notifications. `omarchy.bar`
is itself just a plugin of kind `bar`; Celeste replaces it on equal terms.

## Install

```sh
omarchy plugin add https://github.com/NoodleSploder/omarchy-celeste.git
```

Then select it as the active bar in `~/.config/omarchy/shell.json`:

```json
{ "bar": { "id": "noodlesploder.celeste" } }
```

Remove `bar.id` to go back to the built-in bar.

## Development

The repo *is* the plugin — `manifest.json` sits at the root, exactly as
`omarchy plugin add` expects. To install a working copy:

```sh
./deploy.sh              # validate, rsync into the plugins dir, restart the shell
./deploy.sh --validate-only
```

`deploy.sh` rsyncs rather than symlinks, because `omarchy-plugin-validate`
rejects a plugin folder containing symlinks.

### Testing without touching your desktop

Celeste imports `qs.Commons` (Omarchy's theme singletons), which only resolves
inside the shell's import path. To load it in isolation, copy `Commons/` and
`Ui/` out of `/usr/share/omarchy/shell` into a probe directory next to a copy of
the plugin, and point Quickshell at a `shell.qml` that `Loader`s `plugin/Bar.qml`.
See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Workspace overview

Clicking the workspace you are already on opens an expose-style overview on
every monitor at once, each showing its own block of workspaces with live window
previews. Drag a window between workspaces — including onto another monitor's
overview, which works because every card publishes its rectangle in global
layout coordinates and the dragging surface hit-tests them itself.

Bind it, or drive it from a script:

```sh
hyprctl dispatch 'hl.dsp.global("celeste:overview")'
qs -c omarchy ipc call overview toggle
```

## Hosting Omarchy bar widgets

Celeste can render Omarchy's own bar widgets alongside its native entries — add
the widget's plugin id to `bar.entries`:

```json
{ "id": "omarchy.clock", "enabled": true }
```

Any entry id Celeste does not recognise is resolved against the host's widget
registry, so third-party widgets work the same way.

**Limits.** Omarchy's `Ui/PluginBarApi` lives in the shell tree and is
constructed by the built-in bar, so a third-party bar cannot hand out a real
one. Celeste supplies a compatible shim with its own palette; the host's
internal callbacks are no-ops, so a hosted widget renders and updates but its
own popouts and tooltips stay inert.

Separately, a plugin that *self-registers* a bar widget (calling
`barWidgetRegistry.register(...)`) cannot do so under any third-party bar —
plugins receive a detached read-only snapshot of the registry, which has no
`register()`. `im0001gt.screens` is one such plugin.

## Configuration

Celeste reads `~/.config/celeste/shell.json`, falling back to
`~/.config/caelestia/shell.json` if the former does not exist, so a machine
migrating from Caelestia keeps its settings. Built-in defaults cover everything;
the file only needs the keys you want to change.

```json
{
  "bar": {
    "clock": { "showDate": true, "showIcon": false },
    "workspaces": { "shown": 6, "perMonitorWorkspaces": true },
    "entries": [
      { "id": "activeWindow", "enabled": true },
      { "id": "spacer", "enabled": true },
      { "id": "workspaces", "enabled": true },
      { "id": "clock", "enabled": true }
    ]
  }
}
```

### Per-monitor workspaces

With `perMonitorWorkspaces`, each monitor shows only its own block of
workspaces, relabelled `1..shown`. The block is derived from Hyprland's
`workspace_rule` assignments — Celeste reads the monitor's lowest workspace id
rather than duplicating the allocation, so adding a monitor needs no change here.

## Requirements

- Omarchy shell with plugin schema v1
- Quickshell 0.3+
- `Material Symbols Rounded` font (ships with Omarchy)

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE) and [ATTRIBUTION.md](ATTRIBUTION.md).
