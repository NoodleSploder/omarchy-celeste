pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../../components"
import "../../services"

// The thumbnail that follows the cursor during a drag.
//
// A dragged item cannot render outside its own surface, so instead of moving one
// thumbnail across the screen, every overview draws its own copy at the shared
// global cursor position and clips it. A window crossing a bezel therefore
// splits across the two surfaces rather than vanishing at the edge.
Item {
    id: root

    required property real screenX
    required property real screenY

    visible: OverviewState.dragging

    x: OverviewState.ghostX - root.screenX
    y: OverviewState.ghostY - root.screenY
    width: OverviewState.ghostWidth
    height: OverviewState.ghostHeight

    opacity: 0.85

    StyledClippingRect {
        anchors.fill: parent
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainerHighest

        ScreencopyView {
            anchors.fill: parent
            captureSource: OverviewState.draggedToplevel && OverviewState.draggedToplevel.wayland
                ? OverviewState.draggedToplevel.wayland : null
            live: true
        }
    }
}
