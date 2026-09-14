pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components"

// A panel that grows upward out of the bottom border -- the mirror image of
// modules/bar/Popout.qml's centred placement (which grows downward out of
// the top bar). Free on both sides, fillets bridge the border on both sides
// at the BOTTOM instead of the top: the corner that stays square is the one
// touching the border, same rule as Popout.qml, just upside down.
Item {
    id: root

    property bool open: false
    property int borderThickness: 0
    property int radius: Tokens.rounding.extraLarge
    property int filletSize: Config.border.rounding
    property color colour: Colours.tPalette.m3surface
    property int minWidth: 0

    property Component contentComponent: null

    readonly property int contentWidth: contentLoader.item ? contentLoader.item.implicitWidth : 0
    readonly property int contentHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0

    readonly property int fullWidth: Math.max(root.minWidth, root.contentWidth + Tokens.padding.large * 2)
    readonly property int fullHeight: root.contentHeight + Tokens.padding.large * 2

    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.borderThickness
    anchors.horizontalCenter: parent.horizontalCenter

    width: root.fullWidth
    // Height is what animates: the panel extends upward out of the border.
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

    // Bottom is always square: it continues the border. Both top corners are
    // free (the panel is centred, touching nothing on either side).
    Rectangle {
        anchors.fill: parent
        color: root.colour
        bottomLeftRadius: 0
        bottomRightRadius: 0
        topLeftRadius: root.radius
        topRightRadius: root.radius
    }

    // Swallows presses that land on the panel's own padding or background so
    // they never reach the click-outside-to-close MouseArea underneath (see
    // Bar.qml). Declared BEFORE the content below on purpose: sibling order
    // is real input z-order in Qt Quick and applies to a sibling's whole
    // subtree, so a catch-all declared after the content would win every
    // hit-test over it and eat the list's own clicks.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
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

    // Border -> panel, at the panel's bottom-left and bottom-right.
    InvertedCorner {
        anchors.right: parent.left
        anchors.bottom: parent.bottom
        size: root.filletSize
        colour: root.colour
        corner: InvertedCorner.BottomRight
        visible: root.open
    }

    InvertedCorner {
        anchors.left: parent.right
        anchors.bottom: parent.bottom
        size: root.filletSize
        colour: root.colour
        corner: InvertedCorner.BottomLeft
        visible: root.open
    }
}
