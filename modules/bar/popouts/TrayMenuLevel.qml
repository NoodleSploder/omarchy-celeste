pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../../core"
import "../../../components"

// One level of a tray item's DBus menu. Submenus nest a further instance of
// this file INSIDE the level that opened them, which is the whole point:
//
//   A QsMenuEntry is owned by the QsMenuOpener that vended it. Rendering a
//   submenu by reassigning one shared opener's `menu` to the child entry does
//   not fire the entry's AboutToShow round-trip (Remmina's "OU (2)" came back
//   as "Empty menu"), and rebuilding that shared opener instead destroys the
//   parent that owns the entry, invalidating the very handle being opened.
//   Nesting keeps every ancestor opener alive for as long as its descendant is
//   on screen, and each level's opener is CONSTRUCTED with its handle rather
//   than having it reassigned later -- same shape as the local Caelestia
//   install's modules/bar/popouts/TrayMenu.qml SubMenu/StackView approach.
//
// Recursion goes through Loader.setSource(url, {...}) rather than naming the
// type directly: a QML file instantiating itself by type name is a circular
// import, and setSource's initial-properties map is also what guarantees
// `handle` is in place before the child's opener is created.
ColumnLayout {
    id: level

    property var handle: null
    property bool isRoot: false

    // Raised by a non-root level's Back row; the parent clears childEntry.
    signal closeRequested

    property var childEntry: null

    spacing: Tokens.spacing.small

    onChildEntryChanged: {
        if (level.childEntry)
            childLoader.setSource(Qt.resolvedUrl("TrayMenuLevel.qml"), {
                handle: level.childEntry,
                isRoot: false
            });
        else
            childLoader.setSource("");
    }

    QsMenuOpener {
        id: opener

        menu: level.handle
    }

    // This level's own rows, replaced by the submenu while one is open.
    ColumnLayout {
        Layout.fillWidth: true
        visible: level.childEntry === null
        spacing: Tokens.spacing.small

        Item {
            Layout.fillWidth: true
            visible: !level.isRoot
            implicitHeight: backRow.implicitHeight

            RowLayout {
                id: backRow

                anchors.left: parent.left
                spacing: Tokens.spacing.small

                MaterialIcon { text: "chevron_left"; color: Colours.palette.m3primary }
                StyledText { text: "Back"; color: Colours.palette.m3primary; font.bold: true }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: level.closeRequested()
            }
        }

        Repeater {
            model: opener.children

            delegate: Rectangle {
                id: entryRow

                required property var modelData

                Layout.fillWidth: true
                visible: !entryRow.modelData.isSeparator
                implicitHeight: entryRow.modelData.isSeparator ? 1 : Tokens.spacing.extraLarge
                radius: Tokens.rounding.full
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    IconImage {
                        visible: entryRow.modelData.icon !== ""
                        implicitWidth: Tokens.fontSize.large
                        implicitHeight: Tokens.fontSize.large
                        source: entryRow.modelData.icon
                        asynchronous: true
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: entryRow.modelData.text
                        color: entryRow.modelData.enabled ? Colours.palette.m3onSurface : Colours.palette.m3outline
                    }

                    MaterialIcon {
                        visible: entryRow.modelData.hasChildren
                        text: "chevron_right"
                        color: entryRow.modelData.enabled ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3outline
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: entryRow.modelData.enabled && !entryRow.modelData.isSeparator
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (entryRow.modelData.hasChildren)
                            level.childEntry = entryRow.modelData;
                        else
                            entryRow.modelData.triggered();
                    }
                }
            }
        }

        StyledText {
            visible: opener.children.values.length === 0
            text: "Empty menu"
            color: Colours.palette.m3outline
            font.pointSize: Tokens.fontSize.small
        }
    }

    Loader {
        id: childLoader

        Layout.fillWidth: true

        onLoaded: item.closeRequested.connect(function () {
            level.childEntry = null;
        })
    }
}
