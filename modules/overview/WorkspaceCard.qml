pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../core"
import "../../components"
import "../../services"

// One workspace, drawn as a scaled-down picture of that workspace's windows.
//
// The card publishes its rectangle in GLOBAL layout coordinates so a drag that
// started on another monitor can hit-test it -- see OverviewState.
StyledRect {
    id: root

    required property int workspaceId
    required property string label
    required property var hostScreen
    required property real screenX
    required property real screenY

    readonly property var workspace:
        Hyprland.workspaces.values.find(w => w.id === root.workspaceId) || null

    readonly property var toplevels:
        root.workspace && root.workspace.toplevels ? root.workspace.toplevels.values : []

    readonly property bool isActive: {
        const mon = Hyprland.monitorFor(root.hostScreen);
        return !!(mon && mon.activeWorkspace && mon.activeWorkspace.id === root.workspaceId);
    }

    readonly property bool isDropTarget: OverviewState.hoveredWorkspace === root.workspaceId

    // The monitor's logical size. ShellScreen is transform-aware; Hyprland's
    // monitor.width/height report the UNROTATED panel mode, so a portrait
    // display (transform 1 or 3) would come back with its axes swapped and
    // every preview squashed along one of them.
    readonly property real monitorWidth: root.hostScreen ? root.hostScreen.width : 1
    readonly property real monitorHeight: root.hostScreen ? root.hostScreen.height : 1

    readonly property real previewScale: root.width / Math.max(1, root.monitorWidth)

    color: root.isDropTarget
        ? Colours.palette.m3primaryContainer
        : Colours.tPalette.m3surfaceContainerHigh
    radius: Tokens.rounding.large

    border.width: root.isActive || root.isDropTarget ? 2 : 0
    border.color: root.isDropTarget ? Colours.palette.m3primary
        : root.isActive ? Colours.palette.m3primary : "transparent"

    Behavior on color {
        CAnim {}
    }

    // Publish/refresh the global rect whenever geometry changes.
    function publish() {
        const scene = root.mapToItem(null, 0, 0);
        OverviewState.registerCard(root.workspaceId, {
            x: scene.x + root.screenX,
            y: scene.y + root.screenY,
            width: root.width,
            height: root.height,
            monitor: root.hostScreen ? root.hostScreen.name : ""
        });
    }

    onWidthChanged: root.publish()
    onHeightChanged: root.publish()
    onXChanged: root.publish()
    onYChanged: root.publish()
    Component.onCompleted: root.publish()
    Component.onDestruction: OverviewState.unregisterCard(root.workspaceId)

    StyledText {
        anchors.centerIn: parent
        text: root.label
        color: Colours.palette.m3onSurfaceVariant
        opacity: root.toplevels.length === 0 ? 0.6 : 0
        font.pointSize: Tokens.fontSize.large
    }

    Item {
        id: previews

        anchors.fill: parent
        anchors.margins: Tokens.padding.extraSmall
        clip: true

        Repeater {
            model: root.toplevels

            delegate: WindowPreview {
                required property var modelData

                readonly property var ipc: modelData.lastIpcObject

                toplevel: modelData
                workspaceId: root.workspaceId
                previewScale: root.previewScale
                screenX: root.screenX
                screenY: root.screenY

                // Hyprland reports window geometry in global layout coordinates;
                // subtract the monitor origin to get a position within this card.
                x: ipc ? (ipc.at[0] - (root.screenX)) * root.previewScale : 0
                y: ipc ? (ipc.at[1] - (root.screenY)) * root.previewScale : 0
                width: ipc ? Math.max(8, ipc.size[0] * root.previewScale) : 0
                height: ipc ? Math.max(8, ipc.size[1] * root.previewScale) : 0
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Hyprland.dispatch(Hyprland.usingLua
                ? `hl.dsp.focus({ workspace = "${root.workspaceId}" })`
                : `workspace ${root.workspaceId}`);
            OverviewState.close();
        }
    }
}
