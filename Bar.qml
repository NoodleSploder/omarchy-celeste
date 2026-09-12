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
import "modules/bar" as BarModules
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

            // Only the bar strip accepts input; the frame is click-through.
            mask: Region {
                item: barStrip
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

                BarComponents.ActiveWindow {
                    screen: panel.modelData
                }
            }

            Component {
                id: statusIconsComponent

                BarComponents.StatusIcons {}
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
                }
            }
        }
    }
}
