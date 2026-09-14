pragma ComponentBehavior: Bound

// Celeste -- a full bar replacement for the Omarchy shell.
//
// Declaring kind "bar" in manifest.json is what grants bar capabilities:
// shell.qml's pluginHasBarCapabilities() is a kinds check and nothing more, so
// a third-party full bar receives summon/hide/toggle over every bar-widget,
// panel, overlay and menu plugin, plus the omarchy.idle, omarchy.media,
// omarchy.nightlight and omarchy.notifications service proxies.
//
// The root is a plain Item that owns its own per-monitor PanelWindows, the same
// shape as the first-party plugins/bar/Bar.qml. That matters beyond the bar:
// Celeste's drawers will be additional windows created here, keeping bar and
// drawers in one scope so they can share state and draw as one surface.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "core"
import "components"
import "modules/bar" as BarModules
import "modules/bar/components" as BarComponents
import "modules/bar/popouts" as Popouts
import "modules/overview" as OverviewModule
import "modules/menu" as MenuModule
import "modules/sidepanel" as SidePanelModule
import "modules/settings" as SettingsModule
import "modules/leftpanel" as LeftPanelModule
import "services"

Item {
    id: root

    // ---------------------------------------------------------- host inputs
    // configureBar() in shell.qml assigns each of these if the property exists.

    property string omarchyPath: Quickshell.env("OMARCHY_PATH")
    property var shell: null
    property var manifest: null
    property var barWidgetRegistry: null
    property var pluginRegistry: null
    property var barConfig: ({})

    // -------------------------------------------------------- host contract
    // shell.qml binds these into PluginBarApi so panels and overlays can anchor
    // themselves relative to whichever bar is active.

    readonly property int borderThickness: Config.border.enabled ? Config.border.thickness : 0
    readonly property int borderRounding: Config.border.rounding

    readonly property int padding: Math.max(Tokens.padding.small, borderThickness)
    readonly property int barSize: Tokens.sizes.bar.innerWidth + padding * 2
    property bool barHidden: false
    readonly property string position: "top"
    readonly property string fontFamily: Tokens.font.sans

    // ------------------------------------------------------ bar-widget hooks
    //
    // A full bar is expected to host Omarchy's own widgets; the host exposes its
    // catalogue through PluginBarWidgetRegistryApi explicitly "for third-party
    // full-bar implementations". These three functions are what shell.qml calls
    // to open the system panels (Super+Ctrl+A/B/W/D/P and the calendar), so they
    // must answer truthfully or summon() logs "no live bar widget".

    // Live hosted widget instances, keyed by widget id. One entry per monitor,
    // since each bar surface instantiates its own copy.
    // Where the clock sits, so panels anchored to it open beneath it.
    property real clockCentre: 0

    // Full Omarchy panels are hosted invisibly. Keep an anchor per output and
    // per panel id, rather than sharing the clock's x coordinate: a shared
    // coordinate is wrong as soon as a second monitor reports its clock.
    property var statusPanelAnchors: ({})

    property var hostedItems: ({})

    function registerHosted(id, item) {
        const key = String(id || "");
        if (!key || !item)
            return;
        const next = {};
        for (const k in root.hostedItems)
            next[k] = root.hostedItems[k].slice();
        if (!next[key])
            next[key] = [];
        if (next[key].indexOf(item) === -1)
            next[key].push(item);
        root.hostedItems = next;
    }

    function unregisterHosted(id, item) {
        const key = String(id || "");
        if (!key)
            return;
        const next = {};
        for (const k in root.hostedItems)
            next[k] = root.hostedItems[k].filter(i => k !== key || i !== item);
        root.hostedItems = next;
    }

    // Prefer the copy on the focused monitor, so a panel opens where the user is
    // looking rather than always on the first screen.
    function hostedItemFor(id) {
        const list = root.hostedItems[String(id || "")];
        if (!list || list.length === 0)
            return null;
        const focused = Hyprland.focusedMonitor;
        if (focused)
            for (const item of list)
                if (item.hostScreen && item.hostScreen.name === focused.name)
                    return item;
        return list[0];
    }

    // The host calls these to drive a widget's own panel. They must actually
    // open it -- returning a bare true while doing nothing makes shell.summon()
    // report success for a panel that never appeared.
    //
    // Open acts on one instance (the focused monitor's), but close and the
    // is-open test act on ALL of them. A widget hosted as an anchor exists once
    // per monitor, so asking only the focused copy whether it is open gets the
    // wrong answer as soon as focus has moved since it opened -- the panel then
    // reads as closed, every toggle re-opens it, and it can never be dismissed.
    function summonBarWidget(id) {
        const item = root.hostedItemFor(id);
        if (!item || !item.widgetItem || typeof item.widgetItem.open !== "function")
            return false;
        item.widgetItem.open();
        return true;
    }

    function hideBarWidget(id) {
        const list = root.hostedItems[String(id || "")];
        if (!list || list.length === 0)
            return false;
        let closed = false;
        for (const item of list) {
            if (item.widgetItem && typeof item.widgetItem.close === "function") {
                item.widgetItem.close();
                closed = true;
            }
        }
        return closed;
    }

    function isBarWidgetOpen(id) {
        const list = root.hostedItems[String(id || "")];
        if (!list)
            return false;
        for (const item of list)
            if (item.widgetItem && item.widgetItem.opened === true)
                return true;
        return false;
    }

    // ------------------------------------------------------------- entries

    readonly property var entries: (Config.bar.entries || []).filter(e => e && e.enabled)

    // ------------------------------------------------------------ sections
    //
    // The bar is three sections, and `entries` still decides what goes in
    // each: the first two "spacer" entries are the boundaries. That keeps one
    // source of truth for element order and means an existing config needs no
    // migration -- the default entries list already reads left / spacer /
    // middle / spacer / right.
    //
    // A THIRD or later spacer is not a boundary; it stays in whatever section
    // it landed in and still works as an in-section filler.
    readonly property var sectionEntries: {
        const out = { left: [], middle: [], right: [] };
        const order = ["left", "middle", "right"];
        let bucket = 0;
        for (const e of root.entries) {
            if (e.id === "spacer" && bucket < 2) {
                bucket++;
                continue;
            }
            out[order[bucket]].push(e);
        }
        return out;
    }

    readonly property var sectionConfig: Config.bar.sections || ({})
    readonly property string sectionMode: String(root.sectionConfig.mode || "percent")

    // Resolves the three section widths for a bar of `avail` usable pixels.
    //
    // In fixed mode a width may be the string "remaining", which takes an
    // equal share of whatever the fixed sections leave over -- that is how
    // "Middle: 250px or Remaining" is expressed. In percent mode every width
    // is a share of `avail`.
    function sectionWidths(avail) {
        const keys = ["left", "middle", "right"];
        const out = {};

        if (root.sectionMode === "fixed") {
            const fixed = root.sectionConfig.fixed || ({});
            const flexible = [];
            let used = 0;
            for (const k of keys) {
                if (String(fixed[k]) === "remaining") {
                    flexible.push(k);
                    out[k] = 0;
                } else {
                    out[k] = Math.max(0, Number(fixed[k]) || 0);
                    used += out[k];
                }
            }
            if (flexible.length > 0) {
                const share = Math.max(0, avail - used) / flexible.length;
                for (const k of flexible)
                    out[k] = share;
            }
            return out;
        }

        const percent = root.sectionConfig.percent || ({});
        for (const k of keys)
            out[k] = avail * Math.max(0, Number(percent[k]) || 0) / 100;
        return out;
    }

    // Opens/closes a plugin from the Plugins bar strip (see
    // services/PluginCatalog.qml for why the enabled-plugins list itself
    // isn't sourced from root.pluginRegistry -- that object is scoped to
    // Celeste's own manifest only, not a catalogue of everything installed).
    // shell.toggle() is the same general-purpose invocation already used for
    // the calendar's fallback path above, and works regardless of whether
    // the target plugin is hosted anywhere in this bar.
    function togglePlugin(id) {
        if (root.shell && typeof root.shell.toggle === "function")
            root.shell.toggle(id, "{}");
    }

    // Clicking the clock opens the Omarchy calendar panel.
    //
    // That panel belongs to a bar-widget plugin and anchors itself to a *live*
    // widget instance, so the plugin must be hosted somewhere in this bar. Rather
    // than make the user add it to bar.entries by hand, each surface hosts it
    // invisibly below -- see anchorWidgetIds.
    property string calendarWidgetId: Config.bar.clock.calendarWidget

    // Plugins hosted purely as panel anchors: live, laid out, but drawing
    // nothing. Any id that the registry does not know is skipped.
    readonly property var anchorWidgetIds: {
        const ids = [];
        if (root.calendarWidgetId)
            ids.push(root.calendarWidgetId);
        for (const id of (Config.bar.anchorWidgets || []))
            if (ids.indexOf(id) === -1)
                ids.push(id);
        const panels = Config.bar.statusIconPanels || ({});
        for (const key in panels) {
            const id = panels[key];
            if (id && ids.indexOf(id) === -1)
                ids.push(id);
        }
        return ids;
    }

    // Which monitor currently shows the calendar; "" means closed everywhere.
    //
    // Held as a monitor name rather than a bool because the panel exists once
    // per surface: a shared bool would open and close all four at once. Storing
    // the owner instead makes "only one at a time" fall out of the binding --
    // opening on a second monitor reassigns the name, which closes the first.
    property string calendarScreen: ""

    // Clicking the clock toggles Celeste's own calendar panel, which grows out
    // of the top border. Set bar.clock.calendarWidget to a plugin id to summon
    // that plugin's floating panel instead.
    function toggleCalendar(screenName) {
        if (root.calendarWidgetId) {
            if (!root.toggleHosted(root.calendarWidgetId) && root.shell
                && typeof root.shell.toggle === "function")
                root.shell.toggle(root.calendarWidgetId, "{}");
            return;
        }
        const name = String(screenName || "");
        root.calendarScreen = (root.calendarScreen === name) ? "" : name;
    }

    function closeCalendar() {
        root.calendarScreen = "";
    }

    // The monitor the user is on, for callers with no screen of their own.
    function focusedScreenName() {
        const mon = Hyprland.focusedMonitor;
        return mon ? String(mon.name) : "";
    }

    // Keeps Hyprland's `lastIpcObject` snapshots current.
    //
    // Quickshell tracks workspaces/toplevels/monitors as objects, but the
    // detail fields hanging off `lastIpcObject` -- a workspace's window
    // COUNT, its monitor, a toplevel's class -- come from a full `hyprctl -j`
    // query, and nothing re-runs that query on its own. Anything reading them
    // therefore keeps showing whatever was true when the shell started: the
    // workspace dots were stuck on the occupancy they had at launch, filling
    // in only on restart.
    //
    // Ported from the Caelestia backup's services/Hypr.qml, which hits the
    // same wall and solves it the same way. The event names are gated rather
    // than refreshing on everything, since Hyprland emits these constantly;
    // "v2" variants are skipped because they duplicate the plain event.
    //
    // Root scope on purpose: this Item is instantiated once (the per-monitor
    // surfaces come from the Variants below), so there is exactly one
    // refresher rather than one per screen re-querying the same state.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const n = event.name;
            if (n.endsWith("v2"))
                return;

            if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                // The occupancy case: a window appearing or leaving changes a
                // workspace's count, so both lists have to be re-read.
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
            } else if (["workspace", "moveworkspace", "activespecial", "focusedmon"].includes(n)) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshMonitors();
            } else if (n.includes("mon")) {
                Hyprland.refreshMonitors();
            } else if (n.includes("workspace")) {
                Hyprland.refreshWorkspaces();
            } else if (n.includes("window") || n.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) {
                Hyprland.refreshToplevels();
            }
        }
    }

    // Clicking a status icon toggles its full Omarchy panel. Hovering uses the
    // same panel, but only ever opens it: moving across an already-open icon
    // must not immediately close the mixer beneath the pointer.
    function statusPanelId(name) {
        const panels = Config.bar.statusIconPanels || ({});
        return panels[String(name)] || "";
    }

    function closeOtherStatusPanels(keepId) {
        const panels = Config.bar.statusIconPanels || ({});
        const closed = {};
        for (const key in panels) {
            const id = panels[key] || "";
            if (id && id !== keepId && !closed[id]) {
                root.hideBarWidget(id);
                closed[id] = true;
            }
        }
    }

    function setStatusPanelAnchor(name, screenName, centre) {
        const id = root.statusPanelId(name);
        if (!id || !screenName)
            return;
        const next = {};
        for (const key in root.statusPanelAnchors)
            next[key] = root.statusPanelAnchors[key];
        next[`${screenName}:${id}`] = Math.max(0, Number(centre) || 0);
        root.statusPanelAnchors = next;
    }

    function panelAnchorCentre(screenName, panelId) {
        const value = root.statusPanelAnchors[`${screenName}:${panelId}`];
        return value === undefined ? root.clockCentre : value;
    }

    function openStatusPanel(name) {
        const id = root.statusPanelId(name);
        if (!id)
            return false;
        if (root.isBarWidgetOpen(id))
            return root.hideBarWidget(id);
        root.closeOtherStatusPanels(id);
        return root.summonBarWidget(id);
    }

    function showStatusPanelOnHover(name) {
        const id = root.statusPanelId(name);
        if (!id)
            return false;
        root.closeOtherStatusPanels(id);
        // This is deliberately not toggleHosted(): StatusIcons emits hover
        // updates continuously, and a toggle would flicker the real panel.
        if (!root.isBarWidgetOpen(id))
            return root.summonBarWidget(id);
        return true;
    }

    function toggleHosted(id) {
        const item = root.hostedItemFor(id);
        if (!item || !item.widgetItem)
            return false;
        if (root.isBarWidgetOpen(id))
            return root.hideBarWidget(id);
        return root.summonBarWidget(id);
    }

    // Renders Omarchy's own menu data (services/OmarchyMenu.qml) in Celeste's
    // own border-attached panel instead of toggling Omarchy's native
    // omarchy.menu plugin -- same SUPER+Space keybind and the same items,
    // grown up from the bottom border like Caelestia's launcher instead of
    // Omarchy's floating KeyboardPanel.
    function openOmarchyMenu() {
        OmarchyMenu.toggle(root.focusedScreenName());
        return true;
    }

    function openOmarchyThemeSwitcher() {
        // The picker is a blocking request/reply conversation with Omarchy's
        // image-selector overlay. Keep the process alive here until the user
        // picks or cancels; a detached command can be reaped before it gets
        // the selector's reply on some Quickshell versions.
        if (!themeSwitcher.running)
            themeSwitcher.running = true;
        return true;
    }

    Process {
        id: themeSwitcher

        command: [
            "bash",
            "-c",
            "theme=$(omarchy-theme-switcher); [[ -n \"$theme\" ]] && omarchy-theme-set \"$theme\" >/dev/null 2>&1"
        ]
    }

    // ------------------------------------------------------- external control
    //
    // A global shortcut so the overview can be bound in Hyprland, and an IPC
    // target so it can be driven from scripts:
    //
    //   hyprctl dispatch 'hl.dsp.global("celeste:overview")'
    //   qs -c omarchy ipc call overview toggle

    GlobalShortcut {
        appid: "celeste"
        name: "overview"
        description: "Toggle the workspace overview"
        onPressed: OverviewState.toggle()
    }

    // One-way counterparts to "overview" above, for the four-finger swipe in
    // ~/.config/hypr/input.lua: a direction gesture should mean the same thing
    // every time, so up always opens and down always closes rather than both
    // toggling.
    GlobalShortcut {
        appid: "celeste"
        name: "overviewShow"
        description: "Open the workspace overview"
        onPressed: OverviewState.show()
    }

    GlobalShortcut {
        appid: "celeste"
        name: "overviewHide"
        description: "Close the workspace overview"
        onPressed: OverviewState.close()
    }

    GlobalShortcut {
        appid: "celeste"
        name: "menu"
        description: "Toggle the Omarchy menu"
        onPressed: root.openOmarchyMenu()
    }

    IpcHandler {
        target: "calendar"

        function toggle(): void {
            root.toggleCalendar(root.focusedScreenName());
        }

        function close(): void {
            root.closeCalendar();
        }
    }

    IpcHandler {
        target: "menu"

        function toggle(): void {
            root.openOmarchyMenu();
        }

        function open(): void {
            root.openOmarchyMenu();
        }

        function close(): void {
            if (root.shell && typeof root.shell.hide === "function")
                root.shell.hide("omarchy.menu");
        }
    }

    IpcHandler {
        target: "theme"

        function open(): void {
            root.openOmarchyThemeSwitcher();
        }

        function toggle(): void {
            root.openOmarchyThemeSwitcher();
        }
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            OverviewState.toggle();
        }

        function open(): void {
            OverviewState.open = true;
        }

        function close(): void {
            OverviewState.close();
        }

        function isOpen(): bool {
            return OverviewState.open;
        }
    }

    // ------------------------------------------------------------ surfaces
    //
    // Two window sets per monitor.
    //
    // The frame must be drawn by a window that covers the whole screen, because
    // its arched corners span the join between the bar and the screen edges. But
    // a fullscreen layer-shell surface would swallow every click, so its input
    // mask is narrowed to the bar strip and nothing else -- the frame is inert.
    //
    // A fullscreen window also cannot express four different exclusive zones, so
    // the space each edge reserves is claimed by four 1x1 helper windows. They
    // are 1x1 rather than 0x0 deliberately: a 0x0 layer surface never maps, and
    // then reserves nothing, silently.

    Variants {
        model: Quickshell.screens

        Scope {
            id: exclusions

            required property var modelData

            PanelWindow {
                screen: exclusions.modelData
                WlrLayershell.namespace: "celeste-exclusion"
                anchors.top: true
                exclusiveZone: root.barHidden ? 0 : root.barSize
                mask: Region {}
                implicitWidth: 1
                implicitHeight: 1
                color: "transparent"
            }

            PanelWindow {
                screen: exclusions.modelData
                WlrLayershell.namespace: "celeste-exclusion"
                anchors.left: true
                exclusiveZone: root.borderThickness
                mask: Region {}
                implicitWidth: 1
                implicitHeight: 1
                color: "transparent"
            }

            PanelWindow {
                screen: exclusions.modelData
                WlrLayershell.namespace: "celeste-exclusion"
                anchors.right: true
                exclusiveZone: root.borderThickness
                mask: Region {}
                implicitWidth: 1
                implicitHeight: 1
                color: "transparent"
            }

            PanelWindow {
                screen: exclusions.modelData
                WlrLayershell.namespace: "celeste-exclusion"
                anchors.bottom: true
                exclusiveZone: root.borderThickness
                mask: Region {}
                implicitWidth: 1
                implicitHeight: 1
                color: "transparent"
            }
        }
    }

    // Anchor host surfaces.
    //
    // Omarchy panels position themselves from `anchorWindow.height`, taking it
    // to be the bar's height -- Omarchy's own bar is a bar-height window, so
    // that holds there. Celeste draws its bar inside ONE FULLSCREEN surface, so
    // hosting an anchor in it reports a bar 1440px tall and the panel opens at
    // the bottom of the screen.
    //
    // So anchors live in their own window instead: full width, exactly bar
    // height, transparent, and masked to accept no input. Nothing is drawn here;
    // it exists purely to give hosted panels an honest coordinate frame.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: anchorSurface

            required property var modelData

            screen: anchorSurface.modelData

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "celeste-anchors"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors.top: true
            anchors.left: true
            anchors.right: true

            implicitHeight: root.barSize
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            color: "transparent"
            mask: Region {}

            Repeater {
                model: root.anchorWidgetIds

                delegate: BarModules.HostedWidget {
                    required property string modelData

                    // The first-party KeyboardPanel reads this item's geometry
                    // to place itself. Bind it to the hovered icon on this
                    // output, falling back to the clock for keyboard summons.
                    x: Math.max(0, Math.min(
                        root.panelAnchorCentre(String(anchorSurface.modelData.name), modelData),
                        anchorSurface.width - 1))
                    y: 0

                    widgetId: modelData
                    registry: root.barWidgetRegistry
                    shell: root.shell
                    settings: ({ hidden: true })
                    barSize: Tokens.sizes.bar.innerWidth
                    barTotalSize: root.barSize
                    hostScreen: anchorSurface.modelData

                    onRegistered: (id, self) => root.registerHosted(id, self)
                    onUnregistered: (id, self) => root.unregisterHosted(id, self)
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData

            screen: panel.modelData

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "celeste-bar"
            // OnDemand, not None: this surface now hosts real text input (the
            // menu's search box, and NetworkPopout's Wi-Fi password field,
            // which had the same defect already -- neither could ever
            // actually receive a keystroke under None, silently, since a QML
            // `focus: true` binding has no effect on Wayland-level keyboard
            // focus at all). OnDemand only takes focus when something inside
            // actually wants it, so this is a no-op for every other bar
            // surface interaction.
            //
            // OnDemand is not enough on its own for the menu, though.
            // "On demand" means the compositor hands this surface focus when
            // the user interacts with it -- a click. Summoned by a keybind
            // instead, with a real window already focused, Hyprland leaves
            // focus where it is and every keystroke goes to that window:
            // reproduced exactly (focus Chromium, SUPER+Space, type, watch
            // the text land in the browser while the menu's own cursor sits
            // there blinking, because a QML forceActiveFocus() only claims
            // focus WITHIN the surface).
            //
            // Omarchy's own Ui/KeyboardPanel.qml hits this and solves it by
            // priming with Exclusive -- which does take focus, including for
            // an ALREADY-MAPPED surface like this one (the bar never unmaps,
            // so there is no map-time grant to rely on) -- then settling back
            // to OnDemand a beat later. Exclusive must not be held: it makes
            // Hyprland route every pointer event to this surface regardless
            // of which output the cursor is over, which would break clicks on
            // other monitors. 75ms matches KeyboardPanel's own prime.
            // Anything on this surface with a text field needs the same
            // treatment, not just the launcher: the left panel's plugin
            // search is a second one, and a field that never receives a
            // keystroke is exactly the failure this priming exists to avoid.
            readonly property bool wantsKeyboard: panel.menuOpen || panel.leftPanelOpen

            WlrLayershell.keyboardFocus: panel.wantsKeyboard
                ? (panel.keyboardPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
                : WlrKeyboardFocus.OnDemand

            property bool keyboardPrimed: false

            onWantsKeyboardChanged: {
                panel.keyboardPrimed = false;
                if (panel.wantsKeyboard)
                    keyboardPrime.restart();
                else
                    keyboardPrime.stop();
            }

            Timer {
                id: keyboardPrime

                interval: 75
                onTriggered: panel.keyboardPrimed = true
            }

            anchors.top: true
            anchors.left: true
            anchors.right: true
            anchors.bottom: true

            // The helper windows above own the exclusive zones. This surface
            // must also IGNORE them: a layer-shell window anchored to all four
            // edges is otherwise shrunk by every other surface's exclusive zone,
            // including its own helpers, which pushes the frame inward and
            // leaves a strip of wallpaper above the bar.
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            color: "transparent"

            // Input is limited to the bar strip plus, while open, the popout.
            // Regions union, so the frame stays click-through either way -- and
            // an open panel must be added or its own controls never receive the
            // clicks that the mask is busy discarding.
            // A Region with no item is EMPTY, not "everything" -- the exclusion
            // windows above rely on exactly that to accept no input at all. So
            // the overview cannot be handled by nulling the region's item; the
            // mask property itself has to go away, since an unset mask is what
            // means "the whole surface accepts input".
            // The menu joins this list for the same reason the calendar is in
            // it: click-outside-to-close needs the surface to actually accept
            // a click outside the bar strip, and barRegion by definition
            // discards exactly those.
            mask: (OverviewState.open || panel.calendarOpen || panel.menuOpen || panel.settingsOpen || panel.leftPanelOpen) ? null : panel.barRegion

            property Region barRegion: Region {
                item: barStrip

                Region {
                    item: popout
                    intersection: Intersection.Combine
                }

                Region {
                    item: calendarPopout
                    intersection: Intersection.Combine
                }

                Region {
                    item: menuPanel
                    intersection: Intersection.Combine
                }

                Region {
                    item: sidePanel
                    intersection: Intersection.Combine
                }

                Region {
                    item: menuHotzone
                    intersection: Intersection.Combine
                }

                Region {
                    item: settingsPanel
                    intersection: Intersection.Combine
                }

                Region {
                    item: leftPanel
                    intersection: Intersection.Combine
                }
            }

            readonly property bool calendarOpen:
                root.calendarScreen !== "" && root.calendarScreen === String(panel.modelData.name)

            readonly property bool menuOpen:
                OmarchyMenu.open && OmarchyMenu.screenName === String(panel.modelData.name)

            readonly property bool settingsOpen:
                SettingsPanel.open && SettingsPanel.screenName === String(panel.modelData.name)

            readonly property bool leftPanelOpen:
                LeftPanel.panel !== "" && LeftPanel.screenName === String(panel.modelData.name)

            // Which status icon the pointer is over, and where it sits.
            property string popoutName: ""
            property real popoutCentre: 0



            // Closing is delayed so travel between the icon and the panel does
            // not dismiss it mid-move.
            Timer {
                id: popoutCloser

                interval: Tokens.anim.durations.small
                onTriggered: panel.popoutName = ""
            }

            function setPopout(name, centre) {
                if (name) {
                    popoutCloser.stop();
                    panel.popoutName = name;
                    panel.popoutCentre = centre;
                } else if (!popoutHover.hovered) {
                    popoutCloser.restart();
                }
            }

            // Declared here rather than on root: the Components below live in
            // this scope, so a resolver on root could not see them.
            //
            // An entry that is not implemented yet resolves to null and renders
            // nothing, rather than drawing a placeholder that looks like a bug.
            function componentFor(id) {
                switch (id) {
                case "spacer":
                    return spacerComponent;
                case "workspaces":
                    return workspacesComponent;
                case "clock":
                    return clockComponent;
                case "activeWindow":
                    return activeWindowComponent;
                case "statusIcons":
                    return statusIconsComponent;
                case "runningApps":
                    return runningAppsComponent;
                case "tray":
                    return trayComponent;
                case "media":
                    return mediaComponent;
                case "resources":
                    return resourceComponent;
                default:
                    // Not a Celeste entry: treat the id as an Omarchy bar widget
                    // and let HostedWidget resolve it against the registry. An
                    // id that matches nothing renders at zero width.
                    return hostedWidgetComponent;
                }
            }

            OverviewModule.Overview {
                anchors.fill: parent
                hostScreen: panel.modelData
                barSize: root.barSize
                borderThickness: root.borderThickness
                z: 10
            }

            BarModules.Border {
                anchors.fill: parent
                borderLeft: root.borderThickness
                borderRight: root.borderThickness
                borderBottom: root.borderThickness
                borderTop: root.barHidden ? root.borderThickness : root.barSize
                radius: root.borderRounding
            }

            // Clicking anywhere off the menu dismisses it. MenuPanel swallows
            // presses that land on itself (see the catch-all MouseArea in
            // MenuPanel.qml), so this only ever sees clicks that really are
            // outside it.
            //
            // z 10, not 0 like the calendar's closer below: that one sits
            // under barStrip so the bar keeps working while the calendar is
            // open, which for a launcher would mean clicking a status icon
            // opens its popout with the menu still standing behind it -- two
            // panels at once. Above the bar (but below menuPanel and
            // sidePanel at 11), the first click dismisses and the second does
            // the thing, which is how every launcher behaves.
            MouseArea {
                anchors.fill: parent
                z: 10
                enabled: panel.menuOpen
                visible: panel.menuOpen
                acceptedButtons: Qt.AllButtons
                onPressed: OmarchyMenu.close()
            }

            // Only the monitor OmarchyMenu.show() captured shows it -- see
            // the comment on OmarchyMenu.screenName for why that's a captured
            // value rather than a live "am I focused" binding.
            MenuModule.MenuPanel {
                id: menuPanel

                // No anchors.fill here: MenuPanel positions itself (bottom +
                // horizontal-center) against whatever it's parented to, which
                // just needs to span this surface -- an external anchors.fill
                // would fight its own internal anchors.
                z: 11
                borderThickness: root.borderThickness
                open: panel.menuOpen
                contentComponent: menuContent
            }

            Component {
                id: menuContent

                MenuModule.MenuContent {}
            }

            // Hover hotzone for the launcher: the segment of the BOTTOM
            // border directly under where MenuPanel opens, matching its
            // width. Same reasoning as the side panel's edge strip -- it
            // stays within the border, which the exclusion windows above
            // already reserve, so hovering it costs no app area.
            //
            // z 11 puts it above the click-outside closer (z 10) so that
            // closer can't shadow it while the menu is open. It holds only a
            // HoverHandler, which doesn't consume presses, so a click here
            // still falls through to the closer.
            Item {
                id: menuHotzone

                z: 11
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                // The launcher's own width. MenuPanel can't be measured while
                // it's shut -- its content Loader is inactive then, so it
                // reports bare padding -- and this is the token MenuContent
                // pins itself to, so the two stay the same width by
                // construction.
                width: Tokens.sizes.launcher.itemWidth + Tokens.padding.large * 2
                // The floor only matters if borders are configured off, where
                // borderThickness is 0 and the strip would vanish entirely.
                height: Math.max(root.borderThickness, Config.border.minThickness)

                HoverHandler {
                    id: menuHotzoneHover

                    onHoveredChanged: {
                        if (menuHotzoneHover.hovered)
                            menuHotzoneDwell.restart();
                        else
                            menuHotzoneDwell.stop();
                    }
                }

                // Brushing past the screen edge shouldn't summon a launcher
                // that takes keyboard focus, so the pointer has to settle
                // here first.
                Timer {
                    id: menuHotzoneDwell

                    interval: 250
                    onTriggered: {
                        // show() resets the route stack and query, so calling
                        // it on a menu that's already up would throw away
                        // whatever the user had navigated to.
                        if (!panel.menuOpen)
                            OmarchyMenu.show(String(panel.modelData.name));
                    }
                }
            }

            // Screen-targeted, like the menu and the calendar: one monitor
            // shows this at a time, chosen by SidePanel.screenName (the
            // hovered screen, or the focused one for the reactive
            // volume/brightness path). Caelestia's own OSD does appear on
            // every screen at once and Celeste matched that originally, but
            // four copies of the sliders/session/notification drawer on a
            // multi-monitor desk is not what was wanted here.
            // The left edge's hover rail and its slideouts -- the mirror of
            // sidePanel below, and screen-targeted the same way so only the
            // monitor the pointer settled on shows it.
            LeftPanelModule.LeftPanel {
                id: leftPanel

                screen: panel.modelData
                borderThickness: root.borderThickness
                topInset: root.barHidden ? root.borderThickness : root.barSize
                z: 11

                onPluginActivated: id => root.togglePlugin(id)
            }

            SidePanelModule.SidePanel {
                id: sidePanel

                screen: panel.modelData
                borderThickness: root.borderThickness
                // Same value BarModules.Border uses for borderTop above: the
                // bar IS the top border while it's shown, so the side panel
                // treats it as the top edge of its usable area and never
                // draws over it. Follows barHidden for the same reason the
                // border does -- hidden bar, space comes back.
                topInset: root.barHidden ? root.borderThickness : root.barSize
                z: 11
            }

            Item {
                id: barStrip

                z: 2
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.barHidden ? 0 : root.barSize
                visible: !root.barHidden

                // Three independently sized sections, POSITIONED rather than
                // laid out in a row: left anchored left, right anchored right,
                // middle anchored to the centre of the bar.
                //
                // That is the fix for the centred group drifting. A RowLayout
                // gave the middle whatever space the outer two happened to
                // leave, so a long window title on the left pushed it along;
                // anchoring the middle to the centre makes its position
                // independent of its neighbours' content entirely, and each
                // section clips rather than growing past its width.
                Item {
                    id: barContent

                    anchors.fill: parent
                    anchors.margins: root.padding

                    // "auto" has to be computed here rather than in
                    // root.sectionWidths: it depends on what the sections
                    // actually contain, and those items live in this scope.
                    //
                    // The middle takes exactly what its entries need, so it
                    // is never the thing that gets squeezed, and the outer two
                    // are capped at the space left on their side of it. The
                    // left section holds the window title, which elides, so it
                    // is the one that gives -- everything else keeps its
                    // natural size instead of being clipped.
                    readonly property var widths: {
                        if (root.sectionMode !== "auto")
                            return root.sectionWidths(barContent.width);
                        const middle = middleSection.contentWidth;
                        const half = Math.max(0, (barContent.width - middle) / 2);
                        return {
                            left: Math.min(leftSection.contentWidth, half),
                            middle: middle,
                            right: Math.min(rightSection.contentWidth, half)
                        };
                    }

                    BarModules.BarSection {
                        id: leftSection

                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: barContent.widths.left
                        entries: root.sectionEntries.left
                        resolve: panel.componentFor
                        alignment: Qt.AlignLeft
                    }

                    BarModules.BarSection {
                        id: middleSection

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: barContent.widths.middle
                        entries: root.sectionEntries.middle
                        resolve: panel.componentFor
                        alignment: Qt.AlignHCenter
                    }

                    BarModules.BarSection {
                        id: rightSection

                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: barContent.widths.right
                        entries: root.sectionEntries.right
                        resolve: panel.componentFor
                        alignment: Qt.AlignRight
                    }
                }
            }

            // Anchor-only hosts: zero-width, invisible, but live so their
            // panels can open and position themselves against this surface.
            // Catches clicks anywhere outside the bar and the open panel. Only
            // present while the calendar is open, which is also the only time
            // the surface accepts input beyond the bar strip.
            MouseArea {
                anchors.fill: parent
                z: 0
                enabled: panel.calendarOpen
                visible: panel.calendarOpen
                acceptedButtons: Qt.AllButtons
                onPressed: root.closeCalendar()
            }

            // Celeste's own settings panel, opened by the gear in the side
            // panel's session column. Reuses MenuPanel rather than growing a
            // near-identical component: that type is already generic over
            // open/contentComponent, and sharing it means the settings panel
            // inherits the same grow-from-the-bottom-border animation and
            // border fillets the launcher has.
            //
            // Its closer sits at z 0 like the calendar's, NOT z 10 like the
            // launcher's: the launcher wants to swallow the first click
            // anywhere, but leaving the bar and side panel live here means
            // the gear that opened this can also close it.
            MouseArea {
                anchors.fill: parent
                z: 0
                enabled: panel.settingsOpen
                visible: panel.settingsOpen
                acceptedButtons: Qt.AllButtons
                onPressed: SettingsPanel.close()
            }

            MenuModule.MenuPanel {
                id: settingsPanel

                z: 11
                borderThickness: root.borderThickness
                open: panel.settingsOpen
                contentComponent: settingsContent
            }

            Component {
                id: settingsContent

                SettingsModule.SettingsContent {}
            }

            BarModules.Popout {
                id: calendarPopout

                anchors.top: barStrip.bottom
                z: 3
                placement: "centre"
                borderThickness: root.borderThickness
                open: panel.calendarOpen
                contentComponent: panel.calendarOpen ? calendarContent : null
            }

            Component {
                id: calendarContent

                Popouts.CalendarPopout {}
            }

            BarModules.Popout {
                id: popout

                anchors.top: barStrip.bottom
                z: 3
                // "right" only reads correctly for the icons actually flush
                // against the right border (audio/network/bluetooth/battery/
                // statusIcons). Anything living elsewhere on the bar --
                // tray, running apps -- has to follow the icon that opened
                // it instead, or the panel appears nowhere near the cursor.
                placement: (panel.popoutName.indexOf("app:") === 0 || panel.popoutName.indexOf("tray:") === 0)
                    ? "anchored" : "right"
                anchorCentre: panel.popoutCentre
                borderThickness: root.borderThickness
                open: panel.popoutName !== ""

                contentComponent: {
                    if (panel.popoutName.indexOf("app:") === 0)
                        return appWindowsPopout;
                    if (panel.popoutName.indexOf("tray:") === 0)
                        return trayMenuPopout;
                    switch (panel.popoutName) {
                    case "audio":
                        return audioPopout;
                    case "microphone":
                        return micPopout;
                    case "network":
                        return networkPopout;
                    case "bluetooth":
                        return bluetoothPopout;
                    case "battery":
                        return batteryPopout;
                    case "agents":
                        return agentsPopout;
                    }
                    return null;
                }

                HoverHandler {
                    id: popoutHover

                    onHoveredChanged: {
                        if (hovered)
                            popoutCloser.stop();
                        else
                            panel.setPopout("", 0);
                    }
                }
            }

            Component {
                id: audioPopout

                Popouts.AudioPopout {}
            }

            Component {
                id: micPopout

                Popouts.AudioPopout {
                    inputMode: true
                }
            }

            Component {
                id: networkPopout

                Popouts.NetworkPopout {}
            }

            Component {
                id: bluetoothPopout

                Popouts.BluetoothPopout {}
            }

            Component {
                id: batteryPopout

                Popouts.BatteryPopout {}
            }

            Component {
                id: agentsPopout

                Popouts.AgentsPopout {}
            }

            Component {
                id: appWindowsPopout

                Popouts.AppWindowsPopout {
                    appClass: panel.popoutName.slice(4)
                }
            }

            Component {
                id: trayMenuPopout

                Popouts.TrayMenuPopout {
                    itemId: panel.popoutName.slice(5)
                }
            }

            Component {
                id: spacerComponent

                Item {}
            }

            Component {
                id: workspacesComponent

                BarComponents.Workspaces {
                    screen: panel.modelData

                    onActiveWorkspaceClicked: OverviewState.toggle()
                }
            }

            Component {
                id: clockComponent

                BarComponents.Clock {
                    // Pass this surface's monitor so the panel opens here, and
                    // only here.
                    onDashboardRequested: tab => root.toggleCalendar(panel.modelData.name)
                    onCentreChanged: c => root.clockCentre = c
                }
            }

            Component {
                id: activeWindowComponent

                BarComponents.ActiveWindow {
                    screen: panel.modelData
                }
            }

            Component {
                id: statusIconsComponent

                BarComponents.StatusIcons {
                    // System panels deliberately stay inside Celeste's full
                    // screen surface. That gives them the same downward grow
                    // animation and concave border joins as the calendar.
                    //
                    // "agents" used to be a special case routed through the
                    // anchor-hosted real omarchy.agents panel, but that panel
                    // draws its own border via a shared Omarchy Ui component
                    // this repo cannot restyle -- see CLAUDE.md's "AI usage
                    // icon" entry. It now has a full Celeste-native popout
                    // (AgentsPopout.qml, backed by services/AgentUsage.qml)
                    // like every other status icon, so no special-casing is
                    // needed here any more.
                    onHoverChanged: (name, centre) => panel.setPopout(name, centre)
                    onIconClicked: (name, centre) => {
                        if (panel.popoutName === name) {
                            panel.popoutName = "";
                        } else {
                            panel.popoutName = name;
                            panel.popoutCentre = centre;
                        }
                    }
                }
            }

            Component {
                id: runningAppsComponent

                BarComponents.RunningApps {
                    // Same border-attached popout as statusIconsComponent, just
                    // keyed by "app:<class>" so the switch in contentComponent
                    // can tell the two families of popout apart.
                    onHoverChanged: (appClass, centre) => panel.setPopout(appClass ? "app:" + appClass : "", centre)
                    onIconClicked: (appClass, centre) => {
                        const name = "app:" + appClass;
                        if (panel.popoutName === name) {
                            panel.popoutName = "";
                        } else {
                            panel.popoutName = name;
                            panel.popoutCentre = centre;
                        }
                    }
                }
            }

            Component {
                id: trayComponent

                BarComponents.Tray {
                    // Same border-attached popout as statusIconsComponent /
                    // runningAppsComponent, keyed by "tray:<itemId>".
                    onHoverChanged: (itemId, centre) => panel.setPopout(itemId ? "tray:" + itemId : "", centre)
                    onIconClicked: (itemId, centre) => {
                        const name = "tray:" + itemId;
                        if (panel.popoutName === name) {
                            panel.popoutName = "";
                        } else {
                            panel.popoutName = name;
                            panel.popoutCentre = centre;
                        }
                    }
                }
            }


            Component {
                id: mediaComponent

                BarComponents.Media {}
            }

            Component {
                id: resourceComponent

                BarComponents.Resource {}
            }

            Component {
                id: hostedWidgetComponent

                BarModules.HostedWidget {
                    // Not `required`: a Loader cannot supply required properties
                    // to a sourceComponent, so this is assigned in onLoaded.
                    property var modelData: ({})

                    widgetId: String(modelData.id || "")
                    registry: root.barWidgetRegistry
                    shell: root.shell
                    settings: modelData
                    barSize: Tokens.sizes.bar.innerWidth
                    barTotalSize: root.barSize
                    // Bar entries only -- the anchor-only hosts below stay at
                    // their natural size, since nothing of them is drawn.
                    contentScale: 1.4
                    uniformCell: Tokens.sizes.bar.innerWidth * 0.65
                    hostScreen: panel.modelData

                    onRegistered: (id, self) => root.registerHosted(id, self)
                    onUnregistered: (id, self) => root.unregisterHosted(id, self)
                }
            }
        }
    }
}
