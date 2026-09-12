pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../components"
import "../../../services"

ColumnLayout {
    id: root

    spacing: Tokens.spacing.extraSmall

    StyledText {
        text: "Bluetooth"
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.fontSize.small
    }

    RowLayout {
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: Bt.icon
            color: Bt.connected ? Colours.palette.m3primary : Colours.palette.m3outline
        }

        StyledText {
            text: Bt.label
            color: Colours.palette.m3onSurface
        }
    }

    Repeater {
        model: Bt.connectedDevices

        delegate: StyledText {
            required property var modelData

            text: `• ${modelData.name || "Device"}`
            color: Colours.palette.m3outline
            font.pointSize: Math.round(Tokens.fontSize.small * 0.85)
        }
    }
}
