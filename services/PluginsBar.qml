pragma Singleton

// State for the Plugins bar button (modules/bar/components/Plugins.qml) and
// its expandable strip (modules/bar/PluginsStrip.qml).
//
// Hovering the button previews the strip; clicking it pins the strip open --
// same "hover previews, click pins" convention Tray.qml/StatusIcons.qml/
// RunningApps.qml already use for their own popouts. The difference here is
// that `pinned` is deliberately its OWN boolean rather than reusing the
// shared Popout's popoutName mechanism: the user asked for a way to make the
// strip "static", i.e. survive mouse movement elsewhere on the bar and other
// popouts opening, not just "stays open until the next unrelated click" the
// way the existing popout-pinning behaviour works.
//
// A single global singleton, not per-monitor state: every monitor's Plugins
// button and strip watch the same pinned/hovered state, the same pattern
// SidePanel.qml already uses for the OSD ("every monitor watches the same
// global state independently").

import QtQuick

QtObject {
    id: root

    property bool pinned: false
    property bool hovered: false

    readonly property bool open: root.pinned || root.hovered

    function togglePinned() {
        root.pinned = !root.pinned;
    }
}
