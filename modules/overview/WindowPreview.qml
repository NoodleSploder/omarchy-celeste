pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../core"
import "../../components"
import "../../services"

// One window inside a workspace card: a live capture, draggable to another card.
//
// While dragging, the original is hidden with opacity rather than `visible`.
// A hidden item stops receiving mouse events, which would drop the implicit
// pointer grab and strand the drag the moment it began.
Item {
    id: root

    required property var toplevel
    required property int workspaceId
    required property real previewScale

    readonly property bool beingDragged: OverviewState.dragging
        && OverviewState.draggedToplevel === root.toplevel

    opacity: root.beingDragged ? 0 : 1

    StyledClippingRect {
        anchors.fill: parent
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainerHigh

        ScreencopyView {
            anchors.fill: parent
            captureSource: root.toplevel && root.toplevel.wayland ? root.toplevel.wayland : null
            live: true
        }
    }

    MouseArea {
        id: drag

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        property bool armed: false
        property real pressSceneX: 0
        property real pressSceneY: 0

        onPressed: mouse => {
            const scene = root.mapToItem(null, mouse.x, mouse.y);
            drag.pressSceneX = scene.x;
            drag.pressSceneY = scene.y;
            drag.armed = true;
        }

        onPositionChanged: mouse => {
            if (!drag.armed)
                return;
            const scene = root.mapToItem(null, mouse.x, mouse.y);
            const gx = scene.x + root.screenX;
            const gy = scene.y + root.screenY;

            if (!OverviewState.dragging) {
                // Only promote to a drag past a small threshold, so a click that
                // wobbles a pixel still reads as a click.
                const dx = scene.x - drag.pressSceneX;
                const dy = scene.y - drag.pressSceneY;
                if (dx * dx + dy * dy < 36)
                    return;
                OverviewState.beginDrag(root.toplevel, root.workspaceId,
                    mouse.x, mouse.y, root.width, root.height);
            }
            OverviewState.cursorX = gx;
            OverviewState.cursorY = gy;
        }

        onReleased: {
            drag.armed = false;
            if (!OverviewState.dragging) {
                root.activate();
                return;
            }
            const target = OverviewState.hoveredWorkspace;
            OverviewState.endDrag();
            if (target > 0 && target !== root.workspaceId)
                root.moveTo(target);
        }

        onCanceled: {
            drag.armed = false;
            OverviewState.endDrag();
        }
    }

    // Offset of this surface's monitor in the global layout, so scene
    // coordinates can be lifted into the shared global space.
    property real screenX: 0
    property real screenY: 0

    // Both of these go through Apps.hyprAddress: Quickshell hands out a bare
    // hex address and Hyprland wants it 0x-prefixed, which is why clicking a
    // window in the overview used to close it without going anywhere.
    // Focusing a window on another workspace switches to that workspace on
    // its own, so this is all "take me to that app" needs.
    function activate() {
        const address = Apps.hyprAddress(root.toplevel);
        if (address === "")
            return;
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.focus({ window = "address:${address}" })`
            : `focuswindow address:${address}`);
        OverviewState.close();
    }

    function moveTo(workspaceId) {
        const address = Apps.hyprAddress(root.toplevel);
        if (address === "")
            return;
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.window.move({ window = "address:${address}", workspace = "${workspaceId}", follow = false })`
            : `movetoworkspacesilent ${workspaceId},address:${address}`);
    }
}
