pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components"

// A panel that grows downward out of the top border.
//
// Whichever edges touch the frame stay square and continue it; the free corners
// are rounded. Where the panel leaves the frame, an InvertedCorner fillet bridges
// the join, so it appears to swell out of the border rather than sit on top of
// it.
//
//   placement "right"    - pinned into the top-right corner, flush against both
//                          the bar and the right border. Fillets: bar -> panel at
//                          the top-left, panel -> right border below the right.
//   placement "centre"   - hangs from the bar in the middle of the screen, free
//                          on both sides. Fillets bridge the bar on both sides.
//   placement "anchored" - same free-on-both-sides visual as "centre", but
//                          centred under anchorCentre (a bar-relative x, e.g.
//                          the hovered icon's midpoint) instead of the screen's
//                          middle, clamped so it never runs off either edge.
//                          For any row that isn't flush against the right
//                          border -- the tray, the running-apps row -- "right"
//                          silently ignores where the icon actually is (it
//                          never read anchorCentre at all) and just pins to
//                          the screen edge, which reads as "attached" only by
//                          coincidence when the row happens to already be
//                          there. Confirmed by a live report: hovering a tray
//                          icon mid-bar opened the menu nowhere near the
//                          cursor, so moving toward it crossed dead space and
//                          closed it before arriving.
//
// The fillets sit OUTSIDE this item's bounds, so the root must never clip. Only
// the inner content holder does.
Item {
    id: root

    property bool open: false
    property string placement: "right"
    property real anchorCentre: 0
    property int borderThickness: 0
    property int radius: Tokens.rounding.extraLarge
    property int filletSize: Config.border.rounding
    property color colour: Colours.tPalette.m3surface

    property Component contentComponent: null

    readonly property bool anchored: root.placement === "anchored"
    readonly property bool centred: root.placement === "centre" || root.anchored

    readonly property int contentWidth: contentLoader.item ? contentLoader.item.implicitWidth : 0
    readonly property int contentHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0

    readonly property int fullWidth: root.contentWidth + Tokens.padding.large * 2
    readonly property int fullHeight: root.contentHeight + Tokens.padding.large * 2

    x: {
        const parentWidth = parent ? parent.width : 0;
        if (root.anchored)
            return Math.max(root.borderThickness, Math.min(
                root.anchorCentre - root.fullWidth / 2,
                parentWidth - root.borderThickness - root.fullWidth));
        return root.placement === "centre"
            ? Math.round((parentWidth - root.fullWidth) / 2)
            : parentWidth - root.borderThickness - root.fullWidth;
    }

    width: root.fullWidth
    // Height is what animates: the panel extends downwards out of the bar.
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

    // Top is always square: it continues the bar. The right is square too when
    // the panel is flush against the right border.
    Rectangle {
        anchors.fill: parent
        color: root.colour
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.radius
        bottomRightRadius: root.centred ? root.radius : 0
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

    // Bar -> panel, at the panel's top-left. Present in both placements.
    InvertedCorner {
        anchors.right: parent.left
        anchors.top: parent.top
        size: root.filletSize
        colour: root.colour
        corner: InvertedCorner.TopRight
        visible: root.open
    }

    // Centred: bar -> panel on the right-hand side too.
    InvertedCorner {
        anchors.left: parent.right
        anchors.top: parent.top
        size: root.filletSize
        colour: root.colour
        corner: InvertedCorner.TopLeft
        visible: root.open && root.centred
    }

    // Flush right: panel -> right border, below the panel's right edge.
    InvertedCorner {
        anchors.right: parent.right
        anchors.top: parent.bottom
        size: root.filletSize
        colour: root.colour
        corner: InvertedCorner.TopRight
        visible: root.open && !root.centred
    }
}
