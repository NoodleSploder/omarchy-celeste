pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../core"
import "../../components"
import "../../services"

// One monitor's expose: a grid of that monitor's own workspaces, relabelled
// 1..n, with live window previews that can be dragged between them -- and, via
// OverviewState's global card registry, onto another monitor's workspaces.
//
// Every monitor opens its overview at once, each showing only its own block, so
// dragging left off one screen lands on the next.
Item {
    id: root

    required property var hostScreen
    required property int barSize
    required property int borderThickness

    readonly property bool open: OverviewState.open

    readonly property var monitor: Hyprland.monitorFor(root.hostScreen)
    readonly property string monitorName: root.monitor ? root.monitor.name : ""

    readonly property int shown: Config.bar.workspaces.shown

    // Global layout origin of this monitor, used to lift local coordinates into
    // the shared space the drag registry works in.
    readonly property real screenX: root.monitor ? root.monitor.x : 0
    readonly property real screenY: root.monitor ? root.monitor.y : 0

    // This monitor's contiguous block of persistent workspaces; the block start
    // is its lowest workspace id, so the allocation is never duplicated here.
    readonly property int wsBase: {
        const ids = Hyprland.workspaces.values
            .filter(w => w.id > 0 && w.lastIpcObject && w.lastIpcObject.monitor === root.monitorName)
            .map(w => w.id);
        return ids.length > 0 ? Math.min(...ids) : 1;
    }

    visible: opacity > 0
    opacity: root.open ? 1 : 0

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    // Scrim, and a click-off target.
    StyledRect {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3scrim, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: OverviewState.close()
        }
    }

    GridLayout {
        id: grid

        anchors.centerIn: parent
        width: parent.width - root.borderThickness * 2 - Tokens.padding.extraExtraLarge * 2
        height: parent.height - root.barSize - root.borderThickness - Tokens.padding.extraExtraLarge * 2

        columns: Math.min(3, root.shown)
        rowSpacing: Tokens.spacing.large
        columnSpacing: Tokens.spacing.large

        Repeater {
            model: root.shown

            delegate: WorkspaceCard {
                required property int index

                Layout.fillWidth: true
                Layout.fillHeight: true

                workspaceId: root.wsBase + index
                // Relabelled to the monitor-local number, not the global id.
                label: String(index + 1)
                hostScreen: root.hostScreen
                screenX: root.screenX
                screenY: root.screenY

                scale: root.open ? 1 : 0.92

                Behavior on scale {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
            }
        }
    }

    // Drawn last so the dragged thumbnail floats above every card.
    DragGhost {
        screenX: root.screenX
        screenY: root.screenY
    }
}
