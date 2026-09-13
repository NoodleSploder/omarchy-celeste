pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../../core"
import "../../../components"
import "../../../services"

// Open-window list for one running app, grouped by window class. There is no
// generic "app menu" a DBus-less window can hand over the way a system-tray
// item can (see services/Apps.qml) -- this is the practical equivalent:
// every open window of that app, click to focus, with a close button per row.
ColumnLayout {
    id: root

    required property string appClass

    readonly property var group: Apps.groupFor(root.appClass)
    readonly property var windows: root.group ? root.group.windows : []
    readonly property string displayName: {
        const entry = DesktopEntries.heuristicLookup(root.appClass);
        return (entry && entry.name) || root.appClass;
    }
    readonly property string iconSource: Apps.iconSource(root.appClass)

    spacing: Tokens.spacing.medium

    RowLayout {
        Layout.fillWidth: true; Layout.preferredWidth: 420; spacing: Tokens.spacing.medium

        IconImage {
            visible: root.iconSource !== ""
            implicitWidth: Tokens.font.icon.large.pointSize
            implicitHeight: Tokens.font.icon.large.pointSize
            source: root.iconSource
            asynchronous: true
        }
        MaterialIcon {
            visible: root.iconSource === ""
            text: Apps.fallbackGlyph
            fontStyle: Tokens.font.icon.large
            color: Colours.palette.m3primary
        }

        ColumnLayout {
            Layout.fillWidth: true; spacing: -2
            StyledText { Layout.fillWidth: true; text: root.displayName; elide: Text.ElideRight; color: Colours.palette.m3onSurface; font.pointSize: Tokens.fontSize.large; font.bold: true }
            StyledText {
                text: root.windows.length === 1 ? "1 window" : `${root.windows.length} windows`
                color: Colours.palette.m3outline; font.pointSize: Tokens.fontSize.small; font.bold: true
            }
        }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colours.palette.m3outlineVariant }

    Repeater {
        model: root.windows
        delegate: Rectangle {
            id: windowRow
            required property var modelData
            readonly property bool isActive: {
                const t = Hyprland.activeToplevel;
                return !!(t && t.address === windowRow.modelData.address);
            }
            Layout.fillWidth: true; implicitHeight: Tokens.spacing.extraLarge; radius: Tokens.rounding.full
            color: windowRow.isActive ? Colours.palette.m3surfaceContainerHighest : "transparent"

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: Tokens.padding.medium; anchors.rightMargin: Tokens.padding.medium; spacing: Tokens.spacing.medium
                MaterialIcon { text: "desktop_windows"; color: windowRow.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: -2
                    StyledText {
                        Layout.fillWidth: true; elide: Text.ElideRight
                        text: Apps.windowTitle(windowRow.modelData) || "Untitled window"
                        color: Colours.palette.m3onSurface; font.bold: windowRow.isActive
                    }
                    StyledText {
                        visible: text !== ""
                        text: Apps.workspaceName(windowRow.modelData)
                        color: Colours.palette.m3outline; font.pointSize: Tokens.fontSize.small
                    }
                }
                MaterialIcon {
                    text: "close"; color: Colours.palette.m3outline; fontStyle: Tokens.font.icon.small
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Apps.close(windowRow.modelData) }
                }
            }
            MouseArea {
                anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor
                onClicked: Apps.focus(windowRow.modelData)
            }
        }
    }

    StyledText {
        visible: root.windows.length === 0
        text: "No open windows"; color: Colours.palette.m3outline; font.pointSize: Tokens.fontSize.small
    }
}
