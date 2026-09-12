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

    // Clicking a status icon opens the owning Omarchy plugin's real panel.
    function openStatusPanel(name) {
        const panels = Config.bar.statusIconPanels || ({});
        const id = panels[String(name)] || "";
        if (!id)
            return false;
        return root.toggleHosted(id);
    }

    function toggleHosted(id) {
        const item = root.hostedItemFor(id);
        if (!item || !item.widgetItem)
            return false;
        if (root.isBarWidgetOpen(id))
            return root.hideBarWidget(id);
        return root.summonBarWidget(id);
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

            Item {
                anchors.top: parent.top
                x: Math.max(0, Math.min(root.clockCentre, anchorSurface.width - 1))
                width: 1
                height: root.barSize

                Repeater {
                    model: root.anchorWidgetIds

                    delegate: BarModules.HostedWidget {
                        required property string modelData

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
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property var modelData

            screen: panel.modelData

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "celeste-bar"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

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
            mask: (OverviewState.open || panel.calendarOpen) ? null : panel.barRegion

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
            }

            readonly property bool calendarOpen:
                root.calendarScreen !== "" && root.calendarScreen === String(panel.modelData.name)

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

            Item {
                id: barStrip

                z: 2
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.barHidden ? 0 : root.barSize
                visible: !root.barHidden

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: root.padding
                    spacing: Tokens.spacing.medium

                    Repeater {
                        model: root.entries

                        delegate: Loader {
                            id: entry

                            required property var modelData
                            readonly property string entryId: entry.modelData.id

                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: entry.entryId === "spacer"
                            // Workspaces is loaded synchronously so the bar does
                            // not visibly reflow on startup.
                            asynchronous: entry.entryId !== "workspaces"

                            sourceComponent: panel.componentFor(entry.entryId)

                            // HostedWidget needs the whole entry (its id and any
                            // inline settings); Celeste's own entries ignore it.
                            onLoaded: {
                                if (item && "modelData" in item)
                                    item.modelData = entry.modelData;
                            }
                        }
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
                placement: "right"
                borderThickness: root.borderThickness
                open: panel.popoutName !== ""

                contentComponent: {
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
                    onHoverChanged: (name, centre) => panel.setPopout(name, centre)
                    onIconClicked: name => root.openStatusPanel(name)
                }
            }

            Component {
                id: trayComponent

                BarComponents.Tray {}
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
                    hostScreen: panel.modelData

                    onRegistered: (id, self) => root.registerHosted(id, self)
                    onUnregistered: (id, self) => root.unregisterHosted(id, self)
                }
            }
        }
    }
}
