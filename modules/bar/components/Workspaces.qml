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

    // Clicking the workspace you are already on opens the overview rather than
    // re-dispatching a focus to where you already are.
    signal activeWorkspaceClicked()

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

    // The three dot sizes. The active indicator is a CIRCLE, not a pill: it
    // grows in both axes at once so it never stretches sideways. Sized off the
    // strip's own row height so it stays proportional if the bar is rescaled,
    // with room inside for the workspace number and clearance for the halo.
    readonly property int dotSize: Tokens.spacing.medium
    readonly property int activeSize: Math.round(Tokens.sizes.bar.innerWidth * 0.62)
    readonly property int haloSize: Math.round(Tokens.sizes.bar.innerWidth * 0.82)

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
                property bool hovered: false

                implicitWidth: Tokens.sizes.bar.innerWidth
                implicitHeight: Tokens.sizes.bar.innerWidth

                // A soft halo behind the active pill -- a low-opacity, larger
                // copy of the primary colour -- is the one purely decorative
                // addition here; everything else is the same M3 tokens the
                // rest of the bar already uses, just applied with more
                // contrast between the three states (active/occupied/empty)
                // than the original flat dot did.
                Rectangle {
                    anchors.centerIn: parent
                    // Square, so radius:full makes it a circle rather than a
                    // pill -- same rule as the dot below.
                    implicitWidth: ws.isActive ? root.haloSize : root.dotSize
                    implicitHeight: implicitWidth
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primary
                    opacity: ws.isActive ? 0.18 : 0

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }

                    Behavior on implicitWidth {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }
                }

                // The dot swells into a larger CIRCLE when active -- width and
                // height grow together, so radius:full keeps it round at every
                // point of the animation instead of stretching into a pill --
                // and the number fades in on top of it. Both are driven off
                // isActive so they stay in step. Occupied-but-inactive
                // workspaces get the theme's secondary accent instead of a flat
                // grey, and empty ones are a hollow ring rather than a dim
                // filled dot -- three visually distinct states at a glance
                // instead of "bright dot vs. two shades of the same dim one".
                StyledRect {
                    id: dot

                    anchors.centerIn: parent
                    implicitWidth: ws.isActive ? root.activeSize : root.dotSize
                    implicitHeight: implicitWidth
                    radius: Tokens.rounding.full
                    scale: ws.hovered && !ws.isActive ? 1.25 : 1
                    color: ws.isActive
                        ? Colours.palette.m3primary
                        : ws.isOccupied ? Colours.palette.m3secondary : "transparent"
                    border.width: !ws.isActive && !ws.isOccupied ? 1.5 : 0
                    border.color: Colours.palette.m3outlineVariant
                    opacity: ws.isActive || ws.isOccupied ? 1 : 0.7

                    Behavior on implicitWidth {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }

                    Behavior on scale {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: String(ws.index + 1)
                    // Smaller than the bar default: a circle gives the label
                    // less horizontal room than the old pill did.
                    font.pointSize: Tokens.fontSize.small
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
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: ws.hovered = true
                    onExited: ws.hovered = false
                    onClicked: {
                        if (ws.isActive)
                            root.activeWorkspaceClicked();
                        else
                            root.focusWorkspace(ws.wsId);
                    }
                }
            }
        }
    }
}
