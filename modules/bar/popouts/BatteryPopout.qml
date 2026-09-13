pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../components"
import "../../../services"

// Mirrors Omarchy's own power panel (plugins/panels/power/Panel.qml): hero
// (icon, rotating status phrase, percentage), a charge progress bar, a
// size/cycles/time/rate stats grid, then the power-profile picker.
ColumnLayout {
    id: root

    spacing: Tokens.spacing.medium

    Component.onCompleted: Battery.watchDetails()
    Component.onDestruction: Battery.unwatchDetails()

    // Layout.preferredWidth is what actually pins the popout's width -- see
    // the comment on AudioPopout's divider for why a plain implicitWidth on
    // the root ColumnLayout does not work. It has to go on the hero row
    // specifically here (not a divider below): everything below the hero is
    // `visible: Battery.present`, and an invisible item is excluded from
    // ColumnLayout's size computation entirely, so pinning it there would
    // silently do nothing on a no-battery machine.
    RowLayout {
        Layout.fillWidth: true; Layout.preferredWidth: 800; spacing: Tokens.spacing.medium
        MaterialIcon { text: Battery.icon; color: Battery.low ? Colours.palette.m3error : Colours.palette.m3primary; fontStyle: Tokens.font.icon.large }
        ColumnLayout {
            Layout.fillWidth: true; spacing: -2
            StyledText { text: "Battery"; color: Colours.palette.m3onSurface; font.pointSize: Tokens.fontSize.large; font.bold: true }
            StyledText {
                animate: true
                visible: text !== ""
                text: Battery.heroStatusText.toUpperCase()
                color: Colours.palette.m3outline; font.pointSize: Tokens.fontSize.small; font.bold: true
            }
        }
        StyledText {
            visible: Battery.present
            text: `${Battery.percent}%`; color: Colours.palette.m3onSurface
            font.pointSize: Tokens.fontSize.extraLarge; font.bold: true
        }
    }

    Item {
        Layout.fillWidth: true; implicitHeight: Tokens.spacing.small; visible: Battery.present
        Rectangle { anchors.fill: parent; radius: height / 2; color: Colours.palette.m3surfaceContainerHighest }
        Rectangle {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            height: parent.height; radius: height / 2
            width: Math.max(height, parent.width * Battery.percentage)
            color: Battery.low ? Colours.palette.m3error : Colours.palette.m3primary
            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; visible: Battery.present; color: Colours.palette.m3outlineVariant }

    GridLayout {
        Layout.fillWidth: true
        visible: Battery.hasInfo
        columns: 4
        columnSpacing: Tokens.spacing.large
        rowSpacing: Tokens.spacing.extraSmall

        StatLabel { text: "Battery size" }
        StatValue { Layout.fillWidth: true; text: Battery.info.size || "—" }
        StatLabel { text: "Charge cycles" }
        StatValue { Layout.fillWidth: true; text: Battery.info.cycles || "—" }

        StatLabel { text: Battery.discharging ? "Time left" : "Time to full" }
        StatValue { Layout.fillWidth: true; text: Battery.batteryFull ? "-" : (Battery.info.time || "—") }
        StatLabel { text: Battery.discharging ? "Discharging" : "Charging" }
        StatValue { Layout.fillWidth: true; text: Battery.batteryFull ? "-" : (Battery.info.rate || "—") }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; visible: Battery.profiles.length > 0; color: Colours.palette.m3outlineVariant }

    ColumnLayout {
        Layout.fillWidth: true
        visible: Battery.profiles.length > 0
        spacing: Tokens.spacing.small

        StyledText { text: "POWER PROFILE"; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.fontSize.small; font.bold: true }

        RowLayout {
            Layout.fillWidth: true; spacing: Tokens.spacing.small
            Repeater {
                model: Battery.profiles
                delegate: Rectangle {
                    id: profilePill
                    required property string modelData
                    readonly property bool active: Battery.activeProfile === profilePill.modelData
                    Layout.fillWidth: true; implicitHeight: Tokens.spacing.extraLarge * 1.6; radius: Tokens.rounding.large
                    color: "transparent"
                    border.width: 1
                    border.color: profilePill.active ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

                    ColumnLayout {
                        anchors.centerIn: parent; spacing: Tokens.spacing.extraSmall
                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: Battery.profileIcon(profilePill.modelData)
                            color: profilePill.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Battery.profileLabel(profilePill.modelData)
                            color: profilePill.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            font.bold: profilePill.active
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Battery.setProfile(profilePill.modelData) }
                }
            }
        }
    }

    StyledText {
        visible: !Battery.present
        text: "No battery"; color: Colours.palette.m3outline; font.pointSize: Tokens.fontSize.small
    }

    component StatLabel: StyledText {
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.fontSize.small
        opacity: 0.8
    }

    component StatValue: StyledText {
        horizontalAlignment: Text.AlignRight
        color: Colours.palette.m3onSurface
        font.pointSize: Tokens.fontSize.small
        font.bold: true
        elide: Text.ElideRight
    }
}
