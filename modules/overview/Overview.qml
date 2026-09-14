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

    // ---------------------------------------------------------- card sizing
    //
    // Cards are shaped like the monitor they stand for. WorkspaceCard scales
    // its window previews by WIDTH alone (root.width / monitorWidth), so a
    // card whose aspect doesn't match the screen's leaves a dead band along
    // the bottom -- the previews stop where the monitor's height maps to,
    // and the rest of the card is empty. Letting the cells fill the grid gave
    // them whatever shape the grid area happened to divide into, which is
    // exactly that bug.
    //
    // hostScreen, not Hyprland's monitor: ShellScreen is transform-aware,
    // while monitor.width/height report the unrotated panel mode, so a
    // portrait display would come back with its axes swapped. Same source
    // WorkspaceCard already scales from.
    readonly property int columns: Math.min(3, root.shown)
    readonly property int rows: Math.ceil(root.shown / root.columns)

    readonly property real monitorAspect: {
        const w = root.hostScreen ? root.hostScreen.width : 0;
        const h = root.hostScreen ? root.hostScreen.height : 0;
        return (w > 0 && h > 0) ? w / h : 16 / 9;
    }

    readonly property real availableWidth:
        root.width - root.borderThickness * 2 - Tokens.padding.extraExtraLarge * 2
    readonly property real availableHeight:
        root.height - root.barSize - root.borderThickness - Tokens.padding.extraExtraLarge * 2

    // The largest cell of the right shape that still fits the grid both ways:
    // width-limited on a wide screen, height-limited on a tall one.
    readonly property real cellWidth: {
        const spacing = Tokens.spacing.large;
        const maxWidth = (root.availableWidth - spacing * (root.columns - 1)) / root.columns;
        const maxHeight = (root.availableHeight - spacing * (root.rows - 1)) / root.rows;
        return Math.max(0, Math.min(maxWidth, maxHeight * root.monitorAspect));
    }

    readonly property real cellHeight: root.cellWidth / root.monitorAspect

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

        // No explicit size: the grid now shrinks to its cells rather than
        // filling the screen and stretching them to fit.
        anchors.centerIn: parent

        columns: root.columns
        rowSpacing: Tokens.spacing.large
        columnSpacing: Tokens.spacing.large

        Repeater {
            model: root.shown

            delegate: WorkspaceCard {
                required property int index

                Layout.preferredWidth: root.cellWidth
                Layout.preferredHeight: root.cellHeight

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
