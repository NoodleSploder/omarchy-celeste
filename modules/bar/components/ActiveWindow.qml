pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../core"
import "../../../components"

// App class dimmed above the window title, with a category icon.
//
// This follows THIS monitor's active window, not the globally focused one --
// on a multi-monitor setup a global binding makes every bar show the same
// title. A special workspace open on this monitor takes precedence, since that
// is what the user is actually looking at.
//
// The window is found by focusHistoryID rather than the workspace's `lastwindow`
// field: Hyprland's `activewindow` event refreshes toplevels but not workspaces,
// so `lastwindow` goes stale exactly when you switch apps within a workspace.
// focusHistoryID orders most-recently-focused first, so the lowest one wins.
Item {
    id: root

    required property var screen

    property color colour: Colours.palette.m3primary
    property int maxTextWidth: 260

    readonly property var monitor: Hyprland.monitorFor(root.screen)

    readonly property var monitorWs: {
        const mon = root.monitor;
        if (!mon)
            return null;
        const special = mon.lastIpcObject && mon.lastIpcObject.specialWorkspace
            ? mon.lastIpcObject.specialWorkspace.name : "";
        if (special)
            return Hyprland.workspaces.values.find(w => w.name === special) || mon.activeWorkspace;
        return mon.activeWorkspace;
    }

    readonly property var toplevel: {
        const ws = root.monitorWs;
        if (!ws || !ws.toplevels)
            return null;

        let active = null;
        let activeId = Infinity;
        for (const t of ws.toplevels.values) {
            const id = (t.lastIpcObject && t.lastIpcObject.focusHistoryID !== undefined)
                ? t.lastIpcObject.focusHistoryID : Infinity;
            if (id < activeId) {
                activeId = id;
                active = t;
            }
        }
        return active;
    }

    readonly property string appClass:
        (root.toplevel && root.toplevel.lastIpcObject) ? String(root.toplevel.lastIpcObject.class || "") : ""

    readonly property string windowTitle: {
        const title = root.toplevel ? root.toplevel.title : "";
        if (!title)
            return "Desktop";
        if (Config.bar.activeWindow.compact) {
            // Trim the leading document part of "doc - App" style titles:
            // " - " (hyphen), " — " (em dash), " – " (en dash).
            const parts = title.split(/\s+[\-–—]\s+/);
            if (parts.length > 1)
                return parts[parts.length - 1].trim();
        }
        return title;
    }

    clip: true
    implicitWidth: layout.implicitWidth
    implicitHeight: Tokens.sizes.bar.innerWidth

    RowLayout {
        id: layout

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: Tokens.spacing.small

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            animate: true
            text: root.toplevel ? "desktop_windows" : "desktop_access_disabled"
            color: root.colour
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            // Negative: the two lines are set tighter than their line boxes so
            // they read as one block rather than two stacked labels.
            spacing: -2

            StyledText {
                Layout.fillWidth: true
                Layout.maximumWidth: root.maxTextWidth

                animate: true
                visible: root.appClass.length > 0
                text: root.appClass
                font.pointSize: Math.round(Tokens.fontSize.small * 0.78)
                color: Colours.palette.m3outline
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                Layout.maximumWidth: root.maxTextWidth

                animate: true
                text: root.windowTitle
                font.pointSize: Math.round(Tokens.fontSize.small * 0.95)
                color: root.colour
                elide: Text.ElideRight
            }
        }
    }
}
