pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../../../components"

// Time, an optional separator dot and the date, on one line. Clicking it opens
// the dashboard -- there is deliberately no keybind for the dashboard, so this
// is its primary entry point.
StyledRect {
    id: root

    signal dashboardRequested(int tab)

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background ? Tokens.padding.medium : Tokens.padding.extraSmall
    readonly property int pointSize: Math.round(Tokens.fontSize.small * 1.1)

    implicitWidth: layout.implicitWidth + root.padding * 2
    implicitHeight: Tokens.sizes.bar.innerWidth

    color: Config.bar.clock.background
        ? Colours.tPalette.m3surfaceContainer
        : Qt.alpha(Colours.tPalette.m3surfaceContainer, 0)
    radius: Tokens.rounding.full

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.dashboardRequested(0)
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.extraSmall

        Loader {
            Layout.alignment: Qt.AlignVCenter
            asynchronous: true
            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Config.services.useTwelveHourClock
                ? `${Time.hourStr}:${Time.minuteStr} ${Time.amPmStr.toLowerCase()}`
                : `${Time.hourStr}:${Time.minuteStr}`
            font.pointSize: root.pointSize
            color: root.colour
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            asynchronous: true
            active: Config.bar.clock.showDate
            visible: active

            sourceComponent: StyledText {
                text: "•"
                font.pointSize: root.pointSize
                color: Colours.palette.m3outline
            }
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            asynchronous: true
            active: Config.bar.clock.showDate
            visible: active

            sourceComponent: StyledText {
                text: Time.format("dddd, MM/dd")
                font.pointSize: root.pointSize
                color: root.colour
            }
        }
    }
}
