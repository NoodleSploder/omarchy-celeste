pragma ComponentBehavior: Bound

import QtQuick
import "../../core"
import "../../components"

// Celeste's settings panel: a nav list on the left, the selected page on the
// right. Built as a structure rather than a single page because more pages
// are coming -- adding one is an entry in `pages` plus a file.
//
// An Item root with hand-set implicit sizes, not a Layout: MenuPanel sizes
// itself from this item's implicitWidth/implicitHeight, and a Layout root
// silently recomputes its own implicitWidth from its children on every
// relayout (documented in CLAUDE.md), which would throw the fixed panel width
// away.
//
// Every control in here is click-driven, deliberately. The settings panel has
// no keyboard-focus wiring -- Bar.qml primes WlrKeyboardFocus only for the
// launcher -- so a text field here would silently never receive a keystroke,
// which is the exact trap that made the launcher's search box dead on arrival
// once before.
Item {
    id: root

    readonly property var pages: [
        { id: "topbar", label: "Top Bar" },
        { id: "system", label: "System" }
    ]

    property string current: "topbar"

    implicitWidth: 760
    implicitHeight: 520

    StyledText {
        id: title

        anchors.left: parent.left
        anchors.top: parent.top
        text: "Celeste Settings"
        font: Tokens.font.body.large
        color: Colours.palette.m3onSurface
    }

    Rectangle {
        id: titleRule

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        anchors.topMargin: Tokens.padding.small
        implicitHeight: 1
        color: Colours.palette.m3outlineVariant
    }

    // ---------------------------------------------------------------- nav

    Column {
        id: nav

        anchors.left: parent.left
        anchors.top: titleRule.bottom
        anchors.topMargin: Tokens.padding.medium
        anchors.bottom: parent.bottom
        width: 180
        spacing: Tokens.spacing.small

        Repeater {
            model: root.pages

            delegate: Rectangle {
                id: navItem

                required property var modelData
                readonly property bool selected: root.current === navItem.modelData.id

                width: nav.width
                implicitHeight: Tokens.sizes.bar.innerWidth
                radius: Tokens.rounding.large
                color: navItem.selected
                    ? Colours.palette.m3secondaryContainer
                    : navArea.containsMouse ? Colours.palette.m3surfaceContainerHighest : "transparent"

                Behavior on color {
                    CAnim {}
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.verticalCenter: parent.verticalCenter
                    text: navItem.modelData.label
                    font: Tokens.font.body.normal
                    color: navItem.selected
                        ? Colours.palette.m3onSecondaryContainer
                        : Colours.palette.m3onSurface
                }

                MouseArea {
                    id: navArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.current = navItem.modelData.id
                }
            }
        }
    }

    Rectangle {
        id: navRule

        anchors.left: nav.right
        anchors.leftMargin: Tokens.padding.medium
        anchors.top: nav.top
        anchors.bottom: parent.bottom
        implicitWidth: 1
        color: Colours.palette.m3outlineVariant
    }

    // --------------------------------------------------------------- page

    Loader {
        anchors.left: navRule.right
        anchors.leftMargin: Tokens.padding.medium
        anchors.right: parent.right
        anchors.top: nav.top
        anchors.bottom: parent.bottom

        sourceComponent: root.current === "topbar" ? topBarPage
            : root.current === "system" ? systemPage
            : null
    }

    Component {
        id: topBarPage

        TopBarSettings {}
    }

    Component {
        id: systemPage

        SystemSettings {}
    }
}
