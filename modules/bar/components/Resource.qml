pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../components"
import "../../../services"

// Memory usage as a ring plus a percentage.
StyledRect {
    id: root

    property real value: SysUsage.memPercentage
    property color colour: Colours.palette.m3primary

    readonly property int padding: Tokens.padding.extraSmall
    readonly property int ringSize: Math.round(Tokens.sizes.bar.innerWidth * 0.6)

    implicitWidth: layout.implicitWidth + padding * 2
    implicitHeight: Tokens.sizes.bar.innerWidth

    color: "transparent"
    radius: Tokens.rounding.full

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        CircularProgress {
            Layout.alignment: Qt.AlignVCenter

            implicitSize: root.ringSize
            strokeWidth: Math.max(2, Math.round(root.ringSize * 0.14))
            value: root.value
            fgColour: root.colour

            Behavior on value {
                Anim {}
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: `${Math.round(root.value * 100)}%`
            color: root.colour
        }
    }
}
