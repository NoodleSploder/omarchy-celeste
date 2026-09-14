# External configuration Celeste depends on

Celeste is a self-contained Omarchy bar plugin — installing it is `./deploy.sh`
and nothing else. But a handful of things it does reach outside its own tree,
and this machine accumulated several changes while it was being built. This
file separates the two, because they are not the same kind of thing:

- **[Required](#required)** — without these, a Celeste feature does not work.
- **[Recommended](#recommended)** — Celeste works without them, but they are
  what the design assumes.
- **[This machine only](#this-machine-only)** — hardware and personal-taste
  changes made during Celeste's development that have nothing to do with it.

Every path below is a user-owned file. Nothing here edits `/usr/share/omarchy/`,
which the package manager overwrites on update.

---

## Required

### 1. Do not start a second Quickshell instance

**File:** `~/.config/hypr/autostart.lua`

Celeste is a *plugin inside* Omarchy's shell, not a standalone Quickshell
config. Omarchy's own `omarchy-launch-shell` already starts the one shell it
lives in. Any line like this must be **removed or commented out**:

```lua
-- o.exec_on_start("quickshell -p /usr/share/omarchy/shell")
```

It is usually left behind by a previous standalone-Caelestia setup. Leaving it
in starts a second full shell in the same second as the first, so
`-n`/`--no-duplicate` never catches it, and you get two of everything:

| Symptom | What it actually is |
|---|---|
| Wide gap between windows and the top bar | Two bars each reserving an exclusive zone |
| Launcher "needs closing twice" | Two identical panels stacked pixel-on-pixel |

**Check first, before reading any QML:**

```sh
ps -eo pid,etimes,cmd | grep quickshell | grep -v grep   # must show exactly one
hyprctl monitors -j | jq '.[].reserved'                  # top should be ~60, not ~110
```

### 2. Select Celeste as the bar

**File:** `~/.config/omarchy/shell.json`

```jsonc
{
  "bar": {
    "id": "noodlesploder.celeste",
    "position": "top",
    "layout": { /* ... unchanged ... */ }
  }
}
```

`bar.layout` keeps working: Celeste hosts Omarchy's own bar widgets, and the
left panel's "Show on Celeste bar" switch reads this to know what is already on
a bar.

### 3. Global shortcuts

**File:** `~/.config/hypr/bindings.lua`

Celeste registers four `GlobalShortcut`s under the appid `celeste`. They do
nothing until something is bound to them:

| Shortcut | Purpose |
|---|---|
| `celeste:menu` | The Omarchy menu, rendered by Celeste |
| `celeste:overview` | Toggle the workspace overview |
| `celeste:overviewShow` | Open it (one-way) |
| `celeste:overviewHide` | Close it (one-way) |

```lua
hl.unbind("SUPER + SPACE")
o.bind("SUPER + SPACE", "Omarchy menu", hl.dsp.global("celeste:menu"))

hl.unbind("CTRL + TAB")
o.bind("CTRL + TAB", "Workspace overview", hl.dsp.global("celeste:overview"))
```

`SUPER+SPACE` is rebound rather than added: Celeste renders the same menu data
and the same actions, just in its own panel that grows up from the bottom
border instead of Omarchy's floating window.

### 4. Command-line tools Celeste shells out to

Celeste does not reimplement probing that Omarchy already does correctly — its
popouts call the same tools the native panels call, which is what guarantees
the numbers match.

| Popout / service | Commands |
|---|---|
| Network | `omarchy-network-status`, `omarchy-network-band`, `omarchy-dns` |
| Battery | `omarchy-battery-status`, `omarchy-powerprofiles-list/-set` |
| Bluetooth | `omarchy-bluetooth-device`, `omarchy-bluetooth-power` |
| Audio | `omarchy-audio-output-set-default`, `omarchy-audio-input-set-default` |
| AI usage | `omarchy-agent-usage-update` |
| Session buttons | `omarchy-system-lock`, `-logout`, `-shutdown` |
| Notifications | `omarchy-shell notifications toggleDnd` / `clear` / `dismissAll` |
| Menu | `omarchy-menu` |

Two non-Omarchy tools are also required:

- **`brightnessctl`** — the brightness slider writes through it rather than raw
  sysfs, so its exponential-curve handling stays intact.
- **`inotifywait`** (`inotify-tools`) — notifications and the plugin catalogue
  watch directories rather than polling. Already an Omarchy dependency; its own
  `PluginRegistry` uses it.

### 5. State directories Celeste reads

All under `$XDG_STATE_HOME/omarchy` (`~/.local/state/omarchy`), all written by
Omarchy or its plugins. Celeste reads them directly rather than claiming any
DBus name of its own:

| Path | Read by |
|---|---|
| `notifications/` | live toasts |
| `notifications/history/` | dismissed/expired notifications |
| `notifications.json` | the do-not-disturb flag |
| `agents/usage/*.json` | the AI-usage popout |

**The one place Celeste writes into Omarchy's state**: dismissing a single
history entry `rm`s that entry's own JSON file. No IPC exists for it — the
`dismiss(summary)` handler acts on on-screen toasts only.

Celeste deliberately does **not** run its own `NotificationServer`. Omarchy's
shell already owns `org.freedesktop.Notifications`, and a second server would
risk breaking notification delivery machine-wide.

---

## Recommended

### Touchpad gestures

**File:** `~/.config/hypr/input.lua`

Celeste's overview and Hyprland's workspace swipe are both driven from here.
**Four fingers, not three**, and that distinction matters:

```lua
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "up",
  action = function() hl.dispatch(hl.dsp.global("celeste:overviewShow")) end })
hl.gesture({ fingers = 4, direction = "down",
  action = function() hl.dispatch(hl.dsp.global("celeste:overviewHide")) end })

hl.config({ gestures = { workspace_swipe_create_new = false } })
```

Three-finger swipes were hit or miss because `touchpad.drag_3fg = 1` is also
set — libinput had to decide on the fly whether a three-finger motion was a
click-and-drag or a swipe, and guessed wrong about half the time. macOS splits
them the same way: three fingers drag, four change space.

`workspace_swipe_create_new = false` stops an overswipe past the last workspace
from inventing a new one, which with fixed per-monitor workspaces reads as a
glitch rather than a feature. The other swipe-feel knobs
(`workspace_swipe_distance`, `_cancel_ratio`, `_min_speed_to_force`) are listed
commented-out in that file with their defaults — every one hot-reloads on save.

### Per-monitor workspace blocks

**Files:** `~/.config/hypr/hyprland.lua`, `~/.config/hypr/bindings.lua`

Each monitor owns a contiguous block of six persistent workspaces, matched by
monitor **description** rather than port name — dock reconnects renumber DP
connectors, so a port name is not stable. Celeste's workspace switcher relabels
each block as 1..N, so every monitor reads the same while the underlying ids
stay globally unique.

Because a global id no longer matches what any monitor's bar shows, `SUPER+1..6`
are rebound to the Nth workspace of the *focused* monitor via
`~/.config/hypr/scripts/workspace-relative`, and `SUPER+7..0` are unbound rather
than left pointing at another monitor's block.

This is not strictly a Celeste requirement — the bar works with global
workspaces — but the switcher's design assumes it.

### Celeste's own config

**File:** `~/.config/celeste/shell.json` (falls back to
`~/.config/caelestia/shell.json` if absent, so a machine migrating from
Caelestia keeps its settings).

One trap worth knowing: **objects merge recursively, arrays replace wholesale.**
A `bar.entries` override is a complete replacement, not an element-wise patch —
which is what someone reordering their bar expects, but it also means a new
entry id added to Celeste's built-in defaults will *not* appear if this file has
its own `entries` array. Add it there too.

---

## This machine only

Changes made while Celeste was being built that are unrelated to it. Recorded so
nobody mistakes them for Celeste requirements.

### Dock hotplug recovery (a kernel bug workaround)

**Installer:** `~/dock-hotplug-install.sh` (run once: `sudo bash ~/dock-hotplug-install.sh`)

Booting docked works; hotplugging a Dell Thunderbolt 4 dock does not — the
kernel rejects every atomic modeset with EINVAL, right down to 640x480, under
**both** i915 and xe. Ruled out with evidence: bandwidth, refresh, bit depth,
monitor layout, dock firmware, and driver choice.

The only things that recover it are a reboot or a suspend/resume, because resume
re-initialises the GPU **display engine**, not just the connectors. Nothing
reachable from userspace does that. So the installer lays down a udev rule, a
systemd oneshot, and a guarded script that does a 5-second
`rtcwake -m freeze -s 5` — but only when the externals are genuinely stuck
(connected *and* `enabled=disabled`), a live Hyprland exists, a lock is free,
and a 120s cooldown has elapsed.

```sh
journalctl -t dock-display-recover -f      # watch what it decided
sudo /usr/local/bin/dock-display-recover   # run by hand
sudo bash ~/dock-hotplug-install.sh --uninstall
```

Not verified end to end: this environment cannot escalate privileges, so the
installer has been written and reviewed but not run.

### Other personal changes

| Change | File | Why |
|---|---|---|
| Session restore on start | `autostart.lua` | Third-party `hypr-session-restore` |
| `NVD_BACKEND = "egl"` | `hyprland.lua` | Hybrid Intel+NVIDIA video decode corruption |
| xe instead of i915 | `~/xe-driver-switch.sh` | Tried against the dock bug; did not fix it, left in place because it boots clean |
| Qylock lock screen | `bindings.lua` | Replaces `omarchy-system-lock` |
| Monitor layout | `monitors.lua`, `hyprmoncfg-monitors.lua` | Managed by the `im0001gt.screens` and `crmne.hyprmoncfg` plugins |

### A trap that is *not* Celeste's fault

`~/.config/omarchy/extensions/omarchy-menu.jsonc` is Omarchy's sanctioned
per-user menu override file. A stale override left behind by an uninstalled
plugin once pointed `style.theme` at a script that no longer existed, and
because Omarchy fires menu actions through `execDetached()` — which swallows
stderr and exit status entirely — the failure was completely silent. The theme
switcher simply "did nothing."

**If a menu item does nothing, check this file for a bad override before
touching any QML.** It would have failed identically under the stock bar.
