pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../components"
import "../../../services"

ColumnLayout {
    spacing: Tokens.spacing.extraSmall

    StyledText {
        text: "Battery"
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.fontSize.small
    }

    RowLayout {
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: Battery.icon
            color: Battery.low ? Colours.palette.m3error : Colours.palette.m3primary
        }

        ColumnLayout {
            spacing: -2

            StyledText {
                text: Battery.present ? `${Battery.percent}%` : "No battery"
                color: Colours.palette.m3onSurface
            }

            StyledText {
                visible: Battery.present
                text: Battery.charging ? "Charging"
                    : Battery.fullyCharged ? "Fully charged"
                    : Battery.discharging ? "On battery" : "Plugged in"
                color: Colours.palette.m3outline
                font.pointSize: Math.round(Tokens.fontSize.small * 0.85)
            }
        }
    }
}
