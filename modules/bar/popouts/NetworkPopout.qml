pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../components"
import "../../../services"

ColumnLayout {
    spacing: Tokens.spacing.extraSmall

    StyledText {
        text: "Network"
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.fontSize.small
    }

    RowLayout {
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: Net.icon
            color: Net.connected ? Colours.palette.m3primary : Colours.palette.m3outline
        }

        ColumnLayout {
            spacing: -2

            StyledText {
                text: Net.label || "Resolving…"
                color: Colours.palette.m3onSurface
            }

            StyledText {
                visible: Net.wireless && Net.strength > 0
                text: `${Net.strength}%`
                color: Colours.palette.m3outline
                font.pointSize: Math.round(Tokens.fontSize.small * 0.85)
            }
        }
    }
}
