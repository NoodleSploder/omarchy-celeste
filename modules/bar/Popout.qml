pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components"

// A panel that grows out of the top-right of the frame.
//
// It is pinned flush to both the bar above and the right border beside it, so
// those two edges are square and continue the frame; only the two free corners
// are shaped. Where the panel leaves the frame, an InvertedCorner fillet bridges
// the join so the panel appears to swell out of the border rather than sit on
// top of it:
//
//   - left of the top edge, bridging bar -> panel
//   - below the right edge, bridging panel -> right border
//
// The fillets are positioned OUTSIDE this item's bounds, so the root must never
// clip. Only the inner content holder does.
Item {
    id: root

    property bool open: false
    property int borderThickness: 0
    property int radius: Tokens.rounding.extraLarge
    property int filletSize: Tokens.rounding.large
    property color colour: Colours.tPalette.m3surface

    property Component contentComponent: null

    readonly property int contentWidth: contentLoader.item ? contentLoader.item.implicitWidth : 0
    readonly property int contentHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0

    readonly property int fullWidth: root.contentWidth + Tokens.padding.large * 2
    readonly property int fullHeight: root.contentHeight + Tokens.padding.large * 2

    // Flush against the inner edge of the right border, directly under the bar.
    anchors.right: parent ? parent.right : undefined
    anchors.rightMargin: root.borderThickness

    width: root.fullWidth
    height: root.open ? root.fullHeight : 0

    visible: height > 0
    opacity: root.open ? 1 : 0

    Behavior on height {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on opacity {
        Anim {
            type: Anim.FastEffects
        }
    }

    // Body. Top and right are square: they continue the bar and the border.
    Rectangle {
        anchors.fill: parent
        color: root.colour
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.radius
        bottomRightRadius: 0
    }

    Item {
        anchors.fill: parent
        clip: true

        Loader {
            id: contentLoader

            anchors.centerIn: parent
            active: root.open || root.height > 0
            sourceComponent: root.contentComponent
            opacity: root.open ? 1 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }

    // Bar -> panel, at the panel's top-left.
    InvertedCorner {
        anchors.right: parent.left
        anchors.top: parent.top
        size: root.filletSize
        colour: root.colour
        corner: InvertedCorner.TopRight
        visible: root.open
    }

    // Panel -> right border, below the panel's right edge.
    InvertedCorner {
        anchors.right: parent.right
        anchors.top: parent.bottom
        size: root.filletSize
        colour: root.colour
        corner: InvertedCorner.TopRight
        visible: root.open
    }
}
