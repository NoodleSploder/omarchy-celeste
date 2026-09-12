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
import Quickshell.Wayland
import "core"
import "components"
import "modules/bar/components" as BarComponents

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

    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
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

    property var openWidgets: ({})

    function summonBarWidget(id) {
        const key = String(id || "");
        if (!key)
            return false;
        const next = {};
        for (const k in root.openWidgets)
            next[k] = root.openWidgets[k];
        next[key] = true;
        root.openWidgets = next;
        return true;
    }

    function hideBarWidget(id) {
        const key = String(id || "");
        if (!(key in root.openWidgets))
            return false;
        const next = {};
        for (const k in root.openWidgets)
            if (k !== key)
                next[k] = root.openWidgets[k];
        root.openWidgets = next;
        return true;
    }

    function isBarWidgetOpen(id) {
        return root.openWidgets[String(id || "")] === true;
    }

    // ------------------------------------------------------------- entries

    readonly property var entries: (Config.bar.entries || []).filter(e => e && e.enabled)

    // The dashboard is not built yet. Until it is, the clock gesture is routed
    // at Omarchy's calendar panel so it does nothing surprising.
    function openDashboard(tab) {
        if (root.shell && typeof root.shell.toggle === "function")
            root.shell.toggle("tmn73.calendar", "{}");
    }

    // ------------------------------------------------------------ surfaces

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

            implicitHeight: root.barSize
            exclusiveZone: root.barHidden ? 0 : root.barSize
            color: "transparent"

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
                default:
                    return null;
                }
            }

            StyledRect {
                anchors.fill: parent
                color: Colours.tPalette.m3surface
            }

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
                        // Workspaces is loaded synchronously so the bar does not
                        // visibly reflow on startup.
                        asynchronous: entry.entryId !== "workspaces"

                        sourceComponent: panel.componentFor(entry.entryId)
                    }
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
                }
            }

            Component {
                id: clockComponent

                BarComponents.Clock {
                    onDashboardRequested: tab => root.openDashboard(tab)
                }
            }

            Component {
                id: activeWindowComponent

                BarComponents.ActiveWindow {}
            }
        }
    }
}
