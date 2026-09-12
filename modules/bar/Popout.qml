pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components"

// A panel that grows out of the bar.
//
// It is drawn inside the same fullscreen surface as the bar and border, so it
// shares their colour and reads as one continuous shape. The top edge sits
// flush against the bar strip with no radius, and a pair of inverted corner
// fillets bridge the join, so the panel appears to swell out of the border
// rather than hang below it.
//
// Opening animates height and opacity on the expressive spatial curve -- the
// one with slight overshoot -- which is what gives it the organic "popping into
// place" motion rather than a linear slide.
Item {
    id: root

    property bool open: false
    property real anchorCentre: 0        // x centre to point at, in surface coords
    property int edgeMargin: Tokens.padding.medium
    property int radius: Tokens.rounding.extraLarge
    property int filletSize: Tokens.rounding.large
    property color colour: Colours.tPalette.m3surface

    // A Component rather than a default property alias. Aliasing the default
    // property at `contentHolder.data` would also swallow this file's OWN
    // children -- background, fillets, and contentHolder itself -- since they
    // are declared in the same scope.
    property Component contentComponent: null

    readonly property int contentWidth: contentLoader.item ? contentLoader.item.implicitWidth : 0
    readonly property int contentHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0

    readonly property int fullWidth: root.contentWidth + Tokens.padding.large * 2
    readonly property int fullHeight: root.contentHeight + Tokens.padding.large * 2

    // Clamp inside the border so the panel never overhangs the frame.
    readonly property real idealX: root.anchorCentre - fullWidth / 2
    readonly property real minX: root.edgeMargin
    readonly property real maxX: (parent ? parent.width : 0) - fullWidth - root.edgeMargin

    x: Math.max(root.minX, Math.min(root.maxX, root.idealX))
    width: root.fullWidth
    height: root.open ? root.fullHeight : 0

    visible: height > 0
    opacity: root.open ? 1 : 0
    clip: true

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

    Behavior on x {
        Anim {
            type: Anim.FastSpatial
        }
    }

    // Body: square at the top where it meets the bar, rounded below.
    Rectangle {
        anchors.fill: parent
        color: root.colour
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.radius
        bottomRightRadius: root.radius
    }

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

    // The fillets live just outside the panel, bridging it to the bar above.
    InvertedCorner {
        anchors.right: parent.left
        anchors.top: parent.top
        size: root.filletSize
        colour: root.colour
        corner: InvertedCorner.TopRight
        visible: root.open
    }

    InvertedCorner {
        anchors.left: parent.right
        anchors.top: parent.top
        size: root.filletSize
        colour: root.colour
        corner: InvertedCorner.TopLeft
        visible: root.open
    }
}
