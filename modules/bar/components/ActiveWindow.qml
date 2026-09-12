pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../../core"
import "../../../components"

// Focused window title, elided. Width is capped rather than left to the layout
// so a long title cannot push the rest of the bar around.
Item {
    id: root

    readonly property var toplevel: ToplevelManager.activeToplevel
    readonly property bool compact: Config.bar.activeWindow.compact
    readonly property string title: root.toplevel ? root.toplevel.title : ""
    readonly property int maxWidth: root.compact ? 320 : 520

    implicitWidth: Math.min(layout.implicitWidth, root.maxWidth)
    implicitHeight: Tokens.sizes.bar.innerWidth
    clip: true

    RowLayout {
        id: layout

        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: root.toplevel ? "desktop_windows" : "desktop_access_disabled"
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: root.maxWidth - Tokens.sizes.bar.innerWidth
            text: root.title || "Desktop"
            color: Colours.palette.m3onSurface
            elide: Text.ElideRight
            animate: true
        }
    }
}
