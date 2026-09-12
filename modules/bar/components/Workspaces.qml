pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../core"
import "../../../components"

// A fixed-width strip of workspace dots for one monitor.
//
// With perMonitorWorkspaces, each monitor owns a contiguous block of persistent
// workspaces (assigned by workspace_rule in the Hyprland config), and the block
// start is simply this monitor's lowest workspace id. Deriving it that way means
// the allocation is never duplicated here -- add a monitor and this follows.
// Dots are relabelled 1..shown, so every monitor reads as "1-6" regardless of
// the global ids behind them.
StyledClippingRect {
    id: root

    required property var screen

    readonly property int shown: Config.bar.workspaces.shown
    readonly property bool perMonitor: Config.bar.workspaces.perMonitorWorkspaces

    readonly property var monitor: root.perMonitor
        ? Hyprland.monitorFor(root.screen)
        : Hyprland.focusedMonitor
    readonly property string monitorName: root.monitor ? root.monitor.name : ""

    readonly property int activeWsId: {
        if (!root.perMonitor)
            return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
        return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : 1;
    }

    readonly property var occupied: {
        const occ = {};
        for (const ws of Hyprland.workspaces.values)
            occ[ws.id] = (ws.lastIpcObject ? ws.lastIpcObject.windows : 0) > 0;
        return occ;
    }

    readonly property int wsBase: {
        if (!root.perMonitor)
            return 1;
        const ids = Hyprland.workspaces.values
            .filter(w => w.id > 0 && w.lastIpcObject && w.lastIpcObject.monitor === root.monitorName)
            .map(w => w.id);
        return ids.length > 0 ? Math.min(...ids) : 1;
    }

    // Which page of `shown` workspaces the active one falls in, anchored at the
    // block start so monitors with more workspaces than dots still page cleanly.
    readonly property int groupOffset: {
        const s = root.shown;
        return root.wsBase - 1 + Math.max(0, Math.floor((root.activeWsId - root.wsBase) / s)) * s;
    }

    // Hyprland can be configured for Lua dispatch, where the plain
    // "workspace N" string is a syntax error. Quickshell reports which mode is
    // active, so pick the matching form rather than assuming the classic one.
    function focusWorkspace(id) {
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.focus({ workspace = "${id}" })`
            : `workspace ${id}`);
    }

    implicitWidth: layout.implicitWidth + Tokens.padding.small
    implicitHeight: Tokens.sizes.bar.innerWidth

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: root.shown

            delegate: Item {
                id: ws

                required property int index

                readonly property int wsId: root.groupOffset + ws.index + 1
                readonly property bool isActive: root.activeWsId === ws.wsId
                readonly property bool isOccupied: root.occupied[ws.wsId] === true

                implicitWidth: Tokens.sizes.bar.innerWidth
                implicitHeight: Tokens.sizes.bar.innerWidth

                // The dot stretches into a pill when active; the number fades in
                // on top of it. Both are driven off isActive so they stay in step.
                StyledRect {
                    anchors.centerIn: parent
                    implicitWidth: ws.isActive ? Tokens.sizes.bar.innerWidth : Tokens.spacing.medium
                    implicitHeight: Tokens.spacing.medium
                    radius: Tokens.rounding.full
                    color: ws.isActive
                        ? Colours.palette.m3primary
                        : ws.isOccupied ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3outlineVariant
                    opacity: ws.isActive || ws.isOccupied ? 1 : 0.45

                    Behavior on implicitWidth {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: String(ws.index + 1)
                    color: ws.isActive ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                    opacity: ws.isActive ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusWorkspace(ws.wsId)
                }
            }
        }
    }
}
